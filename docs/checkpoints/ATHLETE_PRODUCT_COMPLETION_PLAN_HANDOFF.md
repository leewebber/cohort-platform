# Athlete Product Completion Plan — handoff

**Recorded:** 2026-09-20

**Status:** Binding next-task authority after M10 infrastructure closeout
and Complete Athlete Experience closeout. Launch programme library is
**audited, awaiting approval**. Implementation is **not** authorised.

```text
PLAN_AUTHORITY=docs/planning/Athlete_Product_Completion_Plan_v1.md
M10_CLOSED=true
COACH_PLATFORM_FROZEN=true
DAILY_JOURNEY_INTEGRITY=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=COMPLETE
HOSTED_MIGRATION_APPLIED=true
SPRINT_2_HOSTED_MIGRATION_APPLIED=true
SPRINT_3_HOSTED_MIGRATION_APPLIED=true
NEXT_MILESTONE=LAUNCH_PROGRAMME_LIBRARY
LAUNCH_PROGRAMME_LIBRARY=AUDITED_AWAITING_APPROVAL
LAUNCH_PROGRAMME_LIBRARY_IMPLEMENTATION_AUTHORISED=false
NEXT_IMPLEMENTATION_MILESTONE=LAUNCH_PROGRAMME_LIBRARY
NEXT_IMPLEMENTATION_AUTHORISED=false
FOUNDER_ROADMAP_APPROVAL_REQUIRED=true
HOSTED_WRITES_THIS_TASK=false
PHONE_UNTOUCHED=true
REPO_ENV_UNTOUCHED=true
PUSHED=false
```

Binding:
[`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md),
[`M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md`](./M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md),
[`../planning/Delivery_Roadmap_v1.md`](../planning/Delivery_Roadmap_v1.md).

This file does not rewrite
[`M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](./M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md)
or historical M10 sprint/preflight/hardening records.

---

## Plan authority

Cohort is an athlete-first hybrid training platform. Launch bar: Runna-level
product quality for complete hybrid performance. Development order in the
plan (close M10 → freeze coach → complete athlete experience → library →
adaptation → progression → media → wearables → onboarding → commercial →
betas → individual launch → Build Your Own → coaching → B2B) is binding.

## M10 closure state

Field Manual (`otnhhdxstdnwccehacku`, `eu-west-1`) **ACTIVE_HEALTHY**, ledger
**96 / `20260920120000`**, capability schema **3**, zero invitation /
membership / event rows, empty roster, Lee Apollo assignment pinned and
**not** in roster, manifests **2**, reconstruction jobs **0**, M10 client
path RPC-only. `service_role` roster-view leftover ACL accepted; no further
M10 migration. Phone **build 7** untouched. No hosted consent smoke.

## Next implementation milestone

Daily Journey Integrity is **closed**. Binding:
[`DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md`](./DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md).

Complete Athlete Experience is **complete**. Closeout:
[`COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md`](./COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md).
The next sequenced item is **launch programme library**. It is
**audited, awaiting approval**
([`LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](./LAUNCH_PROGRAMME_LIBRARY_AUDIT.md),
[`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md)).
It has **not** started. Implementation is **not** authorised.

## Frozen / deferred coach scope

Invitations UX, hosted consent smoke, first real relationship, roster-driven
assignment, monitoring, messaging, teams, publisher billing, Join-coach
migration, white label. M10 schema remains; product is Phase C.

## Readiness summary

Strongest: architecture integrity and the programme-athlete
`ActiveSessionScreen` spine. Weakest vs launch bar: programme library depth
(two published families), wearables (unverified / missing), commercial/legal,
exercise media, guest/Coach Brain onboarding leftover, athlete comparison
UI, recovery player. See plan §15 bands — not false precision. Production
audit addendum 2026-09-20 (late repository pass) is folded into plan §2.

## Critical path

Experience completion → launch library (founder authorship parallel) →
adaptation v1 + progression honesty → media (film parallel) → wearables
(research now) → onboarding matching → commercial → staged betas → public
athlete launch.

## Founder decisions required

- Approve this roadmap (pause point)
- iOS-first confirmation
- HYROX equipment substitution policy
- Whether mobility is embedded-only
- Radar hidden-until-honest
- First wearable vendor / commercial API spend
- Account-deletion SLA
- Crash/analytics vendor
- **Pricing later** — not chosen here

## Immediate next sprint recommendation

Athlete Experience Completion — Daily Journey Integrity. Out of scope: M10
Sprint 3, consent rows, IAP, BYO, Phase 3.2E as a science allocation.

## Systems explicitly untouched (this planning task)

Field Manual data and ACL (read-only confirm only) · Apollo/Spartan
manifests · founder phone · repo `.env` · consent relationship rows ·
`origin/main` (no push).
