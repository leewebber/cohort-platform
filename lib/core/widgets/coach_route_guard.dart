import 'package:flutter/material.dart';

import '../access/app_role_access.dart';
import '../errors/user_facing_error_messages.dart';

/// Blocks coach-only screens when the signed-in user lacks coach access.
class CoachRouteGuard extends StatelessWidget {
  const CoachRouteGuard({
    super.key,
    required this.child,
    this.title = 'Coach',
  });

  final Widget child;
  final String title;

  /// Wraps [child] for coach-only screens (deep-link safe).
  static Widget wrap({
    required Widget child,
    String title = 'Coach',
  }) {
    return CoachRouteGuard(title: title, child: child);
  }

  /// Material route that always applies [CoachRouteGuard].
  static Route<T> materialRoute<T>({
    required WidgetBuilder builder,
    String title = 'Coach',
    RouteSettings? settings,
  }) {
    return MaterialPageRoute<T>(
      settings: settings,
      builder: (context) => CoachRouteGuard(
        title: title,
        child: Builder(builder: builder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppRoleAccess.canAccessCoachOperations) {
      return child;
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(UserFacingErrorMessages.coachAccessRequired()),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
