defmodule Opencensus.Absinthe.LoggerTest do
  use ExUnit.Case

  test "can set span" do
    # Make sure Logger doesn't already have any metadata
    assert Logger.metadata() == [], "setup: metadata not empty"
    :ocp.with_child_span("can set span")

    # Start a new span in the current process, and capture its details
    ctx = :ocp.current_span_ctx()
    {:span_ctx, trace_id, span_id, _, _} = ctx

    # Make sure Logger still doesn't have any metadata
    assert Logger.metadata() == [], "setup: ocp.with_child_span had unexpected side-effect"

    # Act
    Opencensus.Absinthe.Logger.set_logger_metadata(ctx)

    # Assert
    assert Logger.metadata() == [
             trace_options: 1,
             span_id: span_id |> hexify(16),
             trace_id: trace_id |> hexify(32)
           ]
  end

  test "can unset span" do
    # Make sure Logger doesn't already have any metadata
    assert Logger.metadata() == [], "setup: metadata not empty"

    # Give it some
    Logger.metadata(
      trace_options: 1,
      span_id: "b999f8f0c8cb65b3",
      trace_id: "82aebfb4ef02a0000000000000000001"
    )

    assert Logger.metadata() != []

    # Act
    Opencensus.Absinthe.Logger.set_logger_metadata(:undefined)

    # Assert
    assert Logger.metadata() == []
  end

  defp hexify(n, digits) do
    n
    |> Integer.to_string(16)
    |> String.pad_leading(digits, "0")
    |> String.downcase()
  end
end
