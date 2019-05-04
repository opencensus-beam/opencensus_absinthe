defmodule Opencensus.Absinthe.Phase.Pop do
  @moduledoc false

  use Absinthe.Phase

  @doc false
  @impl true
  @spec run(Absinthe.Blueprint.t(), keyword()) :: Absinthe.Phase.result_t()
  def run(blueprint, _opts \\ []) do
    :ocp.finish_span()
    {:ok, blueprint}
  end
end
