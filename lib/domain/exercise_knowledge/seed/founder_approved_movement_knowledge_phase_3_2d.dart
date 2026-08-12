import '../models/coaching_content.dart';
import '../models/exercise_catalogue_snapshot.dart';
import '../models/exercise_definition.dart';
import '../models/knowledge_content_common.dart';
import '../models/knowledge_reference.dart';
import '../models/movement_standard.dart';
import '../ports/exercise_knowledge_repository.dart';
import '../services/exercise_knowledge_publication_service.dart';
import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';

/// Founder-approved Phase 3.2D text-only movement-knowledge pilot.
///
/// The pilot owns content, not canonical exercise identity. Callers must supply
/// the repository-authoritative definitions; missing or renamed identities fail
/// closed before publication. Publication still runs through
/// [ExerciseKnowledgePublicationService].
class FounderApprovedMovementKnowledgePhase32d {
  FounderApprovedMovementKnowledgePhase32d._();

  static const catalogueVersion = 'phase-3.2d-pilot-1';
  static const definitionVersionSuffix = '+phase3.2d';

  static final authorId = KnowledgeActorId.parse('cohort.founder_authoring');
  static final authoredAt = DateTime.utc(2026, 8, 12);

  static const canonicalNames = <String, String>{
    'EX-012': 'Push Up',
    'EX-021': 'Plank',
    'EX-025': 'Walking Lunge',
    'EX-049': 'Row Erg',
    'EX-050': 'Ski Erg',
    'EX-052': 'Wall Ball',
    'EX-057': 'Kettlebell Swing',
    'EX-130': 'Burpee Broad Jump',
  };

