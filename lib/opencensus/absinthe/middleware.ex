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
      attributes: field |> extract_metadata() |> Enum.into(%{}, &stringify_keys/1),
      kind: "SERVER"
    }

    span_ctx = :oc_trace.start_span(field |> extract_name(), acc.span_ctx, span_options)
    on_complete = {{__MODULE__, :on_complete}, span_ctx: span_ctx}
    %{resolution | middleware: resolution.middleware ++ [on_complete]}
  end

  @doc false
  def on_complete(%{state: :resolved} = resolution, span_ctx: span_ctx) do
    :oc_trace.finish_span(span_ctx)
    resolution
  end

  defp extract_name(%Type.Field{} = field) do
    name = field.name
    module = field.__reference__.module |> delixir()
    "#{module}:#{name}"
  end

  defp extract_metadata(%Type.Field{} = field) do
    %{name: name, type: type} = field
    %{module: module, location: location} = field.__reference__

    [
      field_name: name,
      field_type: type,
      field_module: module |> delixir(),
      field_file: location.file,
      field_line: location.line
    ]
  end

  # Ensure attribute map keys are binaries, as required:
  # https://hexdocs.pm/opencensus/ocp.html#put_attribute-2
  # https://hexdocs.pm/opencensus/opencensus.html#type-attributes
  defp stringify_keys({k, v}), do: {k |> to_string(), v}

  # Remove Elixir. from the front of the module name.
  defp delixir(a) when is_atom(a), do: a |> Atom.to_string() |> delixir()
  defp delixir(s) when is_binary(s), do: s |> String.replace(~r/^Elixir\./, "")
end
