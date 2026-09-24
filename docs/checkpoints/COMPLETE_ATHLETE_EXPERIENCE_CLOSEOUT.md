# Complete Athlete Experience — closeout

**Recorded:** 2026-09-24

**Status:** Complete Athlete Experience is **complete**. This is a
documentation closeout of an already-integrated, founder-approved
milestone. It does **not** mean the entire Cohort product is complete or
launch-ready. The next sequenced product item is **launch programme
library**. Its implementation is **not** authorised.

```text
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
HOSTED_MIGRATION_APPLIED=true
SPRINT_2_HOSTED_MIGRATION_APPLIED=true
SPRINT_3_HOSTED_MIGRATION_APPLIED=true
NEXT_IMPLEMENTATION_AUTHORISED=false
CLOSEOUT_BASE=fc73ae0b0863127fc5b6e6a5b5d1e31c5fb25dac
HOSTED_TARGET=Cohort Field Manual
HOSTED_PROJECT_REF=otnhhdxstdnwccehacku
HOSTED_LEDGER_MAX=20260924120000
HOSTED_PENDING_MIGRATIONS=0
PUSHED=false
PHONE_UNTOUCHED=true
REPO_ENV_UNTOUCHED=true
NEXT_MILESTONE_STARTED=false
```

Binding:

- [`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md)
- [`../architecture/Athlete_Programme_Discovery_and_Decision_v1.md`](../architecture/Athlete_Programme_Discovery_and_Decision_v1.md)
- [`../architecture/Complete_Athlete_Experience_Sprint_2_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_2_v1.md)
- [`../architecture/Complete_Athlete_Experience_Sprint_3_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_3_v1.md)
- [`COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md`](./COMPLETE_ATHLETE_EXPERIENCE_AUDIT.md)
- [`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1_HANDOFF.md`](./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1_HANDOFF.md)
- [`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_HANDOFF.md`](./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_HANDOFF.md)
- [`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md`](./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2_AUDIT.md)
- [`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md`](./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md)
- [`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_HANDOFF.md`](./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_HANDOFF.md)
- [`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md)
- [`../planning/Delivery_Roadmap_v1.md`](../planning/Delivery_Roadmap_v1.md)

Historical sprint handoffs, audits, and stop reports remain evidence. Their
dated flags are not rewritten here.

---

## Purpose and founder-approved outcome

Complete Athlete Experience is the coherent production athlete journey
around the Daily Journey execution spine: discover authored programmes,
inspect facts, enrol into an exact published version, keep the assignment
pin, train on Home / Calendar / Daily Journey, complete the programme, and
keep completed evidence without rewriting history.

Founder approval covered architecture, production behaviour, visual review,
Sprint 3 integration onto `origin/main`, cleanup integration at `fc73ae0`,
and hosted apply of the two authorised Field Manual migrations. No further
visual iteration was required for Sprint 3.

This closeout records that the **milestone** is complete. It does not
declare Cohort launch-ready, commercially complete, or finished as a
product.

---

## Closeout base

| Item | Value |
|------|--------|
| Repository | `/Users/leewebber/Developer/cohort_platform` |
| Closeout base / `origin/main` at documentation start | `fc73ae0b0863127fc5b6e6a5b5d1e31c5fb25dac` |
| Includes | Approved Sprint 1–3 implementation plus cleanup `fix(journey): clean sprint three closeout evidence` |
| Worktree at start | clean |
| `.env` | hash verified; contents not read or printed |

---

## Sprint boundaries and status

| Sprint | Boundary | Integrated HEAD | Status |
|--------|----------|-----------------|--------|
| 1 Programme Discovery and Decision | Catalogue inspect/compare, enrol into an exact version, no replace/repin | `a3cd351` | **COMPLETE** |
| 2 Enrolment Start Integrity and Programme Continuity | IANA timezone, athlete-local `started_at`, pin vs catalogue default, no replacement transaction | `8405421` | **COMPLETE** |
| 3 Programme Completion and History Integrity | Completed Home / Calendar inspect / Programmes continuity, Progress failure vs empty, last-good, identity fail-closed | `8dcf58e` | **COMPLETE** |
| Closeout-readiness cleanup | Trailing-whitespace and unused-import evidence only | `fc73ae0` | **COMPLETE** (on `origin/main`) |

Sprint 3 implementation range on `8d7606d..8dcf58e` is linear (17 commits).
Cleanup `fc73ae0` is one linear commit on that HEAD.

---

## Hosted migrations

