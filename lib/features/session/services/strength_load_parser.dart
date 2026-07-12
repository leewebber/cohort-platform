/// Parses free-text load strings into value + unit for performance logging.
class StrengthLoadParser {
  StrengthLoadParser._();

  static const _unitAliases = {
    'kg': 'kg',
    'kgs': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'lb': 'lb',
    'lbs': 'lb',
    'pound': 'lb',
    'pounds': 'lb',
    'bw': 'bw',
    'bodyweight': 'bw',
    'rpe': 'rpe',
  };

  static ParsedLoad parse(String? raw) {
    if (raw == null) {
      return const ParsedLoad();
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const ParsedLoad();
    }

    final normalized = trimmed.toLowerCase();
    if (normalized == 'bw' || normalized == 'bodyweight') {
      return const ParsedLoad(unit: 'bw');
    }

    if (normalized.startsWith('rpe')) {
      final value = double.tryParse(
        normalized.replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      return ParsedLoad(value: value, unit: 'rpe');
    }

    final match = RegExp(
      r'^([\d.]+)\s*([a-z]+)?',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (match == null) {
      final numericOnly = double.tryParse(trimmed.replaceAll(RegExp(r'[^0-9.]'), ''));
      return ParsedLoad(
        value: numericOnly,
        unit: numericOnly == null ? 'unknown' : null,
      );
    }

    final value = double.tryParse(match.group(1) ?? '');
    final unitToken = match.group(2)?.toLowerCase();
    final unit = unitToken == null ? null : _unitAliases[unitToken] ?? 'unknown';

    return ParsedLoad(value: value, unit: unit);
  }
}

class ParsedLoad {
  const ParsedLoad({
    this.value,
    this.unit,
  });

  final double? value;
  final String? unit;
}
