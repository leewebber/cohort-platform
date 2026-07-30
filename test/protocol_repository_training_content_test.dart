import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cohortPublished = [
    Protocol(protocolId: 'RN-006', name: 'Classic Threshold'),
    Protocol(protocolId: 'ST-001', name: 'Lower Body A'),
  ];

  final coachSession = Protocol(protocolId: 'SES-001', name: 'Coach Session');

  final programmeSession = Protocol(
    protocolId: 'SES-P1',
    name: 'Programme Session',
  );

  final template = Protocol(protocolId: 'TPL-001', name: 'Template');

  final unpublishedCohort = Protocol(
    protocolId: 'BW-001',
    name: 'Bodyweight Grinder',
  );

  group('ProtocolRepository training content queries (fake)', () {
    test('listCohortProtocols excludes coach sessions and templates', () async {
      final repository = _FakeTrainingContentRepository(
        rows: [...cohortPublished, coachSession, programmeSession, template],
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
        rows: [...cohortPublished, unpublishedCohort],
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

    test(
      'listCoachSessions scopes by owner and excludes programme-only',
      () async {
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
      },
    );

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
        rows: [template, coachSession, ...cohortPublished],
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

    test(
      'listCanonicalSessionTemplates returns only published cohort templates',
      () async {
        final canonical = Protocol(protocolId: 'TMP-001', name: 'Full-Body');
        final coachTemplate = Protocol(
          protocolId: 'TPL-COACH',
          name: 'Coach Template',
        );
        final unpublished = Protocol(
          protocolId: 'TMP-UNPUB',
          name: 'Unpublished',
        );
        final unendorsed = Protocol(
          protocolId: 'TMP-UNEND',
          name: 'Unendorsed',
        );
        final ownedGlobal = Protocol(
          protocolId: 'TMP-OWNED',
          name: 'Owned Global',
        );
        final repository = _FakeTrainingContentRepository(
          rows: [
            canonical,
            coachTemplate,
            coachSession,
            unpublished,
            unendorsed,
            ownedGlobal,
          ],
          metadata: {
            'TMP-001': _Metadata.canonicalTemplate,
            'TPL-COACH': _Metadata.template(ownerId: 'dev-coach'),
            'SES-001': _Metadata.coachPrivate(ownerId: 'dev-coach'),
            'TMP-UNPUB': _Metadata(
              contentKind: TrainingContentKind.sessionTemplate,
              authoringScope: TrainingAuthoringScope.cohortGlobal,
              published: false,
              endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
            ),
            'TMP-UNEND': _Metadata(
              contentKind: TrainingContentKind.sessionTemplate,
              authoringScope: TrainingAuthoringScope.cohortGlobal,
              published: true,
              endorsementStatus: TrainingEndorsementStatus.coachAuthored,
            ),
            'TMP-OWNED': _Metadata(
              contentKind: TrainingContentKind.sessionTemplate,
              authoringScope: TrainingAuthoringScope.cohortGlobal,
              published: true,
              ownerId: 'dev-coach',
              endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
            ),
          },
        );

        final results = await repository.listCanonicalSessionTemplates();

        expect(results.map((p) => p.protocolId), ['TMP-001']);
      },
    );
  });
}

class _Metadata {
  const _Metadata({
    required this.contentKind,
    required this.authoringScope,
    this.ownerId,
    this.programmeVersionId,
    this.published = false,
    this.endorsementStatus,
  });

  final TrainingContentKind contentKind;
  final TrainingAuthoringScope authoringScope;
  final String? ownerId;
  final String? programmeVersionId;
  final bool published;
  final TrainingEndorsementStatus? endorsementStatus;

  static const cohortPublished = _Metadata(
    contentKind: TrainingContentKind.cohortProtocol,
    authoringScope: TrainingAuthoringScope.cohortGlobal,
    published: true,
    endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
  );

  static _Metadata coachPrivate({required String ownerId}) {
    return _Metadata(
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.coachPrivate,
      ownerId: ownerId,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
    );
  }

  static _Metadata programmeOnly({required String programmeVersionId}) {
    return _Metadata(
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.programmeOnly,
      programmeVersionId: programmeVersionId,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
    );
  }

  static _Metadata template({
    String? ownerId,
    bool published = true,
    TrainingEndorsementStatus endorsementStatus =
        TrainingEndorsementStatus.coachAuthored,
  }) {
    return _Metadata(
      contentKind: TrainingContentKind.sessionTemplate,
      authoringScope: ownerId == null
          ? TrainingAuthoringScope.cohortGlobal
          : TrainingAuthoringScope.coachPrivate,
      ownerId: ownerId,
      published: published,
      endorsementStatus: endorsementStatus,
    );
  }

  static const canonicalTemplate = _Metadata(
    contentKind: TrainingContentKind.sessionTemplate,
    authoringScope: TrainingAuthoringScope.cohortGlobal,
    published: true,
    endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
  );
}

/// In-memory filter mirror of repository query predicates for unit tests.
class _FakeTrainingContentRepository extends ProtocolRepository {
  _FakeTrainingContentRepository({
    required List<Protocol> rows,
    Map<String, _Metadata>? metadata,
  }) : _rows = rows,
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

  @override
  Future<List<Protocol>> listCanonicalSessionTemplates({
    int limit = 100,
  }) async {
    return _rows
        .where((row) {
          final meta = _metadata[row.protocolId];
          return meta != null &&
              meta.contentKind == TrainingContentKind.sessionTemplate &&
              meta.authoringScope == TrainingAuthoringScope.cohortGlobal &&
              meta.endorsementStatus ==
                  TrainingEndorsementStatus.cohortEndorsed &&
              meta.published &&
              (meta.ownerId == null || meta.ownerId!.trim().isEmpty);
        })
        .take(limit)
        .toList();
  }
}
