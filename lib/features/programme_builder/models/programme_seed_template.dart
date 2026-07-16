/// Starting structural scaffold for a new programme draft.
///
/// Seeds produce week/day/slot hierarchy only — no protocol assignment.
/// See `45_Coach_Studio_Programme_Catalogue.md`.
enum ProgrammeSeedTemplate {
  empty,
  strength,
  running,
  circuit,
  recovery,
  assessment,
  hybrid,
}

extension ProgrammeSeedTemplateLabels on ProgrammeSeedTemplate {
  String get label {
    return switch (this) {
      ProgrammeSeedTemplate.empty => 'Empty',
      ProgrammeSeedTemplate.strength => 'Strength',
      ProgrammeSeedTemplate.running => 'Running',
      ProgrammeSeedTemplate.circuit => 'Circuit',
      ProgrammeSeedTemplate.recovery => 'Recovery',
      ProgrammeSeedTemplate.assessment => 'Assessment',
      ProgrammeSeedTemplate.hybrid => 'Hybrid',
    };
  }

  String get description {
    return switch (this) {
      ProgrammeSeedTemplate.empty =>
        'Week 1 with one training day and an empty required slot.',
      ProgrammeSeedTemplate.strength =>
        'Week 1 strength day plus a rest day.',
      ProgrammeSeedTemplate.running =>
        'Week 1 running day plus a rest day.',
      ProgrammeSeedTemplate.circuit =>
        'Week 1 circuit day plus a rest day.',
      ProgrammeSeedTemplate.recovery =>
        'Week 1 recovery-oriented day with an optional slot.',
      ProgrammeSeedTemplate.assessment =>
        'Week 1 test-intent day with a required assessment slot.',
      ProgrammeSeedTemplate.hybrid =>
        'Week 1 with three training days and a rest day.',
    };
  }
}
