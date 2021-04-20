defmodule PhoenixLiveViewExt.MultiRender do
  @moduledoc """
  The module provides a @before_compile macro enabling multiple template files per live component or live view.
  Each template file gets pre-compiled as a private render/2 function in its live component or live view module.
  This in turn enables (conditional) invocation from the render/1 functions.

  The template files should share the component or live view folder and start with their respective underscored names.

  In the example below we have a component that requires a different template when flagged for deletion (as part of,
  say, an appended container list) than the one used in the base-case scenario.

      defmodule MyComponent do
        use Phoenix.LiveComponent
        require PhoenixLiveViewExt.MultiRender
        @before_compile PhoenixLiveViewExt.MultiRender

        @impl true
        def render( %{ delete: :true} = assigns) do
          render( "my_component_delete.html", assigns)
        end
        def render( assigns) do
          render( "my_component_enjoy.html", assigns)
        end
      end

  The component folder tree may look as follows:

      my_app
        lib
          my_app_web
            live
              components
                my_component.ex
                my_component_delete.html.leex
                my_component_enjoy.html.leex
                ..
  """

  defmacro __before_compile__( env) do
    render? = Module.defines?( env.module, { :render, 1})

    if render? do
      root = Path.dirname( env.file)
      pattern = template_pattern( env)
      templates = Phoenix.Template.find_all( root, pattern)

      for template <- templates do
        basename = Path.basename( template, Path.extname( template))
        relative_path = Path.relative_to_cwd( template)
        ext = template |> Path.extname() |> String.trim_leading( ".") |> String.to_atom()
        engine = Map.fetch!( Phoenix.Template.engines(), ext)
        ast = engine.compile( template, basename)

        quote do
          @external_resource unquote( relative_path)
          defp render( unquote( basename), var!( assigns)) when is_map( var!( assigns)) do
            unquote( ast)
          end
        end
      end
    end
  end

  defp template_pattern( env) do
    env.module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>( "*.html")
  end
end
