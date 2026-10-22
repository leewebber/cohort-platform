import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import '../../domain/hyrox_base/base_personalisation.dart';
import 'bound_programme.dart';

class BoundRefusal implements Exception {
  const BoundRefusal(this.code);
  final String code;
  @override
  String toString() => code;
}

class LocalBenchmarkRevision {
  const LocalBenchmarkRevision._(
    this.benchmark,
    this.revision,
    this.predecessorDigest,
  );
  final BaseBenchmark benchmark;
  final int revision;
  final String? predecessorDigest;
  Map<String, Object?> toJson() => {
    'revision': revision,
    'predecessor_digest': predecessorDigest,
    'benchmark': benchmark.toJson(),
    'benchmark_digest': benchmark.digest,
  };
}

class BoundConsentProposal {
  const BoundConsentProposal._(
    this.definitionId,
    this.evidence,
    this.generation,
  );
  final String definitionId;
  final LocalBenchmarkRevision evidence;
  final int generation;
}

class LocalBoundConsent {
  const LocalBoundConsent._(
    this.id,
    this.definitionId,
    this.evidence,
    this.packageHash,
  );
  final String id, definitionId, packageHash;
  final LocalBenchmarkRevision evidence;
  Map<String, Object?> toJson() => {
    'consent_id': id,
    'definition_id': definitionId,
    'package_hash': packageHash,
    'effect': 'future_unstarted_only',
    'evidence_revision': evidence.toJson(),
    'claim': 'local synthetic acceptance only',
  };
}

class BoundReviewReceipt {
  const BoundReviewReceipt._(this.slotKey, this.generation, this.json);
  final String slotKey, json;
  final int generation;
  Map<String, dynamic> get document => jsonDecode(json) as Map<String, dynamic>;
  String get digest => personalisationDigest(document);
}

class FrozenBoundSession {
  const FrozenBoundSession._(this.slotKey, this.json);
  final String slotKey, json;
  Map<String, dynamic> get document => jsonDecode(json) as Map<String, dynamic>;
  String get digest => personalisationDigest(document);
}

/// Serial, in-memory synthetic transaction model. No database, authentication,
/// durable storage, imported-consent or production execution authority.
class LocalBoundRepository {
  LocalBoundRepository({
    required this.athleteId,
    required this.programme,
    DateTime Function()? clock,
  }) : _clock = clock ?? _utcNow {
    if (!{'synthetic-a', 'synthetic-b'}.contains(athleteId)) {
      throw const BoundRefusal('unsupported_synthetic_owner');
    }
  }
  final String athleteId;
  final BoundProgramme programme;
  final DateTime Function() _clock;
  static DateTime _utcNow() => DateTime.now().toUtc();
  Future<void> _tail = Future.value();
  int _generation = 0, _consentSequence = 0, _reviewSequence = 0;
  int? _incrementGrams;
  bool _disposed = false;
  final Map<String, LocalBenchmarkRevision> _evidence = {};
  final Map<BaseMetric, LocalBenchmarkRevision> _latestRevision = {};
  final Map<String, LocalBoundConsent> _selected = {};
  final Map<String, BoundReviewReceipt> _receipts = {};
  final Map<String, FrozenBoundSession> _started = {};
  final Map<String, String> _completed = {};
  BoundConsentProposal? _proposal;
  Map<String, LocalBenchmarkRevision> get evidence =>
      Map.unmodifiable(_evidence);
  Map<String, LocalBoundConsent> get selected => Map.unmodifiable(_selected);
  Map<String, FrozenBoundSession> get started => Map.unmodifiable(_started);
  Map<String, String> get completedActuals => Map.unmodifiable(_completed);
  int? get incrementGrams => _incrementGrams;

