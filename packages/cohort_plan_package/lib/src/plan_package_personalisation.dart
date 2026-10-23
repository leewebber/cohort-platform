import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Independent prescription references; never observational tracking credentials.
class PersonalisationReference {
  const PersonalisationReference(this.id, this.version, this.digest);
  final String id, digest;
  final int version;
  factory PersonalisationReference.parse(Object? raw) {
    final m = _object(raw, {'id', 'version', 'digest'});
    final id = _text(m, 'id');
    final version = _integer(m, 'version');
    final digest = _text(m, 'digest');
    if (!_identity.hasMatch(id) || version < 1 || !_hash.hasMatch(digest)) {
      throw const FormatException('invalid_dependency_reference');
    }
    return PersonalisationReference(id, version, digest);
  }
  Map<String, Object> toJson() => {
    'id': id,
    'version': version,
    'digest': digest,
  };
}

enum PersonalisationTargetKind {
  runningIntervals,
  dedicatedRowIntervals,
  backSquat,
}

enum PersonalisationUnit {
  milliseconds,
  microgramsTotalExternalLoad,
  millisecondsPerKilometre,
  millisecondsPer500Metres,
  gramsTotalExternalLoad,
}

class PlanPackagePersonalisationTarget {
  PlanPackagePersonalisationTarget({
    required this.id,
    required this.slotKey,
    required this.weekNumber,
    required this.sessionKey,
    required this.protocolId,
    required this.protocolRevision,
    required this.sessionBodyDigest,
    required this.blockId,
    required List<String> stepIds,
    required this.identityNamespace,
    required this.exercise,
    required this.benchmark,
    required this.rule,
    required this.kind,
    required this.inputUnit,
    required this.outputUnit,
    required Map<String, Object> parameters,
  }) : stepIds = List.unmodifiable(stepIds),
       parameters = Map.unmodifiable(parameters);
  final String id,
      slotKey,
      sessionKey,
      protocolId,
      sessionBodyDigest,
      blockId,
      identityNamespace;
  final int weekNumber, protocolRevision;
  final List<String> stepIds;
  final PersonalisationReference exercise, benchmark, rule;
  final PersonalisationTargetKind kind;
  final PersonalisationUnit inputUnit, outputUnit;
  final Map<String, Object> parameters;
  factory PlanPackagePersonalisationTarget.parse(Object? raw) {
    final m = _object(raw, {
      'id',
      'slot_key',
      'week_number',
      'session_key',
      'protocol_id',
      'protocol_revision',
      'session_body_sha256',
      'block_id',
      'step_ids',
      'identity_namespace',
      'exercise',
      'benchmark',
      'rule',
      'kind',
      'input_unit',
      'output_unit',
      'parameters',
    });
    for (final key in ['id', 'slot_key', 'session_key', 'protocol_id']) {
      if (!_identity.hasMatch(_text(m, key))) {
        throw const FormatException('invalid_target_identity');
      }
    }
    if (!_hash.hasMatch(_text(m, 'session_body_sha256'))) {
      throw const FormatException('invalid_session_body_digest');
    }
    final stepRaw = m['step_ids'];
    if (stepRaw is! List ||
        stepRaw.any((x) => x is! String || !_identity.hasMatch(x)) ||
        stepRaw.toSet().length != stepRaw.length) {
      throw const FormatException('invalid_step_ids');
    }
    final ns = _text(m, 'identity_namespace');
    if (!{'synthetic_fixture', 'canonical_exercise'}.contains(ns)) {
      throw const FormatException('unsupported_identity_namespace');
    }
    final block = _text(m, 'block_id');
    if (!_identity.hasMatch(block) &&
        !(ns == 'canonical_exercise' &&
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            ).hasMatch(block))) {
      throw const FormatException('invalid_target_block_identity');
    }
    final kind = PersonalisationTargetKind.values.byName(_text(m, 'kind'));
    final params = _object(
      m['parameters'],
      kind == PersonalisationTargetKind.backSquat
          ? {'sets', 'reps', 'five_rm_basis_points', 'rir'}
          : {'repetitions', 'work_seconds', 'recovery_seconds'},
    );
    for (final key in params.keys) {
      if (key == 'rir') {
        _text(params, key);
      } else if (_integer(params, key) < 1 || _integer(params, key) > 1000000) {
        throw const FormatException('invalid_authored_parameter');
      }
    }
    return PlanPackagePersonalisationTarget(
      id: _text(m, 'id'),
      slotKey: _text(m, 'slot_key'),
      weekNumber: _integer(m, 'week_number'),
      sessionKey: _text(m, 'session_key'),
      protocolId: _text(m, 'protocol_id'),
      protocolRevision: _integer(m, 'protocol_revision'),
      sessionBodyDigest: _text(m, 'session_body_sha256'),
      blockId: _text(m, 'block_id'),
      stepIds: stepRaw.cast<String>(),
      identityNamespace: ns,
      exercise: PersonalisationReference.parse(m['exercise']),
      benchmark: PersonalisationReference.parse(m['benchmark']),
      rule: PersonalisationReference.parse(m['rule']),
      kind: kind,
      inputUnit: PersonalisationUnit.values.byName(_text(m, 'input_unit')),
      outputUnit: PersonalisationUnit.values.byName(_text(m, 'output_unit')),
      parameters: params.cast<String, Object>(),
    );
  }
  Map<String, Object> toJson() => {
    'id': id,
    'slot_key': slotKey,
    'week_number': weekNumber,
    'session_key': sessionKey,
    'protocol_id': protocolId,
    'protocol_revision': protocolRevision,
    'session_body_sha256': sessionBodyDigest,
    'block_id': blockId,
    'step_ids': stepIds,
    'identity_namespace': identityNamespace,
    'exercise': exercise.toJson(),
    'benchmark': benchmark.toJson(),
    'rule': rule.toJson(),
    'kind': kind.name,
    'input_unit': inputUnit.name,
    'output_unit': outputUnit.name,
    'parameters': parameters,
  };
}

