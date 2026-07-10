/// Distribution of movement patterns within a protocol.
///
/// v0.1 counts raw occurrences per step. Future versions may weight counts
/// by reps, time, and distance.
class MovementProfile {
  const MovementProfile({
    this.push = 0,
    this.pull = 0,
    this.squat = 0,
    this.hinge = 0,
    this.lunge = 0,
    this.carry = 0,
    this.core = 0,
    this.running = 0,
    this.erg = 0,
    this.upperBody = 0,
    this.lowerBody = 0,
    this.totalMovements = 0,
  });

  final int push;
  final int pull;
  final int squat;
  final int hinge;
  final int lunge;
  final int carry;
  final int core;
  final int running;
  final int erg;
  final int upperBody;
  final int lowerBody;
  final int totalMovements;

  /// Share of classified steps tagged with push (0–100).
  double get pushPercent => _movementPercent(push);

  /// Share of classified steps tagged with pull (0–100).
  double get pullPercent => _movementPercent(pull);

  /// Share of classified steps tagged with squat (0–100).
  double get squatPercent => _movementPercent(squat);

  /// Share of classified steps tagged with hinge (0–100).
  double get hingePercent => _movementPercent(hinge);

  /// Share of classified steps tagged with lunge (0–100).
  double get lungePercent => _movementPercent(lunge);

  /// Share of classified steps tagged with carry (0–100).
  double get carryPercent => _movementPercent(carry);

  /// Share of classified steps tagged with core (0–100).
  double get corePercent => _movementPercent(core);

  /// Share of classified steps tagged with running (0–100).
  double get runningPercent => _movementPercent(running);

  /// Share of classified steps tagged with erg (0–100).
  double get ergPercent => _movementPercent(erg);

  /// Share of body-region steps tagged upper body (0–100).
  double get upperBodyPercent => _bodyRegionPercent(upperBody);

  /// Share of body-region steps tagged lower body (0–100).
  double get lowerBodyPercent => _bodyRegionPercent(lowerBody);

  double _movementPercent(int count) {
    if (totalMovements == 0) {
      return 0;
    }
    return count / totalMovements * 100;
  }

  double _bodyRegionPercent(int count) {
    final total = upperBody + lowerBody;
    if (total == 0) {
      return 0;
    }
    return count / total * 100;
  }

  @override
  String toString() {
    return 'MovementProfile('
        'push: $push, '
        'pull: $pull, '
        'squat: $squat, '
        'hinge: $hinge, '
        'lunge: $lunge, '
        'carry: $carry, '
        'core: $core, '
        'running: $running, '
        'erg: $erg, '
        'upperBody: $upperBody, '
        'lowerBody: $lowerBody, '
        'totalMovements: $totalMovements'
        ')';
  }
}
