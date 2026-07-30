import '../../../domain/adaptation/adaptation_domain.dart';
import '../../../models/protocol.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/protocol_metadata_vocabulary.dart';

/// V1 discovery filters for the Templates catalogue.
///
/// Derived from existing structured session fields — not a second ontology.
enum SessionTemplateModalityFilter {
  all,
  strength,
  conditioning,
  running,
  hyrox,
  mobilityRecovery,
  testing,
}

enum SessionTemplateEquipmentFilter { all, bodyweight, minimalKit, fullGym }

extension SessionTemplateModalityFilterLabels on SessionTemplateModalityFilter {
  String get label {
    return switch (this) {
      SessionTemplateModalityFilter.all => 'All',
      SessionTemplateModalityFilter.strength => 'Strength',
      SessionTemplateModalityFilter.conditioning => 'Conditioning',
      SessionTemplateModalityFilter.running => 'Running',
      SessionTemplateModalityFilter.hyrox => 'HYROX',
      SessionTemplateModalityFilter.mobilityRecovery => 'Mobility / Recovery',
      SessionTemplateModalityFilter.testing => 'Testing',
    };
  }
}

extension SessionTemplateEquipmentFilterLabels
    on SessionTemplateEquipmentFilter {
  String get label {
    return switch (this) {
      SessionTemplateEquipmentFilter.all => 'All equipment',
      SessionTemplateEquipmentFilter.bodyweight => 'Bodyweight',
      SessionTemplateEquipmentFilter.minimalKit => 'Minimal kit',
      SessionTemplateEquipmentFilter.fullGym => 'Full gym',
    };
  }
}

/// Derives V1 filter membership from existing Protocol / ProtocolDraft fields.
class SessionTemplateTaxonomy {
  const SessionTemplateTaxonomy();

  SessionTemplateModalityFilter? modalityForProtocol(Protocol protocol) {
    return modalityFor(
      sessionType: protocol.sessionType,
      suitableFor: protocol.suitableFor,
      primaryIntent: protocol.primarySessionIntent,
      primaryCapability: protocol.capability ?? protocol.goal,
    );
  }

  SessionTemplateModalityFilter? modalityForDraft(ProtocolDraft draft) {
    return modalityFor(
      sessionType: draft.sessionType,
      suitableFor: draft.suitableFor,
      primaryIntent: draft.primarySessionIntent,
      primaryCapability: draft.primaryCapability,
    );
  }

  /// Returns null when structured fields do not support a confident modality.
  /// Unknown items remain visible under [SessionTemplateModalityFilter.all] only.
  SessionTemplateModalityFilter? modalityFor({
    String? sessionType,
    String? suitableFor,
    SessionIntent? primaryIntent,
    String? primaryCapability,
  }) {
    final type = sessionType?.trim() ?? '';
    final suitable = ProtocolMetadataVocabulary.parseCommaSeparated(
      suitableFor,
    );
    final intent = primaryIntent;
    final capability = primaryCapability?.trim() ?? '';

    if (type == 'Benchmark' || suitable.contains('Testing')) {
      return SessionTemplateModalityFilter.testing;
    }
    if (type == 'Recovery' ||
        type == 'Mobility' ||
        intent == SessionIntent.mobility ||
        intent == SessionIntent.activeRecovery ||
        intent == SessionIntent.flexibility ||
        capability == 'Mobility' ||
        capability == 'Recovery') {
      return SessionTemplateModalityFilter.mobilityRecovery;
    }
    // HYROX only from explicit suitability or HYROX-specific intent — not bare
    // Hybrid / mixed-modal labels or exercise titles.
    if (suitable.contains('HYROX') ||
        intent == SessionIntent.hyroxSpecificConditioning) {
      return SessionTemplateModalityFilter.hyrox;
    }
    if (type == 'Conditioning' ||
        type == 'Intervals' ||
        type == 'AMRAP' ||
        type == 'EMOM' ||
        type == 'Circuit' ||
        type == 'Hybrid' ||
        intent == SessionIntent.aerobicConditioning ||
        intent == SessionIntent.anaerobicConditioning ||
        intent == SessionIntent.highIntensityIntervals ||
        intent == SessionIntent.workCapacity ||
        intent == SessionIntent.mixedModalConditioning ||
        capability == 'Engine' ||
        capability == 'Threshold') {
      return SessionTemplateModalityFilter.conditioning;
    }
    if (type == 'Running' ||
        (intent != null && _isRunningIntent(intent)) ||
        (suitable.contains('Endurance') &&
            intent != null &&
            _isRunningIntent(intent))) {
      return SessionTemplateModalityFilter.running;
    }
    if (type == 'Strength' ||
        type == 'Hypertrophy' ||
        capability == 'Strength' ||
        capability == 'Hypertrophy' ||
        intent != null && _isStrengthIntent(intent)) {
      return SessionTemplateModalityFilter.strength;
    }
    return null;
  }

