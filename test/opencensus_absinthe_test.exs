defmodule Opencensus.AbsintheTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Opencensus.Absinthe.TestSupport.SpanCaptureReporter
  alias Opencensus.Absinthe.TestSupport.SpanContext

  defmodule MyApp.Schema do
    use Absinthe.Schema

    @impl Absinthe.Schema
    def middleware(middleware, field, object) do
      Opencensus.Absinthe.middleware(middleware, field, object)
    end

    query do
      field :item, :item, meta: [trace: true] do
        arg(:id, non_null(:integer))

        resolve(fn %{id: item_id}, _ ->
          case item_id do
            0 -> {:ok, %{id: 0, name: "Foo"}}
            _ -> {:error, %ArgumentError{message: "404 NOT FOUND"}}
          end
        end)
      end

      field :simulated_error, :item, meta: [trace: true] do
        arg(:id, non_null(:integer))

        resolve(fn %{id: _}, _ ->
          {:error, "Something went horribly wrong."}
        end)
      end

      field :simulated_crash, :item, meta: [trace: true] do
        arg(:id, non_null(:integer))

        resolve(fn %{id: _}, _ ->
          IO.inspect(:ocp.current_span_ctx(), label: "naughty resolver current_span_ctx")
          raise ArgumentError, message: "NAUGHTY RESOLVER"
        end)
      end
    end

    @desc "An item"
    object :item do
      field(:id, :integer)
      field(:name, :string)
    end
  end

  defmodule SpanPopper do
    @spec unwind_span_failures(:opencensus.span_ctx() | %SpanContext{}) :: nil
    def unwind_span_failures(target_span_ctx) when is_tuple(target_span_ctx) do
      target_span_ctx
      |> SpanContext.from()
      |> dead_child_spans(:ocp.current_span_ctx(), [])
      |> IO.inspect(label: "dead spans")
      |> Enum.each(&:oc_trace.finish_span(&1))

      :ocp.with_span_ctx(target_span_ctx |> IO.inspect(label: "restoring"))
    end

    @spec dead_child_spans(%SpanContext{}, :opencensus.span_ctx(), [:opencensus.span_ctx()]) :: [
            :opencensus.span_ctx()
          ]
    defp dead_child_spans(%SpanContext{} = target, span_ctx, spans) do
      %{span_id: span_id, trace_id: trace_id} = target

      case SpanContext.from(span_ctx) do
        %{span_id: ^span_id} ->
          spans |> Enum.reverse()

        %{trace_id: ^trace_id} ->
          dead_child_spans(target, :oc_trace.parent_span_ctx(span_ctx), [span_ctx | spans])

        _ ->
          []
      end
    end
  end

  defmodule MyApp.TracePlug do
    use Opencensus.Plug.Trace
  end

  defmodule MyApp.Plug do
    use Plug.Builder

    plug(MyApp.TracePlug)

    plug(Absinthe.Plug,
      json_codec: Jason,
      schema: MyApp.Schema,
      pipeline: {__MODULE__, :traced_pipeline}
    )

    def call(conn, opts) do
      span_ctx = :ocp.current_span_ctx()

      try do
        super(conn, opts)
      after
        SpanPopper.unwind_span_failures(span_ctx)
      end
    end

    def traced_pipeline(config, pipeline_opts \\ []) do
      config
      |> Absinthe.Plug.default_pipeline(pipeline_opts)
      |> Opencensus.Absinthe.add_phases()
    end
  end

  setup_all do
    :ok = Application.ensure_started(:mime)
    :ok = Application.ensure_started(:plug_crypto)
    :ok = Application.ensure_started(:plug)
    :ok = Application.ensure_started(:telemetry)
    :ok
  end

  setup do
    old_ctx = :ocp.current_span_ctx()
    on_exit(make_ref(), fn -> :ocp.with_span_ctx(old_ctx) end)
    :ocp.with_span_ctx(:undefined)

    SpanCaptureReporter.attach()
    on_exit(make_ref(), &SpanCaptureReporter.detach/0)

    :ocp.with_child_span("test span")
    span_ctx = :ocp.current_span_ctx()
    assert span_ctx != :undefined

    %{span_ctx: span_ctx}
  end

  describe "integration tests:" do
    test "happy path", %{span_ctx: span_ctx} do
      result =
        conn(:post, "/", ~S'{ item(id: 0) { name } }')
        |> put_req_header("content-type", "application/graphql")
        |> put_req_header("traceparent", traceparent(span_ctx))
        |> Plug.Parsers.call(plug_parser_opts())
        |> MyApp.Plug.call(MyApp.Plug.init([]))

      assert result.status == 200
      assert result.resp_body == ~S'{"data":{"item":{"name":"Foo"}}}'

      assert :ocp.current_span_ctx() == span_ctx
      :ocp.finish_span()

      spans = SpanCaptureReporter.collect() |> Enum.sort_by(& &1.start_time)
      [_, request_span, blueprint_span, field_span] = spans

      assert request_span.name == "/"

      assert_contains!(blueprint_span, %{
        name: "Blueprint",
        trace_id: request_span.trace_id,
        parent_span_id: request_span.span_id
      })

      assert blueprint_span.attributes == %{
               "absinthe.blueprint.error_count" => 0,
               "absinthe.blueprint.status" => "ok"
             }

      assert_contains!(field_span, %{
        name: "Opencensus.AbsintheTest.MyApp.Schema:item",
        trace_id: blueprint_span.trace_id,
        parent_span_id: blueprint_span.span_id
      })

      assert Map.keys(field_span.attributes) == [
               "absinthe.field.file",
               "absinthe.field.line",
               "absinthe.field.module",
               "absinthe.field.name",
               "absinthe.field.resolution_error_count",
               "absinthe.field.resolution_status",
               "absinthe.field.type"
             ]

      assert_contains!(field_span.attributes, %{
        "absinthe.field.module" => "Opencensus.AbsintheTest.MyApp.Schema",
        "absinthe.field.name" => "item",
        "absinthe.field.resolution_error_count" => 0,
        "absinthe.field.resolution_status" => "ok"
      })
    end

    test "field resolver error", %{span_ctx: span_ctx} do
      result =
        conn(:post, "/", ~S'{ simulated_error(id: 0) { name } }')
        |> put_req_header("content-type", "application/graphql")
        |> put_req_header("traceparent", traceparent(span_ctx))
        |> Plug.Parsers.call(plug_parser_opts())
        |> MyApp.Plug.call(MyApp.Plug.init([]))

      assert result.status == 200

      assert result.resp_body |> Jason.decode!() == %{
               "data" => %{"simulated_error" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 0, "line" => 1}],
                   "message" => "Something went horribly wrong.",
                   "path" => ["simulated_error"]
                 }
               ]
             }

      assert :ocp.current_span_ctx() == span_ctx
      :ocp.finish_span()

      spans = SpanCaptureReporter.collect() |> Enum.sort_by(& &1.start_time)
      [_, request_span, blueprint_span, field_span] = spans

      assert request_span.name == "/"

      assert_contains!(blueprint_span, %{
        name: "Blueprint",
        trace_id: request_span.trace_id,
        parent_span_id: request_span.span_id
      })

      assert blueprint_span.attributes == %{
               "absinthe.blueprint.error_count" => 1,
               "absinthe.blueprint.status" => "error"
             }

      assert_contains!(field_span, %{
        name: "Opencensus.AbsintheTest.MyApp.Schema:simulated_error",
        trace_id: blueprint_span.trace_id,
        parent_span_id: blueprint_span.span_id
      })

      assert Map.keys(field_span.attributes) == [
               "absinthe.field.file",
               "absinthe.field.line",
               "absinthe.field.module",
               "absinthe.field.name",
               "absinthe.field.resolution_error_count",
               "absinthe.field.resolution_status",
               "absinthe.field.type"
             ]

      assert_contains!(field_span.attributes, %{
        "absinthe.field.module" => "Opencensus.AbsintheTest.MyApp.Schema",
        "absinthe.field.name" => "simulated_error",
        "absinthe.field.resolution_error_count" => 1,
        "absinthe.field.resolution_status" => "error"
      })
    end

    defp traceparent(span_ctx) do
      [{"traceparent", iolist}] = :oc_propagation_http_tracecontext.to_headers(span_ctx)
      iolist |> to_string
    end

    test "field resolver crash", %{span_ctx: span_ctx} do
      result =
        try do
          conn(:post, "/", ~S'{ simulated_crash(id: 0) { name } }')
          |> put_req_header("content-type", "application/graphql")
          |> put_req_header("traceparent", traceparent(span_ctx))
          |> Plug.Parsers.call(plug_parser_opts())
          |> MyApp.Plug.call(MyApp.Plug.init([]))
        rescue
          err -> err
        end

      # We got the error, all the way to the top:
      assert result == %ArgumentError{message: "NAUGHTY RESOLVER"}

      # Our traces got unwound:
      assert :ocp.current_span_ctx() == span_ctx
      :ocp.finish_span()

      # TODO the reason this isn't working the way we want is because we are NOT tracking the
      # resolver's trace using OCP. We need to find another way:
      [_, request_span, blueprint_span, field_span] =
        SpanCaptureReporter.collect()
        |> Enum.sort_by(& &1.start_time)
        |> IO.inspect(label: "all spans")

      assert request_span.name == "/"

      assert_contains!(blueprint_span, %{
        name: "Blueprint",
        trace_id: request_span.trace_id,
        parent_span_id: request_span.span_id
      })

      assert blueprint_span.attributes == %{
               "absinthe.blueprint.error_count" => 1,
               "absinthe.blueprint.status" => "error"
             }

      assert_contains!(field_span, %{
        name: "Opencensus.AbsintheTest.MyApp.Schema:simulated_error",
        trace_id: blueprint_span.trace_id,
        parent_span_id: blueprint_span.span_id
      })

      assert Map.keys(field_span.attributes) == [
               "absinthe.field.file",
               "absinthe.field.line",
               "absinthe.field.module",
               "absinthe.field.name",
               "absinthe.field.resolution_error_count",
               "absinthe.field.resolution_status",
               "absinthe.field.type"
             ]

      assert_contains!(field_span.attributes, %{
        "absinthe.field.module" => "Opencensus.AbsintheTest.MyApp.Schema",
        "absinthe.field.name" => "simulated_error",
        "absinthe.field.resolution_error_count" => 1,
        "absinthe.field.resolution_status" => "error"
      })
    end

    test "bad query", %{span_ctx: span_ctx} do
      result =
        conn(:post, "/", ~S'{ error(id: "foo") { name } }')
        |> put_req_header("content-type", "application/graphql")
        |> put_req_header("traceparent", traceparent(span_ctx))
        |> Plug.Parsers.call(plug_parser_opts())
        |> MyApp.Plug.call(MyApp.Plug.init([]))

      assert result.status == 200

      assert result.resp_body |> Jason.decode!() == %{
               "errors" => [
                 %{
                   "locations" => [%{"column" => 0, "line" => 1}],
                   "message" => "Cannot query field \"error\" on type \"RootQueryType\"."
                 },
                 %{
                   "locations" => [%{"column" => 0, "line" => 1}],
                   "message" =>
                     "Unknown argument \"id\" on field \"error\" of type \"RootQueryType\"."
                 }
               ]
             }

      assert :ocp.current_span_ctx() == span_ctx
      :ocp.finish_span()

      [_, request_span, blueprint_span] =
        SpanCaptureReporter.collect() |> Enum.sort_by(& &1.start_time)

      assert request_span.name == "/"

      assert Map.take(blueprint_span, [:name, :trace_id, :parent_span_id]) == %{
               name: "Blueprint",
               trace_id: request_span.trace_id,
               parent_span_id: request_span.span_id
             }

      assert blueprint_span.attributes == %{
               "absinthe.blueprint.error_count" => 2,
               "absinthe.blueprint.status" => "error"
             }
    end
  end

  def assert_contains!(%_{} = bigger, smaller) when is_map(smaller),
    do: assert_contains!(Map.from_struct(bigger), smaller)

  def assert_contains!(bigger, smaller) when is_map(bigger) and is_map(smaller) do
    problems =
      smaller
      |> Map.to_list()
      |> Enum.map(&check_against(&1, bigger))
      |> Enum.filter(&(&1 != nil))

    assert problems == []
  end

  defp check_against({key, wanted}, map) when is_map(map) do
    got = Map.get(map, key)

    cond do
      not Map.has_key?(map, key) -> {:missing, key: key}
      got != wanted -> {:mismatch, key: key, got: got, wanted: wanted}
      true -> nil
    end
  end

  def plug_parser_opts,
    do:
      Plug.Parsers.init(
        parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
        json_decoder: Jason
      )
end
