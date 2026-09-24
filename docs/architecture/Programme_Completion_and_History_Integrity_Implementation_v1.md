# Programme Completion and History Integrity — implementation contract

**Status:** Local implementation contract for authorised Sprint 3.
**Parent:**
[`Complete_Athlete_Experience_Sprint_3_v1.md`](./Complete_Athlete_Experience_Sprint_3_v1.md)
**Base:** `origin/main` `8d7606d0c43b4b3b499dfbdc2f5ba9b0caa151ce`

```text
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
NEXT_IMPLEMENTATION_AUTHORISED=false
REPLACEMENT_TRANSACTION_AUTHORISED=false
PERFORMANCE_PORTFOLIO_AUTHORISED=false
HOSTED_APPLY=false
```

This contract is local implementation authority only. It does not
licence push, hosted apply, a replacement transaction, or marking
Sprint 3 complete.

---

## Assignment projection

Shared production read: `AthleteProgrammeContext`.

| Result | Meaning |
|--------|---------|
| `active` | `getActiveAssignment` returned `status = active` |
| `completed` | no active; most-recent `status = completed` |
| `none` | successful read; no active and no completed |
| `unavailable` | auth, network, repository, parse, or unsupported failure |

Active always wins. Completed is historical context, never execution
or enrolment authority. Enrolment still uses **only** the active row
and the existing no-active-programme RPC.

**Most-recent completed** is deterministic from persisted fields, in
order: `completed_at` desc, then `updated_at` desc, then `created_at`
desc, then `id` desc. Do not infer from UI or fixtures.

Reuse `listForAthlete` + `getActiveAssignment`. No new RPC or column.

## Continuity

Home, Calendar, Programmes, and Progress consume the same projection
plus existing `AthleteProgrammeContinuity`. Completed assignment
remains current historical context until a later active assignment
exists. Pin facts come only from the pinned version. Catalogue default
must not substitute. Unavailable pin and Sprint 2 timezone
repair-required remain fail-closed on **active** rows.

Calendar after complete calls existing
`resolve_fixed_programme_calendar(assignment_id)`. No Begin/Resume.
Later enrol switches current Calendar to the new active assignment
without rewriting completed history.

## Identity

Production athlete id: `AuthenticatedIdentity.requireAthleteId()`.
No `'athlete.local'`, display-name, cache, or previous-user fallback.
Coach-only does not authorise athlete Progress/History or
`AthleteAppShell`. Missing context fails closed. Tests/preview may
pass explicit fixture ids only.

Sign-out and account switch invalidate last-good Progress/History for
the previous athlete immediately.

## Error versus empty

Genuine empty = successful authoritative query with no qualifying
evidence. Loading, auth, repository, parse, and offline failures are
typed errors. Refresh failure keeps last-good in-memory data for the
**same** athlete and shows Retry. No new offline persistence.

## Home completed state

```text
Complete
You finished {authored programme title}.
Primary: View results  → existing History / completed evidence
Secondary: Browse programmes → existing discovery (enrol eligible)
```

No Begin/Resume. No first-run Choose Plan. No improvement or goal
claims. Hosted completion wins over stale local drafts.

## Non-goals

New completion mutation; replacement/repin; recommendations;
automatic next programme; Progress metric redesign; Performance
Portfolio; adaptation; payments; wearables; offline completion queue;
WOD Timer/Whiteboard; blue brand; hosted repair; schema/RPC changes.

## Acceptance gates

Parent architecture §11. Plus: production entry does not import the
fixture preview; no `athlete.local` on production athlete surfaces;
cross-surface matrix A–M from the implementation task.
