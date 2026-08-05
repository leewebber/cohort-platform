import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Private credential handoff from Journey D fixture creator → execute runner.
///
/// Credentials never appear in result JSON, stdout, evidence, or git.
/// Artifact mode is `0600`. Single-consume. Secure dispose after use.
class JourneyDPrivateCredential {
  const JourneyDPrivateCredential({
    required this.marker,
    required this.lineageCode,
    required this.athleteId,
    required this.email,
    required this.password,
    required this.assignmentId,
    required this.versionId,
    required this.nonce,
    required this.createdAtUtc,
    this.consumed = false,
    this.schema = schemaV1,
  });

  static const schemaV1 = 's17_jd_credential_v1';
  static const lineageProgS17JdAdapt = 'PROG-S17-JD-ADAPT';
  static final markerPattern = RegExp(
    r'^s17_jd_adapt_\d{8}T\d{6}Z_[0-9a-f]{8}$',
  );

  final String schema;
  final String marker;
  final String lineageCode;
  final String athleteId;
  final String email;
  final String password;
  final String assignmentId;
  final String versionId;
  final String nonce;
  final DateTime createdAtUtc;
  final bool consumed;

  /// Email local-part only for diagnostics — never the full address in logs.
  String get emailLocalRedacted {
    final local = email.split('@').first;
    if (local.length <= 12) return '${local.substring(0, 4)}…';
    return '${local.substring(0, 12)}…';
  }

  String get athleteIdRedacted =>
      athleteId.length >= 8 ? '${athleteId.substring(0, 8)}…' : '…';

  Map<String, Object?> toPrivateMap() => {
    'schema': schema,
    'marker': marker,
    'lineage_code': lineageCode,
    'athlete_id': athleteId,
    'email': email,
    'password': password,
    'assignment_id': assignmentId,
    'version_id': versionId,
    'nonce': nonce,
    'created_at': createdAtUtc.toUtc().toIso8601String(),
    'consumed': consumed,
  };

  JourneyDPrivateCredential copyWith({bool? consumed}) =>
      JourneyDPrivateCredential(
        schema: schema,
        marker: marker,
        lineageCode: lineageCode,
        athleteId: athleteId,
        email: email,
        password: password,
        assignmentId: assignmentId,
        versionId: versionId,
        nonce: nonce,
        createdAtUtc: createdAtUtc,
        consumed: consumed ?? this.consumed,
      );
}

class JourneyDCredentialHandoffException implements Exception {
  JourneyDCredentialHandoffException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'JourneyDCredentialHandoffException($code)';
}

