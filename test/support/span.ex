defmodule Opencensus.Absinthe.TestSupport.Span do
  @moduledoc "Converts `:opencensus.span` records to structs."

  require Record
  @fields Record.extract(:span, from_lib: "opencensus/include/opencensus.hrl")
  Record.defrecordp(:span, @fields)

  defstruct Keyword.keys(@fields)

  @doc "Convert a span."
  @spec from(:opencensus.span()) :: %__MODULE__{}
  def from(record) when Record.is_record(record, :span), do: struct!(__MODULE__, span(record))
end
