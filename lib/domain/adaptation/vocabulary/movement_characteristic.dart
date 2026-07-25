/// Movement execution characteristics relevant to substitution constraints.
enum MovementCharacteristic {
  bilateral,
  unilateral,
  explosive,
  isometric,
  plyometric,
  cyclic,
  stableBase,
  unstableBase,
  overhead,
  axialLoad,
}

extension MovementCharacteristicDb on MovementCharacteristic {
  String get dbValue {
    return switch (this) {
      MovementCharacteristic.bilateral => 'bilateral',
      MovementCharacteristic.unilateral => 'unilateral',
      MovementCharacteristic.explosive => 'explosive',
      MovementCharacteristic.isometric => 'isometric',
      MovementCharacteristic.plyometric => 'plyometric',
      MovementCharacteristic.cyclic => 'cyclic',
      MovementCharacteristic.stableBase => 'stable_base',
      MovementCharacteristic.unstableBase => 'unstable_base',
      MovementCharacteristic.overhead => 'overhead',
      MovementCharacteristic.axialLoad => 'axial_load',
    };
  }

  static MovementCharacteristic? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final characteristic in MovementCharacteristic.values) {
      if (characteristic.dbValue == normalized) return characteristic;
    }
    return null;
  }
}
