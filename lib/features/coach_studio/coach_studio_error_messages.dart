/// User-facing messages for coach Studio database failures.
class CoachStudioErrorMessages {
  const CoachStudioErrorMessages._();

  static String fromObject(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();

    if (lower.contains('postgrestexception') ||
        lower.contains('column') && lower.contains('does not exist') ||
        lower.contains('42703')) {
      return 'This panel could not load right now. Please try again.';
    }

    if (lower.contains('42501') || lower.contains('permission denied')) {
      return 'You do not have permission to view this information.';
    }

    if (lower.contains('network') || lower.contains('socket')) {
      return 'Network connection failed. Check your connection and try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}
