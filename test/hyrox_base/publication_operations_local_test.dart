// Task-owned disposable synthetic programme only. No hosted URL or real actor.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cohort_platform/application/hyrox_base/benchmark_repository.dart';
import 'package:cohort_platform/application/hyrox_base/programme_prescription_repository.dart';
import 'package:cohort_platform/application/hyrox_base/duration_choice.dart';
import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_supabase_store.dart';
import 'package:cohort_platform/data/repositories/programme_version_supabase_store.dart';
import 'package:cohort_platform/domain/hyrox_base/base_personalisation.dart';
import 'package:cohort_platform/domain/hyrox_base/programme_prescription.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_supabase_store.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/interval_work_result.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/repositories/supabase_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/session/models/bound_programme_execution.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';

void main() {
  final path = Platform.environment['COHORT_LOCAL_V3_CONFIG'];
  test(
    '48 approved sources → consent/start/frozen prescription/save/completion/History',
    () async {
      final config = jsonDecode(File(path!).readAsStringSync()) as Map;
      final uri = Uri.parse(config['API_URL'] as String);
      expect(uri.scheme, 'http');
      expect({'127.0.0.1', 'localhost'}, contains(uri.host));
      var actor = 'bc310000-0000-4000-8000-000000000006';
      String token() {
        String enc(Object o) =>
            base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
        final m =
            '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': actor, 'role': 'authenticated', 'aud': 'authenticated', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800})}';
        return '$m.${base64Url.encode(Hmac(sha256, utf8.encode(config['JWT_SECRET'] as String)).convert(utf8.encode(m)).bytes).replaceAll('=', '')}';
      }

      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: uri.toString(),
        publishableKey: config['ANON_KEY'] as String,
        accessToken: () async => token(),
        debug: false,
      );
      addTearDown(() => Supabase.instance.dispose());
      final benchmarks = BaseBenchmarkRepository();
      final prescriptions = ProgrammePrescriptionRepository();
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
          testDate: '2026-10-25',
          sourceType: BaseSourceType.knownResult,
          sourceReference: 'LOCAL REHEARSAL ${m.name}',
        );
        expect(r['status'], 'recorded');
        chosen[m.name] = r['revision_id'] as String;
      }
      const assignments = ProgrammeAssignmentSupabaseStore();
      final initial = (await assignments.getActiveAssignment(actor))!;
      final state = await prescriptions.review(
        assignmentId: initial.id,
        programmeVersionId: 'bc310000-0000-4000-8000-000000000040',
        selectedRevisions: chosen,
        incrementGrams: 2500,
      );
      expect(state['status'], 'review');
      final consent = await prescriptions.consent(
        commandId: DatabaseUuid.newV4(),
        assignmentId: initial.id,
        programmeVersionId: 'bc310000-0000-4000-8000-000000000040',
        reviewId: state['review_id'] as String,
        expectedConsentId: null,
        withdraw: false,
      );
      expect(consent['status'], 'accepted');
      final service = AthleteProgrammeSessionPrepareService(
        assignmentStore: assignments,
        slotResolver: const AthleteProgrammeAuthoredSlotResolver(
          versionStore: ProgrammeVersionSupabaseStore(),
        ),
        sessionLoader: SessionExecutionLoader(),
      );
      final calendar =
          await const FixedProgrammeOccurrenceProjectionSupabaseStore()
              .resolveForAssignment(initial.id);
      final occurrences = [...calendar.occurrences]
        ..sort((a, b) {
          final w = a.weekNumber.compareTo(b.weekNumber);
          return w != 0 ? w : a.dayKey.compareTo(b.dayKey);
        });
      expect(occurrences.length, 48);
      final launcher = ProgrammeSessionExecutionLauncher();
      final coordinator = PerformanceRecordSaveCoordinator();
      final history = <String, Map<String, dynamic>>{};
      var windowsCount = 0, paired = 0;
      for (final occurrence in occurrences) {
        final assignment = (await assignments.getActiveAssignment(actor))!;
        final prepared = await service.prepareFixedOccurrence(
          assignment,
          occurrence,
        );
        expect(
          prepared.isReady,
          true,
          reason:
              '${occurrence.weekNumber}/${occurrence.dayKey} ${occurrence.state} date=${occurrence.scheduledDate} start=${calendar.startDate} today=${calendar.today}: ${prepared.code}: ${prepared.message}',
        );
        final c = prepared.executionContext!.copyWith(
          boundConsentId: consent['consent_id'] as String,
        );
        final windows = authoredDurationWindows(prepared.package!.plan);
        windowsCount += windows.length;
        final started = await launcher.createOrResumeLaunchResult(
          athleteId: actor,
          programmeContext: c,
          package: prepared.package!,
          durationChoices: windows.isEmpty
              ? null
              : {for (final e in windows.entries) e.key: e.value.last},
        );
        final retry = await launcher.createOrResumeLaunchResult(
          athleteId: actor,
          programmeContext: c,
          package: prepared.package!,
        );
        expect(retry.wasResumed, true);
        expect(retry.trainingSession.id, started.trainingSession.id);
        expect(
          retry.boundPrescriptionSnapshot,
          started.boundPrescriptionSnapshot,
        );
        expect(retry.durationChoiceSnapshot, started.durationChoiceSnapshot);
        var plan = bindProgrammePrescription(
          plan: prepared.package!.plan,
          prescription: ProgrammePrescription(
            started.boundPrescriptionSnapshot!,
          ),
          protocolId: c.effectiveProtocolId,
          slotKey: c.packageSlotKey!,
        );
        if (windows.isNotEmpty) {
          plan = applyFrozenDurationChoices(
            plan,
            started.durationChoiceSnapshot!,
          );
        }
        if (plan.blocks.any(
          (b) => b.linkedExercises.any((e) => e.hasExecutionGroup),
        )) {
          paired++;
        }
        final capture =
            PerformanceCaptureController.initializeFromExecutionPlan(
              plan: plan,
              athleteId: actor,
              trainingSessionId: started.trainingSession.id,
              programmeContext: c,
            );
        for (final b in capture.draft.blockDrafts) {
          final r = b.resultData;
          if (r is IntervalResultData) {
            capture.updateBlockResultData(
              b.sourceBlockId,
              r.copyWith(
                intervals: [
                  for (final i in r.intervals)
                    i.copyWith(
                      state: IntervalWorkState.completed,
                      paceSecondsPerKm:
                          r.paceUnit == IntervalPaceUnit.secondsPer500m
                          ? 132
                          : 305,
                    ),
                ],
              ),
            );
          } else if (r is EnduranceResultData) {
            expect(r.durationSeconds, isNull);
            capture.updateBlockResultData(
              b.sourceBlockId,
              r.copyWith(distance: 5, durationSeconds: 2400),
            );
          } else {
            for (final e in b.exerciseResults) {
              for (final s in e.sets) {
                expect(s.reps, isNull);
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
          restored!.sessionSnapshot.toJson(),
          saved.sessionSnapshot.toJson(),
        );
        final finished = await coordinator.completeSession(
          controller: capture,
          trainingSessionId: started.trainingSession.id,
          athleteId: actor,
          programmeContext: c,
        );
        expect(finished.programmeCompletion!.isSuccess, true);
        final record = await SupabasePerformanceRecordStore().getById(
          finished.record.recordId,
        );
        expect(
          record!.sessionSnapshot.boundPrescription!.json,
          started.boundPrescriptionSnapshot,
        );
        expect(
          record.sessionSnapshot.durationChoiceSnapshot,
          started.durationChoiceSnapshot,
        );
        history[record.recordId] = record.sessionSnapshot.toJson();
      }
      expect(windowsCount, 16);
      expect(paired, 24);
      for (final entry in history.entries) {
        expect(
          (await SupabasePerformanceRecordStore().getById(
            entry.key,
          ))!.sessionSnapshot.toJson(),
          entry.value,
        );
      }
      actor = 'bc310000-0000-4000-8000-000000000007';
      expect(
        await SupabasePerformanceRecordStore().getById(history.keys.first),
        isNull,
      );
    },
    skip: path == null
        ? 'Requires task-owned full publication rehearsal gate.'
        : false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
