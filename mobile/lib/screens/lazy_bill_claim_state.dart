/// Whether a person may change item selections in the lazy bill picker.
bool canChangeLazyBillSelection({required bool saving, required bool paid}) =>
    !saving && !paid;

bool lazySelectionHasChanges(Set<int> selected, Set<int> assigned) =>
    selected.length != assigned.length ||
    selected.any((itemId) => !assigned.contains(itemId));
