enum SessionResultEntryMode {
  live('live'),
  backfill('backfill');

  const SessionResultEntryMode(this.wireValue);

  final String wireValue;

  static SessionResultEntryMode parse(Object? value) {
    final wire = value?.toString();
    for (final mode in values) {
      if (mode.wireValue == wire) return mode;
    }
    return SessionResultEntryMode.live;
  }
}

enum SessionPerformedPrecision {
  timestamp('timestamp'),
  date('date');

  const SessionPerformedPrecision(this.wireValue);

  final String wireValue;

  static SessionPerformedPrecision parse(Object? value) {
    final wire = value?.toString();
    for (final precision in values) {
      if (precision.wireValue == wire) return precision;
    }
    return SessionPerformedPrecision.timestamp;
  }
}
