/// Whether a person may change item selections in the lazy bill picker.
bool canChangeLazyBillSelection({required bool saving, required bool paid}) =>
    !saving && !paid;
