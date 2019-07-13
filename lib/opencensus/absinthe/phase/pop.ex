defmodule Opencensus.Absinthe.Phase.Pop do
  @moduledoc false

  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Phase
  alias Opencensus.Absinthe.Acc

  @impl true
  @spec run(Blueprint.t(), keyword()) :: Phase.result_t()
  def run(blueprint, _opts \\ []) do
    acc = Acc.get(blueprint)

    {status, error_count} =
      case blueprint do
        %{result: %{errors: errors}} -> {:error, length(errors)}
        _ -> {:ok, 0}
      end

    :oc_trace.put_attributes(
      %{
        "absinthe.blueprint.error_count" => error_count,
        "absinthe.blueprint.status" => Atom.to_string(status)
      },
      acc.span_ctx
    )

    # Finish our span, even if it isn't current:
    :oc_trace.finish_span(acc.span_ctx)
    # Restore our parent span:
    :ocp.with_span_ctx(acc.parent_span_ctx)

    {:ok, blueprint}
  end
end
