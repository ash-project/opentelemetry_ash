defmodule OpentelemetryAsh do
  @moduledoc """
  Documentation for `OpentelemetryAsh`.
  """

  use Ash.Tracer
  require OpenTelemetry.Tracer

  @impl Ash.Tracer
  def start_span(type, name) do
    s =
      OpenTelemetry.Tracer.start_span(name, %{
        kind: :client,
        attributes: %{
          type: type
        }
      })

    OpenTelemetry.Tracer.set_current_span(s)

    :ok
  end

  @impl Ash.Tracer
  def trace_type?(:custom) do
    true
  end

  def trace_type?({:custom, type}) do
    trace_type?(type)
  end

  def trace_type?(type) do
    allowed_types =
      Application.get_env(:opentelemetry_ash, :trace_types) || [:custom, :action, :flow]

    is_nil(allowed_types) || Enum.member?(allowed_types, type)
  end

  @impl Ash.Tracer
  def stop_span do
    current = OpenTelemetry.Tracer.current_span_ctx()

    if current != :undefined do
      OpenTelemetry.Tracer.end_span()
    end

    :ok
  end

  @impl Ash.Tracer
  def get_span_context do
    parent_context =
      case OpentelemetryProcessPropagator.fetch_ctx(self()) do
        :undefined ->
          OpentelemetryProcessPropagator.fetch_parent_ctx(1, :"$callers")

        ctx ->
          ctx
      end

    %{
      parent_context: parent_context
    }
  end

  @impl Ash.Tracer
  def set_span_context(%{parent_context: parent_context}) do
    if parent_context != :undefined do
      OpenTelemetry.Ctx.attach(parent_context)
    end

    :ok
  end

  @impl Ash.Tracer
  def set_metadata(_type, _metadata) do
    :ok
  end

  @impl Ash.Tracer
  def set_error(error, _opts \\ []) do
    s = OpenTelemetry.Tracer.current_span_ctx()

    if s != :undefined do
      OpenTelemetry.Span.set_status(s, OpenTelemetry.status(:error, format_error(error)))
    end

    :ok
  end

  defp format_error(%{__exception__: true} = exception) do
    Exception.message(exception)
  end

  defp format_error(_), do: ""
end