**Target:** Cohort Field Manual `otnhhdxstdnwccehacku` (`eu-west-1`).
Cohort Staging was not targeted.

| Version | File | SHA-256 | Hosted |
|---------|------|---------|--------|
| `20260923120000` | `supabase/migrations/20260923120000_enrolment_iana_timezone_and_local_start.sql` | `32e81d17a4b204ce182529e3142f1ad0f7163a33c274c83745ce0aa00bbbc9df` | applied |
| `20260924120000` | `supabase/migrations/20260924120000_completed_fixed_programme_calendar_inspection.sql` | `3df3970c7951c2b3b1bdfec81959a58dfb690f5c7711f2954d7c9b466f6a9f26` | applied |

Post-apply (SELECT / `migration list` / `db push --linked --dry-run` only):

- Both versions present; ledger max `20260924120000`; 98 versions
- Pending hosted migrations: **zero** (“Remote database is up to date.”)
- Enrolment RPC validates IANA names and derives `started_at` as
  `(now() AT TIME ZONE v_tz)::date` **before** INSERT; `invalid_timezone`
  fails closed
- `cohort_resolve_fixed_programme_calendar_at` accepts owned `active` or
  `completed`; completed path is inspection-only (`IF NOT v_completed`
  around ensure/reconcile); success includes `assignment_status`
- `resolve_active_fixed_programme_calendar` remains active-only
- Intended grants preserved: inner `_at` helper EXECUTE postgres /
  service_role only; athlete wrappers and enrolment EXECUTE authenticated
  (+ postgres / service_role); no anon/PUBLIC EXECUTE
- Missing identity and non-athlete identity fail closed in the live
  function text; foreign assignment remains `assignment_not_found`
- No hosted athlete, assignment, occurrence, session, outcome, profile, or
  catalogue **data repair**

---

## Final athlete journey now supported

An authenticated athlete can:

1. Discover authored programmes
2. Inspect and compare programme facts
3. Enrol into an exact published version
4. Choose a validated training timezone
5. Preserve the assignment pin
6. Execute through Home, Calendar, and Daily Journey
7. Complete the final session
8. Retain completed programme, Calendar, Progress, and History evidence
9. Enrol into a later programme without rewriting completed history
10. Fail closed for missing or non-athlete identity

---

## Verification evidence (already accepted)

This closeout does **not** rerun the full Flutter suite. Cite the approved
implementation-head result at Sprint 3 integration HEAD `8dcf58e`:
**3247 passed, 6 skipped, 0 failed**. Cleanup `fc73ae0` was mechanical
documentation/import-only.

This documentation task reran the focused production-entry and Complete
Athlete Experience agreement set
(`test/auth/production_entry_scan_test.dart`,
`test/programme/programme_completion_history_integrity_test.dart`,
`test/programme/completion_history_preview_states_test.dart`,
`test/programme/athlete_programme_discovery_decision_test.dart`,
`test/programme/enrolment_iana_timezone_test.dart`): **54 passed**.
The Phase 2 consolidation safety gate passed
(`PHASE2_CONSOLIDATION_SAFETY_GATE=PASS`, 6/6 groups).

Sprint handoffs and integration reports remain the detailed evidence:

- Sprint 1 / 2 / 3 audits and handoffs linked above
- Local DB gates including Gate BA (completed calendar inspection)
- Hosted apply transcript (two-file exact set; no repair / reset / DML)

---

## Explicit non-actions and exclusions

This closeout did not:

- Change Dart, SQL, migrations, tests, fixtures, dependencies, native
  files, configuration, or hosted systems
- Push this documentation commit
- Contact Field Manual, the founder phone, or start another milestone

These items were **not** delivered by Complete Athlete Experience and
remain future work. Do not treat them as implied:

- Replacement transaction and mid-programme switching
- Automatic repin or version upgrade
- Timezone repair of historical abbreviation/offset rows
- Active-programme travel rescheduling
- Progress metric redesign / Performance Portfolio
- WOD Timer / Whiteboard
- Adaptation and matching
- Payments
- Wearables
- Android and broader device hardening
- Offline completion queue
- Blue-brand redesign
- Beta and launch work

No later milestone has started. Starting one requires a new
audit/architecture decision and explicit founder approval.

---

## Live flags

```text
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
HOSTED_MIGRATION_APPLIED=true
SPRINT_2_HOSTED_MIGRATION_APPLIED=true
SPRINT_3_HOSTED_MIGRATION_APPLIED=true
NEXT_IMPLEMENTATION_AUTHORISED=false
```