  static final movementStandards = List<MovementStandard>.unmodifiable([
    _standard(
      exerciseId: 'EX-012',
      id: 'standard.ex012.push_up.base_bodyweight',
      title: 'Push Up — Base Bodyweight Standard',
      applicabilityKey: 'base_bodyweight_push_up',
      startPosition:
          'Place both hands on the floor and extend the legs with the feet '
          'providing lower-body support. Begin with the elbows straight and '
          'the body held under control.',
      executionSequence: const [
        'Bend both elbows and lower the body towards the floor.',
        'Continue until the chest contacts the floor.',
        'Press through both hands and move the body away from the floor.',
        'Finish with both elbows fully extended.',
      ],
      completionCriteria: const [
        'The chest contacts the floor at the bottom of the movement.',
        'Both elbows are fully extended at completion.',
        'The hands and feet remain the supporting contacts throughout.',
      ],
      invalidCriteria: const [
        'The chest does not contact the floor.',
        'Either elbow remains bent at completion.',
        'A supporting hand or foot loses contact before completion.',
        'A knee, thigh or hip is used as an additional supporting contact.',
      ],
      safetyNotes: const [
        'Use a stable surface with clear space around the body.',
        'Stop the movement under control if a supporting contact is lost.',
      ],
    ),
    _standard(
      exerciseId: 'EX-021',
      id: 'standard.ex021.plank.forearm',
      title: 'Forearm Plank — Base Bodyweight Standard',
      applicabilityKey: 'forearm_plank',
      startPosition:
          'Support both forearms on the floor with the elbows positioned '
          'approximately beneath the shoulders. Use the feet for lower-body '
          'support and lift the trunk and pelvis into a controlled, '
          'approximately straight alignment.',
      executionSequence: const [
        'Maintain support through both forearms and the feet.',
        'Hold the trunk and pelvis in a controlled, approximately straight alignment.',
        'Maintain the defined position without adding another supporting body contact.',
      ],
      completionCriteria: const [
        'Both forearms and the feet remain the supporting contacts.',
        'The defined support position and controlled trunk and pelvis alignment are maintained until the externally determined endpoint.',
      ],
      invalidCriteria: const [
        'A forearm or foot loses its supporting position.',
        'A knee, hip or the trunk becomes an additional supporting contact.',
        'Controlled trunk or pelvis alignment is lost and not re-established.',
      ],
      safetyNotes: const [
        'Use a stable surface and lower under control if the support position cannot be maintained.',
      ],
    ),
    _standard(
      exerciseId: 'EX-025',
      id: 'standard.ex025.walking_lunge.alternating_forward',
      title: 'Walking Lunge — Alternating Forward-Travelling Standard',
      applicabilityKey: 'alternating_forward_walking_lunge',
      startPosition:
          'Stand upright on a stable surface with clear space to travel forwards.',
      executionSequence: const [
        'Step forwards and establish support through the front foot.',
        'Lower the body by bending both legs.',
        'Rise from the lunge and transfer the body forwards.',
        'Bring the rear leg through into the next alternating step.',
      ],
      completionCriteria: const [
        'A forward step, lowering phase and return from the lunge are completed.',
        'The body travels forwards as the rear leg comes through for the next alternating step.',
        'The athlete finishes the step under control.',
      ],
      invalidCriteria: const [
        'The lowering phase is omitted.',
        'The athlete does not rise from the lunge before transferring into the next step.',
        'The movement does not travel forwards.',
        'Balance or foot support is lost before the step is completed.',
      ],
      safetyNotes: const [
        'Use a stable, unobstructed route and stop if controlled balance or foot placement cannot be maintained.',
      ],
    ),
    _standard(
      exerciseId: 'EX-049',
      id: 'standard.ex049.row_erg.generic_stroke',
      title: 'Row Erg — Generic Stroke Standard',
      applicabilityKey: 'generic_row_erg_stroke',
      startPosition:
          'Sit on the Row Erg seat with both feet supported by the footplates '
          'and both hands holding the handle. Begin in a controlled forward '
          'position ready to drive the seat and handle away from the front of '
          'the machine.',
      executionSequence: const [
        'Drive through the feet as the legs extend and the seat moves rearwards.',
        'Move the trunk from the forward position as the handle travels towards the body.',
        'Draw the handle towards the torso to finish the drive.',
        'Return the handle, trunk and seat forwards under control.',
      ],
      completionCriteria: const [
        'The stroke contains a rearward drive and a controlled forward recovery.',
        'The handle travels towards the torso during the drive.',
        'The seat and handle return to a controlled position ready for another stroke.',
      ],
      invalidCriteria: const [
        'The rearward drive or forward recovery is omitted.',
        'A foot or hand loses its supporting contact.',
        'The handle or seat is released or returned without control.',
      ],
      safetyNotes: const [
        'Confirm that the machine is stable and the feet are secured before starting.',
        'Keep fingers, clothing and loose items clear of moving parts.',
      ],
    ),
    _standard(
      exerciseId: 'EX-050',
      id: 'standard.ex050.ski_erg.generic_drive',
      title: 'Ski Erg — Generic Movement Standard',
      applicabilityKey: 'generic_ski_erg_drive',
      startPosition:
          'Stand facing the Ski Erg in a stable position with one handle held '
          'in each hand and the handles raised under control.',
      executionSequence: const [
        'Initiate the downward drive with the arms and trunk as both handles travel downwards.',
        'Flex or hinge the trunk forwards while the knees flex as appropriate during the downward phase.',
        'Finish the pull with the arms as the handles reach the lower end of the controlled drive.',
        'Recover under control as the body returns upwards and both handles rise.',
      ],
      completionCriteria: const [
        'Both handles complete a clear downward drive.',
        'The body and handles return upwards under control to a position ready for another drive.',
      ],
      invalidCriteria: const [
        'The downward drive or upward recovery is omitted.',
        'A handle is released while its cord is tensioned.',
        'The handles or body return without control.',
      ],
      safetyNotes: const [
        'Confirm that the device, cords and surrounding area are clear before starting.',
        'Maintain control of both handles throughout the drive and recovery.',
      ],
    ),
    _standard(
      exerciseId: 'EX-052',
      id: 'standard.ex052.wall_ball.generic',
      title: 'Wall Ball — Generic Training Standard',
      applicabilityKey: 'generic_wall_ball',
      startPosition:
          'Face the wall in a stable stance with sufficient clearance and hold '
          'the wall ball securely in front of the body.',
      executionSequence: const [
        'Lower into a squat under control.',
        'Rise from the squat and release the ball upwards towards the wall.',
        'Allow the ball to contact the wall.',
        'Receive the returning ball with both hands and regain control.',
      ],
      completionCriteria: const [
        'The movement includes a squat, an upward throw and contact between the ball and wall.',
        'The returning ball is received and controlled.',
      ],
      invalidCriteria: const [
        'The squat or throw phase is omitted.',
        'The ball does not contact the wall.',
        'The returning ball is not received under control.',
      ],
      safetyNotes: const [
        'Keep other people outside the ball flight and rebound path.',
        'Allow an uncontrolled rebound to clear rather than reaching into its path.',
      ],
    ),
    _standard(
      exerciseId: 'EX-057',
      id: 'standard.ex057.kettlebell_swing.russian_chest_height',
      title: 'Russian Kettlebell Swing — Chest-Height Standard',
      applicabilityKey: 'russian_kettlebell_swing_chest_height',
      startPosition:
          'Stand in a stable position with clear space for the kettlebell and '
          'hold the handle securely with both hands.',
      executionSequence: const [
        'Guide the kettlebell back between the legs while hinging at the hips.',
        'Extend the hips to drive the kettlebell forwards in a controlled swing.',
        'Allow the kettlebell to rise to approximately chest height while the arms guide its path.',
        'Receive the returning kettlebell by hinging at the hips and maintaining control.',
      ],
      completionCriteria: const [
        'The kettlebell follows a controlled, hip-driven swing.',
        'The forward swing terminates approximately at chest height.',
        'The kettlebell remains controlled through the return or final placement.',
      ],
      invalidCriteria: const [
        'The movement is not performed as a hip-driven swing.',
        'The kettlebell or grip is not controlled during the forward or return phase.',
        'The movement is intentionally completed overhead, outside this applicability.',
      ],
      safetyNotes: const [
        'Use a secure grip and keep the swing path clear.',
        'Finish by guiding the kettlebell to a controlled position.',
      ],
    ),
    _standard(
      exerciseId: 'EX-130',
      id: 'standard.ex130.burpee_broad_jump.generic_combined',
      title: 'Burpee Broad Jump — Generic Combined Standard',
      applicabilityKey: 'generic_burpee_broad_jump_combined',
      startPosition:
          'Stand facing a clear forward path with enough space for floor '
          'contact and a forward landing.',
      executionSequence: const [
        'Place both hands on the floor and move the body into the floor phase.',
        'Lower until the chest or front torso contacts the floor.',
        'Press away from the floor and return to standing movement.',
        'Take off forwards using both feet.',
        'Land on both feet and establish control before continuing.',
      ],
      completionCriteria: const [
        'The chest or front torso contacts the floor.',
        'The athlete returns from the floor to standing movement.',
        'The forward take-off uses both feet.',
        'The landing uses both feet and is controlled before continuation.',
      ],
      invalidCriteria: const [
        'The floor-contact phase or forward jump is omitted.',
        'The chest or front torso does not contact the floor.',
        'The forward take-off does not use both feet.',
        'The landing does not use both feet or is not controlled before continuation.',
      ],
      safetyNotes: const [
        'Use a stable surface with a clear forward landing area.',
        'Do not continue until the two-foot landing is controlled.',
      ],
    ),
  ]);

