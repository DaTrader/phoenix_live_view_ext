# PhoenixLiveViewExt

A library of functional extensions to the Phoenix LiveView framework.

## MultiRender

PhoenixLiveViewExt.MultiRender is a multi-template alternative to the `Phoenix.LiveView.Renderer.render/1` macro.
It pre-compiles as many template files as found collocated with and named after the live component or live view
module they relate to. In other words, it allows for conditional rendering of multiple template files per live component
or live view module, the functionality which is presently available in live components only if using the ~L sigil. 

Special credits go to José Valim for providing the instructions on how to properly approach the problem this module
is solving.

## Listiller

Listiller (a.k.a. list distiller) handles assigns construction, diffing and pre-sorting required for an optimized
use of LiveView pre/appended container lists, whether of one dimension (e.g. shopping cards, todo lists, etc.) or more
nested ones (e.g. tables). 

With Listiller, LiveView only sends and traverses those elements in the list that have actually changed without
replacing the list as a whole which has a tremendous impact on performance whether it's about just updating a
single element or updating, inserting and deleting multiple elements all at the same time.

Again, credits to José Valim for helping with suggestions in the brainstorming phase of this feature.

## Installation

This package can be installed by adding `phoenix_live_view_ext` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    { :phoenix_live_view_ext, "~> 1.2.1"}
  ]
end
```

In JS file(s) where the hooks are defined, import the Listiller JS code as follows:

```
import {
  newListill,
  prepForSorting,
  completeListill,
  applyCall,
  initApplyCall,
  deinitApplyCall,
} from "../../deps/phoenix_live_view_ext/assets/js/listiller";
```

## Docs

The docs can be found at [https://hexdocs.pm/phoenix_live_view_ext](https://hexdocs.pm/phoenix_live_view_ext).

## Notes

- Formatting

  The source code formatting in this library diverges from the standard formatting practice based on using `mix format`
  in that there's a leading space character inserted before all first arguments and first elements for the purpose of
  (subject to author's personal perception) improving the code readability.
