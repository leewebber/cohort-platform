import 'enrolment_iana_timezone.dart';

enum EnrolmentTimezoneCaptureKind {
  detecting,
  suggestedValid,
  athleteSelected,
  selectionRequired,
  unavailable,
}

/// One enrolment-timezone authority. Device IANA is a suggestion only.
class EnrolmentTimezoneCapture {
  const EnrolmentTimezoneCapture._({
    required this.kind,
    this.iana,
    this.deviceSuggestion,
  });

  final EnrolmentTimezoneCaptureKind kind;
  final String? iana;
  final String? deviceSuggestion;

  static const detecting = EnrolmentTimezoneCapture._(
    kind: EnrolmentTimezoneCaptureKind.detecting,
  );

  static const unavailable = EnrolmentTimezoneCapture._(
    kind: EnrolmentTimezoneCaptureKind.unavailable,
  );

  static const selectionRequired = EnrolmentTimezoneCapture._(
    kind: EnrolmentTimezoneCaptureKind.selectionRequired,
  );

  factory EnrolmentTimezoneCapture.fromDeviceSuggestion(String? raw) {
    final valid = EnrolmentIanaTimezone.canonicalize(raw);
    if (valid == null) {
      return EnrolmentTimezoneCapture._(
        kind: EnrolmentTimezoneCaptureKind.selectionRequired,
        deviceSuggestion: raw?.trim(),
      );
    }
    return EnrolmentTimezoneCapture._(
      kind: EnrolmentTimezoneCaptureKind.suggestedValid,
      iana: valid,
      deviceSuggestion: valid,
    );
  }

  EnrolmentTimezoneCapture select(String raw) {
    final valid = EnrolmentIanaTimezone.canonicalize(raw);
    if (valid == null) return selectionRequired;
    return EnrolmentTimezoneCapture._(
      kind: EnrolmentTimezoneCaptureKind.athleteSelected,
      iana: valid,
      deviceSuggestion: deviceSuggestion,
    );
  }

  bool get canConfirm =>
      iana != null && EnrolmentIanaTimezone.isValidIdentifier(iana);

  bool get needsExplicitSelection =>
      kind == EnrolmentTimezoneCaptureKind.selectionRequired ||
      kind == EnrolmentTimezoneCaptureKind.unavailable ||
      kind == EnrolmentTimezoneCaptureKind.detecting;

  String get displayIana => iana ?? '';
}

abstract class DeviceIanaTimezoneSource {
  Future<String?> detect();
}

class StaticDeviceIanaTimezoneSource implements DeviceIanaTimezoneSource {
  const StaticDeviceIanaTimezoneSource(this.value);
  final String? value;

  @override
  Future<String?> detect() async => value;
}

class ThrowingDeviceIanaTimezoneSource implements DeviceIanaTimezoneSource {
  const ThrowingDeviceIanaTimezoneSource();

  @override
  Future<String?> detect() async => throw StateError('device timezone unavailable');
}
