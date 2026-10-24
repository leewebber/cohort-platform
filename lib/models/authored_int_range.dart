/// An authored inclusive integer window. Choosing a value never edits the window.
class AuthoredIntRange {
  const AuthoredIntRange(this.min, this.max);
  final int min;
  final int max;
  bool contains(int value) => value >= min && value <= max;
  bool get isValid => min >= 0 && max >= min;
  List<int> toJson() => [min, max];
  factory AuthoredIntRange.fromJson(Object? raw) {
    if (raw is! List || raw.length != 2 || raw.any((v) => v is! int)) {
      throw const FormatException('Invalid authored integer range.');
    }
    final result = AuthoredIntRange(raw[0] as int, raw[1] as int);
    if (!result.isValid) {
      throw const FormatException('Reversed or negative authored range.');
    }
    return result;
  }
}
