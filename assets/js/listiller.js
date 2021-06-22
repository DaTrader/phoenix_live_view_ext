/**
 * Listiller JS Helper Functions
 *
 *
 */

/**
 * Instantiates a new listill data structure
 * If isNotifyRemoval function is specified, all elements for which the function returns a truthy value will
 * be notified by a 'beforeRemoved' event prior to their removal from the DOM tree.
 */
export function newListill( sortAttr, deleteSelector, isNotifyRemoval = null) {
  return {
    deleteSelector: deleteSelector,
    isNotifyRemoval: isNotifyRemoval,
    sortAttr: sortAttr,
    elementsToSort: []
  };
}

/**
 * Pushes the element for sorting in a FILO array if its sort attribute is pointing to a destination element before
 * which it is supposed to move.
 * We can't sort here directly for we need to sort from the last inserted by LiveView to the first.
 * Returns the sorting instructions or null if none.
 */
export function prepForSorting( listill, el, getsId) {
  const sortData = el.dataset[ listill.sortAttr];
  if( !sortData) return null;

  const [ dstBareId, version] = sortData.split( ":");
  const sort = {
    src: el.id,
    dst: getsId( dstBareId)
  };
  listill.elementsToSort.unshift( sort);
  return sort;
}

/**
 * Completes the list distilling process by deleting elements marked for deletion and sorting the inserted ones.
 */
export function completeListill( listill, rootEl) {
  deleteElements( listill, rootEl);
  sortElements( listill);
}

/**
 * Deletes all elements under the provided root element that are tagged for deletion.
 * If defined, listilled.isNotifyRemoval function is called for each element and if it returns a truthy value,
 * a beforeRemoved event is dispatched to the element before having it removed from its parent node.
 */
function deleteElements( listill, rootEl) {
  rootEl.querySelectorAll( listill.deleteSelector).forEach( el => {
    if( listill.isNotifyRemoval && listill.isNotifyRemoval( el)) {
    el.dispatchEvent( new Event( 'beforeRemoved'));
  }
  el.parentNode.removeChild( el);
})
}

/**
 * Iterates over FILO elements prepared for sorting (starting from the last pushed) and sorts each of the
 * elements found therein.
 */
function sortElements( listill) {
  listill.elementsToSort.forEach( sort => {
    const src = document.getElementById( sort.src);
  const dst = document.getElementById( sort.dst);
  if( src && dst) {
    dst.parentNode.insertBefore( src, dst);
  }
});
  listill.elementsToSort = [];
}

/**
 * Calls a function with the dataset of a LiveView Hook associated with the provided element.
 * The function accepts the Hook dataset.
 */
export function applyCall( elId, fun) {
  document.getElementById( elId).dispatchEvent( new CustomEvent( "applyCall", { detail: { fun: fun}}));
}

/**
 * Initializes the applyCall event listener for the provided Hook dataset.
 */
export function initApplyCall( me) {
  me._applyCall = e => e.detail.fun( me);
  me.el.addEventListener( "applyCall", me._applyCall);
}

/**
 * Removes the applyCall event listener for the provided Hook dataset.
 */
export function deinitApplyCall( me) {
  if( me._applyCall) me.el.removeEventListener( "applyCall", me._applyCall);
}
