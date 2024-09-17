# Getting Started with OpentelemetryAsh

## Installation

Add `opentelemetry_ash` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:opentelemetry_ash, "~> 0.1.0"}
  ]
end
```

## Configuration

After installing the `opentelemetry_ash` dependency, add this to your config:

```elixir
# `config` supports a list, so this can be combined with other tracers
config :ash, :tracer, [OpentelemetryAsh]

# Optionally configure span types to be sent to opentelemetry. The default is
# [:custom, :action, :flow]
# We suggest using this list. It trims down some noisy traces that Ash emits
config :opentelemetry_ash,
  trace_types: [:custom, :action, :flow]
```

For all available types, see the documentation for `Ash.Tracer`.

Thats it! Opentelemetry should take care of the rest!
