/// Shared source-neutral ownership bookkeeping. Reservation numbers are never reused,
/// including after cancel. It confers no published or historical authority.
class LocalRevisionNumbers {
  LocalRevisionNumbers({this.highWater = 1});
  int highWater;
  final Map<int, int> reservations = {};
  final Map<int, int> parents = {};

  int reserve(int parent) {
    if (highWater >= 1000000) {
      throw StateError('No new local revision number is available.');
    }
    final next = ++highWater;
    reservations[next] = parent;
    return next;
  }
}

/// Common owner collection, keyed by exact lineage rather than display title.
class SessionOwnerCollection<T> {
  final Map<String, T> _owners = {};
  List<T> get values => List.unmodifiable(_owners.values);
  T operator [](String lineage) =>
      _owners[lineage] ?? (throw StateError('Unknown session owner.'));
  void add(String lineage, T owner) {
    if (_owners.containsKey(lineage)) {
      throw StateError('Duplicate session owner.');
    }
    _owners[lineage] = owner;
  }
}
