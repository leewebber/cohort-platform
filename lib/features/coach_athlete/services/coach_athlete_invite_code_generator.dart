import 'dart:math';

/// Generates human-readable invitation codes without ambiguous characters.
class CoachAthleteInviteCodeGenerator {
  const CoachAthleteInviteCodeGenerator();

  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _length = 8;

  String generate() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < _length; i++) {
      buffer.write(_alphabet[random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }
}
