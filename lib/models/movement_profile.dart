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
