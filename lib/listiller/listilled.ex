defmodule PhoenixLiveViewExt.Listilled do
  @moduledoc """
  Listilled behaviour should be implemented by the modules (e.g. LiveView components) assuming the concern
  of their state-to-assigns transformation where such assigns then need to get compared and diffed (listilled)
  by the Listiller before getting actually assigned for the LiveComponent list rendering. This is to avoid
  updating (replacing) the appended (or prepended) container list with elements that haven't really changed
  which for LiveView is the default behavior when dealing with element lists.

  LiveComponent templates rendered by relying on the assigns constructed with this module need to take into account
  the `:updated` assign and interpret it according to the `t:updated/0` docs. The same is also used in the Javascript
  element sorting code.
  """

  @typedoc """
  The state is typically a map of domain/business logic structure assigns. It contains caller-relative normalized
  structures which require transforming into assigns of the component-children, the functions of which the state
  is passed to.
  """
  @type state() :: term() | nil
  @type state_version() :: non_neg_integer()
  @type listilled() :: module()
  @type component_id() :: String.t()
  @type sort_data() :: { component_id(), state_version()}

  @typedoc """
  - `:noop` instructs of patching without sorting; intended for actual element updates or `:full` insertions
    (replacements)
  - `:delete` instructs of rendering the marked-for-deletion variation of the LiveComponent element
  - `{ :sort, { dst :: component_id(), state_version()}}` instructs of sorting the element i.e. inserting it before
     the provided destination element dom id.
  """
  @type updated() :: :noop | :delete | { :sort, sort_data()}
  @type assigns() :: %{
                       :updated => updated(),
                       optional( atom()) => any()
                     }
  @type diff_id() :: term()


  @doc """
  Checks if any distilling-relevant portion of the provided state has changed.
  This is an optional callback that, if defined, is invoked before distilling any assigns from the state.
  It should be defined to provide simple, comparison based checking as an alternative to constructing assigns
  if there are no changes in the state.
  """
  @callback state_changed?( old :: state(), new :: state()) :: boolean()

  @doc """
  Returns the list of all element diff ids along with the provided state with its last moment updates if any.
  """
  @callback prepare_list( state()) :: { [ diff_id()], state()}

  @doc """
  Returns the component id string representation for the provided element diff id.
  The returned string value should not contain the ':' character for it is later used as a separator between the
  component_id and the state version when sorting.
  """
  @callback component_id( diff_id(), state()) :: component_id()

  @doc """
  Returns the component name if different than the module last name without the "Component" suffix.
  Optional callback.
  """
  @callback component_name() :: String.t()

  @doc "Constructs component assigns from the provided model state."
  @callback construct_assigns( state(), diff_id()) :: assigns()

  @optional_callbacks state_changed?: 2, component_name: 0


  # Returns the module list version socket assign key
  @spec get_version( listilled(), state()) :: non_neg_integer()
  def get_version( listilled, state) do
    version_key =
      listilled
      |> listilled_name()
      |> version_key()

    state[ version_key] || 1
  end

  # Returns the Listilled module component name either as one optionally provided by the Listilled module
  # or, if absent, as the module's last name without the "Component" suffix.
  @spec listilled_name( listilled()) :: String.t()
  def listilled_name( listilled) do
    unless function_exported?( listilled, :component_name, 0) do
      listilled
      |> to_string()
      |> Phoenix.Naming.unsuffix( "Component")
      |> Phoenix.Naming.resource_name()
    else
      listilled.component_name()
    end
  end

  # Returns list assigns key for the provided listilled name string.
  @spec list_assigns_key( String.t()) :: atom()
  def list_assigns_key( listilled_name) do
    String.to_atom( "#{ listilled_name}_list_assigns")
  end

  # Returns list update key for the provided listilled name string.
  @spec list_update_key( String.t()) :: atom()
  def list_update_key( listilled_name) do
    String.to_atom( "#{ listilled_name}_list_update")
  end

  # Returns list version key for the provided listilled name string.
  @spec version_key( String.t()) :: atom()
  def version_key( listilled_name) do
    String.to_atom( "#{ listilled_name}_list_version")
  end
end