  static final coachingContents = List<CoachingContent>.unmodifiable([
    _coaching(
      exerciseId: 'EX-012',
      id: 'coaching.ex012.push_up',
      setup: const [
        'Set both hands firmly on the floor.',
        'Extend the legs and establish a controlled body position before lowering.',
      ],
      execution: const [
        'Lower the chest while the body moves as one unit.',
        'Press to straight elbows without losing hand or foot support.',
      ],
      cues: const [
        'Body straight, elbows controlled, chest to floor, lock out fully.',
        'Move the body as one unit.',
        'Keep both hands planted.',
      ],
      faults: const [
        CoachingFaultCorrection(
          fault: 'The hips sag or rise away from the rest of the body.',
          correction:
              'Re-establish a controlled body position before continuing.',
        ),
        CoachingFaultCorrection(
          fault: 'The chest stops above the floor.',
          correction:
              'Continue the controlled descent until the chest contacts the floor.',
        ),
        CoachingFaultCorrection(
          fault: 'The elbows remain bent at completion.',
          correction: 'Continue pressing until both elbows are straight.',
        ),
      ],
      breathing: const [
        'Breathe in while lowering and breathe out while pressing.',
      ],
      safety: const [
        'Use a stable surface and stop under control if a supporting contact is lost.',
      ],
      regressionProgression:
          'A shorter working lever or reduced proportion of supported body '
          'mass can reduce the movement demand. A longer lever or externally '
          'prescribed resistance can increase it. This does not select a '
          'variant, authorise substitution or grant comparability.',
      legacyNotes:
          'Retains the EX-012 catalogue coaching cue unchanged. Programme '
          'purpose and free-text relationship links were not migrated.',
    ),
    _coaching(
      exerciseId: 'EX-021',
      id: 'coaching.ex021.plank.forearm',
      setup: const [
        'Set both forearms on the floor with the elbows approximately beneath the shoulders.',
        'Use the feet for support and establish controlled trunk and pelvis alignment.',
      ],
      execution: const [
        'Maintain support through both forearms and the feet.',
        'Keep the trunk and pelvis controlled without adding another support contact.',
      ],
      cues: const [
        'Ribs down, glutes tight, straight line from head to heels.',
        'Keep both forearms supported.',
        'Keep the trunk and pelvis controlled.',
      ],
      faults: const [
        CoachingFaultCorrection(
          fault:
              'The pelvis repeatedly drops or rises beyond a controlled position.',
          correction:
              'Re-establish an approximately straight, controlled trunk and pelvis alignment.',
        ),
        CoachingFaultCorrection(
          fault: 'A forearm or foot loses its support position.',
          correction: 'Reset both forearms and the feet before continuing.',
        ),
        CoachingFaultCorrection(
          fault: 'The shoulders or pelvis rotate and remain uncontrolled.',
          correction: 'Return to balanced support through both sides.',
        ),
      ],
      breathing: const [
        'Breathe continuously and avoid deliberately holding the breath.',
      ],
      safety: const [
        'Lower under control if the forearm-plank support position cannot be maintained.',
      ],
      regressionProgression:
          'A shorter support lever or larger support base can reduce positional '
          'demand. A longer lever or smaller support base can increase it. '
          'These descriptions do not select another exercise or grant '
          'comparability.',
      legacyNotes:
          'Retains the EX-021 catalogue coaching cue for the founder-approved '
          'forearm-plank applicability. Programme duration was not migrated.',
    ),
    _coaching(
      exerciseId: 'EX-025',
      id: 'coaching.ex025.walking_lunge',
      setup: const [
        'Face along a clear route and begin upright and balanced.',
        'Secure any separately prescribed load before starting.',
      ],
      execution: const [
        'Step forwards and establish stable support through the front foot.',
        'Lower and rise under control before bringing the rear leg through.',
        'Maintain a stable, controlled relationship between the hip, knee and foot.',
      ],
      cues: const [
        'Take a stable step and keep the front foot supported.',
        'Keep the hip, knee and foot working together under control.',
        'Move from one balanced step to the next.',
      ],
      faults: const [
        CoachingFaultCorrection(
          fault: 'Front-foot support becomes unstable.',
          correction: 'Adjust the step and re-establish stable foot contact.',
        ),
        CoachingFaultCorrection(
          fault: 'The hip, knee and foot relationship becomes uncontrolled.',
          correction:
              'Reduce the range or pace until the leg remains stable and controlled.',
        ),
        CoachingFaultCorrection(
          fault: 'Balance is lost during the transfer forwards.',
          correction:
              'Regain an upright, controlled position before the next step.',
        ),
      ],
      breathing: const [
        'Breathe continuously; breathe in while lowering and out while rising.',
      ],
      safety: const [
        'Use a clear route and stop if stable foot contact or balance cannot be maintained.',
      ],
      regressionProgression:
          'A shorter step, reduced lowering range, pause between steps or '
          'external support can reduce range and balance demands. Removing the '
          'pause or using separately prescribed external load can increase '
          'them. No substitution or comparison authority is implied.',
      legacyNotes:
          'The EX-025 RETAIN-eligible cue was incorporated with an explicit '
          'edit. “Long enough step” and one exact knee-to-toe track were not '
          'made universal requirements.',
    ),
    _coaching(
      exerciseId: 'EX-049',
      id: 'coaching.ex049.row_erg',
      setup: const [
        'Sit centrally on the seat and secure both feet.',
        'Hold the handle with relaxed hands and begin in a controlled forward position.',
      ],
      execution: const [
        'Press through the feet to begin the drive.',
        'Move the trunk and draw the handle towards the torso.',
        'Send the handle forwards and return the seat under control.',
      ],
      cues: const [
        'Legs, body, arms; arms, body, legs; keep strokes powerful and relaxed.',
        'Push through the footplates.',
        'Send the handle away before returning the seat.',
        'Control the movement forwards.',
      ],
      faults: const [
        CoachingFaultCorrection(
          fault: 'The handle path and seat movement interfere with each other.',
          correction:
              'Send the handle forwards before allowing the knees to rise.',
        ),
        CoachingFaultCorrection(
          fault: 'The recovery rushes into the next stroke.',
          correction: 'Slow and control the return forwards.',
        ),
        CoachingFaultCorrection(
          fault: 'The grip and shoulders become unnecessarily tense.',
          correction: 'Relax the grip while maintaining secure handle contact.',
        ),
      ],
      breathing: const [
        'Let breathing follow the stroke; generally breathe out during the drive and in during recovery.',
      ],
      safety: const [
        'Keep both feet secure, maintain handle control and keep clear of moving components.',
      ],
      regressionProgression:
          'A shorter slide and deliberate pauses can reduce range and '
          'coordination demands. A fuller controlled stroke and smoother '
          'linking can increase them. Device settings and output remain '
          'programme prescription.',
      legacyNotes: 'Retains the EX-049 catalogue coaching cue unchanged.',
    ),
    _coaching(
      exerciseId: 'EX-050',
      id: 'coaching.ex050.ski_erg',
      setup: const [
        'Face the device and hold both handles evenly.',
        'Use a balanced stance and keep the handle and cord paths clear.',
      ],
      execution: const [
        'Initiate the downward drive with the arms and trunk.',
        'Move both handles down as the trunk flexes or hinges forwards and the knees flex as appropriate.',
        'Finish the pull with the arms.',
        'Recover under control as the body returns upwards and the handles rise.',
      ],
      cues: const [
        'Hinge through hips, drive handles down, recover tall.',
        'Start with the arms and trunk.',
        'Finish the pull, then guide the handles upwards.',
        'Keep both handles moving together.',
      ],
      faults: const [
        CoachingFaultCorrection(
          fault:
              'The downward drive is attempted by extending the hips and knees.',
          correction:
              'Drive the handles down while the trunk flexes or hinges forwards and the knees flex as appropriate.',
        ),
        CoachingFaultCorrection(
          fault: 'The handles recoil during recovery.',
          correction: 'Maintain contact and guide both handles upwards.',
        ),
        CoachingFaultCorrection(
          fault: 'The two handles move unevenly or without control.',
          correction:
              'Reduce the range and re-establish an even, controlled pull.',
        ),
      ],
      breathing: const [
        'Breathe out during the downward drive and in during the controlled recovery.',
      ],
      safety: const [
        'Do not release tensioned handles and keep clothing and loose items clear of the cords.',
      ],
      regressionProgression:
          'A smaller controlled range and separated drive and recovery can '
          'reduce coordination demand. A larger controlled range and smoother '
          'linking can increase it. This grants no selection, dosage or '
          'comparison authority.',
      legacyNotes:
          'Retains the EX-050 catalogue coaching cue unchanged. The corrected '
          'drive wording is original Cohort founder-approved wording and has '
          'no external attribution or licence claim.',
    ),
    _coaching(
      exerciseId: 'EX-052',
      id: 'coaching.ex052.wall_ball.generic',
      setup: const [
        'Face the wall with room for the ball to travel and return.',
        'Hold the ball securely and establish a balanced stance.',
      ],
      execution: const [
        'Squat under control.',
        'Rise and send the ball upwards towards the wall.',
        'Watch the returning ball and receive it securely with both hands.',
      ],
      cues: const [
        'Squat under control, stand and throw smoothly, receive the ball securely.',
        'Keep the ball close before the throw.',
        'Send the ball upwards.',
        'Watch the ball back into both hands.',
      ],
      faults: const [
        CoachingFaultCorrection(
          fault: 'The ball moves away from the body during the squat.',
          correction: 'Keep it supported close to the body before the throw.',
        ),
        CoachingFaultCorrection(
          fault:
              'The ball is directed forwards rather than upwards towards the wall.',
          correction: 'Direct the release upwards.',
        ),
        CoachingFaultCorrection(
          fault: 'The returning ball pulls the athlete off balance.',
          correction:
              'Track the rebound and receive the ball before resetting.',
        ),
      ],
      breathing: const [
        'Breathe in while lowering and out while rising and releasing the ball.',
      ],
      safety: const [
        'Keep the rebound path clear and allow an uncontrolled rebound to clear.',
      ],
      regressionProgression:
          'Separating the squat, rise and throw with a deliberate reset can '
          'reduce coordination demand. Linking them while retaining a '
          'controlled catch can increase it. No substitution or comparability '
          'is implied.',
      legacyNotes:
          'The EX-052 REVISE cue “Full squat, stand hard, throw smoothly, '
          'catch into next rep.” was replaced with the first coaching cue. '
          'The revision removes depth, force and next-repetition implications.',
    ),
    _coaching(
      exerciseId: 'EX-057',
      id: 'coaching.ex057.kettlebell_swing.russian_chest_height',
      setup: const [
        'Use a stable stance with enough room for the kettlebell swing path.',
        'Hinge to the handle and establish a secure two-handed grip.',
      ],
      execution: const [
        'Guide the kettlebell back into the hinge.',
        'Extend the hips to send it forwards.',
        'Let the arms guide rather than lift the kettlebell.',
        'Allow it to rise approximately to chest height, then receive the return through the hinge.',
      ],
      cues: const [
        'Hinge, snap hips, arms guide the bell, brace at the top.',
        'Keep the bell close on the backswing.',
        'Stand tall as the bell reaches approximately chest height.',
        'Guide the return into the next hinge.',
      ],
      faults: const [
        CoachingFaultCorrection(
          fault: 'The movement becomes predominantly a squat.',
          correction: 'Send the hips backwards and re-establish the hinge.',
        ),
        CoachingFaultCorrection(
          fault: 'The arms lift the kettlebell.',
          correction:
              'Drive with the hips first and let the arms guide the swing.',
        ),
        CoachingFaultCorrection(
          fault: 'The kettlebell or grip becomes uncontrolled.',
          correction: 'Reduce the range and regain control before continuing.',
        ),
        CoachingFaultCorrection(
          fault: 'The kettlebell is intentionally driven overhead.',
          correction:
              'Use the approved Russian-swing endpoint at approximately chest height.',
        ),
      ],
      breathing: const [
        'Breathe out as the hips extend and in as the kettlebell returns.',
      ],
      safety: const [
        'Keep a secure grip and a clear swing path, and guide the kettlebell to a controlled finish.',
      ],
      regressionProgression:
          'A lighter externally prescribed kettlebell or slower controlled '
          'movement can reduce loading or speed demand. A heavier prescribed '
          'kettlebell or faster hip drive can increase it while preserving the '
          'same applicability. This does not prescribe load or authorise '
          'substitution.',
      legacyNotes:
          'Retains the EX-057 catalogue coaching cue unchanged. Within this '
          'record, “top” means approximately chest height and not overhead.',
    ),
    _coaching(
      exerciseId: 'EX-130',
      id: 'coaching.ex130.burpee_broad_jump',
      setup: const [
        'Face the intended direction of travel and clear the floor and landing area.',
        'Begin from a balanced standing position.',
      ],
      execution: const [
        'Plant both hands and lower the chest or front torso to the floor.',
        'Press away and return to standing movement.',
        'Take off forwards from both feet.',
        'Land on both feet and establish control before continuing.',
      ],
      cues: const [
        'Hands down, chest or front torso to the floor.',
        'Return to standing movement and organise both feet.',
        'Drive forwards from both feet.',
        'Land on both feet and establish control.',
      ],
      faults: const [
        CoachingFaultCorrection(
          fault: 'The floor-contact phase is incomplete.',
          correction:
              'Lower until the chest or front torso contacts the floor.',
        ),
        CoachingFaultCorrection(
          fault: 'The forward take-off uses one foot.',
          correction: 'Organise both feet before taking off forwards.',
        ),
        CoachingFaultCorrection(
          fault: 'The landing is one-footed or uncontrolled.',
          correction:
              'Land on both feet and establish control before continuing.',
        ),
      ],
      breathing: const [
        'Breathe out while pressing away from the floor and moving into the jump, then resume steady breathing after landing.',
      ],
      safety: const [
        'Keep the floor and landing area clear and do not continue until the landing is controlled.',
      ],
      regressionProgression:
          'Reducing transition speed or jump distance can reduce coordination '
          'or travel demand while retaining both phases. Increasing either can '
          'increase demand. This creates no prescription, substitution or '
          'comparison authority.',
      legacyNotes:
          'EX-130 has no canonical legacy cue. EX-009 Burpee and EX-024 Broad '
          'Jump cues remain attached to their own identities and were not '
          'copied, concatenated or migrated.',
    ),
  ]);

