defmodule Opencensus.Absinthe.Logger do
  @moduledoc false

  require Record

  Record.defrecordp(
    :ctx,
    Record.extract(:span_ctx, from_lib: "opencensus/include/opencensus.hrl")
  )

  @doc """
  Update the `Logger.metadata/1` in the process dictionary with our `span` details.

  See also:

  * `Opencensus.Plug.Trace.set_logger_metadata/1`
  * `OpencensusPhoenix.Instrumenter.set_logger_metadata/1`
  """
  @spec set_logger_metadata(:opencensus.span_ctx() | :undefined) :: :ok
  def set_logger_metadata(span)

  def set_logger_metadata(:undefined) do
    Logger.metadata(
      trace_id: nil,
      span_id: nil,
      trace_options: nil
    )

    :ok
  end

  def set_logger_metadata(span) do
    trace_id = List.to_string(:io_lib.format("~32.16.0b", [ctx(span, :trace_id)]))
    span_id = List.to_string(:io_lib.format("~16.16.0b", [ctx(span, :span_id)]))

    Logger.metadata(
      trace_id: trace_id,
      span_id: span_id,
      trace_options: ctx(span, :trace_options)
    )

    :ok
  end
end
