defmodule OpentelemetryAshTest do
  use ExUnit.Case

  defmodule Resource do
    use Ash.Resource, domain: OpentelemetryAshTest.Domain

    actions do
      defaults([:read, :destroy, create: :*, update: :*])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(Resource)
    end
  end

  require OpenTelemetry.Tracer

  setup do
    :application.stop(:opentelemetry)
    :application.set_env(:opentelemetry, :tracer, :ot_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    Application.put_env(:ash, :tracer, [OpentelemetryAsh])
    Application.put_env(:opentelemetry_ash, :trace_types, [:action, :changeset])
    :ok
  end

  test "retains parent span information" do
    OpenTelemetry.Tracer.with_span "span-1" do
      Ash.create!(Resource, %{name: "name"})
    end

    assert_receive {:span,
                    {:span, _, _, _, _, _, "changeset:resource:create", _, _, _, _, _, _, _, _, _,
                     _}}

    assert_receive {:span,
                    {:span, _, _, _, _, _, "domain:resource.create", _, _, _, _, _, _, _, _, _, _}}

    assert_receive {:span, {:span, _, _, _, _, _, "span-1", _, _, _, _, _, _, _, _, _, _}}
  end

  test "set_metadata merges metadata as ash-prefixed span attributes" do
    OpenTelemetry.Tracer.with_span "span-with-metadata" do
      OpentelemetryAsh.set_metadata(:action, %{
        domain: OpentelemetryAshTest.Domain,
        action: :read,
        authorize?: true,
        actor: %{id: 1}
      })

      OpentelemetryAsh.set_metadata(:action, %{resource_short_name: "resource"})
    end

    assert_receive {:span,
                    {:span, _, _, _, _, _, "span-with-metadata", _, _, _, attributes, _, _, _, _,
                     _, _}}

    assert %{
             "ash.domain" => "OpentelemetryAshTest.Domain",
             "ash.action" => "read",
             "ash.authorize?" => true,
             "ash.resource_short_name" => "resource"
           } = :otel_attributes.map(attributes)

    refute Map.has_key?(:otel_attributes.map(attributes), "ash.actor")
  end

  test "set_metadata with no current span is a no-op" do
    assert OpentelemetryAsh.set_metadata(:action, %{action: :read}) == :ok
  end
end
