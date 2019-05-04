defmodule Opencensus.Absinthe.Phase.Push do
  @moduledoc false

  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Opencensus.Absinthe.Acc

  # Transform the blueprint. Called from the PID of the `Plug`, so we can rely on `:ocp`'s
  # maintenance of trace and span context in the process dictionary.
  @doc false
  @impl true
  @spec run(Blueprint.t(), keyword()) :: Absinthe.Phase.result_t()
  def run(blueprint, _opts \\ []) do
    parent_span_ctx = :ocp.with_child_span("Blueprint")
    span_ctx = :ocp.current_span_ctx()

    acc = %Acc{
      parent_span_ctx: parent_span_ctx,
      span_ctx: span_ctx
    }

    :ok = Opencensus.Absinthe.Logger.set_logger_metadata(acc.span_ctx)
    {:ok, blueprint |> Acc.set(acc)}
  end
end
