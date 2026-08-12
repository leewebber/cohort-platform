import '../value_objects/exercise_id.dart';
import 'coaching_content.dart';
import 'movement_standard.dart';
import 'video_reference.dart';

/// Read-only knowledge attached to one canonical exercise.
///
/// Text guidance remains valid when [playableVideos] is empty.
class ExerciseMovementKnowledge {
  ExerciseMovementKnowledge({
    required this.exerciseId,
    required List<MovementStandard> movementStandards,
    required List<CoachingContent> coachingContents,
    required List<VideoReference> playableVideos,
  }) : movementStandards = List.unmodifiable(movementStandards),
       coachingContents = List.unmodifiable(coachingContents),
       playableVideos = List.unmodifiable(playableVideos);

  final ExerciseId exerciseId;
  final List<MovementStandard> movementStandards;
  final List<CoachingContent> coachingContents;
  final List<VideoReference> playableVideos;

  bool get hasTextGuidance =>
      movementStandards.isNotEmpty || coachingContents.isNotEmpty;
}
