defmodule Opencensus.Absinthe.TestSupport.SpanContext do
  @moduledoc "Converts `:opencensus.span_ctx` records to structs."

  require Record
  @fields Record.extract(:span_ctx, from_lib: "opencensus/include/opencensus.hrl")
  Record.defrecordp(:span_ctx, @fields)

  defstruct Keyword.keys(@fields)

  @doc "Convert a span context."
  @spec from(:opencensus.span_ctx() | :undefined) :: %__MODULE__{}
  def from(record)

  def from(record) when Record.is_record(record, :span_ctx),
    do: struct!(__MODULE__, span_ctx(record))

  def from(:undefined), do: nil
end
