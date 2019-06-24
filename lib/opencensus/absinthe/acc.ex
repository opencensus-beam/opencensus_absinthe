defmodule Opencensus.Absinthe.Acc do
  @moduledoc false

  alias Absinthe.Blueprint
  alias Absinthe.Resolution
  alias Absinthe.Blueprint.Execution

  @accumulator_key :opencensus_absinthe

  @typedoc "Our Accumulator within the blueprint."
  @type t :: %__MODULE__{
          span_ctx: :opencensus.span_ctx(),
          parent_span_ctx: :opencensus.span_ctx() | :undefined
        }
  @enforce_keys [:span_ctx, :parent_span_ctx]
  defstruct [:span_ctx, :parent_span_ctx]

  @spec set(Blueprint.t(), any()) :: map()
  def set(%Blueprint{} = bp, our_acc) do
    put_in(bp.execution.acc, Map.put(bp.execution.acc, @accumulator_key, our_acc))
  end

  @spec set(Execution.t(), any()) :: map()
  def set(%Execution{} = exec, our_acc), do
    put_in(exec.acc, Map.put(exec.acc, @accumulator_key, our_acc))
  end

  @spec get(Blueprint.t() | Resolution.t()) :: t()
  def get(blueprint_or_resolution)
  def get(%Blueprint{} = bp), do: bp.execution.acc[@accumulator_key]
  def get(%Resolution{} = r), do: r.acc[@accumulator_key]
  def get(%Execution{} = exec), do: exec.acc[@accumulator_key]
end
