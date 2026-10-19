import 'dart:convert';
import 'dart:typed_data';

import '../../protocol_authoring/synthetic_strength_lineage.dart';
import '../../protocol_authoring/synthetic_strength_session_compiler.dart';
import '../../workspace_json.dart';
import '../synthetic_composition_fixtures.dart';
import '../synthetic_composition_handoff.dart';
import '../synthetic_composition_review_bridge.dart';

const canonicalArchiveMaxBytes = 8 * 1024 * 1024;

Never _refuse(String message) =>
    throw FormatException('canonical sources: $message');

/// Strict in-memory subset of the existing export container. Never extracts or
/// follows paths. PAX/GNU/compressed archives, links and directory entries are
/// intentionally unsupported; re-download the uncompressed Studio TAR instead.
Map<String, String> readCanonicalArchive(Uint8List input) {
  if (input.length > canonicalArchiveMaxBytes ||
      input.length < 1024 ||
      input.length % 512 != 0) {
    _refuse(
      'Use a complete uncompressed Studio .tar download (at most 8 MiB).',
    );
  }
  final bytes = Uint8List.fromList(input);
  final files = <String, String>{};
  var at = 0, total = 0;
  bool zero(int start, int end) =>
      bytes.getRange(start, end).every((b) => b == 0);
  while (at + 512 <= bytes.length) {
    if (zero(at, at + 512)) {
      if (at + 1024 > bytes.length || !zero(at, bytes.length)) {
        _refuse('Archive is truncated or has data after its terminator.');
      }
      return Map.unmodifiable(files);
    }
    if (files.length >= 260) _refuse('Archive exceeds 260 files.');
    final header = bytes.sublist(at, at + 512);
    String text(int offset, int length) {
      final row = header.sublist(offset, offset + length);
      final end = row.indexOf(0);
      if (end >= 0 && row.skip(end).any((b) => b != 0)) {
        _refuse('Non-canonical archive header field.');
      }
      try {
        return ascii.decode(end < 0 ? row : row.sublist(0, end));
      } on FormatException {
        _refuse(
          'Archive paths and headers must use the supported ASCII format.',
        );
      }
    }

    int octal(int offset, int length) {
      // Octal fields may end in NUL/space, never base-256 or signed extensions.
      final raw = ascii.decode(
        header.sublist(offset, offset + length),
        allowInvalid: true,
      );
      if (!RegExp(r'^[0-7]+[\x00 ]*$').hasMatch(raw)) {
        _refuse('Unsupported archive numeric header.');
      }
      return int.parse(raw.replaceAll(RegExp(r'[\x00 ]'), ''), radix: 8);
    }

    final expectedSum = octal(148, 8);
    for (var i = 148; i < 156; i++) {
      header[i] = 32;
    }
    if (header.fold<int>(0, (sum, b) => sum + b) != expectedSum) {
      _refuse(
        'Archive header checksum differs. Download the complete archive again.',
      );
    }
    if (text(257, 6) != 'ustar' ||
        text(263, 2) != '00' ||
        header[156] != 48 ||
        text(157, 100).isNotEmpty ||
        text(345, 155).isNotEmpty ||
        !zero(at + 500, at + 512)) {
      _refuse(
        'Only ordinary files in the existing USTAR export are supported; no links, extensions or prefixed paths.',
      );
    }
    final path = text(0, 100);
    if (!{
          'programme.plan-package.yaml',
          'source-index.json',
          'review.json',
          'README.md',
        }.contains(path) &&
        !RegExp(
          r'^sessions/session-[ab]-v[1-9][0-9]{0,6}\.founder\.yaml$',
        ).hasMatch(path)) {
      _refuse(
        'Unsupported or unsafe archive path "$path". Use the complete Studio file set.',
      );
    }
    if (files.containsKey(path)) _refuse('Duplicate archive entry "$path".');
    final length = octal(124, 12);
    total += length;
    if (length > workspaceMaxBytes || total > 6 * 1024 * 1024) {
      _refuse('Archive body/file size limit exceeded.');
    }
    at += 512;
    final padded = ((length + 511) ~/ 512) * 512;
    if (at + padded > bytes.length || !zero(at + length, at + padded)) {
      _refuse(
        'Truncated file or unsupported nonzero archive padding at "$path".',
      );
    }
    try {
      files[path] = utf8.decode(
        bytes.sublist(at, at + length),
        allowMalformed: false,
      );
    } on FormatException {
      _refuse('"$path" is not valid UTF-8 source text.');
    }
    at += padded;
  }
  _refuse('Archive is missing its complete terminator.');
}

