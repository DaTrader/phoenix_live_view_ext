defmodule PhoenixLiveViewExt.Listiller do
  @moduledoc """
  Transforms new state relative to the old one into a list of LiveComponent assigns so as to leave out
  the assigns for any component for which the new state does not result changed after the transformation.
  In other words, it diffs the list of LiveComponent assigns resulting from the state-to-assigns transformation
  (the list of which components are typically rendered as children of an appended or prepended container element).

  The purpose of Listiller is to allow for optimal use of appended/prepended container lists where only
  the list elements that have actually changed are sent by LiveView from the server to the JS client when
  traversing the DOM changes.
  While this can be manually optimized for changes of the individual component instances by sending the
  changes via LiveView.send_update/3 such an approach to optimization will not suffice in cases with multiple
  component changes and, more importantly, in cases in which there are elements required for insertion to or
  deletion from the container list.

  The module uses :updated as a reserved key in the generated assigns, so developers need to make sure
  they don't use it for other purposes in the assigns they construct in `Listilled.construct_assigns/2`
  implementations of the Listilled behaviour.
  """
  alias PhoenixLiveViewExt.Listilled

  @typep assigns() :: Listilled.assigns()
  @typep state() :: Listilled.state()
  @typep payload() :: %{
                        old_state: state(),
                        new_state: state(),
                        inserted: MapSet.t()
                      }
  @typep diff_id() :: any()  # must be unique relative to the diffs
  @typep diff_insert() :: { :insert, { dst_id :: diff_id(), assigns()}}
  @typep diff_delete() :: { :delete, assigns()}
  @typep diff_update() :: { :update, assigns()}
  @typep diff() :: diff_insert() | diff_delete() | diff_update()


  # Define the then/2 function unless already defined in Kernel
  unless function_exported?( Kernel, :then, 2) do
    def then( value, fun) do
      fun.( value)
    end
  end


  @doc """
  Distills the assigns for the components handled by a module implementing the Listilled behaviour.

  Note:
  Due to the lack of access to the LiveView internally held diff state and the fact that we intentionally assign
  constructed assigns as temporary_assigns, this function invokes Listilled.construct_assigns/2 with both the
  new and old state in every cycle. Typically, this has no significant impact on the overall performance even
  with tens of thousands of elements and the approach was chosen over keeping the derived transformations
  as permanent assigns to reduce memory load on the LiveView instance as it is expected that most if not
  all of the state provided is already kept stored in the LiveView.
  """
  @spec apply( module(), state(), state()) :: { [ assigns()], :full | :partial}
  def apply( listilled, old_state, new_state) do
    if !function_exported?( listilled, :state_changed?, 2) or listilled.state_changed?( old_state, new_state) do
      { old_ids, old_state} = listilled.prepare_list( old_state)
      { new_ids, new_state} = listilled.prepare_list( new_state)
      list_update = old_ids == [] && :full || :partial
      assign_list =
        listill( List.myers_difference( old_ids, new_ids), listilled,
          %{
            old_state: old_state,
            new_state: new_state,
            inserted: MapSet.new()
          }, [])
        |> then( fn { _, _, diffs} -> list_assigns( diffs, list_update) end)
      { assign_list, list_update}
    else
      { [], :partial}
    end
  end


  # Recursively goes through a myers difference of row_id and by first collecting all diff_ids to be inserted
  # ensures those are not deleted as they are considered moved.
  # Relies on the gets_old_assigns and gets_new_assigns to fetch the assigns data and compare and them if different.
  @spec listill( Keyword.t(), module(), payload(), [ diff()]) :: { diff_id(), MapSet.t(), [ diff()]}
  defp listill( [], _, args, diffs) do
    { nil, args.inserted, diffs}
  end

  defp listill( [ { :eq, eq} | rest], listilled, args, diffs) do
    { _, inserted, diffs} = listill( rest, listilled, args, diffs)
    diffs =
      for diff_id <- Enum.reverse( eq),
          new_assigns = listilled.construct_assigns( args.new_state, diff_id),
          new_assigns != listilled.construct_assigns( args.old_state, diff_id),
          reduce: diffs
        do
        diffs -> [ { :update, new_assigns} | diffs]
      end
    [ dst_id | _] = eq
    { dst_id, inserted, diffs}
  end

  defp listill( [ { :ins, ins} | rest], listilled, args, diffs) do
    args = %{ args | inserted: MapSet.union( args.inserted, MapSet.new( ins))}
    { dst_id, inserted, diffs} = listill( rest, listilled, args, diffs)
    { dst_id, diffs} =
      for diff_id <- Enum.reverse( ins), reduce: { dst_id, diffs} do
        { dst_id, diffs} ->
          assigns = listilled.construct_assigns( args.new_state, diff_id)
          diff = { :insert, { dst_id && listilled.component_id( dst_id), assigns}}
          { diff_id, [ diff | diffs]}
      end
    { dst_id, inserted, diffs}
  end

  defp listill( [ { :del, del} | rest], listilled, args, diffs) do
    { dst_id, inserted, diffs} = listill( rest, listilled, args, diffs)
    del = Enum.reject( del, &MapSet.member?( inserted, &1)) # removes from deletion list all marked as inserted (moved)
    diffs =
      for diff_id <- Enum.reverse( del), reduce: diffs do
        diffs ->
          diff = { :delete, diff_id && listilled.construct_assigns( args.old_state, diff_id)}
          [ diff | diffs]
      end
    { dst_id, inserted, diffs}
  end


  # Returns the list of component assigns extracted from the supplied diffs.
  @spec list_assigns( [ diff()], :full | :partial) :: [ assigns()]
  defp list_assigns( diffs, list_update) do
    Enum.map( diffs, &diff_assigns( &1, list_update))
  end

  # Returns component assigns with sorting destination where :partial :insert
  # or :delete instruction where deleted.
  @spec diff_assigns( diff(), :full | :partial) :: assigns()
  defp diff_assigns( { :delete, assigns}, _) do
    Map.put( assigns, :updated, :delete)
  end

  defp diff_assigns( { :update, assigns}, _) do
    noop_assigns( assigns)
  end

  defp diff_assigns( { :insert, { _, assigns}}, :full) do
    noop_assigns( assigns)
  end

  defp diff_assigns( { :insert, { nil, assigns}}, _) do
    noop_assigns( assigns)
  end

  defp diff_assigns( { :insert, { dst_id, assigns}}, :partial) do
    Map.put( assigns, :updated, { :sort, dst_id})
  end

  defp noop_assigns( assigns) do
    Map.put( assigns, :updated, :noop)
  end
end