  /// Returns null when equipment is unspecified rather than inventing Full Gym.
  SessionTemplateEquipmentFilter? equipmentBucketFor({
    String? requiredEquipment,
    String? legacyEquipment,
  }) {
    final tokens = ProtocolMetadataVocabulary.parseCommaSeparated(
      requiredEquipment ?? legacyEquipment,
    );
    if (tokens.isEmpty) {
      return null;
    }
    if (tokens.length == 1 && tokens.contains('Bodyweight')) {
      return SessionTemplateEquipmentFilter.bodyweight;
    }
    if (tokens.contains('Bodyweight') ||
        tokens.contains('Minimal Kit') ||
        tokens.contains('Dumbbell') ||
        tokens.contains('Kettlebell')) {
      if (!tokens.contains('Barbell') &&
          !tokens.contains('Full Gym') &&
          !tokens.contains('Bike Erg') &&
          !tokens.contains('Row Erg') &&
          !tokens.contains('Ski Erg')) {
        if (tokens.contains('Bodyweight') && tokens.length == 1) {
          return SessionTemplateEquipmentFilter.bodyweight;
        }
        return SessionTemplateEquipmentFilter.minimalKit;
      }
    }
    if (tokens.contains('Minimal Kit') &&
        !tokens.contains('Barbell') &&
        !tokens.contains('Full Gym')) {
      return SessionTemplateEquipmentFilter.minimalKit;
    }
    return SessionTemplateEquipmentFilter.fullGym;
  }

  bool matchesModality(
    SessionTemplateModalityFilter filter, {
    SessionTemplateModalityFilter? itemModality,
  }) {
    if (filter == SessionTemplateModalityFilter.all) return true;
    if (itemModality == null) return false;
    return filter == itemModality;
  }

  bool matchesEquipment(
    SessionTemplateEquipmentFilter filter, {
    SessionTemplateEquipmentFilter? itemEquipment,
  }) {
    if (filter == SessionTemplateEquipmentFilter.all) return true;
    if (itemEquipment == null) return false;
    return filter == itemEquipment;
  }

  bool _isRunningIntent(SessionIntent intent) {
    return intent == SessionIntent.aerobicBase ||
        intent == SessionIntent.recoveryRunning ||
        intent == SessionIntent.steadyAerobicEndurance ||
        intent == SessionIntent.tempo ||
        intent == SessionIntent.threshold ||
        intent == SessionIntent.vo2Max ||
        intent == SessionIntent.longRun ||
        intent == SessionIntent.hills ||
        intent == SessionIntent.racePace;
  }

  bool _isStrengthIntent(SessionIntent intent) {
    return intent == SessionIntent.fullBodyStrength ||
        intent == SessionIntent.upperBodyStrength ||
        intent == SessionIntent.lowerBodyStrength ||
        intent == SessionIntent.pushStrength ||
        intent == SessionIntent.pullStrength ||
        intent == SessionIntent.squatStrength ||
        intent == SessionIntent.hingeStrength ||
        intent == SessionIntent.unilateralLowerBodyStrength ||
        intent == SessionIntent.strengthEndurance;
  }
}
