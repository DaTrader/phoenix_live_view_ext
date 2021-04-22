defmodule PhoenixLiveViewExt.Listilled.Helpers do
  @moduledoc """
  Implements helper functions intended for use in LiveView and LiveComponent templates relying on
  Listilled assign lists.
  """

  @doc "Returns the sort instruction string (or nil if :sort not specified)."
  @spec updated_sort( { :sort, dst :: String.t()}) :: String.t()
  def updated_sort( { :sort, dst_dom_id}), do: dst_dom_id
  def updated_sort( _), do: nil

  @doc "Returns container phx_update string based on the type of list update."
  @spec phx_update( :full | :partial) :: String.t()
  def phx_update( :full), do: "replace"
  def phx_update( :partial), do: "append"

end
