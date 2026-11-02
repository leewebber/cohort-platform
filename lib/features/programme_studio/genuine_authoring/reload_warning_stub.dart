/// Native/test surfaces have no browser reload event.
void Function() watchUnsavedReload(bool Function() hasChanges) => () {};
