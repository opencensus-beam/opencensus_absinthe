defmodule Opencensus.Absinthe.Phase.Pop do
  @moduledoc false

  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Phase

  @impl true
  @spec run(Blueprint.t(), keyword()) :: Phase.result_t()
  def run(blueprint, _opts \\ []) do
    :ocp.finish_span()
    {:ok, blueprint}
  end
end
