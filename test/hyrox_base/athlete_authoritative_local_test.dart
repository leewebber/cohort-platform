import 'package:cohort_platform/application/hyrox_base/duration_choice.dart';
// Actual local authenticated repository → canonical server → runner → save/completion/history.
// Opt in only through the disposable loopback gate; no hosted URL is accepted.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cohort_platform/application/hyrox_base/benchmark_repository.dart';
import 'package:cohort_platform/application/hyrox_base/programme_prescription_repository.dart';
import 'package:cohort_platform/core/services/supabase_service.dart';
import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_supabase_store.dart';
import 'package:cohort_platform/data/repositories/programme_version_supabase_store.dart';
import 'package:cohort_platform/domain/hyrox_base/base_personalisation.dart';
import 'package:cohort_platform/domain/hyrox_base/programme_prescription.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_prepared_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_supabase_store.dart';
import 'package:cohort_platform/features/performance/services/performance_correction_service.dart';
import 'package:cohort_platform/features/performance/services/interval_set_sync.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/interval_work_result.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/repositories/supabase_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/session/models/bound_programme_execution.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';

void main() {
  final configFile = Platform.environment['COHORT_LOCAL_V3_CONFIG'];
  test(
    'authenticated v3 review consent canonical start runner save completion History',
    () async {
      final config = jsonDecode(File(configFile!).readAsStringSync()) as Map;
      final api = Uri.parse(config['API_URL'] as String);
      expect(api.scheme, 'http');
      expect({'127.0.0.1', 'localhost'}, contains(api.host));
      var actor =
          config['TEST_ACTOR'] as String? ??
          'bc230000-0000-4000-8000-000000000006';
      String jwt() {
        String enc(Object v) =>
            base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
        final m =
            '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': actor, 'role': 'authenticated', 'aud': 'authenticated', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800})}';
        return '$m.${base64Url.encode(Hmac(sha256, utf8.encode(config['JWT_SECRET'] as String)).convert(utf8.encode(m)).bytes).replaceAll('=', '')}';
      }

      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: api.toString(),
        publishableKey: config['ANON_KEY'] as String,
        accessToken: () async => jwt(),
        debug: false,
      );
      addTearDown(() => Supabase.instance.dispose());
      final client = SupabaseService.client;
      final benchmarks = BaseBenchmarkRepository();
      final prescriptions = ProgrammePrescriptionRepository();
      final launcher = ProgrammeSessionExecutionLauncher();
      Future<AthleteProgrammePrepareResult> prepare() async {
        final service = AthleteProgrammeSessionPrepareService(
          assignmentStore: const ProgrammeAssignmentSupabaseStore(),
          slotResolver: const AthleteProgrammeAuthoredSlotResolver(
            versionStore: ProgrammeVersionSupabaseStore(),
          ),
          sessionLoader: SessionExecutionLoader(),
        );
        final assignment = (await const ProgrammeAssignmentSupabaseStore()
            .getActiveAssignment(actor))!;
        final calendar =
            await const FixedProgrammeOccurrenceProjectionSupabaseStore()
                .resolveForAssignment(assignment.id);
        final occurrence = calendar.occurrences.firstWhere(
          (o) => o.sessionOrder == 1 && o.weekNumber == 1,
        );
        final p = await service.prepareFixedOccurrence(assignment, occurrence);
        expect(p.isReady, true, reason: '${p.code}: ${p.message}');
        expect(p.executionContext!.packageSchemaVersion, 3);
        return p;
      }

      final prepared = await prepare();
      final c = prepared.executionContext!;
      final chosen = <String, String?>{};
      for (final m in [
        BaseMetric.run10km,
        BaseMetric.row2km,
        BaseMetric.backSquat5rm,
      ]) {
        final r = await benchmarks.record(
          commandId: DatabaseUuid.newV4(),
          metric: m,
          value: m == BaseMetric.run10km
              ? '3000'
              : m == BaseMetric.row2km
              ? '480'
              : '100',
          unit: m == BaseMetric.backSquat5rm
              ? BaseInputUnit.kilograms
              : BaseInputUnit.seconds,
          testDate: '2026-10-22',
          sourceType: BaseSourceType.knownResult,
          sourceReference:
              'Local repository test ${m.name} ${DatabaseUuid.newV4()}',
        );
        expect(r['status'], 'recorded');
        chosen[m.name] = r['revision_id'] as String;
      }
      Future<Map<String, Object?>> review(Map<String, String?> selection) =>
          prescriptions.review(
            assignmentId: c.assignmentId,
            programmeVersionId: c.programmeVersionId,
            selectedRevisions: selection,
            incrementGrams: 2500,
          );
      Future<Map<String, Object?>> accept(Map<String, Object?> r) =>
          prescriptions.consent(
            commandId: DatabaseUuid.newV4(),
            assignmentId: c.assignmentId,
            programmeVersionId: c.programmeVersionId,
            reviewId: r['review_id'] as String,
            expectedConsentId: r['expected_consent_id'] as String?,
            withdraw: false,
          );
      final missing = await review({});
      expect(
        ProgrammePrescription(
          Map<String, dynamic>.from(missing['document'] as Map),
        ).targets.every((t) => !t.available),
        true,
      );
      final r = await review(chosen);
      expect(r['status'], 'review');
      final projection = ProgrammePrescription(
        Map<String, dynamic>.from(r['document'] as Map),
      );
      expect(
        projection.targets
            .firstWhere((t) => t.kind == 'runningIntervals')
            .targetLabel,
        '5:00.0–5:15.0 /km',
      );
      expect(
        projection.targets
            .firstWhere((t) => t.kind == 'dedicatedRowIntervals')
            .targetLabel,
        '2:10.0–2:15.0 /500 m',
      );
      expect(
        projection.targets.firstWhere((t) => t.kind == 'backSquat').targetLabel,
        '80.0 kg total external load',
      );
      final consent = await accept(r);
      expect(consent['status'], 'accepted');
      final state = await prescriptions.readState(
        assignmentId: c.assignmentId,
        programmeVersionId: c.programmeVersionId,
      );
      expect((state['benchmarks'] as List).length, greaterThanOrEqualTo(3));
      final exact = c.copyWith(boundConsentId: consent['consent_id'] as String);
      final windows = authoredDurationWindows(prepared.package!.plan);
      if (Platform.environment['COHORT_LOCAL_V3_EXPECT_DURATION'] == '1') {
        expect(
          windows,
          isNotEmpty,
          reason:
              'This task-owned fixture must exercise the three-argument duration RPC.',
        );
      }
      if (windows.isNotEmpty) {
        await expectLater(
          launcher.createOrResumeLaunchResult(
            athleteId: actor,
            programmeContext: exact,
            package: prepared.package!,
          ),
          throwsA(
            isA<ProgrammeSessionExecutionException>().having(
              (e) => e.code,
              'code',
              ProgrammeSessionExecutionFailureCode.durationChoiceRequired,
            ),
          ),
        );
      }
      final started = await launcher.createOrResumeLaunchResult(
        athleteId: actor,
        programmeContext: exact,
        package: prepared.package!,
        durationChoices: windows.isEmpty
            ? null
            : {for (final e in windows.entries) e.key: e.value.last},
      );
      expect(started.wasResumed, false);
      final duplicate = await Future.wait(
        List.generate(
          2,
          (_) => launcher.createOrResumeLaunchResult(
            athleteId: actor,
            programmeContext: c,
            package: prepared.package!,
          ),
        ),
      );
      for (final retry in duplicate) {
        expect(retry.wasResumed, true);
        expect(retry.trainingSession.id, started.trainingSession.id);
        expect(
          retry.boundPrescriptionSnapshot,
          started.boundPrescriptionSnapshot,
        );
      }
      // New declaration is not selected automatically; explicit replacement changes future only.
      final faster = await benchmarks.record(
        commandId: DatabaseUuid.newV4(),
        metric: BaseMetric.run10km,
        value: '2400',
        unit: BaseInputUnit.seconds,
        testDate: '2026-10-23',
        sourceType: BaseSourceType.recordedResult,
        sourceReference: 'Different future result',
      );
      chosen['run10km'] = faster['revision_id'] as String;
      final changed = await review(chosen);
      expect(
        ProgrammePrescription(
          Map<String, dynamic>.from(changed['document'] as Map),
        ).targets.firstWhere((t) => t.kind == 'runningIntervals').targetLabel,
        '4:00.0–4:12.0 /km',
      );
      final replaced = await accept(changed);
      expect(replaced['status'], 'accepted');
      expect((await accept(r))['status'], 'refused');
      final withdrawn = await prescriptions.consent(
        commandId: DatabaseUuid.newV4(),
        assignmentId: c.assignmentId,
        programmeVersionId: c.programmeVersionId,
        reviewId: null,
        expectedConsentId: replaced['consent_id'] as String,
        withdraw: true,
      );
      expect(withdrawn['disposition'], 'withdrawn');
      final resumed = await launcher.createOrResumeLaunchResult(
        athleteId: actor,
        programmeContext: c,
        package: prepared.package!,
      );
      expect(
        resumed.boundPrescriptionSnapshot,
        started.boundPrescriptionSnapshot,
      );
      var plan = bindProgrammePrescription(
        plan: prepared.package!.plan,
        prescription: ProgrammePrescription(resumed.boundPrescriptionSnapshot!),
        protocolId: c.effectiveProtocolId,
        slotKey: c.packageSlotKey!,
      );
      if (windows.isNotEmpty) {
        expect(resumed.durationChoiceSnapshot, started.durationChoiceSnapshot);
        plan = applyFrozenDurationChoices(
          plan,
          resumed.durationChoiceSnapshot!,
        );
        for (final e in windows.entries) {
          final timer = plan.blocks
              .singleWhere((b) => b.blockId == e.key)
              .timerConfiguration!;
          expect(timer.durationSeconds, e.value.last);
          expect(timer.durationSecondsRange!.toJson(), e.value);
        }
      }
      expect(plan.blocks[0].boundTarget!.targetLabel, '5:00.0–5:15.0 /km');
      expect(plan.blocks[2].linkedExercises.single.prescription!.load!.kg, 80);
      final capture = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: plan,
        athleteId: actor,
        trainingSessionId: started.trainingSession.id,
        programmeContext: c,
      );
      final coordinator = PerformanceRecordSaveCoordinator();
      final initialRecord = await coordinator.createOrResumeInProgress(
        controller: capture,
      );
      await expectLater(
        client
            .from('training_session_records')
            .update({
              'session_snapshot': {'boundPrescriptionV1': {}},
            })
            .eq('record_id', initialRecord.recordId),
        throwsA(isA<PostgrestException>()),
      );
      final initialBlock = await client
          .from('training_block_results')
          .select('block_result_id,result_data')
          .eq('session_record_id', initialRecord.recordId)
          .eq('source_block_id', plan.blocks[1].blockId)
          .single();
      final invalidUnit = Map<String, dynamic>.from(
        initialBlock['result_data'] as Map,
      )..['paceUnit'] = 'sec_per_km';
      await expectLater(
        client
            .from('training_block_results')
            .update({'result_data': invalidUnit})
            .eq('block_result_id', initialBlock['block_result_id'] as String),
        throwsA(isA<PostgrestException>()),
      );
      for (final b in capture.draft.blockDrafts) {
        final result = b.resultData;
        if (result is IntervalResultData) {
          expect(result.intervals.length, b.position == 1 ? 4 : 6);
          expect(
            result.paceUnit,
            b.position == 1
                ? IntervalPaceUnit.secondsPerKm
                : IntervalPaceUnit.secondsPer500m,
          );
          capture.updateBlockResultData(
            b.sourceBlockId,
            result.copyWith(
              intervals: [
                for (final row in result.intervals)
                  row.copyWith(
                    state: IntervalWorkState.completed,
                    paceSecondsPerKm: b.position == 1 ? 305 : 132,
                  ),
              ],
            ),
          );
        } else {
          for (final e in b.exerciseResults) {
            for (final s in e.sets) {
              capture.updateSet(
                b.sourceBlockId,
                e.sourceExerciseId,
                s.setResultId,
                (current) => current.copyWith(
                  reps: 8,
                  load: 77.5,
                  loadUnit: 'kg',
                  completed: true,
                ),
              );
            }
          }
        }
        capture.markBlockComplete(b.sourceBlockId);
      }
      final saved = await coordinator.saveDraft(controller: capture);
      expect(
        saved.sessionSnapshot.boundPrescription!.json,
        started.boundPrescriptionSnapshot,
      );
      expect(
        saved.sessionSnapshot.durationChoiceSnapshot,
        started.durationChoiceSnapshot,
      );
      final restored = await coordinator.loadInProgressDraftAsRecord(
        athleteId: actor,
        trainingSessionId: started.trainingSession.id,
      );
      expect(
        restored!.sessionSnapshot.boundPrescription!.json,
        started.boundPrescriptionSnapshot,
      );
      expect(
        restored.sessionSnapshot.durationChoiceSnapshot,
        started.durationChoiceSnapshot,
      );
      final finished = await coordinator.completeSession(
        controller: capture,
        trainingSessionId: started.trainingSession.id,
        athleteId: actor,
        programmeContext: c,
      );
      expect(finished.programmeCompletion!.isSuccess, true);
      final history = await SupabasePerformanceRecordStore().getById(
        finished.record.recordId,
      );
      expect(
        history!.sessionSnapshot.boundPrescription!.json,
        started.boundPrescriptionSnapshot,
      );
      expect(
        history.blockResults[2].exerciseResults.single.setResults.first.load,
        77.5,
      );
      expect(
        history.sessionSnapshot.durationChoiceSnapshot,
        started.durationChoiceSnapshot,
      );
      final correction = PerformanceCorrectionDraft(history);
      final rowBlock = correction.blockResults[1];
      final rowActuals = rowBlock.resultData! as IntervalResultData;
      correction.blockResults[1] = rowBlock.copyWith(
        resultData: rowActuals.replaceInterval(
          rowActuals.intervals.first.copyWith(paceSecondsPerKm: 131),
        ),
      );
      final correctedRowBlock = correction.blockResults[1];
      final editedRows =
          (correctedRowBlock.resultData as IntervalResultData).intervals;
      correction.blockResults[1] = correctedRowBlock.copyWith(
        exerciseResults: [
          for (final e in correctedRowBlock.exerciseResults)
            e.copyWith(
              setResults: [
                for (final set in e.setResults)
                  IntervalSetSync.applyToRecordedSet(
                    set,
                    editedRows.firstWhere(
                      (row) => row.ordinal == set.setNumber,
                    ),
                  ),
              ],
            ),
        ],
      );
      final corrected = await SupabasePerformanceRecordStore().correctCompleted(
        correction,
      );
      expect(
        corrected.sessionSnapshot.durationChoiceSnapshot,
        started.durationChoiceSnapshot,
      );
      expect(
        (corrected.blockResults[1].resultData as IntervalResultData)
            .intervals
            .first
            .paceSecondsPerKm,
        131,
      );
      expect(
        corrected
            .blockResults[1]
            .exerciseResults
            .single
            .setResults
            .first
            .distance,
        closeTo(120 / 131 * 0.5, 0.000001),
      );
      expect(
        IntervalSetSync.rowFromSet(
          corrected.blockResults[1].exerciseResults.single.setResults.first,
          workSeconds: 120,
          paceUnit: IntervalPaceUnit.secondsPer500m,
        ).paceSecondsPerKm,
        closeTo(131, 0.000001),
      );
      expect(
        corrected.sessionSnapshot.boundPrescription!.json,
        started.boundPrescriptionSnapshot,
      );
      // Ordinary record updates cannot override server targets, even with the correct owner.
      final denied = await client
          .from('training_session_records')
          .update({
            'session_snapshot': {'boundPrescriptionV1': {}},
          })
          .eq('record_id', history.recordId)
          .select();
      expect(denied, isEmpty);
      expect(
        (await SupabasePerformanceRecordStore().getById(
          history.recordId,
        ))!.sessionSnapshot.boundPrescription!.json,
        started.boundPrescriptionSnapshot,
      );
      // A different authenticated athlete sees no private records and cannot read/consent the first athlete's assignment.
      actor =
          config['TEST_SECOND_ACTOR'] as String? ??
          'bc230000-0000-4000-8000-000000000007';
      expect(
        await SupabasePerformanceRecordStore().getById(history.recordId),
        isNull,
      );
      await expectLater(
        prescriptions.readState(
          assignmentId: c.assignmentId,
          programmeVersionId: c.programmeVersionId,
        ),
        throwsA(isA<PostgrestException>()),
      );
      final second = await prepare();
      final other = await prescriptions.review(
        assignmentId: second.executionContext!.assignmentId,
        programmeVersionId: second.executionContext!.programmeVersionId,
        selectedRevisions: chosen,
        incrementGrams: 2500,
      );
      expect(other['status'], 'refused');
      final own = <String, String?>{};
      for (final m in [
        BaseMetric.run10km,
        BaseMetric.row2km,
        BaseMetric.backSquat5rm,
      ]) {
        final rec = await benchmarks.record(
          commandId: DatabaseUuid.newV4(),
          metric: m,
          value: m == BaseMetric.run10km
              ? '3600'
              : m == BaseMetric.row2km
              ? '600'
              : '120',
          unit: m == BaseMetric.backSquat5rm
              ? BaseInputUnit.kilograms
              : BaseInputUnit.seconds,
          testDate: '2026-10-23',
          sourceType: BaseSourceType.knownResult,
          sourceReference: 'Second athlete ${m.name}',
        );
        own[m.name] = rec['revision_id'] as String;
      }
      final ownReview = await prescriptions.review(
        assignmentId: second.executionContext!.assignmentId,
        programmeVersionId: second.executionContext!.programmeVersionId,
        selectedRevisions: own,
        incrementGrams: 2500,
      );
      final secondTargets = ProgrammePrescription(
        Map<String, dynamic>.from(ownReview['document'] as Map),
      ).targets;
      expect(
        secondTargets
            .firstWhere((t) => t.kind == 'runningIntervals')
            .targetLabel,
        '6:00.0–6:18.0 /km',
      );
      expect(
        secondTargets
            .firstWhere((t) => t.kind == 'dedicatedRowIntervals')
            .targetLabel,
        '2:40.0–2:45.0 /500 m',
      );
      expect(
        secondTargets.firstWhere((t) => t.kind == 'backSquat').targetLabel,
        '95.0 kg total external load',
      );
      await expectLater(
        launcher.createOrResumeLaunchResult(
          athleteId: actor,
          programmeContext: second.executionContext!,
          package: second.package!,
        ),
        throwsA(isA<ProgrammeSessionExecutionException>()),
      );
      // Correction between review and acceptance invalidates its chosen revision.
      final old =
          (await prescriptions.readState(
                assignmentId: second.executionContext!.assignmentId,
                programmeVersionId: second.executionContext!.programmeVersionId,
              ))['benchmarks']
              as List;
      final selectedRun = old.cast<Map>().singleWhere(
        (b) => b['revision_id'] == own['run10km'],
      );
      await benchmarks.record(
        commandId: DatabaseUuid.newV4(),
        metric: BaseMetric.run10km,
        value: '3500',
        unit: BaseInputUnit.seconds,
        testDate: '2026-10-23',
        sourceType: BaseSourceType.knownResult,
        sourceReference: selectedRun['source_reference'] as String,
        previousRevisionId: own['run10km'],
        correctionReason: 'Local correction race',
      );
      final stale = await prescriptions.consent(
        commandId: DatabaseUuid.newV4(),
        assignmentId: second.executionContext!.assignmentId,
        programmeVersionId: second.executionContext!.programmeVersionId,
        reviewId: ownReview['review_id'] as String,
        expectedConsentId: null,
        withdraw: false,
      );
      expect(stale['status'], 'refused');
    },
    skip: configFile == null
        ? 'Requires task-owned disposable authenticated local gate.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
