# M1.2 — normal onboarding and private-free acquisition

2026-10-26. Authorised implementation from published main
`2a0957fe48c738b048e273c852bb1a4359829be0` under the
[controlling M0–M10 plan](../../planning/Founder_Release_Plan_M0_M10_v1.md).

Trace: main → AuthGate/profile provisioning → AthleteAppShell → Programmes →
selection/detail. Existing private list is owner/coach-relationship scoped and its
activation screen always requests replacement. The catalogue excludes private versions.
Existing private enrolment serialises per athlete, pins the version, materialises and
ensures the canonical schedule atomically. The legacy onboarding wizard generates a
programme and is unsuitable for this authored-programme journey.

Bounded decision: persist only the training timezone (draft then confirmed) against the
authenticated athlete. Display name/roles already belong to account setup. No compulsory
benchmarks, goals, health data, generated prescription or matching system. A new closed
operator-managed exact athlete/version eligibility table supports free private alpha
access, optionally expiring/revocable. Eligibility is not enrolment; the existing assignment
is the acquired exact-version record. No coupons, billing, invitation or subscription system.
New authenticated RPCs read eligible v1/v2 facts and acquire via existing private enrolment
with replacement always false. New eligibility applies only after completed onboarding;
legacy ownership/coach-relationship authority remains unchanged. A transaction-local exact-recipient/version guard permits delegated enrolment only inside the no-replacement acquisition wrapper; new recipients cannot use legacy replacement-capable RPCs. No broad table grants.

Normal authenticated setup gates athlete entry, including the founder's athlete-shell
entry. Programmes/catalogue provide private programme detail/free acquisition and schedule
navigation; generic denied, expired-session, unavailable and empty states remain distinct.
Identity generations discard late async results after logout/account changes. Profile
provision retries retain existing profiles rather than overwrite or duplicate them.

Proof: labelled synthetic content through the same retained publisher, GoTrue-issued
sessions, PostgREST/RLS/RPC and canonical assignment/calendar; draft/complete restart,
foreign account/guessed ID, expiry/revocation, races, existing active assignment, rollback,
logout/switch and partial-response retry. Focused Flutter/widget tests, fresh before/after
analysis and required consolidation safety gate. No hosted apply/publication/accounts,
athlete data, device distribution or browser/app control. Hybrid10K/father content remains
missing (M1.1); complete real-programme continuity/benchmark adoption remains separate.
