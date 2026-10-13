import 'dart:convert';

import '../../session_revision/models/session_revision_usage_models.dart';
import '../protocol_authoring/protocol_authoring_fixtures.dart';
import '../protocol_authoring/synthetic_strength_session_compiler.dart';
import 'synthetic_composition_fixtures.dart';
import 'synthetic_composition_review_bridge.dart';

/// Explicit source transport, not an editable workspace or publication payload.
class SyntheticCompositionHandoff {
  const SyntheticCompositionHandoff();
  String write(CompositionReviewReceipt r) =>
      '${const JsonEncoder.withIndent('  ').convert(compositionSorted({
        'kind': 'synthetic_programme_review_handoff',
        'version': 1,
        'programme_yaml': r.programmeSource,
        'package_hash': r.packageHash,
        'fixture_profile': compositionProfile(),
        'sessions': [
          for (final s in (r.sessions.toList()..sort((a, b) => a.identity.revisionNumber.compareTo(b.identity.revisionNumber)))) {'session_key': d2SessionKey(s.identity.revisionNumber), 'identity': compositionTuple(s.identity), 'founder_yaml': s.source, 'source_digest': s.sourceDigest, 'exercise_bindings': s.bindings},
        ],
        'slot_bindings': r.slotBindings,
      }))}\n';

  Future<CompositionReviewReceipt> read(
    String text,
    SyntheticStrengthSessionCompiler compiler,
  ) async {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException(
        'handoff: complete JSON handoff required. Programme YAML alone has no session sources.',
      );
    }
    _rejectDuplicateKeys(text);
    final root = _object(decoded, {
      'kind',
      'version',
      'programme_yaml',
      'package_hash',
      'fixture_profile',
      'sessions',
      'slot_bindings',
    }, 'handoff');
    if (root['kind'] != 'synthetic_programme_review_handoff' ||
        root['version'] != 1 ||
        root['version'] is! int) {
      throw const FormatException(
        'handoff: unsupported transport kind/version.',
      );
    }
    if (!compositionEqual(root['fixture_profile'], compositionProfile())) {
      throw const FormatException(
        'fixture_profile: fixed identity profile/fingerprint differs.',
      );
    }
    final yaml = _string(root['programme_yaml'], 'programme_yaml');
    final rows = root['sessions'];
    if (rows is! List || rows.isEmpty) {
      throw const FormatException(
        'sessions: complete declared sources are required.',
      );
    }
    final sessions = <D2CompiledSession>[],
        keys = <String>{},
        protocols = <String>{},
        numbers = <int>{};
    for (var n = 0; n < rows.length; n++) {
      final path = 'sessions[$n]';
      final row = _object(rows[n], {
        'session_key',
        'identity',
        'founder_yaml',
        'source_digest',
        'exercise_bindings',
      }, path);
      final tuple = _object(row['identity'], {
        'protocol_id',
        'session_lineage_id',
        'revision_number',
      }, '$path.identity');
      final number = tuple['revision_number'];
      if (number is! int || number < 1 || !numbers.add(number)) {
        throw FormatException('$path.identity: invalid/duplicate revision.');
      }
      final identity = SessionRevisionIdentity(
        protocolId: _string(tuple['protocol_id'], '$path.protocol_id'),
        sessionLineageId: _string(
          tuple['session_lineage_id'],
          '$path.session_lineage_id',
        ),
        revisionNumber: number,
      );
      final key = _string(row['session_key'], '$path.session_key');
      if (key != d2SessionKey(number) ||
          !keys.add(key) ||
          !protocols.add(identity.protocolId)) {
        throw FormatException(
          '$path: duplicate/conflicting session key or protocol identity.',
        );
      }
      final source = _string(row['founder_yaml'], '$path.founder_yaml');
      if (row['source_digest'] != d2SourceDigest(source)) {
        throw FormatException(
          '$path.source_digest: exact source bytes differ.',
        );
      }
      final compiled = await compiler.compileExact(source, identity);
      verifyCompositionSession(compiled);
      if (!compositionEqual(row['exercise_bindings'], compiled.bindings)) {
        throw FormatException(
          '$path.exercise_bindings: resolved identities/versions differ.',
        );
      }
      sessions.add(compiled);
    }
    sessions.sort(
      (a, b) => a.identity.revisionNumber.compareTo(b.identity.revisionNumber),
    );
    final receipt = reviewComposition(yaml, sessions);
    if (root['package_hash'] != receipt.packageHash ||
        !compositionEqual(root['slot_bindings'], receipt.slotBindings)) {
      throw const FormatException(
        'handoff: recomputed package hash or slot/source bindings differ.',
      );
    }
    return receipt;
  }

  Map<String, dynamic> _object(Object? value, Set<String> keys, String path) {
    if (value is! Map<String, dynamic> ||
        !compositionEqual(value.keys.toList()..sort(), keys.toList()..sort())) {
      throw FormatException('$path: missing, extra or unsupported fields.');
    }
    return value;
  }

  String _string(Object? value, String path) {
    if (value is! String || value.isEmpty) {
      throw FormatException('$path: exact source/string is required.');
    }
    return value;
  }

  // jsonDecode first validates syntax. Walk lexical strings so escaped duplicate
  // keys cannot be hidden by its last-key-wins map decoding. No source is parsed here.
  void _rejectDuplicateKeys(String text) {
    var index = 0;
    void space() {
      while (index < text.length && text[index].trim().isEmpty) {
        index++;
      }
    }

    String string() {
      final start = index++;
      while (index < text.length) {
        if (text[index] == '\\') {
          index += 2;
          continue;
        }
        if (text[index++] == '"') break;
      }
      return jsonDecode(text.substring(start, index)) as String;
    }

    late void Function() value;
    value = () {
      space();
      if (text[index] == '"') {
        string();
        return;
      }
      if (text[index] == '{') {
        index++;
        space();
        final seen = <String>{};
        if (text[index] == '}') {
          index++;
          return;
        }
        while (true) {
          space();
          final key = string();
          if (!seen.add(key)) {
            throw FormatException('handoff: duplicate field "$key".');
          }
          space();
          index++;
          value();
          space();
          if (text[index++] == '}') return;
        }
      }
      if (text[index] == '[') {
        index++;
        space();
        if (text[index] == ']') {
          index++;
          return;
        }
        while (true) {
          value();
          space();
          if (text[index++] == ']') return;
        }
      }
      while (index < text.length &&
          !RegExp(r'[\s,}\]]').hasMatch(text[index])) {
        index++;
      }
    };
    value();
  }
}
