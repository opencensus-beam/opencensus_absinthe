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
    @counter_key :dataloader_resolution_counter

    alias Opencensus.Absinthe.Acc
    alias Absinthe.Middleware.Dataloader, as: DefaultDataloader

    @doc """
    The `Absinthe.Plugin` callback. Starts the OpenCensus span.
    """
    def before_resolution(exec) do
      span_options = %{attributes: %{}}
      acc = Acc.get(exec)

      {counter, new_acc} =
        Map.get_and_update(acc, @counter_key, fn cur ->
          case cur do
            nil -> {cur, 1}
            x -> {x, x + 1}
          end
        end)

      span_ctx = :oc_trace.start_span("resolution_#{counter || 0}", acc.span_ctx, span_options)
      new_acc = Map.put(new_acc, @span_key, span_ctx)

      exec
      |> Acc.set(new_acc)
      |> DefaultDataloader.before_resolution()
    end

    @doc """
    The `Absinthe.Plugin` callback. Finishes the OpenCensus span.
    """
    def after_resolution(exec) do
      acc = Acc.get(exec)

      acc
      |> Map.get(@span_key)
      |> :oc_trace.finish_span()

      acc =
        exec
        |> Acc.get()
        |> Map.delete(@span_key)

      exec
      |> Acc.set(acc)
      |> DefaultDataloader.after_resolution()
    end

    def call(resolution, callback), do: DefaultDataloader.call(resolution, callback)
    def pipeline(pipeline, exec), do: DefaultDataloader.pipeline(pipeline, exec)
  end
end
