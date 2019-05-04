defmodule Opencensus.Absinthe.Logger do
  @moduledoc false

  require Record

  Record.defrecordp(
    :ctx,
    Record.extract(:span_ctx, from_lib: "opencensus/include/opencensus.hrl")
  )

  # Scheduled for demolition; see amplifiedai/opencensus_absinthe#6
  @spec set_logger_metadata(:opencensus.span_ctx() | :undefined) :: :ok
  def set_logger_metadata(span)
  def set_logger_metadata(:undefined), do: set_logger_metadata(nil, nil, nil)

  def set_logger_metadata(span) do
    set_logger_metadata(
      List.to_string(:io_lib.format("~32.16.0b", [ctx(span, :trace_id)])),
      List.to_string(:io_lib.format("~16.16.0b", [ctx(span, :span_id)])),
      ctx(span, :trace_options)
    )
  end

  defp set_logger_metadata(trace_id, span_id, trace_options) do
    Logger.metadata(trace_id: trace_id, span_id: span_id, trace_options: trace_options)
    :ok
  end
end
