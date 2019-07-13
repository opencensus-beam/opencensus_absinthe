use Mix.Config

if Mix.env() == :test do
  config :opencensus,
    send_interval_ms: 1,
    reporters: [{Opencensus.Absinthe.TestSupport.SpanCaptureReporter, []}]
end

config :logger,
  backends: [:console],
  level: :warn
