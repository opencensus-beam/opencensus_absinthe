defmodule Opencensus.Absinthe.Phase.SchemaPush do
  @moduledoc false

  use Absinthe.Phase

  @impl true
  @spec run(Blueprint.t(), keyword()) :: Phase.result_t()
  def run(blueprint, opts \\ []) do
    opts = Keyword.put_new(opts, :child_span, "Blueprint")
    Opencensus.Absinthe.Phase.Push.run(blueprint, opts)
  end
end
