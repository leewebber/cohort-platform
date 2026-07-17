import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cohortPublished = const [
    Protocol(protocolId: 'RN-006', name: 'Classic Threshold'),
    Protocol(protocolId: 'ST-001', name: 'Lower Body A'),
  ];

  final coachSession = Protocol(
    protocolId: 'SES-001',
    name: 'Coach Session',
  );

  final programmeSession = Protocol(
    protocolId: 'SES-P1',
    name: 'Programme Session',
  );

  final template = Protocol(
    protocolId: 'TPL-001',
    name: 'Template',
  );

  final unpublishedCohort = Protocol(
    protocolId: 'BW-001',
    name: 'Bodyweight Grinder',
  );

  group('ProtocolRepository training content queries (fake)', () {
    test('listCohortProtocols excludes coach sessions and templates', () async {
      final repository = _FakeTrainingContentRepository(
        rows: [
          ...cohortPublished,
          coachSession,
          programmeSession,
          template,
        ],
        metadata: {
          'RN-006': _Metadata.cohortPublished,
          'ST-001': _Metadata.cohortPublished,
          'SES-001': _Metadata.coachPrivate(ownerId: 'dev-coach'),
          'SES-P1': _Metadata.programmeOnly(
            programmeVersionId: '11111111-1111-1111-1111-111111111111',
          ),
          'TPL-001': _Metadata.template(ownerId: 'dev-coach'),
        },
      );

      final results = await repository.listCohortProtocols();

      expect(results.map((p) => p.protocolId), ['RN-006', 'ST-001']);
    });

    test('listCohortProtocols requires published=true', () async {
      final repository = _FakeTrainingContentRepository(
        rows: [
          ...cohortPublished,
          unpublishedCohort,
        ],
        metadata: {
          'RN-006': _Metadata.cohortPublished,
          'ST-001': _Metadata.cohortPublished,
          'BW-001': const _Metadata(
            contentKind: TrainingContentKind.cohortProtocol,
            authoringScope: TrainingAuthoringScope.cohortGlobal,
            published: false,
          ),
        },
      );

      final results = await repository.listCohortProtocols();

      expect(results.map((p) => p.protocolId), isNot(contains('BW-001')));
    });

    test('listCoachSessions scopes by owner and excludes programme-only', () async {
      final repository = _FakeTrainingContentRepository(
        rows: [
          coachSession,
          programmeSession,
          Protocol(protocolId: 'SES-002', name: 'Other Coach'),
        ],
        metadata: {
          'SES-001': _Metadata.coachPrivate(ownerId: 'dev-coach'),
          'SES-P1': _Metadata.programmeOnly(
            programmeVersionId: '11111111-1111-1111-1111-111111111111',
          ),
          'SES-002': _Metadata.coachPrivate(ownerId: 'other-coach'),
        },
      );

      final results = await repository.listCoachSessions('dev-coach');

      expect(results.map((p) => p.protocolId), ['SES-001']);
    });

    test('listProgrammeSessions scopes by programme version', () async {
      final versionA = '11111111-1111-1111-1111-111111111111';
      final versionB = '22222222-2222-2222-2222-222222222222';

      final repository = _FakeTrainingContentRepository(
        rows: [
          programmeSession,
          Protocol(protocolId: 'SES-P2', name: 'Other Version Session'),
          coachSession,
        ],
        metadata: {
          'SES-P1': _Metadata.programmeOnly(programmeVersionId: versionA),
          'SES-P2': _Metadata.programmeOnly(programmeVersionId: versionB),
          'SES-001': _Metadata.coachPrivate(ownerId: 'dev-coach'),
        },
      );

      final results = await repository.listProgrammeSessions(versionA);

      expect(results.map((p) => p.protocolId), ['SES-P1']);
    });

    test('listSessionTemplates filters by content kind', () async {
      final repository = _FakeTrainingContentRepository(
        rows: [
          template,
          coachSession,
          ...cohortPublished,
        ],
        metadata: {
          'TPL-001': _Metadata.template(ownerId: 'dev-coach'),
          'SES-001': _Metadata.coachPrivate(ownerId: 'dev-coach'),
          'RN-006': _Metadata.cohortPublished,
          'ST-001': _Metadata.cohortPublished,
        },
      );

      final results = await repository.listSessionTemplates();

      expect(results.map((p) => p.protocolId), ['TPL-001']);
    });
  });
}

