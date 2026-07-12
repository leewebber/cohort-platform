/// Athlete-selected reason for ending a strength session before completion.
enum EarlySessionEndReason {
  shortOnTime('Short on time'),
  poorRecovery('Poor recovery'),
  painOrDiscomfort('Pain or discomfort'),
  equipmentIssue('Equipment issue'),
  other('Other');

  const EarlySessionEndReason(this.label);

  final String label;
}
