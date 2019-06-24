# Opencensus.Absinthe

[![CircleCI](https://circleci.com/gh/opencensus-beam/opencensus_absinthe.svg?style=svg)](https://circleci.com/gh/opencensus-beam/opencensus_absinthe)
[![Hex version badge](https://img.shields.io/hexpm/v/opencensus_absinthe.svg)](https://hex.pm/packages/opencensus_absinthe)

Extends [Absinthe] to automatically create [OpenCensus] spans. Designed to
work with whatever is producing spans upstream, e.g. [Opencensus.Plug].

[Absinthe]: http://absinthe-graphql.org
[Opencensus.Plug]: https://github.com/opencensus-beam/opencensus_plug
[OpenCensus]: http://opencensus.io

## Installation

* Take the dependency
* Set up the pipeline
* Set up the middleware
* Adjust your schema
* Check it's all working

### Dependency

If you're using `Absinthe.Plug`, add `opencensus_absinthe` to your `deps`
in `mix.exs` using a tighter version constraint than:

```elixir
{:absinthe_plug, ">= 0.0.0"},
{:opencensus_absinthe, ">= 0.0.0"},
```

### Pipeline

Add a `:pipeline` to your `t:Absinthe.Plug.opts/0` to have it call
`Opencensus.Absinthe.Plug.traced_pipeline/2`. If you're using
`Phoenix.Router.forward/4`, for example:

``` elixir
forward(
  path,
  Absinthe.Plug,
  # ... existing config ...
  pipeline: {Opencensus.Absinthe.Plug, :traced_pipeline}
)
```

If you already have a `pipeline`, you can define your own and call both to
insert their phases. To work with `ApolloTracing`, for example:

```elixir
def your_custom_pipeline(config, pipeline_opts \\ []) do
  config
  |> Absinthe.Plug.default_pipeline(pipeline_opts)
  |> ApolloTracing.Pipeline.add_phases()
  |> Opencensus.Absinthe.add_phases()
end
```

Worst case, you'll need to copy the code from the current `pipeline` target
and add a call to `Opencensus.Absinthe.add_phases/1` as above.

### Middleware

Your [middleware callback][c:middleware/3] needs to run its output through
the matching function in `Opencensus.Absinthe.Middleware` to add the
middleware to only the fields that need it:

```elixir
def middleware(middleware, field, object) do
  Opencensus.Absinthe.middleware(middleware, field, object)
end
```

If you've already got some middleware, like above, you might need to copy
some code around to get the job done:

```elixir
def middleware(middleware, field, object) do
  ([ApolloTracing.Middleware.Tracing, ApolloTracing.Middleware.Caching] ++ middleware)
  |> Opencensus.Absinthe.middleware(field, object)
end
```

[c:middleware/3]: https://hexdocs.pm/absinthe/Absinthe.Schema.html#c:middleware/3

If you're using [`Dataloader`][dataloader], you will want to use the provided
`Opencensus.Absinthe.Middleware.Dataloader` Absinthe plugin module in place of
the default one for tracing batched resolutions. See the [module
docs][internal_dataloader] for details.

[dataloader]: https://github.com/absinthe-graphql/dataloader
[internal_dataloader]: ???

### Schema

Until Absinthe merge and publish their telemetry support (see below) _and_
you upgrade, you'll also need to set `:trace` in the metadata for any
`field` for which you want tracing to happen:

```elixir
  query do
    @desc "List all the things"
    field :things, list_of(:thing), meta: [trace: true] do
      resolve(&Resolvers.Account.all_things/2)
    end
```

Once you're on a telemetry-capable Absinthe, you'll get tracing for every
`field` containing a `resolve`.

### Verification

Check your installation with `iex -S mix phx.server`, assuming Phoenix, and:

    iex> :oc_reporter.register(:oc_reporter_stdout)

Fire off a few requests and check the `{span, <<NAME>` lines on standard
output.

* If you see names matching your GraphQL route, e.g. `<</api>>`, you set up
  `opencensus_plug` properly.

* If you see `<<"Absinthe.Blueprint">>`, the pipeline is working.

* If you see `<<"YourProject.Schema:thefield">>`, the middleware is working
  and you've either:

  * Added `meta: [trace: true]` to your `field :thefield` as above, or

  * Upgraded to a telemetry-capable Absinthe.

## Behaviour

Each Absinthe query runs in the process of its caller. If you hook up
[`opencensus_plug`][opencensus_plug], or something else that'll take trace
details off the wire, the process dictionary will have an `:oc_span_ctx_key`
key used by [`opencensus`][opencensus] to keep track of spans in flight.

This package adds new [phases] to your [Absinthe Pipeline][pipeline]
to start new spans for each [resolution] and call, using both methods
available:

> `opencensus` provides two methods for tracking \[trace and span] context,
> the process dictionary and a variable holding a ctx record.

Specifically, this package:

* Starts a new span registered in the process dictionary for each query, and

* _Without any use of the process dictionary_, starts a new span for each
  field, using the query span as the parent.

The latter is necessary because the fields don't necessarily start and stop
without overlap. Naïve use of `:ocp.with_child_span` and `:ocp.finish_span`
will yield incorrect traces.

[pipeline]: https://hexdocs.pm/absinthe/Absinthe.Pipeline.html
[phases]: https://hexdocs.pm/absinthe/Absinthe.Phase.html
[resolution]: https://hexdocs.pm/absinthe/Absinthe.Resolution.html
[opencensus]: https://hex.pm/packages/opencensus
[opencensus_plug]: https://hex.pm/packages/opencensus_plug

## Development

Dependency management:

* `mix deps.get` to get your dependencies
* `mix deps.compile` to compile them
* `mix licenses` to check their license declarations, recursively

Finding problems:

* `mix compile` to compile your code
* `mix credo` to suggest more idiomatic style for it
* `mix dialyzer` to find problems static typing might spot... *slowly*
* `mix test` to run unit tests
* `mix test.watch` to run the tests again whenever you change something
* `mix coveralls` to check test coverage

Documentation:

* `mix docs` to generate documentation for this project
* `mix help` to find out what else you can do with `mix`

### Next Steps

Obvious next steps include stronger tests and many minor tweaks:

* Rename the outer span according to the schema
* Set some attributes on the outer span
* Trim the path from references so it starts with the closest `lib`
* Set the span status on completion
* Retire `lib/opencensus/absinthe/logger.ex` when possible

The biggest looming change would be telemetry integration:

[`absinthe-graphql/absinthe#663`][PR663] to add [`telemetry`][telemetry] to
Absinthe could give us start and stop calls from within the calling process
suitable for calling `:ocp.with_child_span` and `:ocp.finish_span` to
maintain the main trace. In turn, that'd mean we didn't need the pipeline.

`#663` won't help us generate spans for fields, because there's no way to
pass state back through `:telemetry.execute`. That said, it'll automatically
set `:absinthe_telemetry` in the field metadata if `query` is present.

[PR663]: https://github.com/absinthe-graphql/absinthe/pull/663
[telemetry]: https://hex.pm/packages/telemetry

Rather than push back on the telemetry support to make it better support
tracing, we could integrate this capability directly with Absinthe if:

* The community deploy a lot of `opencensus`
* It proves to be as lightweight and stable as `telemetry`
* Its impact when not hooked up is minimal or zero

We could then retire this module except for users with older versions.