  static Set<ExerciseId> get exerciseIds =>
      canonicalNames.keys.map(ExerciseId.parse).toSet();

  /// Attaches the pilot references to authoritative definitions as a new
  /// definition version while preserving every canonical identity field.
  static ExerciseCatalogueSnapshot draftSnapshot(
    ExerciseCatalogueSnapshot source,
  ) {
    final byId = {
      for (final definition in source.definitions)
        definition.id.value: definition,
    };
    for (final entry in canonicalNames.entries) {
      final definition = byId[entry.key];
      if (definition == null) {
        throw StateError(
          'Phase 3.2D requires canonical definition ${entry.key}.',
        );
      }
      if (definition.canonicalName != entry.value) {
        throw StateError(
          'Canonical identity conflict for ${entry.key}: expected '
          '“${entry.value}”, found “${definition.canonicalName}”.',
        );
      }
    }

    final standardsByExercise = {
      for (final standard in movementStandards) standard.exerciseId: standard,
    };
    final coachingByExercise = {
      for (final coaching in coachingContents) coaching.exerciseId: coaching,
    };
    final definitions = source.definitions
        .map((definition) {
          final standard = standardsByExercise[definition.id];
          final coaching = coachingByExercise[definition.id];
          if (standard == null || coaching == null) return definition;
          return _withContentRefs(definition, standard.id, coaching.id);
        })
        .toList(growable: false);

    final pilotStandardIds = movementStandards.map((item) => item.id).toSet();
    final pilotCoachingIds = coachingContents.map((item) => item.id).toSet();
    return ExerciseCatalogueSnapshot(
      catalogueVersion: catalogueVersion,
      label: 'Founder-approved Phase 3.2D text-only pilot',
      definitions: definitions,
      relationships: source.relationships,
      comparisonProtocols: source.comparisonProtocols,
      movementStandards: [
        ...source.movementStandards.where(
          (item) => !pilotStandardIds.contains(item.id),
        ),
        ...movementStandards,
      ],
      coachingContents: [
        ...source.coachingContents.where(
          (item) => !pilotCoachingIds.contains(item.id),
        ),
        ...coachingContents,
      ],
      videoReferences: source.videoReferences,
    );
  }