class _Metadata {
  const _Metadata({
    required this.contentKind,
    required this.authoringScope,
    this.ownerId,
    this.programmeVersionId,
    this.published = false,
  });

  final TrainingContentKind contentKind;
  final TrainingAuthoringScope authoringScope;
  final String? ownerId;
  final String? programmeVersionId;
  final bool published;

  static const cohortPublished = _Metadata(
    contentKind: TrainingContentKind.cohortProtocol,
    authoringScope: TrainingAuthoringScope.cohortGlobal,
    published: true,
  );

  static _Metadata coachPrivate({required String ownerId}) {
    return _Metadata(
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.coachPrivate,
      ownerId: ownerId,
    );
  }

  static _Metadata programmeOnly({required String programmeVersionId}) {
    return _Metadata(
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.programmeOnly,
      programmeVersionId: programmeVersionId,
    );
  }

  static _Metadata template({required String ownerId}) {
    return _Metadata(
      contentKind: TrainingContentKind.sessionTemplate,
      authoringScope: TrainingAuthoringScope.coachPrivate,
      ownerId: ownerId,
    );
  }
}

/// In-memory filter mirror of repository query predicates for unit tests.
class _FakeTrainingContentRepository extends ProtocolRepository {
  _FakeTrainingContentRepository({
    required List<Protocol> rows,
    Map<String, _Metadata>? metadata,
  })  : _rows = rows,
        _metadata = metadata ?? _defaultCohortMetadata(rows);

  final List<Protocol> _rows;
  final Map<String, _Metadata> _metadata;

  static Map<String, _Metadata> _defaultCohortMetadata(List<Protocol> rows) {
    return {
      for (final row in rows)
        row.protocolId: const _Metadata(
          contentKind: TrainingContentKind.cohortProtocol,
          authoringScope: TrainingAuthoringScope.cohortGlobal,
          published: true,
        ),
    };
  }

  @override
  Future<List<Protocol>> listCohortProtocols({int limit = 100}) async {
    return _rows
        .where((row) {
          final meta = _metadata[row.protocolId];
          return meta != null &&
              meta.contentKind == TrainingContentKind.cohortProtocol &&
              meta.authoringScope == TrainingAuthoringScope.cohortGlobal &&
              meta.published;
        })
        .take(limit)
        .toList();
  }

  @override
  Future<List<Protocol>> listCoachSessions(
    String ownerId, {
    int limit = 100,
  }) async {
    return _rows
        .where((row) {
          final meta = _metadata[row.protocolId];
          return meta != null &&
              meta.contentKind == TrainingContentKind.session &&
              meta.authoringScope == TrainingAuthoringScope.coachPrivate &&
              meta.ownerId == ownerId;
        })
        .take(limit)
        .toList();
  }

  @override
  Future<List<Protocol>> listProgrammeSessions(
    String programmeVersionId, {
    int limit = 100,
  }) async {
    return _rows
        .where((row) {
          final meta = _metadata[row.protocolId];
          return meta != null &&
              meta.contentKind == TrainingContentKind.session &&
              meta.authoringScope == TrainingAuthoringScope.programmeOnly &&
              meta.programmeVersionId == programmeVersionId;
        })
        .take(limit)
        .toList();
  }

  @override
  Future<List<Protocol>> listSessionTemplates({
    String? ownerId,
    int limit = 100,
  }) async {
    return _rows
        .where((row) {
          final meta = _metadata[row.protocolId];
          if (meta == null ||
              meta.contentKind != TrainingContentKind.sessionTemplate) {
            return false;
          }
          if (ownerId == null || ownerId.trim().isEmpty) {
            return true;
          }
          return meta.ownerId == ownerId.trim();
        })
        .take(limit)
        .toList();
  }
}
