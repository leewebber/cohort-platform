import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../features/auth/repositories/profile_repository.dart';
import '../../../features/auth/repositories/supabase_profile_repository.dart';
import '../../../features/auth/services/current_user_session.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_vocabulary.dart';
import '../../programme/models/programme_catalog_entry.dart';
import '../../programme/services/programme_assignment_service.dart';
import '../../programme/services/programme_catalog_service.dart';
import '../models/coach_athlete_invite.dart';
import '../models/coach_athlete_operation_result.dart';
import '../models/coach_athlete_roster_entry.dart';
import '../repositories/coach_athlete_repository.dart';
import '../repositories/supabase_coach_athlete_repository.dart';
import 'coach_athlete_invite_code_generator.dart';

class CoachAthleteService {
  CoachAthleteService({
    CoachAthleteRelationshipRepository? relationshipRepository,
    CoachAthleteInviteRepository? inviteRepository,
    ProfileRepository? profileRepository,
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeVersionStore? versionStore,
    ProgrammeCatalogService? catalogService,
    ProgrammeAssignmentService? assignmentService,
    CoachAthleteInviteCodeGenerator? codeGenerator,
    Duration inviteTtl = const Duration(days: 7),
  })  : _relationshipRepository =
            relationshipRepository ?? const SupabaseCoachAthleteRelationshipRepository(),
        _inviteRepository =
            inviteRepository ?? const SupabaseCoachAthleteInviteRepository(),
        _profileRepository = profileRepository ?? const SupabaseProfileRepository(),
        _assignmentStore = assignmentStore,
        _versionStore = versionStore,
        _catalogService = catalogService,
        _assignmentService = assignmentService,
        _codeGenerator = codeGenerator ?? const CoachAthleteInviteCodeGenerator(),
        _inviteTtl = inviteTtl;

  final CoachAthleteRelationshipRepository _relationshipRepository;
  final CoachAthleteInviteRepository _inviteRepository;
  final ProfileRepository _profileRepository;
  final ProgrammeAssignmentStore? _assignmentStore;
  final ProgrammeVersionStore? _versionStore;
  final ProgrammeCatalogService? _catalogService;
  final ProgrammeAssignmentService? _assignmentService;
  final CoachAthleteInviteCodeGenerator _codeGenerator;
  final Duration _inviteTtl;

  String? get _coachId => CurrentUserSession.maybeInstance?.coachId;
  String? get _athleteId => CurrentUserSession.maybeInstance?.isAthlete == true
      ? CurrentUserSession.maybeInstance?.athleteId
      : null;

  Future<InviteResult> createInvite() async {
    final coachId = _coachId;
    if (coachId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.coachRoleRequired,
        message: 'A coach profile is required to invite athletes.',
      );
    }

