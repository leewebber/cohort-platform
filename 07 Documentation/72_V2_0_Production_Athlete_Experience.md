# 72 — V2.0 Production Athlete Experience (Sprint 9)

## Purpose

Sprint 9 prepares Cohort for real athlete use on iPhone by hiding engineering tooling from normal navigation, making signup and profile setup clearer, and enforcing role-aware Home navigation for athletes and coaches.

Production users must never accidentally see debug, founder acceptance, test programme, or admin engineering actions during ordinary use — including when running locally with `flutter run`.

## Production visibility rules

| Surface | Athlete-only | Coach-only | Coach + athlete |
| --- | --- | --- | --- |
| Today / training | Yes | No | Yes |
| Join a coach | Yes | No | Yes |
| Training history | Yes | No | Yes |
| Adjust today's session | Yes | No | Yes |
| Athlete knowledge libraries | Yes | No | Yes |
| My Athletes | No | Yes | Yes |
| Coach Studio | No | Yes | Yes |
| Help & feedback | Yes | Yes | Yes |
| Internal tools | No* | No* | No* |
| Admin Protocol Editor | No* | No* | No* |

\* Visible only when internal tools are explicitly enabled.

Internal tooling is centralized behind `InternalToolsPolicy` and `ProductionNavigationPolicy` in `lib/core/config/`.

## Internal tools activation

Default: **hidden**.

Enable deliberately using one of:

1. **Local engineering run**
   ```bash
   flutter run -d chrome --web-port 3000 --dart-define=ENABLE_INTERNAL_TOOLS=true
   ```

2. **Automated tests**
   ```dart
   InternalToolsPolicy.enableForTesting();
   addTearDown(InternalToolsPolicy.reset);
   ```

3. **Programmatic local opt-in (do not ship enabled)**
   ```dart
   InternalToolsPolicy.enable();
   ```

When enabled, Home shows a single **Internal tools** entry that navigates to `InternalToolsScreen`, which hosts programme debug, protocol analysis hooks, and Admin Protocol Editor.

`kDebugMode` alone does **not** expose internal tools.

## Local web auth redirect setup

Use a stable port for Supabase email verification redirects during Chrome testing:

```bash
flutter run -d chrome --web-port 3000
```

Supabase Auth configuration for local web:

| Setting | Value |
| --- | --- |
| Site URL | `http://localhost:3000` |
| Allowed Redirect URLs | `http://localhost:3000/**` |

Production web and iOS use separate Supabase project/site URL settings. Do not overwrite production URLs when configuring local testing.

## iOS verification / deep-link status

Email verification deep links for installed iOS builds are **not fully implemented** in this sprint. Supabase redirect URL configuration and universal-link handling remain deployment follow-up before relying on iOS mail-app verification callbacks.

After verification, users can return to the app and sign in; Finish Setup continues from authenticated session + profile state.

## Signup and verification UX

After signup when Supabase requires email confirmation:

- Loading stops; status becomes `awaitingEmailConfirmation`
- User sees **Check your email** with the address used
- Copy explains verifying then returning to Cohort
- **Back to sign in** and **Resend verification email** are available
- Repeat submission is disabled while loading

Display name and roles selected at signup are stored as pending auth metadata and prefilled on Finish Setup when no profile exists yet.

Registration defaults to **Athlete selected, Coach unselected**. At least one role is always required (chips prevent clearing the last role).

## Founder acceptance checklist

Before iPhone athlete testing, confirm:

- [ ] New athlete account sees clean Today with no coach or internal tools
- [ ] Signup transitions to email verification state (not indefinite loading)
- [ ] Finish Setup prefills signup display name and roles
- [ ] Dual-role account can access athlete Today and Coach Studio / My Athletes
- [ ] No debug/founder/test/admin actions on Home without `ENABLE_INTERNAL_TOOLS`
- [ ] Account screen provides sign out
- [ ] Full automated test suite passes
- [ ] Chrome tested at iPhone viewport without overflow/clipping

## Related code

- `lib/core/config/internal_tools_policy.dart`
- `lib/core/config/production_navigation_policy.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/internal_tools/internal_tools_screen.dart`
- `lib/features/auth/screens/email_verification_screen.dart`
- `test/home/production_home_navigation_test.dart`
- `test/core/production_navigation_source_scan_test.dart`
