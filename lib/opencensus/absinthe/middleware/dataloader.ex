if Code.ensure_loaded?(Dataloader) do
  defmodule Opencensus.Absinthe.Middleware.Dataloader do
    @moduledoc """
    This is a small extension on top of `Absinthe.Middleware.Dataloader` that
    will create spans for each resolution.

    ## Usage

    In your Absinthe schema, simply override the `plugins/0` callback (if you're
    not already) and prepend this plugin to the list:

        def plugins do
          [Opencensus.Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
        end
    """

    @behaviour Absinthe.Middleware
    @behaviour Absinthe.Plugin

    @span_key :dataloader_resolution_span_ctx

    alias Opencensus.Absinthe.Acc
    alias Absinthe.Middleware.Dataloader, as: DefaultDataloader

    def before_resolution(exec) do
      span_options = %{attributes: %{}}
      acc = Acc.get(exec)
      span_ctx = :oc_trace.start_span("resolution", acc.span_ctx, span_options)

      exec
      |> Acc.set(Map.put(acc, @span_key, span_ctx))
      |> DefaultDataloader.before_resolution()
    end

    def after_resolution(exec) do
      exec
      |> Acc.get()
      |> Map.get(@span_key)
      |> :oc_trace.finish_span()

      DefaultDataloader.after_resolution(exec)
    end

    def call(resolution, callback), do: DefaultDataloader.call(resolution, callback)
    def pipeline(pipeline, exec), do: DefaultDataloader.pipeline(pipeline, exec)
  end
end
