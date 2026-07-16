import '../../../models/programme_week_draft.dart';
import '../../programme/services/programme_schedule_resolver.dart';
import '../models/programme_builder_document.dart';
import '../models/programme_builder_path.dart';
import '../models/programme_publish_readiness.dart';
import '../models/programme_validation_result.dart';
import 'programme_builder_compiler.dart';
import 'programme_builder_validation_service.dart';

/// Default validation implementation for v0.1 scaffold.
class ProgrammeBuilderValidationServiceImpl
    implements ProgrammeBuilderValidationService {
  ProgrammeBuilderValidationServiceImpl({
    ProgrammeBuilderCompiler compiler = const ProgrammeBuilderCompiler(),
    ProgrammeScheduleResolver? scheduleResolver,
  })  : _compiler = compiler,
        _scheduleResolver = scheduleResolver;

  final ProgrammeBuilderCompiler _compiler;
  final ProgrammeScheduleResolver? _scheduleResolver;

  @override
  ProgrammeValidationResult validate(ProgrammeBuilderDocument document) {
    return _validate(document, forPublish: false, knownProtocolIds: null);
  }

  @override
  ProgrammeValidationResult validateForPublish(
    ProgrammeBuilderDocument document, {
    Set<String>? knownProtocolIds,
  }) {
    return _validate(
      document,
      forPublish: true,
      knownProtocolIds: knownProtocolIds,
    );
  }

  @override
  ProgrammePublishReadiness buildPublishReadiness(
    ProgrammeBuilderDocument document, {
    ProgrammeValidationResult? validation,
    Set<String>? knownProtocolIds,
  }) {
    final result = validation ??
        validateForPublish(document, knownProtocolIds: knownProtocolIds);

    final checks = <ProgrammePublishReadinessCheck>[
      _check(
        id: 'name_present',
        label: 'Programme name',
        passed: document.metadata.name.trim().isNotEmpty,
        message: 'Add a programme name',
        code: ProgrammeValidationCode.metaNameRequired,
        issues: result.issues,
      ),
      _check(
        id: 'lineage_code_valid',
        label: 'Lineage code',
        passed: _compiler.isValidLineageCode(document.metadata.lineageCode),
        message: 'Lineage code must match COHORT-12 style format',
        code: ProgrammeValidationCode.metaLineageCodeInvalid,
        issues: result.issues,
      ),
      _check(
        id: 'has_week',
        label: 'At least one week',
        passed: document.template.allWeeks.isNotEmpty,
        message: 'Add at least one week',
        code: ProgrammeValidationCode.treeNoWeeks,
        issues: result.issues,
      ),
      _check(
        id: 'has_training_session',
        label: 'At least one training session',
        passed: _hasTrainingSlot(document),
        message: 'Add at least one training session slot',
        code: ProgrammeValidationCode.treeEmptyProgramme,
        issues: result.issues,
      ),
      _check(
        id: 'rest_days_valid',
        label: 'Rest days have no slots',
        passed: !_hasInvalidRestDays(document),
        message: 'Rest days must not contain session slots',
        code: ProgrammeValidationCode.treeRestDayHasSlots,
        issues: result.issues,
      ),
      _check(
        id: 'protocols_valid',
        label: 'Protocols are valid',
        passed: !result.issues.any(
          (issue) =>
              issue.code == ProgrammeValidationCode.slotProtocolRequired ||
              issue.code == ProgrammeValidationCode.slotProtocolUnknown,
        ),
        message: 'All training slots need valid protocol references',
        code: ProgrammeValidationCode.slotProtocolRequired,
        issues: result.issues,
      ),
      _check(
        id: 'ordering_valid',
        label: 'Week/day/slot ordering',
        passed: !result.issues.any(
          (issue) =>
              issue.code == ProgrammeValidationCode.treeWeekNumberGap ||
              issue.code == ProgrammeValidationCode.treeDuplicateWeekNumber ||
              issue.code == ProgrammeValidationCode.treeDuplicateDayKey ||
              issue.code == ProgrammeValidationCode.treeDuplicateDayOrder ||
              issue.code == ProgrammeValidationCode.treeDuplicateSlotOrder ||
              issue.code == ProgrammeValidationCode.treeDayKeyInvalid,
        ),
        message: 'Fix duplicate or invalid ordering',
        code: ProgrammeValidationCode.treeDuplicateWeekNumber,
        issues: result.issues,
      ),
      _check(
        id: 'resolver_accepts',
        label: 'Resolver accepts initial cursor',
        passed: !result.issues.any(
          (issue) => issue.code == ProgrammeValidationCode.engineResolverRejects,
        ),
        message: 'Programme structure must resolve an initial cursor',
        code: ProgrammeValidationCode.engineResolverRejects,
        issues: result.issues,
      ),
      _check(
        id: 'no_blocking_errors',
        label: 'No blocking validation errors',
        passed: result.blockingIssueCount == 0,
        message: 'Resolve all blocking validation errors',
        code: ProgrammeValidationCode.treeEmptyProgramme,
        issues: result.issues,
      ),
    ];

    if (result.isPublishable && checks.every((check) => check.passed)) {
      return ProgrammePublishReadiness.ready(
        checks: checks,
        warningCount: result.warningCount,
      );
    }

    return ProgrammePublishReadiness.notReady(
      checks: checks,
      blockingIssueCount: result.blockingIssueCount,
      warningCount: result.warningCount,
    );
  }

  ProgrammeValidationResult _validate(
    ProgrammeBuilderDocument document, {
    required bool forPublish,
    Set<String>? knownProtocolIds,
  }) {
    final issues = <ProgrammeValidationIssue>[];
    final metadata = document.metadata;

    if (metadata.name.trim().isEmpty) {
      issues.add(
        const ProgrammeValidationIssue(
          code: ProgrammeValidationCode.metaNameRequired,
          severity: ProgrammeValidationSeverity.error,
          message: 'Programme name is required',
          path: ProgrammeBuilderProgrammePath(),
        ),
      );
    }

    if (!_compiler.isValidLineageCode(metadata.lineageCode)) {
      issues.add(
        const ProgrammeValidationIssue(
          code: ProgrammeValidationCode.metaLineageCodeInvalid,
          severity: ProgrammeValidationSeverity.error,
          message: 'Lineage code format is invalid',
          path: ProgrammeBuilderProgrammePath(),
        ),
      );
    }

    final weeks = document.template.allWeeks;
    if (weeks.isEmpty) {
      issues.add(
        const ProgrammeValidationIssue(
          code: ProgrammeValidationCode.treeNoWeeks,
          severity: ProgrammeValidationSeverity.error,
          message: 'Programme must contain at least one week',
          path: ProgrammeBuilderProgrammePath(),
        ),
      );
    }

    _validateWeekStructure(weeks, issues);
    _validateDayAndSlotStructure(weeks, issues, knownProtocolIds);

    if (!_hasTrainingSlot(document)) {
      issues.add(
        const ProgrammeValidationIssue(
          code: ProgrammeValidationCode.treeEmptyProgramme,
          severity: ProgrammeValidationSeverity.error,
          message: 'Programme must contain at least one training session',
          path: ProgrammeBuilderProgrammePath(),
        ),
      );
    }

    if (forPublish &&
        metadata.durationWeeks != null &&
        metadata.durationWeeks != weeks.length) {
      issues.add(
        ProgrammeValidationIssue(
          code: ProgrammeValidationCode.metaDurationMismatch,
          severity: ProgrammeValidationSeverity.warning,
          message:
              'Duration weeks (${metadata.durationWeeks}) differs from authored week count (${weeks.length})',
          path: const ProgrammeBuilderProgrammePath(),
        ),
      );
    }

    if (forPublish &&
        _scheduleResolver != null &&
        !issues.any((issue) => issue.isBlocking)) {
      _validateResolver(document, issues);
    }

    return ProgrammeValidationResult.fromIssues(issues);
  }

  void _validateWeekStructure(
    List<ProgrammeWeekDraft> weeks,
    List<ProgrammeValidationIssue> issues,
  ) {
    final seenWeekNumbers = <int>{};
    final weekNumbers = <int>[];

    for (final week in weeks) {
      if (!seenWeekNumbers.add(week.weekNumber)) {
        issues.add(
          ProgrammeValidationIssue(
            code: ProgrammeValidationCode.treeDuplicateWeekNumber,
            severity: ProgrammeValidationSeverity.error,
            message: 'Duplicate week number ${week.weekNumber}',
            path: ProgrammeBuilderWeekPath(weekLocalId: week.localId),
          ),
        );
      }
      weekNumbers.add(week.weekNumber);
    }

    if (weekNumbers.isEmpty) return;

    weekNumbers.sort();
    for (var index = 0; index < weekNumbers.length; index++) {
      final expected = index + 1;
      if (weekNumbers[index] != expected) {
        issues.add(
          const ProgrammeValidationIssue(
            code: ProgrammeValidationCode.treeWeekNumberGap,
            severity: ProgrammeValidationSeverity.error,
            message: 'Week numbers must be contiguous from 1',
            path: ProgrammeBuilderProgrammePath(),
          ),
        );
        break;
      }
    }
  }

  void _validateDayAndSlotStructure(
    List<ProgrammeWeekDraft> weeks,
    List<ProgrammeValidationIssue> issues,
    Set<String>? knownProtocolIds,
  ) {
    for (final week in weeks) {
      final seenDayKeys = <String>{};
      final seenDayOrders = <int>{};

      for (final day in week.days) {
        if (!_compiler.isValidDayKey(day.dayKey)) {
          issues.add(
            ProgrammeValidationIssue(
              code: ProgrammeValidationCode.treeDayKeyInvalid,
              severity: ProgrammeValidationSeverity.error,
              message: 'Invalid day key ${day.dayKey}',
              path: ProgrammeBuilderDayPath(
                weekLocalId: week.localId,
                dayLocalId: day.localId,
              ),
            ),
          );
        }

        if (!seenDayKeys.add(day.dayKey)) {
          issues.add(
            ProgrammeValidationIssue(
              code: ProgrammeValidationCode.treeDuplicateDayKey,
              severity: ProgrammeValidationSeverity.error,
              message: 'Duplicate day key ${day.dayKey}',
              path: ProgrammeBuilderDayPath(
                weekLocalId: week.localId,
                dayLocalId: day.localId,
              ),
            ),
          );
        }

        if (!seenDayOrders.add(day.dayOrder)) {
          issues.add(
            ProgrammeValidationIssue(
              code: ProgrammeValidationCode.treeDuplicateDayOrder,
              severity: ProgrammeValidationSeverity.error,
              message: 'Duplicate day order ${day.dayOrder}',
              path: ProgrammeBuilderDayPath(
                weekLocalId: week.localId,
                dayLocalId: day.localId,
              ),
            ),
          );
        }

        final isRest = day.isRestDay;
        if (isRest && day.slots.isNotEmpty) {
          issues.add(
            ProgrammeValidationIssue(
              code: ProgrammeValidationCode.treeRestDayHasSlots,
              severity: ProgrammeValidationSeverity.error,
              message: 'Rest day ${day.dayKey} must not contain slots',
              path: ProgrammeBuilderDayPath(
                weekLocalId: week.localId,
                dayLocalId: day.localId,
              ),
            ),
          );
        }

        if (!isRest && day.slots.isEmpty) {
          issues.add(
            ProgrammeValidationIssue(
              code: ProgrammeValidationCode.treeTrainingDayNoSlots,
              severity: ProgrammeValidationSeverity.error,
              message: 'Training day ${day.dayKey} requires at least one slot',
              path: ProgrammeBuilderDayPath(
                weekLocalId: week.localId,
                dayLocalId: day.localId,
              ),
            ),
          );
        }

        final seenSlotOrders = <int>{};
        for (final slot in day.slots) {
          if (!seenSlotOrders.add(slot.sessionOrder)) {
            issues.add(
              ProgrammeValidationIssue(
                code: ProgrammeValidationCode.treeDuplicateSlotOrder,
                severity: ProgrammeValidationSeverity.error,
                message: 'Duplicate slot order ${slot.sessionOrder}',
                path: ProgrammeBuilderSlotPath(
                  weekLocalId: week.localId,
                  dayLocalId: day.localId,
                  slotLocalId: slot.localId,
                ),
              ),
            );
          }

          if (slot.protocolId.trim().isEmpty) {
            issues.add(
              ProgrammeValidationIssue(
                code: ProgrammeValidationCode.slotProtocolRequired,
                severity: ProgrammeValidationSeverity.error,
                message: 'Session slot requires a protocol',
                path: ProgrammeBuilderSlotPath(
                  weekLocalId: week.localId,
                  dayLocalId: day.localId,
                  slotLocalId: slot.localId,
                ),
              ),
            );
          } else if (knownProtocolIds != null &&
              !knownProtocolIds.contains(slot.protocolId)) {
            issues.add(
              ProgrammeValidationIssue(
                code: ProgrammeValidationCode.slotProtocolUnknown,
                severity: ProgrammeValidationSeverity.error,
                message: 'Unknown protocol ${slot.protocolId}',
                path: ProgrammeBuilderSlotPath(
                  weekLocalId: week.localId,
                  dayLocalId: day.localId,
                  slotLocalId: slot.localId,
                ),
              ),
            );
          }
        }
      }
    }
  }

  void _validateResolver(
    ProgrammeBuilderDocument document,
    List<ProgrammeValidationIssue> issues,
  ) {
    try {
      final tree = _compiler.toTemplateTree(document);
      _scheduleResolver!.resolveInitialCursor(tree: tree);
    } catch (_) {
      issues.add(
        const ProgrammeValidationIssue(
          code: ProgrammeValidationCode.engineResolverRejects,
          severity: ProgrammeValidationSeverity.error,
          message: 'Programme structure is not resolvable',
          path: ProgrammeBuilderProgrammePath(),
        ),
      );
    }
  }

  bool _hasTrainingSlot(ProgrammeBuilderDocument document) {
    for (final week in document.template.allWeeks) {
      for (final day in week.days) {
        if (!day.isRestDay && day.slots.isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasInvalidRestDays(ProgrammeBuilderDocument document) {
    for (final week in document.template.allWeeks) {
      for (final day in week.days) {
        if (day.isRestDay && day.slots.isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  ProgrammePublishReadinessCheck _check({
    required String id,
    required String label,
    required bool passed,
    required String message,
    required ProgrammeValidationCode code,
    required List<ProgrammeValidationIssue> issues,
  }) {
    ProgrammeValidationIssue? firstMatch;
    for (final issue in issues) {
      if (issue.code == code) {
        firstMatch = issue;
        break;
      }
    }

    return ProgrammePublishReadinessCheck(
      id: id,
      label: label,
      passed: passed,
      message: passed ? null : (firstMatch?.message ?? message),
      path: firstMatch?.path,
    );
  }
}