/// Repository-owned private credential file handoff (mode 0600).
class JourneyDCredentialHandoff {
  JourneyDCredentialHandoff({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  static const maxAge = Duration(hours: 6);

  static void validateMarker(String marker) {
    if (!JourneyDPrivateCredential.markerPattern.hasMatch(marker)) {
      throw JourneyDCredentialHandoffException(
        'invalid_marker',
        'Marker must match s17_jd_adapt_*',
      );
    }
    if (marker.startsWith('s17_stage_')) {
      throw JourneyDCredentialHandoffException(
        'reserved_marker',
        'Athlete D markers are refused',
      );
    }
  }

  String newNonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Writes a fresh unconsumed credential file (mode 0600).
  void writeFresh({
    required File file,
    required String marker,
    required String athleteId,
    required String email,
    required String password,
    required String assignmentId,
    required String versionId,
    String lineageCode = JourneyDPrivateCredential.lineageProgS17JdAdapt,
  }) {
    validateMarker(marker);
    if (lineageCode != JourneyDPrivateCredential.lineageProgS17JdAdapt) {
      throw JourneyDCredentialHandoffException(
        'lineage_mismatch',
        'Only PROG-S17-JD-ADAPT is supported',
      );
    }
    if (athleteId.trim().isEmpty ||
        email.trim().isEmpty ||
        password.isEmpty ||
        assignmentId.trim().isEmpty ||
        versionId.trim().isEmpty) {
      throw JourneyDCredentialHandoffException(
        'incomplete_credential',
        'Required credential fields missing',
      );
    }
    if (!email.startsWith(marker) || !email.endsWith('@example.invalid')) {
      throw JourneyDCredentialHandoffException(
        'email_marker_mismatch',
        'Email must embed marker and use example.invalid',
      );
    }
    final cred = JourneyDPrivateCredential(
      marker: marker,
      lineageCode: lineageCode,
      athleteId: athleteId.trim(),
      email: email.trim(),
      password: password,
      assignmentId: assignmentId.trim(),
      versionId: versionId.trim(),
      nonce: newNonce(),
      createdAtUtc: DateTime.now().toUtc(),
    );
    _atomicWrite(file, cred);
  }

  /// Loads credential and validates binding to [expectedMarker].
  /// Does not consume.
  JourneyDPrivateCredential peek({
    required File file,
    required String expectedMarker,
    String? expectedAthleteId,
  }) {
    validateMarker(expectedMarker);
    if (!file.existsSync()) {
      throw JourneyDCredentialHandoffException(
        'missing_credential',
        'Credential artifact absent',
      );
    }
    final mode = file.statSync().mode & 0x1FF;
    if (mode & 0x049 != 0) {
      // group/other read bits set — refuse
      throw JourneyDCredentialHandoffException(
        'insecure_mode',
        'Credential file must not be group/world readable',
      );
    }
    final raw = jsonDecode(file.readAsStringSync());
    if (raw is! Map) {
      throw JourneyDCredentialHandoffException(
        'malformed_credential',
        'Credential JSON invalid',
      );
    }
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final cred = _fromMap(map);
    if (cred.schema != JourneyDPrivateCredential.schemaV1) {
      throw JourneyDCredentialHandoffException(
        'schema_mismatch',
        'Unsupported credential schema',
      );
    }
    if (cred.marker != expectedMarker) {
      throw JourneyDCredentialHandoffException(
        'marker_mismatch',
        'Credential marker does not match execution marker',
      );
    }
    if (cred.lineageCode != JourneyDPrivateCredential.lineageProgS17JdAdapt) {
      throw JourneyDCredentialHandoffException(
        'lineage_mismatch',
        'Credential lineage refused',
      );
    }
    if (expectedAthleteId != null &&
        expectedAthleteId.trim().isNotEmpty &&
        cred.athleteId != expectedAthleteId.trim()) {
      throw JourneyDCredentialHandoffException(
        'identity_mismatch',
        'Credential athlete identity mismatch',
      );
    }
    if (cred.consumed) {
      throw JourneyDCredentialHandoffException(
        'already_consumed',
        'Credential already consumed',
      );
    }
    final age = DateTime.now().toUtc().difference(cred.createdAtUtc);
    if (age > maxAge || age.isNegative) {
      throw JourneyDCredentialHandoffException(
        'stale_credential',
        'Credential expired or clock skew',
      );
    }
    return cred;
  }

  /// Atomically marks consumed and returns the secret payload.
  /// Second call fails closed.
  JourneyDPrivateCredential consumeOnce({
    required File file,
    required String expectedMarker,
    String? expectedAthleteId,
  }) {
    final cred = peek(
      file: file,
      expectedMarker: expectedMarker,
      expectedAthleteId: expectedAthleteId,
    );
    final consumed = cred.copyWith(consumed: true);
    _atomicWrite(file, consumed);
    // Re-read to detect races (multiply consumed).
    final verify = jsonDecode(file.readAsStringSync());
    if (verify is! Map || verify['consumed'] != true) {
      throw JourneyDCredentialHandoffException(
        'consume_race',
        'Credential consume could not be confirmed',
      );
    }
    if (verify['nonce'] != cred.nonce) {
      throw JourneyDCredentialHandoffException(
        'consume_race',
        'Credential nonce changed during consume',
      );
    }
    return cred;
  }

  /// Overwrite with zeros then delete. Mandatory secret disposal.
  void shred(File file) {
    if (!file.existsSync()) return;
    try {
      final len = file.lengthSync();
      final zeros = List.filled(len > 0 ? len : 64, 0);
      file.writeAsBytesSync(zeros, flush: true);
    } catch (_) {
      // continue to delete
    }
    try {
      file.deleteSync();
    } catch (_) {
      // best-effort
    }
  }

  void _atomicWrite(File file, JourneyDPrivateCredential cred) {
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final tmp = File(
      '${file.path}.tmp.${_random.nextInt(1 << 32).toRadixString(16)}',
    );
    tmp.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(cred.toPrivateMap()),
      flush: true,
    );
    // ignore: avoid_slow_async_io
    Process.runSync('chmod', ['600', tmp.path]);
    tmp.renameSync(file.path);
    Process.runSync('chmod', ['600', file.path]);
  }

  JourneyDPrivateCredential _fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at']?.toString() ?? '';
    final created = DateTime.tryParse(createdRaw);
    if (created == null) {
      throw JourneyDCredentialHandoffException(
        'malformed_credential',
        'created_at missing',
      );
    }
    return JourneyDPrivateCredential(
      schema: map['schema']?.toString() ?? '',
      marker: map['marker']?.toString() ?? '',
      lineageCode: map['lineage_code']?.toString() ?? '',
      athleteId: map['athlete_id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      assignmentId: map['assignment_id']?.toString() ?? '',
      versionId: map['version_id']?.toString() ?? '',
      nonce: map['nonce']?.toString() ?? '',
      createdAtUtc: created.toUtc(),
      consumed: map['consumed'] == true,
    );
  }
}