class PlanPackagePersonalisationBinding {
  PlanPackagePersonalisationBinding(
    List<PlanPackagePersonalisationTarget> targets,
  ) : targets = List.unmodifiable(targets);
  final List<PlanPackagePersonalisationTarget> targets;
  factory PlanPackagePersonalisationBinding.parse(Object? raw) {
    final m = _object(raw, {
      'binding_schema_version',
      'targets',
      'freshness',
      'replacement_policy',
      'missing_input_policy',
    });
    if (m['binding_schema_version'] != 1 ||
        m['freshness'] != 'none' ||
        m['replacement_policy'] != 'explicit_consent_future_unstarted_only' ||
        m['missing_input_policy'] != 'unavailable_with_authored_effort_only') {
      throw const FormatException('unsupported_binding_policy');
    }
    final targets = m['targets'];
    if (targets is! List || targets.isEmpty || targets.length > 512) {
      throw const FormatException('invalid_targets');
    }
    return PlanPackagePersonalisationBinding(
      targets.map(PlanPackagePersonalisationTarget.parse).toList(),
    );
  }
  Map<String, Object> toJson() => {
    'binding_schema_version': 1,
    'freshness': 'none',
    'replacement_policy': 'explicit_consent_future_unstarted_only',
    'missing_input_policy': 'unavailable_with_authored_effort_only',
    'targets': targets.map((x) => x.toJson()).toList(),
  };
}

/// Must resolve trusted immutable rule/benchmark contents, not just compare two supplied hashes.
abstract interface class PersonalisationDependencyResolver {
  String? validateTarget(PlanPackagePersonalisationTarget target);
}

String personalisationCanonicalJson(Object? value) =>
    jsonEncode(_sorted(value));
String personalisationDigest(Object? value) =>
    sha256.convert(utf8.encode(personalisationCanonicalJson(value))).toString();
Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _sorted(value[key])};
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}

final _identity = RegExp(r'^[A-Za-z][A-Za-z0-9._:-]*$');
final _hash = RegExp(r'^[0-9a-f]{64}$');
Map<String, Object?> _object(Object? raw, Set<String> keys) {
  if (raw is! Map ||
      raw.keys.any((k) => k is! String) ||
      raw.length != keys.length ||
      !raw.keys.toSet().containsAll(keys)) {
    throw const FormatException('missing_or_unknown_binding_fields');
  }
  return Map<String, Object?>.from(raw);
}

String _text(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! String || v.isEmpty || v.trim() != v) {
    throw const FormatException('invalid_binding_text');
  }
  return v;
}

int _integer(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! int) throw const FormatException('invalid_binding_integer');
  return v;
}
