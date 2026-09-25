import 'dart:io';

import 'package:cohort_platform/features/programme_studio/domain/programme_review_models.dart';
import 'package:cohort_platform/features/programme_studio/projection/executable_protocol_sql_reader.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_catalog.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_projector.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_source.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = Directory.current;
  const projector = ProgrammeReviewProjector();

  ProgrammeReviewCatalog realCatalog() {
    return ProgrammeReviewWorkspace(
      readAsset: (path) => File('${repoRoot.path}/$path').readAsStringSync(),
    ).loadRealCatalog();
  }

  test('projects Apollo and Spartan with stable identity and ordering', () {
    final first = realCatalog();
    expect(first.authority, ProgrammeReviewCatalog.derivedAuthority);
    expect(first.programmes.map((item) => item.catalogId), [
      'apollo-build-v2',
      'spartan-physique-v3',
    ]);
    final apollo = first.programmes.first;
    expect(apollo.classification, ProgrammeReviewClassification.internalPersonal);
    expect(apollo.lineageCode, 'APOLLO-BUILD-12-WEEK');
    expect(apollo.versionNumber, 2);
    expect(apollo.sessionsPerWeek, 7);
    expect(apollo.durationWeeks, 12);
    expect(apollo.scheduledWeekCount, 12);
    expect(
      apollo.compile.contentHashSha256,
      '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83',
    );
    expect(apollo.programmeVersionId, '2ba018bd-7dc2-4dfd-8d8e-e35823158920');
    expect(apollo.weeks, hasLength(12));
    expect(apollo.weeks.first.days, hasLength(7));

    final spartan = first.programmes.last;
    expect(spartan.classification, ProgrammeReviewClassification.legacyWithheld);
    expect(spartan.durationWeeks, 1);
    expect(spartan.sessionsPerWeek, 6);
    expect(spartan.scheduledWeekCount, 1);
    expect(
      spartan.compile.contentHashSha256,
      isNot(isEmpty),
    );
    expect(spartan.findings.any((item) => item.code == 'single_week_programme'), isTrue);

    final apolloSessions = apollo.weeks
        .expand((week) => week.days)
        .expand((day) => day.sessions);
    expect(apolloSessions.every((session) => session.bodiesResolved), isTrue);
    expect(
      apolloSessions.every((session) => session.blocks.isNotEmpty),
      isTrue,
    );
    final spartanSessions = spartan.weeks
        .expand((week) => week.days)
        .expand((day) => day.sessions);
    expect(spartanSessions.every((session) => session.bodiesResolved), isTrue);

    expect(
      projector.projectCanonicalJson(_realRequest()),
      projector.projectCanonicalJson(_realRequest()),
    );
  });

  test('excludes fixtures from default real inventory', () {
    final catalog = realCatalog();
    expect(
      catalog.realInventory(includeFixtures: false).map((item) => item.catalogId),
      ['apollo-build-v2', 'spartan-physique-v3'],
    );
    expect(
      catalog.realInventory(includeFixtures: false).any(
        (item) =>
            item.classification == ProgrammeReviewClassification.fixtureTestExample,
      ),
      isFalse,
    );
    expect(catalog.plannedFamilies, isNotEmpty);
    expect(
      catalog.plannedFamilies.every((item) => item.toJson()['weeks'] == const <Never>[] || (item.toJson()['weeks'] as List).isEmpty),
      isTrue,
    );
  });

  test('fails closed on malformed package YAML', () {
    final result = projector.projectBundle(
      const ProgrammeReviewSourceBundle(
        spec: ProgrammeReviewSourceSpec(
          catalogId: 'malformed',
          classification: ProgrammeReviewClassification.fixtureTestExample,
          planPackagePath: 'fixture/malformed.yaml',
          fixture: true,
        ),
        planPackageYaml: '::: not yaml',
      ),
    );
    expect(result.compile.state, ProgrammeReviewCompileState.invalid);
    expect(result.weeks, isEmpty);
    expect(
      result.findings.any((item) => item.code == 'package_compile_failed'),
      isTrue,
    );
  });

  test('surfaces unsupported workout format without dropping the block', () {
    const sql = '''
INSERT INTO public.performance_protocols(protocol_id,name,purpose,published,content_kind,authoring_scope,endorsement_status,organisation_id,session_lineage_id,revision_number,lifecycle_status,duration_min,primary_session_intent,coaching_notes) VALUES
 ('PROTO-X','Odd','x','false','session','organisation','organisation_approved','x','00000000-0000-4000-8000-000000000001',1,'draft',10,'test','n');
INSERT INTO public.session_blocks(block_id,session_id,block_type,title,content,workout_format,timer_config,coach_notes,position) VALUES
 ('11111111-0000-4000-8000-000000000001','PROTO-X','mystery','Mystery block','Do the thing','unknown_format',NULL,NULL,1);
''';
    final protocols = const ExecutableProtocolSqlReader().read([sql]);
    expect(protocols['PROTO-X']!.blocks, hasLength(1));
    expect(protocols['PROTO-X']!.blocks.single.unsupportedReason, contains('unknown_format'));
    expect(protocols['PROTO-X']!.blocks.single.title, 'Mystery block');
  });

  test('reads Apollo week-1 SQL blocks including conditioning formats', () {
    final sql = File(
      'supabase/migrations/20260821120000_apollo_build_week1_executable_protocols.sql',
    ).readAsStringSync();
    final protocols = const ExecutableProtocolSqlReader().read([sql]);
    expect(protocols.keys, contains('APOLLO-W1-THU-R1'));
    final engine = protocols['APOLLO-W1-THU-R1']!;
    expect(engine.blocks.map((item) => item.title), contains('5K-effort intervals'));
    expect(
      engine.blocks.any((item) => item.workoutFormat == 'intervals'),
      isTrue,
    );
  });
}

ProgrammeReviewProjectionRequest _realRequest() {
  return ProgrammeReviewProjectionRequest(
    bundles: [
      for (final spec in ProgrammeReviewCatalogRegistry.realSpecs)
        ProgrammeReviewWorkspace(
          readAsset: (path) => File('${Directory.current.path}/$path').readAsStringSync(),
        ).loadBundle(spec),
    ],
    plannedFamilies: ProgrammeReviewCatalogRegistry.plannedFamilies,
  );
}
