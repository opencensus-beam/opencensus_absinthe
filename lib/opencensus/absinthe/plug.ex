defmodule Opencensus.Absinthe.Plug do
  @moduledoc """
  Modify your `Absinthe.Plug` pipeline for `Opencensus.Absinthe`:

  ## Installation

  Specify `traced_pipeline/2` as your `pipeline` in your `t:Absinthe.Plug.opts/0`, e.g. via
  `Phoenix.Router.forward/4`:

  ```elixir
  forward "/graphql", Absinthe.Plug,
    schema: MyApp.Schema,
    pipeline: {Opencensus.Absinthe.Plug, :traced_pipeline}
  ```
  """

  @doc """
  Return the default pipeline with tracing phases.

  See also:

  * `Absinthe.Pipeline.for_document/2`.
  * `Absinthe.Plug.default_pipeline/1`.
  """
  def traced_pipeline(config, pipeline_opts \\ []) do
    config
    |> Absinthe.Plug.default_pipeline(pipeline_opts)
    |> Opencensus.Absinthe.add_phases()
  end
end
