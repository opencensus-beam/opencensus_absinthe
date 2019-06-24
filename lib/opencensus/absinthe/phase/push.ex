defmodule Opencensus.Absinthe.Phase.Push do
  @moduledoc false

  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Phase
  alias Opencensus.Absinthe.Acc

  @impl true
  @spec run(Blueprint.t(), keyword()) :: Phase.result_t()
  def run(blueprint, opts \\ []) do
    child_span = Keyword.get(opts, :child_span, "Blueprint")
    parent_span_ctx = :ocp.with_child_span(child_span)
    span_ctx = :ocp.current_span_ctx()

    acc = %Acc{
      parent_span_ctx: parent_span_ctx,
      span_ctx: span_ctx
    }

    Opencensus.Absinthe.Logger.set_logger_metadata(span_ctx)
    {:ok, blueprint |> Acc.set(acc)}
  end
end
