# Athlete-Safe Application Shell (Closed Family Beta)

Centralizes role checks, route guards, athlete-safe errors, and Training History navigation for production athlete builds.

Every coach-only **screen** wraps its root widget in `CoachRouteGuard.wrap(...)`. See `test/navigation/coach_route_guard_coverage_test.dart` for the audited file list.
