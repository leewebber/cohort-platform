/// Athlete-controlled scheduling operation kinds (Sprint 1.7).
///
/// [undo] is preview/confirm only for the compensating apply path; Undo rows
/// themselves are never undoable.
enum ProgrammeSchedulingOperationType { move, swap, push, skip, undo }
