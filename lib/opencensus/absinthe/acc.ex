defmodule Opencensus.Absinthe.Acc do
  @moduledoc false

  @accumulator_key :opencensus_absinthe

  @typedoc "Our Accumulator within the blueprint."
  @type t :: %__MODULE__{
          span_ctx: :opencensus.span_ctx(),
          parent_span_ctx: :opencensus.span_ctx() | :undefined
        }
  @enforce_keys [:span_ctx, :parent_span_ctx]
  defstruct [:span_ctx, :parent_span_ctx]

  @doc "Update the blueprint `bp` with our accumulator `acc`."
  def set(%Absinthe.Blueprint{} = bp, our_acc) do
    acc = bp.execution.acc |> Map.put(@accumulator_key, our_acc)
    put_in(bp.execution.acc, acc)
  end

  @doc "Get our accumulator from a blueprint `bp`."
  def get(%Absinthe.Blueprint{} = bp) do
    bp.execution.acc[@accumulator_key]
  end

  @doc "Get our accumulator from a resolution `r`."
  def get(%Absinthe.Resolution{} = r) do
    r.acc[@accumulator_key]
  end
end