    try {
      final code = _codeGenerator.generate();
      final expiresAt = DateTime.now().toUtc().add(_inviteTtl);
      final invite = CoachAthleteInvite(
        id: '',
        coachId: coachId,
        code: code,
        status: CoachAthleteInviteStatus.pending,
        expiresAt: expiresAt,
        createdAt: DateTime.now().toUtc(),
      );

      final created = await _inviteRepository.createInvite(invite);
      return CoachAthleteOperationResult.success(created);
    } on ProgrammeStoreException catch (error) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: error.message,
      );
    }
  }

  Future<RosterResult> listLinkedAthletes() async {
    final coachId = _coachId;
    if (coachId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.coachRoleRequired,
        message: 'A coach profile is required to view your roster.',
      );
    }

    try {
      final relationships =
          await _relationshipRepository.listActiveForCoach(coachId);
      final entries = <CoachAthleteRosterEntry>[];

      for (final relationship in relationships) {
        final profile =
            await _profileRepository.getProfile(relationship.athleteId);
        final assignmentSummary = await _loadAssignmentSummary(
          relationship.athleteId,
        );

        entries.add(
          CoachAthleteRosterEntry(
            athleteId: relationship.athleteId,
            displayName: profile?.displayName ?? 'Athlete',
            relationshipId: relationship.id,
            activeProgrammeName: assignmentSummary?.programmeName,
            activeProgrammeVersionLabel: assignmentSummary?.versionLabel,
            hasActiveAssignment: assignmentSummary != null,
          ),
        );
      }

      return CoachAthleteOperationResult.success(entries);
    } on ProgrammeStoreException catch (error) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: error.message,
      );
    }
  }

  Future<CoachAthleteOperationResult<List<CoachAthleteInvite>>>
      listPendingInvites() async {
    final coachId = _coachId;
    if (coachId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.coachRoleRequired,
        message: 'A coach profile is required to manage invitations.',
      );
    }

    try {
      final invites = await _inviteRepository.listPendingForCoach(coachId);
      return CoachAthleteOperationResult.success(invites);
    } on ProgrammeStoreException catch (error) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: error.message,
      );
    }
  }

  Future<CoachAthleteOperationResult<void>> revokeInvite(String inviteId) async {
    final coachId = _coachId;
    if (coachId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.coachRoleRequired,
        message: 'A coach profile is required to revoke invitations.',
      );
    }

    try {
      await _inviteRepository.revokeInvite(inviteId);
      return CoachAthleteOperationResult.success(null);
    } on ProgrammeStoreException catch (error) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: error.message,
      );
    }
  }

  Future<AcceptInviteResult> acceptInvite(String code) async {
    final athleteId = _athleteId;
    if (athleteId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.athleteRoleRequired,
        message: 'An athlete profile is required to join a coach.',
      );
    }

    try {
      final result = await _inviteRepository.acceptInvite(code);
      return CoachAthleteOperationResult.success(
        CoachAthleteAcceptInviteResult(
          coachDisplayName: result.coachDisplayName,
          coachId: result.coachId,
        ),
      );
    } on ProgrammeStoreException catch (error) {
      return CoachAthleteOperationResult.failure(
        status: _mapInviteError(error.message),
        message: _friendlyInviteMessage(error.message),
      );
    } catch (error) {
      final message = error.toString();
      return CoachAthleteOperationResult.failure(
        status: _mapInviteError(message),
        message: _friendlyInviteMessage(message),
      );
    }
  }

  Future<RelationshipResult> getActiveCoachForAthlete() async {
    final athleteId = _athleteId;
    if (athleteId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.athleteRoleRequired,
      );
    }

    try {
      final relationship =
          await _relationshipRepository.getActiveForAthlete(athleteId);
      return CoachAthleteOperationResult.success(relationship);
    } on ProgrammeStoreException catch (error) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: error.message,
      );
    }
  }

  Future<CoachAthleteOperationResult<ProgrammeAssignment?>> getAthleteAssignment(
    String athleteId,
  ) async {
    final coachId = _coachId;
    if (coachId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.coachRoleRequired,
      );
    }

    final linked = await _relationshipRepository.hasActiveRelationship(
      coachId: coachId,
      athleteId: athleteId,
    );
    if (!linked) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.notLinked,
        message: 'This athlete is not linked to your roster.',
      );
    }

    final store = _assignmentStore;
    if (store == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: 'Assignment lookup is unavailable.',
      );
    }

    try {
      final assignment = await store.getActiveAssignment(athleteId);
      return CoachAthleteOperationResult.success(assignment);
    } on ProgrammeStoreException catch (error) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: error.message,
      );
    }
  }

  Future<CoachAthleteOperationResult<List<ProgrammeCatalogEntry>>>
      listPublishedProgrammes() async {
    final coachId = _coachId;
    if (coachId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.coachRoleRequired,
      );
    }

    final catalog = _catalogService;
    if (catalog == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: 'Programme catalogue is unavailable.',
      );
    }

    try {
      final entries = await catalog.listCatalogue(
        query: const ProgrammeCatalogueQuery(
          lifecycleStatus: ProgrammeLifecycleStatus.published,
        ),
      );
      return CoachAthleteOperationResult.success(entries);
    } catch (error) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: error.toString(),
      );
    }
  }

  Future<CoachAthleteOperationResult<ProgrammeAssignmentOperationSummary>>
      assignProgrammeToAthlete({
    required String athleteId,
    required String programmeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
  }) async {
    final coachId = _coachId;
    if (coachId == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.coachRoleRequired,
      );
    }

    final linked = await _relationshipRepository.hasActiveRelationship(
      coachId: coachId,
      athleteId: athleteId,
    );
    if (!linked) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.notLinked,
        message: 'You can only assign programmes to athletes on your roster.',
      );
    }

    final assignmentService = _assignmentService;
    if (assignmentService == null) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: 'Assignment service is unavailable.',
      );
    }

    final result = await assignmentService.assignProgramme(
      athleteId: athleteId,
      programmeVersionId: programmeVersionId,
      startedAt: startedAt,
      timezone: timezone,
      replaceExistingActive: replaceExistingActive,
    );

    if (!result.isSuccess) {
      return CoachAthleteOperationResult.failure(
        status: CoachAthleteOperationStatus.failed,
        message: result.warnings.isNotEmpty
            ? result.warnings.first
            : 'Programme assignment failed.',
      );
    }

    return CoachAthleteOperationResult.success(
      ProgrammeAssignmentOperationSummary(
        assignment: result.assignment!,
        programmeName: result.assignment!.lineageCode,
      ),
    );
  }

  Future<_AssignmentSummary?> _loadAssignmentSummary(String athleteId) async {
    final store = _assignmentStore;
    final versionStore = _versionStore;
    if (store == null || versionStore == null) return null;

    final assignment = await store.getActiveAssignment(athleteId);
    if (assignment == null) return null;

    final version = await versionStore.getVersionById(
      assignment.programmeVersionId,
    );

    return _AssignmentSummary(
      programmeName: version?.name ?? assignment.lineageCode,
      versionLabel: version == null
          ? null
          : 'Version ${version.versionNumber}',
    );
  }

  CoachAthleteOperationStatus _mapInviteError(String message) {
    final normalized = _normalizeError(message);
    if (normalized.contains('expired')) {
      return CoachAthleteOperationStatus.expiredInvite;
    }
    if (normalized.contains('revoked')) {
      return CoachAthleteOperationStatus.revokedInvite;
    }
    if (normalized.contains('already been used') ||
        normalized.contains('already used')) {
      return CoachAthleteOperationStatus.usedInvite;
    }
    if (normalized.contains('cannot accept your own') ||
        normalized.contains('your own invitation')) {
      return CoachAthleteOperationStatus.selfInvite;
    }
    if (normalized.contains('already linked to a coach') ||
        normalized.contains('already linked to this coach')) {
      return CoachAthleteOperationStatus.alreadyLinked;
    }
    if (normalized.contains('not valid') || normalized.contains('valid invitation')) {
      return CoachAthleteOperationStatus.invalidInvite;
    }
    return CoachAthleteOperationStatus.failed;
  }

  String _friendlyInviteMessage(String message) {
    final normalized = _normalizeError(message);
    if (normalized.contains('expired')) {
      return 'This invitation has expired. Ask your coach for a new code.';
    }
    if (normalized.contains('revoked')) {
      return 'This invitation is no longer active.';
    }
    if (normalized.contains('already been used') ||
        normalized.contains('already used')) {
      return 'This invitation has already been used.';
    }
    if (normalized.contains('cannot accept your own')) {
      return 'You cannot use your own invitation code.';
    }
    if (normalized.contains('already linked to a coach')) {
      return 'You are already linked to a coach.';
    }
    if (normalized.contains('already linked to this coach')) {
      return 'You are already linked to this coach.';
    }
    if (normalized.contains('athlete profile is required')) {
      return 'An athlete profile is required to join a coach.';
    }
    if (normalized.contains('not valid')) {
      return 'That invitation code is not valid.';
    }
    return message;
  }

  String _normalizeError(String message) {
    return message.replaceFirst(RegExp(r'^Exception:\s*'), '').toLowerCase();
  }
}

class ProgrammeAssignmentOperationSummary {
  const ProgrammeAssignmentOperationSummary({
    required this.assignment,
    required this.programmeName,
  });

  final ProgrammeAssignment assignment;
  final String programmeName;
}

class _AssignmentSummary {
  const _AssignmentSummary({
    required this.programmeName,
    this.versionLabel,
  });

  final String programmeName;
  final String? versionLabel;
}
