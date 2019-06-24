defmodule Opencensus.Absinthe do
  @moduledoc """
  Extends `Absinthe` to automatically create `opencensus` spans. Designed to work with whatever
  is producing spans upstream, e.g. `Opencensus.Plug`.

  ## Installation

  Assuming you're using `Absinthe.Plug`:

  Add `opencensus_absinthe` to your `deps` in `mix.exs`, using a tighter version constraint than:

  ```elixir
  {:absinthe_plug, ">= 0.0.0"},
  {:opencensus_absinthe, ">= 0.0.0"},
  ```

  Add a `:pipeline` to your `t:Absinthe.Plug.opts/0` to have it call
  `Opencensus.Absinthe.Plug.traced_pipeline/2`. If you're using `Phoenix.Router.forward/4`, for
  example:

  ``` elixir
  forward(
    path,
    Absinthe.Plug,
    # ... existing config ...
    pipeline: {Opencensus.Absinthe.Plug, :traced_pipeline}
  )
  ```

  If you already have a `pipeline`, you can define your own and call both to insert their phases.
  To work with `ApolloTracing`, for example:

  ```elixir
  def your_custom_pipeline(config, pipeline_opts \\ []) do
    config
    |> Absinthe.Plug.default_pipeline(pipeline_opts)
    |> ApolloTracing.Pipeline.add_phases()
    |> Opencensus.Absinthe.add_phases()
  end
  ```

  Worst case, you'll need to copy the code from the current `pipeline` target and add a call to
  `Opencensus.Absinthe.add_phases/1` as above.

  If you're using [`Dataloader`][dataloader], you will want to use the provided
  `Opencensus.Absinthe.Middleware.Dataloader` Absinthe plugin module in place of
  the default one for tracing batched resolutions. See the [module
  docs][internal_dataloader] for details.

  [dataloader]: https://github.com/absinthe-graphql/dataloader
  [internal_dataloader]: ???
  """

  alias Absinthe.Middleware
  alias Absinthe.Type

  @doc """
  Add tracing phases to an existing pipeline for blueprint resolution.

  ```elixir
  pipeline =
    Absinthe.Pipeline.for_document(schema, pipeline_opts)
    |> Opencensus.Absinthe.add_phases()
  ```
  """
  @spec add_phases(Absinthe.Pipeline.t()) :: Absinthe.Pipeline.t()
  def add_phases(pipeline) do
    pipeline
    |> Absinthe.Pipeline.insert_after(
      Absinthe.Phase.Blueprint,
      Opencensus.Absinthe.Phase.Push
    )
    |> Absinthe.Pipeline.insert_after(
      Absinthe.Phase.Document.Result,
      Opencensus.Absinthe.Phase.Pop
    )
  end

  @doc """
  Add tracing middleware for field resolution.

  Specifically, prepends `Opencensus.Absinthe.Middleware` to the `middleware` chain if the field
  has `trace` or `absinthe_telemetry` set in its metadata, e.g.:

  ```elixir
    field :users, list_of(:user), meta: [trace: true] do
      middleware(Middleware.Authorize, "superadmin")
      resolve(&Resolvers.Account.all_users/2)
    end
  ```
  """
  @spec middleware(
          [Middleware.spec(), ...],
          Type.Field.t(),
          Type.Object.t()
        ) :: [Middleware.spec(), ...]
  def middleware(middleware, field, _object) do
    if metaset(field, :trace) or metaset(field, :absinthe_telemetry) do
      [{Opencensus.Absinthe.Middleware, field: field}] ++ middleware
    else
      middleware
    end
  end

  @spec metaset(Type.Field.t(), atom()) :: boolean()
  defp metaset(field, atom), do: Type.meta(field, atom) == true
end
