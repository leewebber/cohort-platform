# Phase 1 preview inventory

Ports below are **local conventions**, not product behaviour.

| Entry | Purpose | State shown | Useful? | Production? |
|-------|---------|-------------|---------|-------------|
| `lib/main.dart` | Production athlete app | Real auth, stores, capabilities | Yes | **Yes** |
| `lib/main_athlete_shell_preview.dart` | 5-tab shell layout | In-memory preview athlete | Yes for layout | No |
| `lib/main_overdue_recovery_preview.dart` | Incomplete recovery UX | Local overdue fixtures | Historical; production Calendar now owns this | No |
| `lib/main_strength_accordion_preview.dart` | Strength accordion | Local strength fixtures | Optional | No |
| `lib/main_emom_result_preview.dart` | EMOM result surface | Local EMOM fixtures (port **4183**) | Yes for isolated QA | No |
| `lib/main_s13_staging_verify.dart` | Staging Sprint 1.3 | Hosted staging only | Staging-gated | No |
| `lib/main_s14a_staging_verify.dart` | Staging 1.4A | Hosted staging only | Staging-gated | No |
| `lib/main_s14b_staging_verify.dart` | Staging 1.4B | Hosted staging only | Staging-gated | No |
| `lib/main_s15a_staging_verify.dart` | Staging 1.5A | Hosted staging only | Staging-gated | No |
| `lib/main_s17_staging_verify.dart` | Staging 1.7 | Hosted staging only | Staging-gated | No |

Preview stores and fixtures must not be imported from `lib/main.dart` or the
production shell/Home/Calendar/Progress path. Loopback preview may show
**LOCAL PREVIEW**; production `BuildEnvironment.production` does not.

`Reset Preview` is preview-harness only. Production capability RPCs fail
closed. Build provenance (`COHORT_BUILD_ENV`, version, build, commit) is
inspectable on Profile without printing URL or keys.

No obsolete preview mains were deleted in this closeout: they still have
tests or local QA value. Staging verify mains stay behind explicit staging
authority.
