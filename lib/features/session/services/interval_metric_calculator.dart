import '../../../models/interval_metric_entry_source.dart';
import '../../../models/interval_modality.dart';
import '../../../models/interval_rep_entry.dart';

/// Identifies which interval metric field the athlete edited.
enum IntervalMetricField {
  distance,
  duration,
  pace,
}

/// Parsed interval metric inputs before auto-calculation.
class IntervalMetricInput {
  const IntervalMetricInput({
    this.distanceMeters,
    this.durationSeconds,
    this.paceSecondsPerKm,
    this.distanceSource = IntervalMetricEntrySource.unset,
    this.durationSource = IntervalMetricEntrySource.unset,
    this.paceSource = IntervalMetricEntrySource.unset,
  });

  final double? distanceMeters;
  final int? durationSeconds;
  final double? paceSecondsPerKm;
  final IntervalMetricEntrySource distanceSource;
  final IntervalMetricEntrySource durationSource;
  final IntervalMetricEntrySource paceSource;
}

/// Resolved interval metrics after optional auto-calculation.
class IntervalMetricResult {
  const IntervalMetricResult({
    this.distanceMeters,
    this.durationSeconds,
    this.paceSecondsPerKm,
    this.distanceSource = IntervalMetricEntrySource.unset,
    this.durationSource = IntervalMetricEntrySource.unset,
    this.paceSource = IntervalMetricEntrySource.unset,
  });

  final double? distanceMeters;
  final int? durationSeconds;
  final double? paceSecondsPerKm;
  final IntervalMetricEntrySource distanceSource;
  final IntervalMetricEntrySource durationSource;
  final IntervalMetricEntrySource paceSource;
}

/// Derives pace, distance, and duration for interval work phases.
///
/// Running uses seconds-per-kilometre internally. Future modalities can extend
/// display formatting without changing canonical storage units.
class IntervalMetricCalculator {
  const IntervalMetricCalculator();

  double? calculatePaceSecondsPerKm({
    required double distanceMeters,
    required int durationSeconds,
  }) {
    if (!_isPositive(distanceMeters) || !_isPositiveInt(durationSeconds)) {
      return null;
    }

    final kilometres = distanceMeters / 1000;
    if (kilometres <= 0) {
      return null;
    }

    return durationSeconds / kilometres;
  }

  double? calculateDistanceMeters({
    required int durationSeconds,
    required double paceSecondsPerKm,
  }) {
    if (!_isPositiveInt(durationSeconds) || !_isPositive(paceSecondsPerKm)) {
      return null;
    }

    return durationSeconds * 1000 / paceSecondsPerKm;
  }

  int? calculateDurationSeconds({
    required double distanceMeters,
    required double paceSecondsPerKm,
  }) {
    if (!_isPositive(distanceMeters) || !_isPositive(paceSecondsPerKm)) {
      return null;
    }

    final seconds = distanceMeters * paceSecondsPerKm / 1000;
    if (seconds <= 0) {
      return null;
    }

    return seconds.round();
  }