  /// Publishes the pilot through the existing founder-authorised boundary.
  static ExerciseKnowledgePublicationResult publish({
    required ExerciseKnowledgeRepository repository,
    required String actingOwner,
    required KnowledgeActorId reviewerId,
    required DateTime publishedAt,
    ExerciseKnowledgePublicationService publicationService =
        const ExerciseKnowledgePublicationService(),
  }) {
    return publicationService.publishCatalogue(
      repository: repository,
      draftSnapshot: draftSnapshot(repository.authoringSnapshot()),
      actingOwner: actingOwner,
      reviewerId: reviewerId,
      publishedAt: publishedAt,
    );
  }

  static MovementStandard _standard({
    required String exerciseId,
    required String id,
    required String title,
    required String applicabilityKey,
    required String startPosition,
    required List<String> executionSequence,
    required List<String> completionCriteria,
    required List<String> invalidCriteria,
    required List<String> safetyNotes,
  }) {
    return MovementStandard(
      id: KnowledgeReferenceId.parse(id),
      exerciseId: ExerciseId.parse(exerciseId),
      version: '1',
      lifecycleStatus: ExerciseLifecycleStatus.draft,
      authorId: authorId,
      language: 'en-GB',
      title: title,
      applicabilityKey: applicabilityKey,
      startPosition: startPosition,
      executionSequence: executionSequence,
      completionCriteria: completionCriteria,
      invalidRepetitionCriteria: invalidCriteria,
      safetyNotes: safetyNotes,
      provenance: KnowledgeProvenance(
        sourceType: 'founder_approved_cohort_content',
        sourceReference:
            'phase_3_2c_1_founder_review:$exerciseId:movement_standard',
        notes:
            'Founder-approved generic training wording with mandatory Phase '
            '3.2D amendments. No external competition standard is asserted.',
      ),
      authoredAt: authoredAt,
    );
  }

