defmodule OpentelemetryAsh do
  @moduledoc """
  Documentation for `OpentelemetryAsh`.
  """

  use Ash.Tracer
  require OpenTelemetry.Tracer

  @impl Ash.Tracer
  def start_span(type, name) do
    parent_span = OpenTelemetry.Tracer.current_span_ctx()

    s =
      OpenTelemetry.Tracer.start_span(name, %{
        kind: :client,
        attributes: %{
          type: type
        }
      })

    OpenTelemetry.Tracer.set_current_span(s)

    Process.put(:opentelemetry_ash_span_stack, [
      {s, parent_span} | Process.get(:opentelemetry_ash_span_stack, [])
    ])

    :ok
  end

  @impl Ash.Tracer
  def stop_span do
    [{span, parent_span} | rest] = Process.get(:opentelemetry_ash_span_stack)
    OpenTelemetry.Tracer.end_span(span)

    OpenTelemetry.Tracer.set_current_span(parent_span)

    Process.put(:opentelemetry_ash_span_stack, rest)

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
      Application.get_env(:opentelemetry_ash, :trace_types) || [:custom, :action]

    is_nil(allowed_types) || Enum.member?(allowed_types, type)
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

  # Ash may call this multiple times per span; `OpenTelemetry.Span.set_attributes/2`
  # merges into the attributes already set on the span, satisfying the documented
  # contract of `Ash.Tracer.set_metadata/2`.
  @impl Ash.Tracer
  def set_metadata(_type, metadata) do
    s = OpenTelemetry.Tracer.current_span_ctx()

    if s != :undefined do
      OpenTelemetry.Span.set_attributes(s, attributes(metadata))
    end

    :ok
  end

  defp attributes(metadata) do
    metadata
    |> Enum.flat_map(fn
      {key, value} when is_atom(key) ->
        case attribute_value(value) do
          :skip -> []
          converted -> [{"ash.#{key}", converted}]
        end

      _other ->
        []
    end)
  end

  # Converts a metadata value into an OpenTelemetry primitive attribute value.
  # Values that cannot be represented as a primitive (e.g. `actor` or `tenant`
  # terms) are skipped rather than stringified wholesale, to avoid exporting
  # arbitrary data onto spans.
  defp attribute_value(value) when is_boolean(value), do: value
  defp attribute_value(value) when is_binary(value), do: value
  defp attribute_value(value) when is_integer(value), do: value
  defp attribute_value(value) when is_float(value), do: value

  defp attribute_value(value) when is_atom(value) do
    case Atom.to_string(value) do
      "Elixir." <> name -> name
      name -> name
    end
  end

  defp attribute_value(_value), do: :skip

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