  IntervalMetricResult applyAutoCalculation(IntervalMetricInput input) {
    var distanceMeters = input.distanceMeters;
    var durationSeconds = input.durationSeconds;
    var paceSecondsPerKm = input.paceSecondsPerKm;
    var distanceSource = input.distanceSource;
    var durationSource = input.durationSource;
    var paceSource = input.paceSource;

    if (distanceMeters != null &&
        durationSeconds != null &&
        paceSource != IntervalMetricEntrySource.manual) {
      final calculated = calculatePaceSecondsPerKm(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
      if (calculated != null) {
        paceSecondsPerKm = calculated;
        paceSource = IntervalMetricEntrySource.auto;
      }
    } else if (durationSeconds != null &&
        paceSecondsPerKm != null &&
        distanceSource != IntervalMetricEntrySource.manual) {
      final calculated = calculateDistanceMeters(
        durationSeconds: durationSeconds,
        paceSecondsPerKm: paceSecondsPerKm,
      );
      if (calculated != null) {
        distanceMeters = calculated;
        distanceSource = IntervalMetricEntrySource.auto;
      }
    } else if (distanceMeters != null &&
        paceSecondsPerKm != null &&
        durationSource != IntervalMetricEntrySource.manual) {
      final calculated = calculateDurationSeconds(
        distanceMeters: distanceMeters,
        paceSecondsPerKm: paceSecondsPerKm,
      );
      if (calculated != null) {
        durationSeconds = calculated;
        durationSource = IntervalMetricEntrySource.auto;
      }
    }

    return IntervalMetricResult(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      paceSecondsPerKm: paceSecondsPerKm,
      distanceSource: distanceSource,
      durationSource: durationSource,
      paceSource: paceSource,
    );
  }

  IntervalRepEntry applyToEntry({
    required IntervalRepEntry entry,
    required IntervalMetricInput input,
  }) {
    final result = applyAutoCalculation(input);

    return entry.copyWith(
      actualDistance: result.distanceMeters,
      actualDuration: result.durationSeconds == null
          ? null
          : Duration(seconds: result.durationSeconds!),
      actualPace: result.paceSecondsPerKm,
      distanceSource: result.distanceSource,
      durationSource: result.durationSource,
      paceSource: result.paceSource,
      clearActualDistance: result.distanceMeters == null,
      clearActualDuration: result.durationSeconds == null,
      clearActualPace: result.paceSecondsPerKm == null,
    );
  }

  IntervalMetricInput inputFromEntry(IntervalRepEntry entry) {
    return IntervalMetricInput(
      distanceMeters: entry.actualDistance,
      durationSeconds: entry.actualDuration?.inSeconds,
      paceSecondsPerKm: entry.actualPace,
      distanceSource: entry.distanceSource,
      durationSource: entry.durationSource,
      paceSource: entry.paceSource,
    );
  }

  IntervalMetricInput buildInputFromTexts({
    required IntervalMetricInput current,
    required String? distanceText,
    required String? durationText,
    required String? paceText,
    IntervalMetricField? editedField,
  }) {
    var distanceMeters = parseDistanceMeters(distanceText);
    var durationSeconds = parseDurationSeconds(durationText);
    var paceSecondsPerKm = parsePaceSecondsPerKm(paceText);
    var distanceSource = current.distanceSource;
    var durationSource = current.durationSource;
    var paceSource = current.paceSource;

    if (editedField == IntervalMetricField.distance) {
      if (_isBlank(distanceText)) {
        distanceMeters = null;
        distanceSource = IntervalMetricEntrySource.unset;
      } else {
        distanceSource = IntervalMetricEntrySource.manual;
      }
    } else if (_isBlank(distanceText) && distanceSource == IntervalMetricEntrySource.auto) {
      distanceMeters = null;
      distanceSource = IntervalMetricEntrySource.unset;
    }

    if (editedField == IntervalMetricField.duration) {
      if (_isBlank(durationText)) {
        durationSeconds = null;
        durationSource = IntervalMetricEntrySource.unset;
      } else {
        durationSource = IntervalMetricEntrySource.manual;
      }
    } else if (_isBlank(durationText) &&
        durationSource == IntervalMetricEntrySource.auto) {
      durationSeconds = null;
      durationSource = IntervalMetricEntrySource.unset;
    }

    if (editedField == IntervalMetricField.pace) {
      if (_isBlank(paceText)) {
        paceSecondsPerKm = null;
        paceSource = IntervalMetricEntrySource.unset;
      } else {
        paceSource = IntervalMetricEntrySource.manual;
      }
    } else if (_isBlank(paceText) && paceSource == IntervalMetricEntrySource.auto) {
      paceSecondsPerKm = null;
      paceSource = IntervalMetricEntrySource.unset;
    }

    return IntervalMetricInput(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      paceSecondsPerKm: paceSecondsPerKm,
      distanceSource: distanceSource,
      durationSource: durationSource,
      paceSource: paceSource,
    );
  }

  int? parseDurationSeconds(String? raw) {
    if (raw == null) {
      return null;
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final clockParts = trimmed.split(':');
    if (clockParts.length == 2 || clockParts.length == 3) {
      final numbers = clockParts.map(int.tryParse).toList();
      if (numbers.any((value) => value == null)) {
        return null;
      }

      if (clockParts.length == 2) {
        final minutes = numbers[0]!;
        final seconds = numbers[1]!;
        if (minutes < 0 || seconds < 0 || seconds >= 60) {
          return null;
        }

        final total = minutes * 60 + seconds;
        return total > 0 ? total : null;
      }

      final hours = numbers[0]!;
      final minutes = numbers[1]!;
      final seconds = numbers[2]!;
      if (hours < 0 ||
          minutes < 0 ||
          seconds < 0 ||
          minutes >= 60 ||
          seconds >= 60) {
        return null;
      }

      final total = hours * 3600 + minutes * 60 + seconds;
      return total > 0 ? total : null;
    }

    final seconds = int.tryParse(trimmed);
    if (seconds != null && seconds > 0) {
      return seconds;
    }

    return null;
  }

  double? parsePaceSecondsPerKm(String? raw) {
    if (raw == null) {
      return null;
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalized = trimmed.toLowerCase().replaceAll('/km', '').trim();
    final clockMatch = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(normalized);
    if (clockMatch != null) {
      final minutes = int.tryParse(clockMatch.group(1) ?? '');
      final seconds = int.tryParse(clockMatch.group(2) ?? '');
      if (minutes == null || seconds == null || minutes < 0 || seconds < 0) {
        return null;
      }

      if (seconds >= 60) {
        return null;
      }

      final total = minutes * 60 + seconds;
      return total > 0 ? total.toDouble() : null;
    }

    final numeric = double.tryParse(normalized);
    if (numeric != null && numeric > 0) {
      return numeric;
    }

    return null;
  }

  double? parseDistanceMeters(String? raw) {
    if (raw == null) {
      return null;
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final value = double.tryParse(trimmed);
    if (value != null && value > 0) {
      return value;
    }

    return null;
  }

  String? formatDurationSeconds(int? seconds) {
    if (seconds == null || seconds <= 0) {
      return null;
    }

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    }

    if (minutes > 0) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }

    return '${remainingSeconds}s';
  }

  String? formatPaceSecondsPerKm(
    double? paceSecondsPerKm, {
    IntervalModality modality = IntervalModality.running,
  }) {
    if (paceSecondsPerKm == null || paceSecondsPerKm <= 0) {
      return null;
    }

    final totalSeconds = paceSecondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final formatted = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return switch (modality) {
      IntervalModality.running => '$formatted/km',
      IntervalModality.cycling ||
      IntervalModality.rowing ||
      IntervalModality.skiing ||
      IntervalModality.other =>
        formatted,
    };
  }

  String? formatDistanceMeters(double? meters) {
    if (meters == null || meters <= 0) {
      return null;
    }

    if (meters == meters.roundToDouble()) {
      return meters.toInt().toString();
    }

    return meters.toString();
  }

  bool _isPositive(double value) => value > 0;

  bool _isPositiveInt(int value) => value > 0;

  bool _isBlank(String? raw) => raw == null || raw.trim().isEmpty;
}
