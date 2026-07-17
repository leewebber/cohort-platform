import 'dart:io';

import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/training_content_classification.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrainingContentKindDb', () {
    test('round-trips cohort_protocol', () {
      expect(
        TrainingContentKindDb.fromDb('cohort_protocol').dbValue,
        'cohort_protocol',
      );
    });

    test('round-trips session', () {
      expect(
        TrainingContentKindDb.fromDb('session').dbValue,
        'session',
      );
    });

    test('round-trips session_template', () {
      expect(
        TrainingContentKindDb.fromDb('session_template').dbValue,
        'session_template',
      );
    });

    test('unknown value falls back to session', () {
      expect(
        TrainingContentKindDb.fromDb('legacy_kind'),
        TrainingContentKind.session,
      );
    });
  });

  group('TrainingAuthoringScopeDb', () {
    test('round-trips all scopes', () {
      for (final scope in TrainingAuthoringScope.values) {
        expect(TrainingAuthoringScopeDb.fromDb(scope.dbValue), scope);
      }
    });

    test('unknown value falls back to coachPrivate', () {
      expect(
        TrainingAuthoringScopeDb.fromDb('unknown_scope'),
        TrainingAuthoringScope.coachPrivate,
      );
    });
  });

  group('TrainingEndorsementStatusDb', () {
    test('round-trips all statuses', () {
      for (final status in TrainingEndorsementStatus.values) {
        expect(TrainingEndorsementStatusDb.fromDb(status.dbValue), status);
      }
    });

    test('unknown endorsement never becomes cohortEndorsed', () {
      expect(
        TrainingEndorsementStatusDb.fromDb('legacy_status'),
        TrainingEndorsementStatus.unreviewed,
      );
      expect(
        TrainingEndorsementStatusDb.fromDb(null),
        TrainingEndorsementStatus.unreviewed,
      );
    });
  });

  group('ProtocolDraft metadata mapping', () {
    test('null legacy row fields load safe non-endorsed fallbacks', () {
      const base = ProtocolDraft(
        protocolId: 'RN-006',
        name: 'Classic Threshold',
        steps: [],
      );

      final loaded = ProtocolDraft.applyTrainingContentMetadata(
        draft: base,
        row: const {},
      );

      expect(loaded.contentKind, TrainingContentKind.session);
      expect(loaded.authoringScope, TrainingAuthoringScope.coachPrivate);
      expect(loaded.endorsementStatus, TrainingEndorsementStatus.unreviewed);
    });

    test('explicit cohort row loads correctly', () {
      const base = ProtocolDraft(
        protocolId: 'RN-006',
        name: 'Classic Threshold',
        steps: [],
      );

      final loaded = ProtocolDraft.applyTrainingContentMetadata(
        draft: base,
        row: const {
          'content_kind': 'cohort_protocol',
          'authoring_scope': 'cohort_global',
          'endorsement_status': 'cohort_endorsed',
        },
      );

      expect(loaded.contentKind, TrainingContentKind.cohortProtocol);
      expect(loaded.authoringScope, TrainingAuthoringScope.cohortGlobal);
      expect(loaded.endorsementStatus, TrainingEndorsementStatus.cohortEndorsed);
    });

    test('toProtocolMap retains metadata columns', () {
      const draft = ProtocolDraft(
        protocolId: 'SES-001',
        name: 'Coach Session',
        steps: [],
        contentKind: TrainingContentKind.session,
        authoringScope: TrainingAuthoringScope.coachPrivate,
        endorsementStatus: TrainingEndorsementStatus.coachAuthored,
        ownerId: 'dev-coach',
        sourceContentId: 'RN-006',
        sourceContentKind: TrainingContentKind.cohortProtocol,
      );

      final map = draft.toProtocolMap();

      expect(map['content_kind'], 'session');
      expect(map['authoring_scope'], 'coach_private');
      expect(map['endorsement_status'], 'coach_authored');
      expect(map['owner_id'], 'dev-coach');
      expect(map['source_content_id'], 'RN-006');
      expect(map['source_content_kind'], 'cohort_protocol');
    });

    test('editing ordinary fields does not reset default cohort classification',
        () {
      const draft = ProtocolDraft(
        protocolId: 'RN-006',
        name: 'Classic Threshold',
        steps: [],
      );

      final edited = draft.copyWith(name: 'Updated Name');

      expect(edited.contentKind, TrainingContentKind.cohortProtocol);
      expect(edited.authoringScope, TrainingAuthoringScope.cohortGlobal);
      expect(edited.endorsementStatus, TrainingEndorsementStatus.cohortEndorsed);
    });
  });

  group('TrainingContentClassification invariants', () {
    test('cohort protocol invariant', () {
      const draft = ProtocolDraft(
        protocolId: 'RN-006',
        name: 'Classic Threshold',
        steps: [],
      );

      expect(TrainingContentClassification.isCohortProtocol(draft), isTrue);
      expect(
        () => TrainingContentClassification.validateCohortProtocol(draft),
        returnsNormally,
      );
    });

    test('programme-only session requires programmeVersionId', () {
      const draft = ProtocolDraft(
        protocolId: 'SES-P1',
        name: 'Week 1 Session',
        steps: [],
        contentKind: TrainingContentKind.session,
        authoringScope: TrainingAuthoringScope.programmeOnly,
        programmeVersionId: '11111111-1111-1111-1111-111111111111',
      );

      expect(TrainingContentClassification.isProgrammeOnlySession(draft), isTrue);
    });

    test('reusable coach session requires ownerId', () {
      const draft = ProtocolDraft(
        protocolId: 'SES-001',
        name: 'My Session',
        steps: [],
        contentKind: TrainingContentKind.session,
        authoringScope: TrainingAuthoringScope.coachPrivate,
        ownerId: 'dev-coach',
      );

      expect(TrainingContentClassification.isReusableCoachSession(draft), isTrue);
      expect(TrainingContentClassification.isProgrammeBuilderAttachable(draft),
          isFalse);
    });

    test('session template is not programme builder attachable', () {
      const draft = ProtocolDraft(
        protocolId: 'TPL-001',
        name: 'Template',
        steps: [],
        contentKind: TrainingContentKind.sessionTemplate,
      );

      expect(TrainingContentClassification.isSessionTemplate(draft), isTrue);
      expect(TrainingContentClassification.isProgrammeBuilderAttachable(draft),
          isFalse);
    });
  });

  group('training content migration contract', () {
    late String migrationSql;

    setUpAll(() {
      migrationSql = File(
        'supabase/migrations/20260718130000_add_training_content_metadata.sql',
      ).readAsStringSync();
    });

    test('migration file exists', () {
      expect(
        File(
          'supabase/migrations/20260718130000_add_training_content_metadata.sql',
        ).existsSync(),
        isTrue,
      );
    });

    test('adds metadata columns with cohort defaults', () {
      expect(migrationSql, contains("content_kind TEXT NOT NULL DEFAULT 'cohort_protocol'"));
      expect(migrationSql, contains("authoring_scope TEXT NOT NULL DEFAULT 'cohort_global'"));
      expect(migrationSql, contains("endorsement_status TEXT NOT NULL DEFAULT 'cohort_endorsed'"));
    });

    test('defines check constraints', () {
      expect(migrationSql, contains('performance_protocols_content_kind_check'));
      expect(migrationSql, contains('performance_protocols_authoring_scope_check'));
      expect(migrationSql, contains('performance_protocols_endorsement_status_check'));
      expect(migrationSql, contains('performance_protocols_source_content_kind_check'));
    });

    test('backfills legacy cohort protocols and logs count', () {
      expect(migrationSql, contains("content_kind = 'cohort_protocol'"));
      expect(migrationSql, contains("authoring_scope = 'cohort_global'"));
      expect(migrationSql, contains("endorsement_status = 'cohort_endorsed'"));
      expect(migrationSql, contains('[TrainingContentMigration] legacy cohort protocol count='));
    });

    test('does not add forbidden columns or content kind', () {
      expect(migrationSql, isNot(contains('is_template')));
      expect(migrationSql, isNot(contains('lifecycle_status')));
      expect(
        migrationSql,
        isNot(
          contains(
            "CHECK (content_kind IN ('cohort_protocol', 'session', 'session_template', 'programme_session'",
          ),
        ),
      );
    });

    test('FK programme_version_id references programme_versions', () {
      expect(migrationSql, contains('performance_protocols_programme_version_id_fkey'));
      expect(migrationSql, contains('REFERENCES programme_versions (id)'));
    });
  });
}