  static CoachingContent _coaching({
    required String exerciseId,
    required String id,
    required List<String> setup,
    required List<String> execution,
    required List<String> cues,
    required List<CoachingFaultCorrection> faults,
    required List<String> breathing,
    required List<String> safety,
    required String regressionProgression,
    required String legacyNotes,
  }) {
    return CoachingContent(
      id: KnowledgeReferenceId.parse(id),
      exerciseId: ExerciseId.parse(exerciseId),
      version: '1',
      lifecycleStatus: ExerciseLifecycleStatus.draft,
      authorId: authorId,
      language: 'en-GB',
      audience: 'general_training',
      setupGuidance: setup,
      executionInstructions: execution,
      coachingCues: cues,
      faultCorrections: faults,
      breathingGuidance: breathing,
      safetyNotes: safety,
      regressionProgressionExplanation: regressionProgression,
      provenance: KnowledgeProvenance(
        sourceType: 'founder_approved_cohort_content',
        sourceReference:
            'phase_3_2c_1_founder_review:$exerciseId:coaching_content',
        notes:
            '$legacyNotes Legacy source: the accepted Phase 3.2C audit of the '
            'Phase 3.1F published catalogue review export. '
            'New wording was approved in the Phase 3.2C founder review.',
      ),
      authoredAt: authoredAt,
    );
  }
}

