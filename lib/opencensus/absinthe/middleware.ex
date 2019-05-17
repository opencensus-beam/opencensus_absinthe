defmodule Opencensus.Absinthe.Middleware do
  @moduledoc "`Absinthe.Middleware` for field resolution tracing."

  require Logger

  alias Absinthe.Resolution
  alias Absinthe.Type
  alias Opencensus.Absinthe.Acc

  @behaviour Absinthe.Middleware

  @impl true
  @spec call(Resolution.t(), term()) :: Resolution.t()
  def call(%Resolution{state: :unresolved} = resolution, field: field) do
    acc = Acc.get(resolution)

    span_options = %{
      attributes: field |> extract_metadata() |> Enum.into(%{}, &stringify_keys/1)
    }

    span_ctx = :oc_trace.start_span(field |> repr(), acc.span_ctx, span_options)
    middleware = resolution.middleware ++ [{{__MODULE__, :on_complete}, span_ctx: span_ctx}]
    %{resolution | middleware: middleware}
  end

  @doc false
  def on_complete(%{state: :resolved} = resolution, span_ctx: span_ctx) do
    :oc_trace.finish_span(span_ctx)
    resolution
  end

  defp extract_metadata(%Type.Field{} = field) do
    %{name: name, type: type} = field
    %{module: module, location: location} = field.__reference__

    [
      "absinthe.field.name": name,
      "absinthe.field.type": type |> repr(),
      "absinthe.field.module": module |> repr(),
      "absinthe.field.file": location.file,
      "absinthe.field.line": location.line
    ]
  end

  # Ensure attribute map keys are binaries, as required:
  # https://hexdocs.pm/opencensus/ocp.html#put_attribute-2
  # https://hexdocs.pm/opencensus/opencensus.html#type-attributes
  defp stringify_keys({k, v}), do: {k |> to_string(), v}

  @doc false
  @spec repr(term()) :: String.t()
  def repr(value)

  def repr(%Type.Field{} = field) do
    name = field.name
    module = field.__reference__.module |> repr()
    "#{module}:#{name}"
  end

  def repr(a) when is_nil(a), do: nil
  def repr(%Type.List{of_type: t}), do: "#{t |> repr()}[]"
  def repr(%Type.NonNull{of_type: t}), do: "#{t |> repr()}!"
  def repr(%_{} = struct), do: struct |> Map.get(:__struct__) |> to_string()
  def repr(a) when is_atom(a), do: a |> Atom.to_string() |> repr()
  def repr(s) when is_binary(s), do: s |> String.replace(~r/^Elixir\./, "")
  def repr(v), do: inspect(v)
end
