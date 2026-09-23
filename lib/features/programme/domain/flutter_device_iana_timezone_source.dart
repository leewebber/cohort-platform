import 'package:flutter_timezone/flutter_timezone.dart';

import 'enrolment_timezone_capture.dart';

/// Platform IANA hint. Never persist without [EnrolmentIanaTimezone] validation.
class FlutterDeviceIanaTimezoneSource implements DeviceIanaTimezoneSource {
  const FlutterDeviceIanaTimezoneSource();

  @override
  Future<String?> detect() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      final trimmed = name.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }
}
