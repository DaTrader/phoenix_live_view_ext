defmodule PhoenixLiveViewExt.Listilled.Helpers do
  @moduledoc """
  Provides helper functions intended for use in LiveView and LiveComponent templates relying on
  Listilled assign lists.
  """

  alias PhoenixLiveViewExt.{ Listilled, Listiller}
  alias Phoenix.LiveView.Socket
  @type listilled() :: module()


  @doc "Returns the sort instruction string (or nil if sorting not required)."
  @spec updated_sort( Listilled.updated()) :: String.t()
  def updated_sort( { :sort, sort_data}) do
    { component_id, state_version} = sort_data
    "#{ component_id}:#{ Integer.to_string( state_version, 36)}"
  end
  def updated_sort( _), do: nil


  @doc "Returns container `phx-update` attribute string based on the type of list update."
  @spec phx_update( Listiller.list_update()) :: String.t()
  def phx_update( :full), do: "replace"
  def phx_update( :partial), do: "append"


  @doc """
  Assigns the listilled list assigns, list update and state version to the socket.

  Uses the listilled name (a value return by Listilled.component_name/0 if defined, otherwise the last name of the
  module with the truncated "Component" suffix if any) and appends the following to form the atom keys:
  - <component_name>_list_assigns
  - <component_name>_list_update
  - <component_name>_list_version
  """
  @spec assign_list( Socket.t(), { [ Listilled.assigns()], Listiller.list_meta()}) :: Socket.t()
  def assign_list( socket, { list_assigns, meta}) do
    name = Listilled.listilled_name( meta.listilled)
    Phoenix.LiveView.assign( socket,
      %{
        Listilled.list_assigns_key( name) => list_assigns,
        Listilled.list_update_key( name) => meta.update,
        Listilled.version_key( name) => meta.version
      })
  end
end
