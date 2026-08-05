import 'dart:convert';
import 'dart:io';

/// Durable, atomically flushed Journey D progress ledger.
///
/// Survives outer launcher/Python timeouts when written outside nested temps.
class JourneyDProgressLedger {
  JourneyDProgressLedger({required this.file});

  final File file;

  static const _secretKeys = {
    'password',
    'email',
    'athlete_password',
    'access_token',
    'service_key',
    'anon_key',
  };

  /// Atomically replace ledger contents (temp + rename + flush).
  void write(Map<String, Object?> data) {
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final map = Map<String, Object?>.from(data);
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    for (final k in _secretKeys) {
      map.remove(k);
    }
    final tmp = File('${file.path}.tmp.$pid');
    tmp.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(map),
      flush: true,
    );
    tmp.renameSync(file.path);
  }

  void writeStage({
    required String marker,
    required String surface,
    required String stage,
    required String status,
    required List<Map<String, Object?>> stages,
    String detail = '',
    bool? requestDispatched,
    String? classification,
    int hostedWritesExecuted = 0,
    bool terminal = false,
  }) {
    write({
      'terminal': terminal,
      'surface': surface,
      'marker': marker,
      'fixture_marker': marker,
      'current_stage': stage,
      'current_status': status,
      'detail': detail,
      'request_dispatched': requestDispatched,
      'classification': classification,
      'hosted_writes_executed': hostedWritesExecuted,
      'stages': stages,
      if (terminal) 'ok': status == 'succeeded',
    });
  }
}
