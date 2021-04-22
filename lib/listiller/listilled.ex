defmodule PhoenixLiveViewExt.Listilled do
  @moduledoc """
  Listilled behaviour should be implemented by the modules (e.g. LiveView components) assuming the concern
  of their state-to-assigns transformation where such assigns then need to get compared and diffed (listilled)
  by the Listiller before getting actually assigned for the LiveComponent list rendering. This is to avoid
  updating (replacing) the appended (or prepended) container list with elements that haven't really changed
  which for LiveView is the default behavior when dealing with element lists.

  LiveComponent templates rendered by relying on the assigns constructed with this module need to take into account
  the :updated assign and interpret it according to the presented in `t:updated/0`. The same is also used
  in the Javascript element sorting code.
  """

  @typedoc """
  - `:noop` instructs of patching without sorting; intended for actual element updates or :full insertions (replacements)
  - `:delete` instructs of rendering the marked-for-deletion variation of the LiveComponent element
  - `{ :sort, dst_id :: String.t()}` instructs of sorting the element before the provided
  """
  @type updated() :: :noop | :delete | { :sort, dst_id :: String.t()}
  @type assigns() :: %{ :updated => updated(), atom() => any()}
  @type state() :: term() | nil
  @typep diff_id() :: any()

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

  @doc "Returns the component id string representation of the provided element diff id."
  @callback component_id( diff_id()) :: String.t()

  @doc "Constructs component assigns from the provided model state."
  @callback construct_assigns( state(), diff_id()) :: assigns()

  @optional_callbacks state_changed?: 2
end
