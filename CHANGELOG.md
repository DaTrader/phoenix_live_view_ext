# Changelog

## 1.2.2 (2021-07-13)

- Add check if Kernel.then/2 macro exists before defining own Listiller.then/2 function.
  This makes it compatible with Elixir 1.12.+ 

## 1.2.1 (2021-06-22)

#### Breaking changes

- `Listiller.apply/3` and `Listiller.Helpers.updated_sort/1` refactored to support versioned element sorting.
  Note: Versioned sorting is the simplest (fastest) way of achieving that the sort destination id value in the
  Listilled component template (the data-sort attribute) gets updated even if the destination id is the same as
  it has been set previously (for a previous sorting) such as in a UC when elements cyclically change
  their relative positions.   
  
  Hint: Study the Listiller API docs to learn the new, much simpler way of assigning `Listiller.apply/3` returned
  values to the LiveView socket. 

#### Enhancement

- Added `Listilled.Helpers.assign_list/2` to support assigning the list assigns, the type of update and its version
  to socket with a set of keys.     

## 1.2.0 (2021-06-04)

#### Breaking change

- Refactor Listilled.component_id/1 to Listilled.component_id/2 to also receive the state when required for
  the component id creation.
  
  Hint: To upgrade simply add an unused second argument in all your Listilled behaviour implementations e.g.:
  ```
  @impl true
  def component_id( diff_id, _) do
  ..
  end
  ``` 

## 1.1.1 (2021-05-23)

- Add support for using different function name for MultiRender.render/2 

## 1.1.0 (2021-04-25)

- Add `listiller.ex` documentation

## 1.0.1 (2021-04-22) 

- Move `multi_render.ex`

## 1.0.0 (2021-04-21)

Initial release
