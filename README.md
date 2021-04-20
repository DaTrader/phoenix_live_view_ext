# PhoenixLiveViewExt

A library of functional extensions to the Phoenix LiveView framework.

In its present version 1.0.0 we start off with the MultiRender module and we'll see where it takes us from there.

## MultiRender

PhoenixLiveViewExt.MultiRender is a multi-template alternative to the Phoenix.LiveView.Renderer.render/1 macro.
It pre-compiles as many template files as found collocated with and named after the live component or live view
module they relate to. In other words, it allows for conditional rendering of multiple template files per live component or
live view module, the functionality which is presently available in live components only if using the ~L sigil. 

Special credits go to José Valim for providing the instructions on how to properly approach the problem this module
is solving.

## Installation

This package can be installed by adding `phoenix_live_view_ext` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    { :phoenix_live_view_ext, "~> 1.0.0"}
  ]
end
```

## Docs

The docs can be found at [https://hexdocs.pm/phoenix_live_view_ext](https://hexdocs.pm/phoenix_live_view_ext).