  Future<T> _atomic<T>(T Function() body) {
    final result = _tail.then((_) {
      if (_disposed) throw const BoundRefusal('repository_disposed');
      return body();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _invalidate() {
    _generation++;
    _reviewSequence++;
    _proposal = null;
    _receipts.clear();
  }

  Future<void> configureIncrement(int? grams) => _atomic(() {
    _invalidate();
    if (grams != null && (grams <= 0 || grams > 1000000000)) {
      _incrementGrams = null;
      throw const BoundRefusal('invalid_equipment_increment');
    }
    _incrementGrams = grams;
  });
  Future<LocalBenchmarkRevision> enter(BaseBenchmark b) => _atomic(() {
    _invalidate();
    if (b.athleteId != athleteId) {
      throw const BoundRefusal('foreign_evidence_owner');
    }
    final kinds = PersonalisationTargetKind.values.where(
      (k) => const HyroxBindingCatalogue().metric(k) == b.metric,
    );
    if (kinds.isEmpty) {
      throw const BoundRefusal('unrelated_benchmark_definition');
    }
    final existing = _evidence[b.id];
    if (existing != null) {
      if (existing.benchmark.digest != b.digest) {
        throw const BoundRefusal('immutable_evidence_identity_conflict');
      }
      return existing;
    }
    final previous = _latestRevision[b.metric];
    final revision = LocalBenchmarkRevision._(
      b,
      (previous?.revision ?? 0) + 1,
      previous?.benchmark.digest,
    );
    _evidence[b.id] = revision;
    _latestRevision[b.metric] = revision;
    return revision;
  });
  Future<BoundConsentProposal> propose(
    String definitionId,
    String evidenceId,
  ) => _atomic(() {
    _invalidate();
    final e = _evidence[evidenceId];
    if (e == null) throw const BoundRefusal('missing_evidence_revision');
    final targets = programme.targets
        .where((t) => t.benchmark.id == definitionId)
        .toList();
    if (targets.isEmpty ||
        targets.any(
          (t) =>
              const HyroxBindingCatalogue().metric(t.kind) !=
              e.benchmark.metric,
        )) {
      throw const BoundRefusal('incompatible_benchmark_definition_or_unit');
    }
    return _proposal = BoundConsentProposal._(definitionId, e, _generation);
  });
  Future<LocalBoundConsent> accept(BoundConsentProposal proposal) =>
      _atomic(() {
        if (!identical(_proposal, proposal) ||
            proposal.generation != _generation ||
            !identical(
              _evidence[proposal.evidence.benchmark.id],
              proposal.evidence,
            )) {
          throw const BoundRefusal('stale_or_foreign_consent');
        }
        final consent = LocalBoundConsent._(
          'local-consent-${++_consentSequence}',
          proposal.definitionId,
          proposal.evidence,
          programme.hash,
        );
        _selected[proposal.definitionId] = consent;
        _invalidate();
        return consent;
      });
  Future<void> cancel() => _atomic(_invalidate);
  Future<void> deselect(String definitionId) => _atomic(() {
    _selected.remove(definitionId);
    _invalidate();
  });

  Map<String, Object?> _reviewDocument(String slot) {
    final targets = programme.targets.where((t) => t.slotKey == slot).toList();
    if (targets.isEmpty) throw const BoundRefusal('unresolved_slot_identity');
    return {
      'format': 'local_bound_review_v1',
      'athlete_id': athleteId,
      'package_hash': programme.hash,
      'selection_configuration_revision': _generation,
      'slot_key': slot,
      'configuration': {'total_barbell_increment_grams': _incrementGrams},
      'targets': [for (final t in targets) _targetDocument(t)],
    };
  }

  Map<String, Object?> _targetDocument(PlanPackagePersonalisationTarget t) {
    final prescription = programme.calculate(t, athleteId, {
      for (final e in _selected.entries) e.key: e.value.evidence.benchmark,
    }, _incrementGrams);
    final numeric = prescription.containsKey('calculated')
        ? prescription['calculated']
        : prescription['calculated_grams_total_external_load'];
    final state = _selected[t.benchmark.id] == null
        ? 'missing_evidence'
        : t.kind == PersonalisationTargetKind.backSquat &&
              _incrementGrams == null
        ? 'missing_equipment_increment'
        : numeric == null
        ? 'unavailable'
        : 'calculated';
    return {
      'binding': t.toJson(),
      'binding_digest': personalisationDigest(t.toJson()),
      'authored_intent': t.parameters,
      'selected_evidence': _selected[t.benchmark.id]?.toJson(),
      'state': state,
      'unavailable_reason': prescription['unavailable_reason'],
      'prescription': prescription,
      'actual': null,
    };
  }

  Future<BoundReviewReceipt> review(
    String slot, {
    Future<void> Function()? beforeReply,
  }) async {
    final captured = await _atomic(() {
      _receipts.remove(slot);
      if (_proposal != null) throw const BoundRefusal('consent_pending');
      return (
        _generation,
        ++_reviewSequence,
        personalisationCanonicalJson(_reviewDocument(slot)),
      );
    });
    if (beforeReply != null) await beforeReply();
    return _atomic(() {
      if (captured.$1 != _generation ||
          captured.$2 != _reviewSequence ||
          _proposal != null) {
        throw const BoundRefusal('stale_review');
      }
      final receipt = BoundReviewReceipt._(slot, _generation, captured.$3);
      _receipts[slot] = receipt;
      _issuedReceipts.add(receipt);
      return receipt;
    });
  }

  Future<FrozenBoundSession> start(BoundReviewReceipt receipt) => _atomic(() {
    final old = _started[receipt.slotKey];
    if (old != null) {
      // Idempotency requires a receipt issued by this repository, not matching supplied hashes.
      if (!_issuedReceipts.contains(receipt)) {
        throw const BoundRefusal('foreign_review_receipt');
      }
      return old;
    }
    if (!identical(_receipts[receipt.slotKey], receipt) ||
        receipt.generation != _generation ||
        _proposal != null) {
      throw const BoundRefusal('stale_or_foreign_review');
    }
    if (personalisationCanonicalJson(_reviewDocument(receipt.slotKey)) !=
        receipt.json) {
      throw const BoundRefusal('review_input_mismatch');
    }
    final targets = programme.targets
        .where((t) => t.slotKey == receipt.slotKey)
        .toList();
    const catalogue = HyroxBindingCatalogue();
    final frozenAt = _clock();
    if (!frozenAt.isUtc) throw const BoundRefusal('invalid_freeze_clock');
    final frozen = FrozenBoundSession._(
      receipt.slotKey,
      personalisationCanonicalJson({
        'format': 'local_bound_start_snapshot_v1',
        'frozen_at_utc': frozenAt.toIso8601String(),
        'scope': 'synthetic_in_memory_only',
        'athlete_id': athleteId,
        'package_hash': programme.hash,
        'package_canonical_json': programme.canonicalJson,
        'authored_source': programme.source,
        'source_text_sha256': personalisationTextDigest(programme.source),
        'slot_key': receipt.slotKey,
        'review': receipt.document,
        'review_digest': receipt.digest,
        'dependencies': [
          for (final t in targets)
            {
              'target_id': t.id,
              'binding': t.toJson(),
              'binding_digest': personalisationDigest(t.toJson()),
              'session_source': programme.sourceBody(t),
              'rule': catalogue.ruleDocument(t.kind),
              'rule_digest': t.rule.digest,
              'benchmark_definition': catalogue.benchmarkDocument(t.kind),
              'exercise_fixture': catalogue.exerciseDocument(t.kind),
            },
        ],
        'actual': null,
      }),
    );
    _started[receipt.slotKey] = frozen;
    return frozen;
  });
  final Set<BoundReviewReceipt> _issuedReceipts = {};
  Future<void> complete(String slot, {int? actualSquatGrams}) => _atomic(() {
    if (!_started.containsKey(slot)) {
      throw const BoundRefusal('session_not_started');
    }
    if (_completed.containsKey(slot)) {
      throw const BoundRefusal('completion_already_recorded');
    }
    if (actualSquatGrams != null &&
        (actualSquatGrams < 0 || actualSquatGrams > 1000000000)) {
      throw const BoundRefusal('invalid_actual_load');
    }
    if (actualSquatGrams != null &&
        !programme.targets.any(
          (t) =>
              t.slotKey == slot &&
              t.kind == PersonalisationTargetKind.backSquat,
        )) {
      throw const BoundRefusal('actual_target_scope_mismatch');
    }
    _completed[slot] = personalisationCanonicalJson({
      'actual_squat_grams': actualSquatGrams,
      'prescription_digest': _started[slot]!.digest,
    });
  });
  Future<void> dispose() => _atomic(() {
    _invalidate();
    _disposed = true;
  });
}

String personalisationTextDigest(String text) =>
    sha256.convert(utf8.encode(text)).toString();
