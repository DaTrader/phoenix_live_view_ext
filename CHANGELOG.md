# Changelog

## 1.2.0 (2021-06-04)

### Breaking change

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
