// Opt-in GoTrue → actual app stores → PostgREST/SQL proof. Local fixtures only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_role.dart';
import 'package:cohort_platform/features/auth/repositories/supabase_profile_repository.dart';
import 'package:cohort_platform/features/auth/services/auth_service.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final configPath = Platform.environment['COHORT_M12_CONFIG'];
  test(
    'new GoTrue athlete setup/private acquisition/security/restart',
    () async {
      final config = jsonDecode(File(configPath!).readAsStringSync()) as Map;
      final api = Uri.parse(config['API_URL'] as String);
      expect(api.scheme, 'http');
      expect(api.host, '127.0.0.1');
      final container = config['CONTAINER'] as String;
      expect(container.startsWith('supabase_db_s12g'), isTrue);
      Future<Process> openSql() => Process.start('docker', [
        'exec',
        '-i',
        container,
        'psql',
        '-X',
        '-U',
        'postgres',
        '-d',
        'postgres',
        '-At',
        '-v',
        'ON_ERROR_STOP=1',
        '-q',
      ]);
      Future<String> sql(String query) async {
        final process = await openSql();
        process.stdin.write(query);
        await process.stdin.close();
        final out = await utf8.decoder.bind(process.stdout).join();
        final err = await utf8.decoder.bind(process.stderr).join();
        expect(await process.exitCode, 0, reason: err);
        return out.trim();
      }

      SupabaseClient client() => SupabaseClient(
        api.toString(),
        config['ANON_KEY'] as String,
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: MemoryPkce(),
        ),
      );
      final a = client();
      final b = client();
      final restart = client();
      addTearDown(() async {
        await a.dispose();
        await b.dispose();
        await restart.dispose();
        CurrentUserSession.clear();
      });
      AuthController controller(SupabaseClient c) => AuthController(
        authService: AuthService(client: c),
        profileProvisioningService: ProfileProvisioningService(
          profileRepository: SupabaseProfileRepository(client: c),
        ),
      );
      final authA = controller(a);
      final authB = controller(b);
      addTearDown(authA.dispose);
      addTearDown(authB.dispose);
      final nonce = '${DateTime.now().microsecondsSinceEpoch}';
      final password = 'M12-local-${Random.secure().nextInt(1 << 32)}-aA!';
      // Sanitised stage marker for disposable proof diagnostics.
      debugPrint('M12_STAGE=signup');
      await authA.signUp(
        email: 'm12-a-$nonce@example.com',
        password: password,
        displayName: 'Synthetic athlete A',
        roles: {UserRole.athlete},
      );
      await authB.signUp(
        email: 'm12-b-$nonce@example.com',
        password: password,
        displayName: 'Synthetic athlete B',
        roles: {UserRole.athlete},
      );
      expect(a.auth.currentUser, isNotNull, reason: authA.state.errorMessage);
      expect(b.auth.currentUser, isNotNull, reason: authB.state.errorMessage);
      final uid = a.auth.currentUser!.id;
      final other = b.auth.currentUser!.id;
      final store = SupabaseAcquisitionStore(athleteId: uid, client: a);
      final foreign = SupabaseAcquisitionStore(athleteId: other, client: b);
      const v1 = 'c2000000-0000-4000-8000-000000000061';
      const v2 = 'c2000000-0000-4000-8000-000000000062';
      // Sanitised stage marker for disposable proof diagnostics.
      debugPrint('M12_STAGE=setup');
      expect((await store.loadSetup()).complete, isFalse);
      await sql(
        "INSERT INTO public.private_programme_alpha_eligibility(athlete_id,programme_version_id) VALUES('$uid','$v1'),('$uid','$v2');",
      );
      await expectLater(
        store.acquire(v1, DateTime(2026, 10, 26)),
        throwsA(isA<AcquisitionException>()),
      );
      await store.saveSetup('Europe/London', complete: false);
      expect((await store.loadSetup()).timezone, 'Europe/London');
      final interrupted = client();
      addTearDown(interrupted.dispose);
      await interrupted.auth.recoverSession(
        jsonEncode(a.auth.currentSession!.toJson()),
      );
      final draftAfterRestart = await SupabaseAcquisitionStore(
        athleteId: uid,
        client: interrupted,
      ).loadSetup();
      expect(draftAfterRestart.timezone, 'Europe/London');
      expect(draftAfterRestart.complete, isFalse);

      expect((await store.loadSetup()).complete, isFalse);
      await expectLater(
        store.saveSetup('UTC', complete: true),
        throwsA(isA<AcquisitionException>()),
      );
      await store.saveSetup('Europe/London', complete: true);
      await store.saveSetup('Europe/London', complete: true);
      await foreign.saveSetup('Asia/Makassar', complete: true);
      expect(await foreign.catalogue(), isEmpty);
      await expectLater(
        foreign.catalogue(versionId: v1),
        throwsA(isA<AcquisitionException>()),
      );
      await expectLater(
        foreign.acquire(v1, DateTime(2026, 10, 26)),
        throwsA(isA<AcquisitionException>()),
      );
      final mismatch = await b.rpc(
        'read_my_private_programme_catalogue',
        params: {'p_expected_athlete_id': uid},
      );
      expect(mismatch['status'], 'access_denied');
      for (final table in [
        'private_programme_alpha_eligibility',
        'athlete_training_setup',
      ]) {
        await expectLater(
          a.from(table).select(),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          a.from(table).insert({'athlete_id': uid, 'programme_version_id': v1}),
          throwsA(isA<PostgrestException>()),
        );
      }
      // Sanitised stage marker for disposable proof diagnostics.
      debugPrint('M12_STAGE=visibility');
      final legacyAttempt = await a.rpc(
        'enrol_athlete_in_private_programme_version',
        params: {
          'p_programme_version_id': v1,
          'p_timezone': 'Europe/London',
          'p_started_at': '2026-10-26',
          'p_replace_active': true,
        },
      );
      expect(legacyAttempt['status'], 'authorization_failure');
      final offers = await store.catalogue();
      expect(offers.length, 2);
      expect(offers.every((o) => o.ready), isTrue);
      expect(
        (await store.catalogue(versionId: v1)).single.title,
        contains('Synthetic'),
      );
      // Expired/revoked eligibility cannot be bypassed by guessed IDs or old RPCs.
      await sql(
        "UPDATE public.private_programme_alpha_eligibility SET expires_at=now()-interval '1 second' WHERE athlete_id='$uid' AND programme_version_id='$v1';",
      );
      await expectLater(
        store.acquire(v1, DateTime(2026, 10, 26)),
        throwsA(isA<AcquisitionException>()),
      );
      final old = await a.rpc(
        'enrol_athlete_in_private_programme_version',
        params: {
          'p_programme_version_id': v1,
          'p_timezone': 'Europe/London',
          'p_started_at': '2026-10-26',
          'p_replace_active': false,
        },
      );
      expect(old['status'], 'authorization_failure');
      await sql(
        "UPDATE public.private_programme_alpha_eligibility SET expires_at=NULL,revoked_at=now() WHERE athlete_id='$uid' AND programme_version_id='$v1';",
      );
      expect((await store.catalogue()).length, 1);
      await sql(
        "UPDATE public.private_programme_alpha_eligibility SET revoked_at=NULL WHERE athlete_id='$uid';",
      );
      // Sanitised stage marker for disposable proof diagnostics.
      debugPrint('M12_STAGE=rollback');
      // Inject failure after assignment creation: same transaction must roll back.
      await sql(
        "CREATE FUNCTION public.m12_fail() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN RAISE EXCEPTION 'synthetic materialisation failure'; END \$\$; CREATE TRIGGER m12_fail BEFORE INSERT ON public.programme_schedule_projections FOR EACH ROW EXECUTE FUNCTION public.m12_fail();",
      );
      await expectLater(
        store.acquire(v1, DateTime(2026, 10, 26)),
        throwsA(isA<AcquisitionException>()),
      );
      expect(
        await sql(
          "SELECT count(*) FROM public.programme_assignments WHERE athlete_id='$uid';",
        ),
        '0',
      );
      await sql(
        'DROP TRIGGER m12_fail ON public.programme_schedule_projections; DROP FUNCTION public.m12_fail();',
      );
      // Sanitised stage marker for disposable proof diagnostics.
      debugPrint('M12_STAGE=concurrency');
      final ids = await Future.wait(
        List.generate(6, (_) => store.acquire(v1, DateTime(2026, 10, 26))),
      );
      expect(ids.toSet().length, 1);
      expect(
        await sql(
          "SELECT count(*) FROM public.programme_assignments WHERE athlete_id='$uid';",
        ),
        '1',
      );
      expect(await store.acquire(v1, DateTime(2026, 10, 27)), ids.first);
      await expectLater(
        store.acquire(v2, DateTime(2026, 10, 26)),
        throwsA(isA<AcquisitionException>()),
      );
      // Sanitised stage marker for disposable proof diagnostics.
      debugPrint('M12_STAGE=calendar');
      final calendar = await a.rpc(
        'resolve_fixed_programme_calendar',
        params: {'p_assignment_id': ids.first},
      );
      expect(calendar['status'], 'ok');
      expect(calendar['assignment_id'], ids.first);
      // Sanitised stage marker for disposable proof diagnostics.
      debugPrint('M12_STAGE=restart');
      final session = jsonEncode(a.auth.currentSession!.toJson());
      await restart.auth.recoverSession(session);
      final authRestart = controller(restart);
      addTearDown(authRestart.dispose);
      await authRestart.initialize();
      final restored = SupabaseAcquisitionStore(
        athleteId: uid,
        client: restart,
      );
      expect((await restored.loadSetup()).complete, isTrue);
      final profileRepo = SupabaseProfileRepository(client: restart);
      final originalProfile = (await profileRepo.getProfile(uid))!;
      final concurrentProfiles = await Future.wait([
        profileRepo.createProfile(originalProfile),
        profileRepo.createProfile(originalProfile),
      ]);
      expect(
        concurrentProfiles.every((p) => p.id == uid && p.isAthlete),
        isTrue,
      );

      expect(
        (await restored.catalogue(versionId: v1)).single.assignmentId,
        ids.first,
      );
      // Repeated profile provisioning never creates/overwrites the existing account.
      await authRestart.completeProfile(
        displayName: 'Ignored retry',
        roles: {UserRole.coach},
      );
      expect(
        (await SupabaseProfileRepository(
          client: restart,
        ).getProfile(uid))!.isAthlete,
        isTrue,
      );
      expect(
        await sql("SELECT count(*) FROM public.profiles WHERE id='$uid';"),
        '1',
      );
      debugPrint('M12_STAGE=end-programme');
      final ending = ids.first;
      Matcher endError(String code) => isA<AcquisitionException>().having(
        (error) => error.code,
        'code',
        code,
      );
      await expectLater(
        foreign.endProgramme(assignmentId: ending, programmeVersionId: v1),
        throwsA(endError('access_denied')),
      );
      await expectLater(
        restored.endProgramme(assignmentId: ending, programmeVersionId: v2),
        throwsA(endError('access_denied')),
      );

      final mismatchedActor = await restart.rpc(
        'end_my_fixed_programme',
        params: {
          'p_expected_athlete_id': other,
          'p_assignment_id': ending,
          'p_programme_version_id': v1,
        },
      );
      expect(mismatchedActor['status'], 'access_denied');
      await expectLater(
        restart
            .from('programme_assignments')
            .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', ending),
        throwsA(isA<PostgrestException>()),
      );

      // Seed one linked session in the disposable database and protect it
      // through the same assignment/slot binding used by fixed session start.
      await sql('''
        WITH slot AS (
          SELECT * FROM public.programme_schedule_occurrences
          WHERE assignment_id='$ending' ORDER BY scheduled_date LIMIT 1
        ), session AS (
          INSERT INTO public.training_sessions(athlete_id,protocol_id,status)
          SELECT '$uid',protocol_id,'in_progress' FROM slot RETURNING id
        ), record AS (
          INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,
            source_protocol_id,assignment_id,programme_session_id,status,session_snapshot,started_at)
          SELECT gen_random_uuid(),'$uid',session.id,slot.protocol_id,slot.assignment_id,
            slot.session_slot_id,'in_progress','{}',now() FROM slot CROSS JOIN session
          RETURNING record_id
        )
        INSERT INTO public.programme_slot_outcomes(
          assignment_id,session_slot_id,week_number,day_key,session_order,
          outcome_status,training_session_id,programme_version_id,
          materialised_package_content_hash,programmed_session_key,completion_record_id)
        SELECT assignment_id,session_slot_id,week_number,day_key,session_order,
          'in_progress',session.id,programme_version_id,package_content_hash,
          programmed_session_key,record.record_id FROM slot CROSS JOIN session CROSS JOIN record;
      ''');
      await expectLater(
        restored.endProgramme(assignmentId: ending, programmeVersionId: v1),
        throwsA(endError('programme_session_in_progress')),
      );
      await sql('''
        UPDATE public.training_sessions SET status='completed'
        WHERE id=(SELECT training_session_id FROM public.programme_slot_outcomes WHERE assignment_id='$ending');
        UPDATE public.programme_slot_outcomes SET outcome_status='completed'
        WHERE assignment_id='$ending';
      ''');
      await expectLater(
        restored.endProgramme(assignmentId: ending, programmeVersionId: v1),
        throwsA(endError('programme_session_in_progress')),
      );
      await sql('''
        UPDATE public.training_session_records SET status='completed', completed_at=now()
        WHERE assignment_id='$ending';
        WITH block AS (
          INSERT INTO public.training_block_results(block_result_id,session_record_id,
            block_snapshot,status,result_type,position)
          SELECT gen_random_uuid(),record_id,'{}','completed','strength',1
          FROM public.training_session_records WHERE assignment_id='$ending'
          RETURNING block_result_id
        ), exercise AS (
          INSERT INTO public.training_exercise_results(exercise_result_id,block_result_id,
            exercise_snapshot,position)
          SELECT gen_random_uuid(),block_result_id,'{}',1 FROM block
          RETURNING exercise_result_id
        )
        INSERT INTO public.training_set_results(set_result_id,exercise_result_id,set_number,
          reps,load,load_unit,completed,position)
        SELECT gen_random_uuid(),exercise_result_id,1,5,10,'kg',true,1 FROM exercise;
      ''');
      Future<String> history() => sql('''
        SELECT jsonb_build_object(
          'outcomes',(SELECT jsonb_agg(to_jsonb(o) ORDER BY o.id) FROM public.programme_slot_outcomes o WHERE assignment_id='$ending'),
          'occurrences',(SELECT jsonb_agg(to_jsonb(o) ORDER BY o.id) FROM public.programme_schedule_occurrences o WHERE assignment_id='$ending'),
          'sessions',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) FROM public.training_sessions s JOIN public.programme_slot_outcomes o ON s.id=o.training_session_id WHERE o.assignment_id='$ending'),
          'records',(SELECT jsonb_agg(to_jsonb(r) ORDER BY r.record_id) FROM public.training_session_records r WHERE assignment_id='$ending'),
          'sets',(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.set_result_id)
            FROM public.training_set_results s JOIN public.training_exercise_results e USING(exercise_result_id)
            JOIN public.training_block_results b USING(block_result_id)
            JOIN public.training_session_records r ON r.record_id=b.session_record_id WHERE r.assignment_id='$ending'),
          'exercises',(SELECT jsonb_agg(to_jsonb(e) ORDER BY e.exercise_result_id)
            FROM public.training_exercise_results e JOIN public.training_block_results b USING(block_result_id)
            JOIN public.training_session_records r ON r.record_id=b.session_record_id WHERE r.assignment_id='$ending'),
          'blocks',(SELECT jsonb_agg(to_jsonb(b) ORDER BY b.block_result_id)
            FROM public.training_block_results b JOIN public.training_session_records r
            ON r.record_id=b.session_record_id WHERE r.assignment_id='$ending'),
          'projection',(SELECT to_jsonb(p) FROM public.programme_schedule_projections p WHERE assignment_id='$ending'));
      ''');
      final savedHistory = await history();
      await restored.endProgramme(assignmentId: ending, programmeVersionId: v1);
      final endStamp = await sql(
        "SELECT ended_at FROM public.programme_assignments WHERE id='$ending' AND status='paused';",
      );
      expect(endStamp, isNotEmpty);
      final retainedRecords = await restart
          .from('training_session_records')
          .select('record_id,status')
          .eq('assignment_id', ending);
      expect(retainedRecords.single['status'], 'completed');
      expect(await history(), savedHistory);
      expect(
        await sql(
          "SELECT count(*) FROM public.programme_assignments WHERE athlete_id='$uid' AND status='active';",
        ),
        '0',
      );
      final londonToday = DateTime.parse(
        await sql("SELECT (now() AT TIME ZONE 'Europe/London')::date;"),
      );
      final next = await restored.acquire(v2, londonToday);
      expect(next, isNot(ending));
      await restored.endProgramme(assignmentId: ending, programmeVersionId: v1);
      expect(
        await sql(
          "SELECT ended_at FROM public.programme_assignments WHERE id='$ending';",
        ),
        endStamp,
      );
      expect(
        await sql(
          "SELECT id FROM public.programme_assignments WHERE athlete_id='$uid' AND status='active';",
        ),
        next,
      );
      expect(await history(), savedHistory);
      expect(
        await sql(
          "SELECT has_function_privilege('authenticated','public.end_my_fixed_programme(uuid,uuid,uuid)','EXECUTE') AND NOT has_function_privilege('anon','public.end_my_fixed_programme(uuid,uuid,uuid)','EXECUTE') AND NOT has_function_privilege('service_role','public.end_my_fixed_programme(uuid,uuid,uuid)','EXECUTE');",
        ),
        't',
      );

      // Sanitised stage marker for disposable proof diagnostics.
      debugPrint('M12_STAGE=logout');
      await authA.signOut();
      await expectLater(
        store.catalogue(),
        throwsA(isA<AcquisitionException>()),
      );
      expect(await foreign.catalogue(), isEmpty);
      expect(
        await sql(
          "SELECT count(*) FROM public.programme_assignments WHERE athlete_id='$other';",
        ),
        '0',
      );
      await sql(
        "INSERT INTO public.private_programme_alpha_eligibility(athlete_id,programme_version_id) VALUES('$other','$v2');",
      );
      final v2Assignment = await foreign.acquire(v2, londonToday);
      final v2Calendar = await b.rpc(
        'resolve_fixed_programme_calendar',
        params: {'p_assignment_id': v2Assignment},
      );
      expect(v2Calendar['status'], 'ok');
      expect((await foreign.catalogue()).single.assignmentId, v2Assignment);
      expect(
        await sql(
          "SELECT package_schema_version FROM public.programme_versions WHERE id='$v2';",
        ),
        '2',
      );
      debugPrint('M12_STAGE=security');
      // Effective ACL proof includes hosted-style function defaults, RLS and closed helper RPCs.
      expect(
        await sql(
          "SELECT bool_and(relrowsecurity) FROM pg_class WHERE oid IN ('public.athlete_training_setup'::regclass,'public.private_programme_alpha_eligibility'::regclass);",
        ),
        't',
      );
      expect(
        await sql(
          "SELECT has_function_privilege('anon','public.acquire_my_private_programme(uuid,uuid,date)','EXECUTE') OR has_function_privilege('service_role','public.acquire_my_private_programme(uuid,uuid,date)','EXECUTE') OR has_function_privilege('authenticated','public.cohort_private_alpha_eligible(uuid)','EXECUTE');",
        ),
        'f',
      );
      expect(
        await sql(
          "SELECT bool_and(NOT has_table_privilege(r,t,p)) FROM unnest(ARRAY['anon','authenticated','service_role']) r CROSS JOIN unnest(ARRAY['public.athlete_training_setup','public.private_programme_alpha_eligibility']) t CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) p;",
        ),
        't',
      );
      expect(
        await sql(
          "SELECT bool_and(NOT has_column_privilege(r,c.oid,a.attname,p)) FROM pg_class c JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped CROSS JOIN unnest(ARRAY['anon','authenticated','service_role']) r CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','REFERENCES']) p WHERE c.oid IN ('public.athlete_training_setup'::regclass,'public.private_programme_alpha_eligibility'::regclass);",
        ),
        't',
      );
      expect(
        await sql(
          "SELECT bool_and(p.proacl IS NOT DISTINCT FROM b.proacl AND p.proowner=b.proowner) FROM public.m12_pre_acls b JOIN pg_proc p ON p.oid=b.oid;",
        ),
        't',
      );
      expect(
        await sql(
          "SELECT bool_and(has_function_privilege('authenticated',f,'EXECUTE') AND NOT has_function_privilege('anon',f,'EXECUTE') AND NOT has_function_privilege('service_role',f,'EXECUTE')) FROM unnest(ARRAY['public.read_my_training_setup(uuid)','public.save_my_training_setup(uuid,text,boolean)','public.read_my_private_programme_catalogue(uuid,uuid)','public.acquire_my_private_programme(uuid,uuid,date)']) f;",
        ),
        't',
      );
      expect(
        await sql(
          "SELECT to_regprocedure('public.approve_publication_event_v1(uuid,uuid,text)') IS NULL;",
        ),
        't',
      );
      debugPrint('M12_STAGE=end-start-races');
      String athleteTransaction(String owner) =>
          """
        SET LOCAL statement_timeout = '10s';
        SET LOCAL request.jwt.claim.sub = '$owner';
        SET LOCAL ROLE authenticated;
      """;
      String end(String owner, String id) =>
          "public.end_my_fixed_programme('$owner','$id','$v2')->>'status'";
      Future<String> occurrence(String id) => sql("""
        SELECT id FROM public.programme_schedule_occurrences
        WHERE assignment_id='$id' AND scheduled_date='${londonToday.toIso8601String().split('T').first}'::date;
      """);
      String start(String id) =>
          "public.create_or_resume_fixed_programme_occurrence_session('$id')";
      expect(
        await sql("""
        BEGIN ISOLATION LEVEL REPEATABLE READ;
        ${athleteTransaction(uid)}
        SELECT ${end(uid, next)};
        ROLLBACK;
      """),
        'unavailable',
      );
      final aOccurrence = await occurrence(next);
      final bOccurrence = await occurrence(v2Assignment);
      expect(aOccurrence, isNotEmpty);
      expect(bOccurrence, isNotEmpty);
      await proveEndStartRace(
        openSql: openSql,
        sql: sql,
        setup: athleteTransaction(uid),
        first: "${start(aOccurrence)}->>'status'",
        firstStatus: 'created',
        second: end(uid, next),
        secondStatus: 'programme_session_in_progress',
      );
      await proveEndStartRace(
        openSql: openSql,
        sql: sql,
        setup: athleteTransaction(other),
        first: end(other, v2Assignment),
        firstStatus: 'ok',
        second: "${start(bOccurrence)}->>'code'",
        secondStatus: 'fixed_assignment_ineligible',
      );
      expect(
        await sql("""
        SELECT status || ':' || (SELECT count(*) FROM public.programme_slot_outcomes
          WHERE assignment_id='$next' AND outcome_status='in_progress')
        FROM public.programme_assignments WHERE id='$next';
      """),
        'active:1',
      );
      expect(
        await sql("""
        SELECT status || ':' || (SELECT count(*) FROM public.programme_slot_outcomes
          WHERE assignment_id='$v2Assignment')
        FROM public.programme_assignments WHERE id='$v2Assignment' AND ended_at IS NOT NULL;
      """),
        'paused:0',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: configPath == null
        ? 'Run only via disposable M1.2 local gate'
        : false,
  );
}