ExerciseDefinition _withContentRefs(
  ExerciseDefinition source,
  KnowledgeReferenceId standardId,
  KnowledgeReferenceId coachingId,
) {
  final standards = [
    ...source.movementStandardRefs.where((ref) => ref.id != standardId),
    MovementStandardRef(id: standardId),
  ]..sort((a, b) => a.id.value.compareTo(b.id.value));
  final coaching = [
    ...source.coachingContentRefs.where((ref) => ref.id != coachingId),
    CoachingContentRef(id: coachingId),
  ]..sort((a, b) => a.id.value.compareTo(b.id.value));
  final version =
      source.version.endsWith(
        FounderApprovedMovementKnowledgePhase32d.definitionVersionSuffix,
      )
      ? source.version
      : '${source.version}${FounderApprovedMovementKnowledgePhase32d.definitionVersionSuffix}';

  return ExerciseDefinition(
    id: source.id,
    canonicalName: source.canonicalName,
    aliases: source.aliases,
    modality: source.modality,
    familyId: source.familyId,
    movementPatterns: source.movementPatterns,
    laterality: source.laterality,
    technicalComplexity: source.technicalComplexity,
    impactLevel: source.impactLevel,
    validPrescriptionDimensions: source.validPrescriptionDimensions,
    validCompletedPerformanceDimensions:
        source.validCompletedPerformanceDimensions,
    equipment: source.equipment,
    environments: source.environments,
    coachingContentRefs: coaching,
    mediaRefs: source.mediaRefs,
    movementStandardRefs: standards,
    sportStandardRefs: source.sportStandardRefs,
    transitionalAliasIds: source.transitionalAliasIds,
    lifecycleStatus: ExerciseLifecycleStatus.draft,
    version: version,
    owner: ExerciseKnowledgePublicationService.founderOwner,
  );
}
