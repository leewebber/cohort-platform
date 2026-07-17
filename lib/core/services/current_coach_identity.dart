import '../constants/programme_dev_identity.dart';

/// Provides the current coach identity for authoring operations.
abstract interface class CurrentCoachIdentity {
  String? get coachId;
}

/// Development identity aligned with Programme Engine RLS helpers.
class DevCoachIdentity implements CurrentCoachIdentity {
  const DevCoachIdentity();

  @override
  String? get coachId => ProgrammeDevIdentity.coachId;
}
