import 'package:cohort_platform/features/programme/domain/enrolment_iana_timezone.dart';
import 'package:cohort_platform/features/programme/domain/enrolment_local_date.dart';
import 'package:cohort_platform/features/programme/domain/enrolment_timezone_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnrolmentIanaTimezone', () {
    test('accepts Bali and UK identifiers', () {
      expect(EnrolmentIanaTimezone.isValidIdentifier('Asia/Makassar'), isTrue);
      expect(EnrolmentIanaTimezone.isValidIdentifier('Europe/London'), isTrue);
    });

    test('rejects abbreviations and offsets', () {
      for (final raw in [
        'BST',
        'GMT',
        'WITA',
        'KST',
        'UTC',
        'UTC+8',
        '+08:00',
        'Etc/GMT-8',
        '',
        null,
      ]) {
        expect(
          EnrolmentIanaTimezone.isValidIdentifier(raw),
          isFalse,
          reason: raw.toString(),
        );
      }
    });
  });

  group('EnrolmentLocalDate', () {
    test('Makassar is UTC+8 with no DST around UTC midnight', () {
      final before = DateTime.utc(2026, 6, 15, 15, 30);
      final after = DateTime.utc(2026, 6, 15, 16, 30);
      expect(
        EnrolmentLocalDate.isoDate(iana: 'Asia/Makassar', utcNow: before),
        '2026-06-15',
      );
      expect(
        EnrolmentLocalDate.isoDate(iana: 'Asia/Makassar', utcNow: after),
        '2026-06-16',
      );
    });

    test('London GMT around UTC midnight', () {
      final winter = DateTime.utc(2026, 1, 15, 23, 30);
      expect(
        EnrolmentLocalDate.isoDate(iana: 'Europe/London', utcNow: winter),
        '2026-01-15',
      );
      expect(
        EnrolmentLocalDate.isoDate(
          iana: 'Europe/London',
          utcNow: DateTime.utc(2026, 1, 16, 0, 30),
        ),
        '2026-01-16',
      );
    });

    test('London BST around UTC midnight', () {
      expect(
        EnrolmentLocalDate.isoDate(
          iana: 'Europe/London',
          utcNow: DateTime.utc(2026, 6, 15, 22, 30),
        ),
        '2026-06-15',
      );
      expect(
        EnrolmentLocalDate.isoDate(
          iana: 'Europe/London',
          utcNow: DateTime.utc(2026, 6, 15, 23, 30),
        ),
        '2026-06-16',
      );
    });

    test('unknown zone fails closed', () {
      expect(
        EnrolmentLocalDate.isoDate(
          iana: 'Not/AZone',
          utcNow: DateTime.utc(2026, 6, 15),
        ),
        isNull,
      );
    });
  });

  group('EnrolmentTimezoneCapture', () {
    test('valid device suggestion can confirm', () {
      final capture = EnrolmentTimezoneCapture.fromDeviceSuggestion(
        'Asia/Makassar',
      );
      expect(capture.kind, EnrolmentTimezoneCaptureKind.suggestedValid);
      expect(capture.canConfirm, isTrue);
    });

    test('abbreviation requires selection', () {
      final capture = EnrolmentTimezoneCapture.fromDeviceSuggestion('BST');
      expect(capture.kind, EnrolmentTimezoneCaptureKind.selectionRequired);
      expect(capture.canConfirm, isFalse);
    });

    test('athlete selection overrides suggestion', () {
      final capture = EnrolmentTimezoneCapture.fromDeviceSuggestion(
        'Asia/Makassar',
      ).select('Europe/London');
      expect(capture.kind, EnrolmentTimezoneCaptureKind.athleteSelected);
      expect(capture.iana, 'Europe/London');
    });
  });
}