// Keep the first real RPC transaction open until PostgreSQL confirms that
// the competing RPC is waiting on it. No timing assumption determines who wins.
Future<void> proveEndStartRace({
  required Future<Process> Function() openSql,
  required Future<String> Function(String) sql,
  required String setup,
  required String first,
  required String firstStatus,
  required String second,
  required String secondStatus,
}) async {
  final holder = await openSql();
  final lines = StreamIterator(
    holder.stdout.transform(utf8.decoder).transform(const LineSplitter()),
  );
  final errors = holder.stderr.transform(utf8.decoder).join();
  try {
    holder.stdin.write("BEGIN; $setup SELECT 'FIRST:' || ($first);\n");
    await holder.stdin.flush();
    expect(await lines.moveNext().timeout(const Duration(seconds: 10)), isTrue);
    expect(lines.current, 'FIRST:$firstStatus');

    final result = sql("""
      BEGIN;
      $setup
      SET LOCAL application_name = 'm12-end-race-waiter';
      SELECT $second;
      COMMIT;
    """);
    // Consume the result even if the blocking assertion fails.
    unawaited(result.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    var blocked = false;
    final deadline = Stopwatch()..start();
    while (!blocked && deadline.elapsed < const Duration(seconds: 5)) {
      blocked =
          await sql("""
        SELECT EXISTS (SELECT 1 FROM pg_stat_activity
          WHERE application_name='m12-end-race-waiter'
          AND cardinality(pg_blocking_pids(pid)) > 0);
      """) ==
          't';
    }
    expect(blocked, isTrue);
    holder.stdin.writeln('COMMIT;');
    expect(await result, secondStatus);
  } finally {
    await holder.stdin.close();
    await lines.cancel();
    expect(await holder.exitCode, 0, reason: await errors);
  }
}

class MemoryPkce extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}
