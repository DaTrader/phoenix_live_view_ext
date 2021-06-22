defmodule PhoenixLiveViewExt.Listiller do
  @moduledoc ~S'''
  Helps LiveView optimally insert, update and delete list elements while replacing the entire list only when absolutely
  necessary (i.e. when initialized).

  Transforms new state relative to the old one into a list of LiveComponent assigns so as to leave out the assigns of
  all listed component instances for which the new state does not result changed after the transformation. In other
  words, it diffs the list of LiveComponent assigns resulting from the state-to-assigns transformation (the components
  of which list are typically rendered as children of an appended or prepended container element).

  The purpose of Listiller is to allow for an optimal implementation of appended/prepended container lists where only
  the list elements that actually change get sent from the server to the JS client over the wire and patched when
  client-side LiveView traverses the DOM elements. While this could be otherwise manually achieved for individual
  component instances by sending changes via `LiveView.send_update/3` such an approach would not suffice in cases with
  multiple component changes and more importantly, in the cases where there are elements required for insertion to or
  deletion from the container list.

  The module relies on the reserved `:updated` key in the 'listilled' assigns, so developers need to make sure they
  don't use it for other purposes when constructing assigns in their `c:PhoenixLiveViewExt.Listilled.construct_assigns/2`
  callback implementations.

  Below we use an example to explain how to use Listiller step by step. We do so on a non-trivial example of a table
  (two dimensions of components - the row components and the cell components nested in them).

  ## TableView example

  Our example relies on the following assumptions:
  - `TableLive` module prepares the assigns for the corresponding `table_live.html.leex` template which lists all table
    rows. The assigns include a temporarily assigned list of rows to append/update mapped to `:row_list_assigns`. The
    list contains only the rows that have actually changed and are to be treated as inserted, updated or deleted.
  - `RowComponent` module prepares the assigns for the corresponding `row_component_t.html.leex` template which lists
    all cells in the row. Analogously, this involves the assigns used by the template itself as well as a temporarily
    assigned list of assigns for each cell that has actually changed (again, as in inserted, updated or deleted cells).
  - We implement the `CellComponent` module and the corresponding `cell_component.html_t.leex` template to render
    table cells.
  - The original state (the data model) that is held persistently assigned with `TableLive` is maintained in its
    domain-logic normalized form and both the temporary assigns for `RowComponent` and the ones for `CellComponent` are
    constructed dynamically. This is because any non-trivial real-life UC will most certainly not have its data kept
    optimally denormalized for the LiveView templates, while in the end the assigns need to be optimized for it is
    based on their diffing that the LiveView framework decides on what to send over the wire and what not.
  - Since an appended container in LiveView can only have its elements updated or appended, the final changes are
    performed in JS when we are sure that LiveView has applied all the necessary patches. The finalization involves
    deletion of the marked-for-deletion updated elements and sorting (repositioning) of the marked-for-sorting appended
    elements.

  The first step is to write our `TableLive` module. Note that the `:row_list_assigns` must be constructed and
  assigned each time the data may have possibly changed, involving all callbacks such as `handle_info` and
  `handle_event`.

      defmodule TableLive do
        use TableAppWeb, :live_view
        alias PhoenixLiveViewExt.{ Listiller, Listilled}

        # If relying on handle_params to initialize then the initialization should be done there instead.
        @impl true
        def mount( _params, _session, socket) do
          { :ok, initialize( socket), temporary_assigns: [ row_list_assigns: []]}
        end

        defp initialize( socket) do
          # passing an empty map to construct_rows to trigger a :full update, i.e. replacing the list
          construct_rows( socket, %{})
        end

        # handles events and optionally changes the state
        @impl true
        def handle_event( event, payload, socket) do
          { :noreply, socket
                      |> maybe_apply_changes( event, payload)
                      |> then( & &1.assigns.any_changes? && construct_rows( &1, socket.assigns) || &1)
          }
        end

        @impl true
        def handle_info( event, socket) do
          { :noreply, event
                      |> handle_server_response( socket)
                      |> construct_rows( socket.assigns)
          }
        end

        defp construct_rows( socket, old_state) do
          list_data = Listiller.apply( RowComponent, old_state, socket.assigns)

          Listilled.Helpers.assign_list( socket, list_data)
        end
      end

  Next we make `PhoenixLiveViewExt.Listilled.Helpers.phx_update/1` function available to our live view template..

      defmodule TableView do
        use TableAppWeb, :view
        import PhoenixLiveViewExt.Listilled.Helpers, only: [ phx_update: 1]
      end

  .. and we make sure we properly render the rows in our `table_live.html.leex`:

      ..
      <div id="table"
        phx-update="<%= phx_update( @row_list_update) %>"
        phx-hook="TableHook">
        <%= for row_assigns <- @row_list_assigns do %>
          <%= live_component @socket, RowComponent, row_assigns %>
        <% end %>
      </div>
      <div id="update-handler"
           class="hidden"
           data-print="<%= update_print( assigns) %>"
           phx-hook="UpdateHook"/>
      ..

  Note that we place the `update-handler` element _after_ the `table` element in our template. This is because we need
  this element's `updated` callback invoked in JS after we are sure that all our components have been rendered by
  LiveView. As a reminder, LiveView will invoke `updated` callbacks starting with the `table` element and followed by
  each component recursively i.e. in the exact same order the elements get patched top down, and since there is no
  `afterUpdated` callback, we need this extra element with its own hook. And we need it updated when and if any listed
  component is updated.

  We assure the latter is true by invoking a _function_ we pass the entire assigns map to so that LiveView cannot
  optimize and skip the update. The `update_print/1` function here returns a pseudo random number encoded as a string
  and is out of the scope of this library. The point is having the `UpdateHook`'s `updated` callback invoked once all
  elements in the lists have been patched by LiveView.

  Now we provide the `RowComponent` module which on one side is a `Listilled` `behaviour` implementation in charge of
  rendering its templates, and on the other it provides the necessary behavior to support its nested `CellComponents`.

      defmodule RowComponent do
        use Phoenix.LiveComponent
        alias PhoenixLiveViewExt.{ Listiller, Listilled}

        ########################
        # Cell container related
        #

        @impl true
        def mount( socket) do
          { :ok, socket, temporary_assigns: [ cell_list_assigns: nil]}
        end

        # Temporarily assigns the list of cell assigns for cell_components.
        @impl true
        def update( new_assigns, socket) do
          list_data = Listiller.apply( CellComponent, socket.assigns, new_assigns)

          socket =
            socket
            |> assign( new_assigns)
            |> Listilled.Helpers.assign_list( list_data)

          { :ok, socket}
        end

        ####################################
        # Listilled behaviour implementation
        #

        @behaviour Listilled

        # Prepares the row dom_id list and (optionally) supplements the provided state with any
        # additional data required for constructing the assigns.
        @impl true
        def prepare_list( state) do
          with %{ model: model} <- state do
            dom_ids = fetch_dom_ids( model)
            { dom_ids, state}
          else
            _ -> { [], state}
          end
        end

        # Returns dom_id as component_id
        @impl true
        def component_id( dom_id, _state) do
          dom_id
        end

        # Constructs new row assigns from the provided model state.
        @impl true
        def construct_assigns( state, dom_id) do
          # state-to-assigns transformations here
          ..
          %{
            id: dom_id, # component id
            # other assigns including state required to construct the cell assigns
            ..
          }
        end

        ##################
        # Template helpers
        #

        import Listilled.Helpers
        require PhoenixLiveViewExt.MultiRender
        @before_compile PhoenixLiveViewExt.MultiRender

        @impl true
        def render( %{ updated: :delete} = assigns) do
          ~L"""
          <div id="row-<%= @id %>" data-delete="true"></div>
          """
        end
        def render( assigns) do
          render( "row_component_t.html", assigns)
        end
      end

  Note that above we rely on the first available feature in the PhoenixLiveViewExt library v1.0.1 - the `MultiRender`
  `before_compile` macro that lets us define multiple (conditional) templates per LiveComponent.

  Also, take note that our `RowComponent` module imports both `Listiller.Helper` functions because its component's
  element requires post-append sorting while the template itself nests `CellComponents` thus requiring the `phx-update`
  attribute set relative to whether to `replace` or to `append` the cells that have changed.

  Below is the relevant part of our `row_component_t.html.leex` template:

      <div id="row-<%= @id %>"
           data-sort="<%= updated_sort( @updated) %>"
           phx-update="<%= phx_update( @cell_list_update) %>"
           phx-hook="RowHook">
        <%= for cell_assigns <- @cell_list_assigns do %>
          <%= live_component( @socket, CellComponent, cell_assigns) %>
        <% end %>
      </div>

  As imagined, our `CellComponent` next is relatively simple as it has no further nested components to pass the assigns
  to, and all it does is implement its `Listilled` behaviour and renders its templates.

      defmodule CellComponent do
        alias PhoenixLiveViewExt.Listilled
        @behaviour Listilled

        # Returns cell component id based on unique cell coordinates (a row dom_id and a cell key).
        @impl true
        def component_id( { dom_id, key}, _state) do
          "#{ dom_id}-#{ key}"
        end

        # Prepares the key list and returns it along with the state.
        @impl true
        def prepare_list( state) do
          with %{ keys: keys} <- state do
            { Enum.map( keys, &{ state.dom_id, &1}), state}
          else
            _ -> { [], state}
          end
        end

        # Constructs cell assigns from the provided segment state.
        @impl true
        def construct_assigns( state, { dom_id, key}) do
          # state-to-assigns transformations here
          ..
          %{
            id: component_id( { dom_id, key}),
            dom_id: dom_id,
            key: key,
            # other assigns
            ..
          }
        end

        ##################
        # Template helpers
        #

        import PhoenixLiveViewExt.Listilled.Helpers, only: [ updated_sort: 1]
        require PhoenixLiveViewExt.MultiRender
        @before_compile PhoenixLiveViewExt.MultiRender

        @impl true
        def render( %{ updated: :delete} = assigns) do
          ~L"""
          <div id="cell-<%= @dom_id %>-<%= @key %>" data-delete="true"></div>
          """
        end
        def render( assigns) do
          render( "cell_component_t.html", assigns)
        end
      end

  And the `cell_component_t.html.leex` template part required to operate:

      <div id="cell-<%= @dom_id %>-<%= @key %>"
         data-sort="<%= updated_sort( @updated) %>"
         phx-hook="CellHook">
         <!-- cell content -->
      </div>

  Finally, there is a file with JS helper functions shipped with our library. To import it in your LiveView app,
  simply add the following import before your JS code (app.js or the imported JS file therein):

      import {
        newListill,
        prepForSorting,
        completeListill,
        applyCall,
        initApplyCall,
        deinitApplyCall
      } from "../../deps/phoenix_live_view_ext/assets/js/listiller";

  The sample code below relies on the imported JS helper functions.

      export const TableHook = {
        mounted: function() {
          initHookState( this,
            {
              listill: newListill( 'sort', 'div[data-delete]')
            });
          initApplyCall( this);
        }
      };

      export const UpdateHook = {
        mounted: function() {
          applyCallToTable( data => setTable( this, data));
          completeTableListill( this);
        },
        updated: function() {
          completeTableListill( this);
        },
        destroyed: function() {
          deinitApplyCall( _table( this));
        }
      };

      function completeTableListill( me) {
        completeListill( _listill( _table( me)), _table( me).el);
      }


      export const RowHook = {
        mounted: function() {
          applyCallToTable( data => setTable( this, data));
          prepRowForSorting( this);
        },
        updated: function() {
          prepRowForSorting( this);
        }
      };

      function prepRowForSorting( me) {
        return prepForSorting( _listill( _table( me)), me.el, getRowSortId);
      }

      function getRowSortId( bareId) {
        return bareId ? ( 'row-' + bareId) : null;
      }


      export const CellHook = {
        mounted: function() {
          applyCallToTable( data => setTable( this, data));
          prepCellForSorting( this);
        },
        updated: function() {
          prepCellForSorting( this);
        }
      };

      function prepCellForSorting( me) {
        return prepForSorting( _listill( _table( me)), me.el, getCellSortId);
      }

      function getCellSortId( bareId) {
        return bareId ? ( 'cell-' + bareId) : null;
      }


      function initHookState( me, state) {
        me._vars = state;
      }

      function _table( me) {
        return me._tableObj;
      }

      function setTable( me, tableObj) {
        me._tableOb = tableObj;
      }

      function _listill( me) {
        return me._vars.listill;
      }
  '''
  alias PhoenixLiveViewExt.Listilled


  @type listilled() :: module()
  @type list_update() :: :full | :partial
  @type list_meta() :: %{
                         listilled: listilled(),
                         update: list_update(),
                         version: Listilled.state_version()
                       }
  @type state() :: Listilled.state()


  @typep script() :: [ { :eq | :ins | :del, list()}]
  @typep payload() :: %{
                        old_state: state(),
                        new_state: state(),
                        inserted: MapSet.t(),
                        version: Listilled.state_version()
                      }
  @typep diff_id() :: any()  # must be unique relative to the diffs
  @typep diff_insert() :: { :insert, { Listilled.sort_data() | nil, map()}}
  @typep diff_delete() :: { :delete, map()}
  @typep diff_update() :: { :update, map()}
  @typep diff() :: diff_insert() | diff_delete() | diff_update()


  # Define the then/2 function unless already defined in Kernel
  unless function_exported?( Kernel, :then, 2) do
    defp then( value, fun) do
      fun.( value)
    end
  end

  @doc """
  Distills a list of assigns for the provided component module implementing the Listilled behaviour.
  Returns a tuple with the list of assigns and the list meta data. The returned tuple may be passed as such to the
  Listilled.Helpers.assign_list/2 function to have the list assigns, the update type and the state version
  assigned to the socket.

  Raises ArgumentError if while diffing a `Listilled.component_id/2` function implementation returns a string value
  containing the ':' character.

  Note:
  Due to the lack of access to the LiveView internally held diff state and the fact that we intentionally assign
  constructed assigns as temporary_assigns, this function invokes `c:PhoenixLiveViewExt.Listilled.construct_assigns/2`
  on both the new and the old state in every cycle. Typically, this has no significant impact on the overall performance
  even with tens of thousands of elements and the approach was chosen over keeping the derived transformations as
  (persistent) assigns to reduce memory load on the LiveView instance for it is expected that most if not all of the
  state supplied to the function is already kept stored with in the LiveView instance.
  """
  @spec apply( listilled(), state(), state()) :: { [ Listilled.assigns()], list_meta()}
  def apply( listilled, old_state, new_state) do
    old_version = Listilled.get_version( listilled, old_state)

    if !function_exported?( listilled, :state_changed?, 2) or listilled.state_changed?( old_state, new_state) do
      { old_ids, old_state} = listilled.prepare_list( old_state)
      { new_ids, new_state} = listilled.prepare_list( new_state)
      list_update = old_ids == [] && :full || :partial
      new_version = old_version + 1

      assign_list =
        listill(
          List.myers_difference( old_ids, new_ids),
          listilled,
          %{
            old_state: old_state,
            new_state: new_state,
            inserted: MapSet.new(),
            version: new_version
          },
          []
        )
        |> then( fn { _, _, diffs} -> list_assigns( diffs, list_update) end)

      list_meta =
        new_list_meta( listilled, list_update, assign_list != [] && new_version || old_version)

      { assign_list, list_meta}
    else
      list_meta = new_list_meta( listilled, :partial, old_version)

      { [], list_meta}
    end
  end

  # Instantiates a new list_meta map
  @spec new_list_meta( listilled(), :full | :partial, non_neg_integer()) :: list_meta()
  defp new_list_meta( listilled, list_update, version) do
    %{
      listilled: listilled,
      update: list_update,
      version: version
    }
  end


  # Recursively goes through a myers difference of row_id and by first collecting all diff_ids to be inserted
  # ensures those are not deleted as they are considered moved.
  # Relies on the gets_old_assigns and gets_new_assigns to fetch the assigns data and compare and them if different.
  # Raises if at an element insertion Listilled.component_id/2 returns a string value containing a ':' character.
  @spec listill( script(), listilled(), payload(), [ diff()]) :: { diff_id(), MapSet.t(), [ diff()]}
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

    { List.first( eq), inserted, diffs}
  end

  defp listill( [ { :ins, ins} | rest], listilled, args, diffs) do
    args = %{ args | inserted: MapSet.union( args.inserted, MapSet.new( ins))}
    { dst_id, inserted, diffs} = listill( rest, listilled, args, diffs)

    { dst_id, diffs} =
      for diff_id <- Enum.reverse( ins), reduce: { dst_id, diffs} do
        { dst_id, diffs} ->
          sort_data =
            if dst_id do
              component_id = validate_id( listilled.component_id( dst_id, args.new_state))
              { component_id, args.version}
            end

          assigns = listilled.construct_assigns( args.new_state, diff_id)
          diff = { :insert, { sort_data, assigns}}

          { diff_id, [ diff | diffs]}
      end

    { dst_id, inserted, diffs}
  end

  defp listill( [ { :del, del} | rest], listilled, args, diffs) do
    { dst_id, inserted, diffs} = listill( rest, listilled, args, diffs)
    # removes from deletion list all marked as inserted (moved)
    del = Enum.reject( del, &MapSet.member?( inserted, &1))

    diffs =
      for diff_id <- Enum.reverse( del), reduce: diffs do
        diffs ->
          diff = { :delete, diff_id && listilled.construct_assigns( args.old_state, diff_id)}
          [ diff | diffs]
      end

    { dst_id, inserted, diffs}
  end

  @compile { :inline, validate_id: 1}
  # Ensures the component id string does not contain a ':' character or raises ArgumentError if it does.
  defp validate_id( id) when is_bitstring( id) do
    unless id =~ ":" do
      id
    else
      raise ArgumentError, "Component id (#{ inspect( id)}) contains a ':' character."
    end
  end


  # Returns the list of component assigns extracted from the supplied diffs.
  @spec list_assigns( [ diff()], :full | :partial) :: [ Listilled.assigns()]
  defp list_assigns( diffs, list_update) do
    Enum.map( diffs, &diff_assigns( &1, list_update))
  end

  # Returns component assigns with sorting destination where :partial :insert
  # or :delete instruction where deleted.
  @spec diff_assigns( diff(), :full | :partial) :: Listilled.assigns()
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

  defp diff_assigns( { :insert, { sort_data, assigns}}, :partial) do
    Map.put( assigns, :updated, { :sort, sort_data})
  end

  defp noop_assigns( assigns) do
    Map.put( assigns, :updated, :noop)
  end
end