/// Fresh exact-byte compilation, independent of supplied review successes. The
/// index and review are consistency claims only, never owner/history authority.
Future<CompositionReviewReceipt> readCanonicalSources(
  Uint8List bytes,
  SyntheticStrengthSessionCompiler compiler,
) async {
  final files = readCanonicalArchive(bytes);
  for (final name in [
    'programme.plan-package.yaml',
    'source-index.json',
    'review.json',
    'README.md',
  ]) {
    if (!files.containsKey(name)) _refuse('Missing required file "$name".');
  }
  if (utf8.encode(files['README.md']!).length > 65536) {
    _refuse('README is too large.');
  }
  final index = workspaceObject(
    readWorkspaceJson(files['source-index.json']!),
    {'kind', 'version', 'programme', 'sessions', 'files_sha256'},
    'source index',
  );
  if (index['kind'] != 'derived_canonical_source_file_index' ||
      index['version'] is! int ||
      index['version'] != 1) {
    _refuse('Unsupported source-index kind/version. Use source-index v1.');
  }
  final programme = workspaceObject(index['programme'], {
    'path',
    'source_digest',
    'package_hash',
  }, 'source index programme');
  if (programme['path'] != 'programme.plan-package.yaml') {
    _refuse('Programme path must be programme.plan-package.yaml.');
  }
  final inventory = <String>{'programme.plan-package.yaml', 'review.json'};
  final numbers = <String, Set<int>>{};
  final sessions = <D2CompiledSession>[];
  final rows = workspaceList(
    index['sessions'],
    'source index sessions',
    max: 256,
  );
  if (rows.isEmpty) _refuse('Complete declared session sources are required.');
  for (final raw in rows) {
    final row = workspaceObject(raw, {
      'path',
      'identity',
      'session_key',
      'source_digest',
      'profile_fingerprint',
      'exercise_bindings',
    }, 'source index session');
    final tuple = workspaceObject(row['identity'], {
      'protocol_id',
      'session_lineage_id',
      'revision_number',
    }, 'source identity');
    final n = workspaceInt(tuple['revision_number'], 'source revision', min: 1);
    final lineage = tuple['session_lineage_id'] == SyntheticStrengthLineage.a.id
        ? SyntheticStrengthLineage.a
        : tuple['session_lineage_id'] == SyntheticStrengthLineage.b.id
        ? SyntheticStrengthLineage.b
        : null;
    if (lineage == null ||
        !compositionEqual(tuple, compositionTuple(lineage.identity(n)))) {
      _refuse(
        'Unknown identity. Only the fixed Session A/B revision tuples are supported.',
      );
    }
    final path =
        'sessions/session-${lineage == SyntheticStrengthLineage.a ? 'a' : 'b'}-v$n.founder.yaml';
    final used = numbers.putIfAbsent(lineage.id, () => <int>{});
    if (row['path'] != path ||
        row['session_key'] != lineage.sessionKey(n) ||
        !inventory.add(path) ||
        !used.add(n) ||
        used.length > 128) {
      _refuse(
        'Conflicting/duplicate session identity/path or too many versions.',
      );
    }
    final source = files[path];
    if (source == null) _refuse('Missing declared session source "$path".');
    guardWorkspaceYaml(source);
    final compiled = await compiler.compileExact(source, lineage.identity(n));
    verifyCompositionSession(compiled);
    if (!sameRevision(compiled.identity, lineage.identity(n)) ||
        compiled.source != source ||
        row['source_digest'] != compiled.sourceDigest ||
        row['profile_fingerprint'] != fixedFixtureFingerprint() ||
        compiled.profileFingerprint != fixedFixtureFingerprint() ||
        !compositionEqual(row['exercise_bindings'], compiled.bindings)) {
      _refuse('Exact source/profile/exercise binding differs at "$path".');
    }
    sessions.add(compiled);
  }
  if (!compositionEqual(
    files.keys.toSet().difference({'README.md', 'source-index.json'}).toList()
      ..sort(),
    inventory.toList()..sort(),
  )) {
    _refuse(
      'Archive inventory differs from the complete declared source set; no extra or missing files are allowed.',
    );
  }
  for (final entry in numbers.entries) {
    if (!entry.value.contains(1)) {
      _refuse('Every supplied lineage requires its exact root version 1.');
    }
  }
  final hashes = workspaceObject(
    index['files_sha256'],
    inventory,
    'file digest inventory',
  );
  for (final path in inventory) {
    if (hashes[path] != d2SourceDigest(files[path]!)) {
      _refuse('Recomputed file digest differs at "$path".');
    }
  }
  final yaml = files['programme.plan-package.yaml']!;
  guardWorkspaceYaml(yaml);
  sessions.sort((a, b) => compareRevisions(a.identity, b.identity));
  final checked = reviewComposition(yaml, sessions);
  if (programme['source_digest'] != checked.programmeSourceDigest ||
      programme['package_hash'] != checked.packageHash) {
    _refuse('Recomputed programme digest/hash differs.');
  }
  final claimed = readWorkspaceJson(files['review.json']!);
  final recomputed = readWorkspaceJson(
    const SyntheticCompositionHandoff().write(checked),
  );
  if (!compositionEqual(claimed, recomputed)) {
    _refuse(
      'Included read-only review differs from recomputed sources and every-slot bindings. Re-export a consistent complete archive.',
    );
  }
  return checked;
}
