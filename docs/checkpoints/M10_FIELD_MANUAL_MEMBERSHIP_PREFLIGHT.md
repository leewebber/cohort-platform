# M10 Field Manual membership rollout preflight

**Recorded:** 2026-09-19

**Status:** Read-only Field Manual preflight. Hosted migrations, invitations,
memberships, and audit events were **not** applied or created.

```text
M10_FIELD_MANUAL_MEMBERSHIP_PREFLIGHT_COMPLETE=true
HOSTED_TARGET=Cohort Field Manual
HOSTED_PROJECT_REF=otnhhdxstdnwccehacku
HOSTED_REGION=eu-west-1
HOSTED_HEALTH=ACTIVE_HEALTHY
HOSTED_PG=17.6
HOSTED_LEDGER_COUNT=90
HOSTED_LEDGER_MAX=20260918120400
M10_MIGRATIONS_HOSTED=absent
M10_RELATIONSHIP_TABLES_HOSTED=absent
SCHEMA_COMPATIBILITY=compatible
CONFLICTING_PREREQUISITE=false
IDENTITY_CHAIN=exact_match
ZERO_INFERENCE=true
LEGACY_COACH_ATHLETE_ROWS=0
HOSTED_MUTATIONS=0
NOTHING_PUSHED=true
PHONE_UNTOUCHED=true
REPO_ENV_UNTOUCHED=true
M10_SPRINT_3_STARTED=false
NEXT_TASK_IMPLEMENTATION_AUTHORISED=false
```

Binding:
[`../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md`](../architecture/M10_Athlete_Coach_Management_and_Isolation_v1.md)
§17,
[`M10_SPRINT_2_HANDOFF.md`](./M10_SPRINT_2_HANDOFF.md),
[`M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](./M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md).

This document does **not** authorise hosted apply, consent smoke tests,
backfill, manifest mutation, or Sprint 3.

---

## A. Repository verification

| Item | Value |
|------|--------|
| Branch | `chore/m10-field-manual-membership-preflight` |
| HEAD at start | `706b730c6a8b6b07bb5487c551080fea0f4d5a9c` |
| Fetched `origin/main` | same SHA; worktree began clean |
| Repo migration-chain maximum | `20260919120400_publisher_athlete_membership_capabilities.sql` |
| Historical migrations vs `origin/main` | unchanged |
| Repo `.env` SHA-256 | `869a01b1e4ee6b0559face678843f0df9ce57cbaf30febadb90f796c2a161816` |

### Candidate hashes (match approved)

| File | SHA-256 |
|------|---------|
| `20260919120000_publisher_athlete_membership_core.sql` | `2390502a7395c960099ddc9ab8aba2551552ed310991c58cf096563e400d22ee` |
| `20260919120100_publisher_athlete_membership_rpcs.sql` | `8371e27f5538d00f8991a8cf3a826b5e8b60b326c21a783f299bf93fdae40309` |
| `20260919120200_publisher_athlete_roster_projection.sql` | `b8f8d37e5915f00e4508eaddcde2a8622c9d2796c61d0f82a1e33def186e4697` |
| `20260919120300_publisher_athlete_membership_rls.sql` | `46dc29a36120ca8c2e0020799267fb374caf7bd8d7dceb686c17efba583c41d9` |
| `20260919120400_publisher_athlete_membership_capabilities.sql` | `1478e9b0a7b34133d24569ddff0a1cfd2cdd3374adb0bc3e665da73a136bda12` |

No Lee / Apollo / Spartan / Field Manual UUIDs in the five files. No
migration-time `INSERT` into M10 tables in `120000` (schema only). Runtime
`INSERT`s exist only inside transactional RPCs in `120100` and are not
executed by `supabase db push` of DDL. No assignment/enrolment/manifest
writes. No trigger on `programme_assignments`.

---

## B. Hosted target

Proven via `supabase projects list` plus Management API
`/database/query` **SELECT-only** (Supabase CLI keychain). Disposable
workdir link was attempted; IPv6 pooler is unsupported on this network, so
SQL used the same operational query path as
`tool/content_graph/verify_hosted_published_artifacts.sh`. Repo
`supabase/.temp` was not written. Staging `tsbadngzgvsyfqjupkng` is
`INACTIVE` and was not queried for inventory beyond identity.

| Field | Value |
|-------|--------|
| Name | Cohort Field Manual |
| Project ref | `otnhhdxstdnwccehacku` |
| Region | `eu-west-1` |
| Health | `ACTIVE_HEALTHY` |
| PostgreSQL | `17.6` (CLI project report `17.6.1.155`) |
| Ledger | `supabase_migrations.schema_migrations` — **90** versions, min `20260713140000`, max **`20260918120400`** |
| M10 five versions | **all absent** |
| M10 tables/view | **absent** (`invitations`, `memberships`, `events`, `roster`) |

Matches the expected M9 closeout baseline.

---

## C. Identity and schema compatibility

**Identity chain:** `auth.users.id` = `profiles.id` = `programme_assignments.athlete_id` (all UUID).

| Check | Result |
|-------|--------|
| Profiles missing from `auth.users` | **0** |
| Assignments with orphan athlete | **0** |
| Assignments with orphan version | **0** |
| Principals with orphan profile | **0** |
| Assignment athlete FK | `FOREIGN KEY (athlete_id) REFERENCES profiles(id) ON DELETE RESTRICT` |

`profiles` hosted columns used as identity: `id` (uuid), `display_name` (text),
`is_athlete`, `is_coach`. **No email or phone column** on `profiles`. Display
name is already readable under `profiles_select_own` /
`profiles_select_linked_users`. M10 selects that same `display_name` only
after active membership; it is not an identity key.

### Compatibility matrix

| Assumption | Verdict | Notes |
|------------|---------|-------|
| `content_publishers.id` UUID; lifecycle `active\|retired` | exact match | 1 row, `cohort_global`, first-party, active |
| `content_publisher_principals.principal_id` UUID | exact match | 1 owner principal |
| `content_graph_publisher_may_operate` | exact match | active principal + active publisher; service role elevated |
| `content_graph_manifests` join on `programme_version_id` + `publisher_id` | exact match | 2 published rows; composites match committed artifacts |
| `programme_assignments.programme_version_id` UUID NOT NULL pin | exact match | one active Apollo v2 pin |
| Assignment status vocab `active\|paused\|completed\|reassigned` | exact match | M10 reads `status = 'active'` only |
| `profiles.id` UUID FK target | exact match | M10 `athlete_id` / `invited_by` |
| `cohort_auth_is_athlete` / `cohort_auth_is_coach` | exact match | present; coach-alone is not M10 authority |
| `enrol_athlete_in_catalogue_programme_version` | exact match | present; **not** modified by M10 |
| Capability RPC | compatible variation | hosted **schema_version 2**; `120400` replaces with **3** additively |
| `cohort_publisher_athlete_*` RPCs / M10 tables | missing prerequisite (additive) | expected |
| `coach_athlete_relationships` / `coach_athlete_invites` | unexpected hosted-only object (legacy) | tables exist; **0 rows**; not referenced by M10 |
| `accept_coach_athlete_invite` | unexpected hosted-only object (legacy) | V2.0 path; M10 does not call it |
| Migration ledger timestamps | exact match | `schema_migrations.version` text timestamps |

**No conflicting prerequisite. Stop condition not met.**

---

## D. Existing relationship inventory (identifier-safe)

### Profiles (2)

| Class | n |
|-------|---|
| Total | 2 |
| `is_athlete` | 2 |
| `is_coach` | 1 |
| athlete ∧ coach | 1 |
| Athletes with no active assignment | 1 |

The coach is the `cohort_global` owner principal (`principal_is_coach = true`).
There is **no** hosted coach-only user who lacks a principal.

### Programme assignments

| Status | n |
|--------|---|
| active | **1** |
| other | 0 |

That single assignment is lineage `APOLLO-BUILD-12-WEEK`, pin
`2ba018bd-7dc2-4dfd-8d8e-e35823158920` (Apollo v2), status `active`. The
subject profile is both athlete and coach. This is **programme enrolment
only**. M10 membership tables do not exist, so it cannot be a management
membership.

Spartan v3 (`32986922-47d1-46b0-b391-a7931d73033e`) is catalogued and
manifested; it has **no** assignment.

### Catalogue / M9

| Object | n / state |
|--------|-----------|
| `content_publishers` | 1 (`cohort_global`, active, first-party) |
| Principals | 1 (`owner`) |
| Manifests | 2 published |
| Reconstruction jobs | 0 |
| Eligible published `cohort_global` versions | 2 |
| Programme versions (all) | 9 |

Apollo composite
`481956c3277f4666ae80766c65e114b69aaf982758917e3de05ca5f8b9157b12`
and Spartan composite
`8c5989bd8ba360294cb619e721213a94fe19302387f7bf8008c203bfb5538d17`
match
[`M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](./M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md)
and committed publication JSON. Source hashes remain Apollo
`81033429…dd0b83` and Spartan `b4bfaab4…473e`.

### Legacy V2.0 coach-athlete

| Table | rows |
|-------|------|
| `coach_athlete_relationships` | **0** |
| `coach_athlete_invites` | **0** |

### Proofs required before migration

| Claim | Proof |
|-------|-------|
| Lee’s Apollo assignment exists | 1 active pin to Apollo v2 |
| It is a programme relationship only | lives in `programme_assignments`; no M10 tables |
| Not a publisher-management membership | M10 objects absent |
| `cohort_global` cannot roster Lee from Apollo use | roster view/RPC absent; after apply, roster requires **active membership**, which migrations do not create |
| Unrelated athlete not implicitly visible | 1 athlete with no active assignment; no membership rows possible |
| Coach role ≠ publisher roster authority | M10 inspect requires `content_graph_publisher_may_operate` **and** active membership; coach-only Gate AY denies invite |

Checkpoint hashes (non-secret):

| Aggregate | md5 |
|-----------|-----|
| publishers | `8fb1b7a6e051f04032c016cedc05fee8` |
| manifests | `91159777d2942f473a1e8b0494e184dd` |
| assignment pins | `e2e3a469d24711560799df8203722198` |

Other counts: training_sessions 36, occurrences 84, slot_outcomes 8,
session_records 13.

---

## E. Consent-boundary static audit

| Rule | Proof |
|------|-------|
| Apply inserts 0 invitations/memberships/events | `120000` has no `INSERT INTO public.publisher_athlete_*`; later files are functions/views/RLS/caps |
| No assignment-watch trigger | no trigger on `programme_assignments` in M10 files |
| Enrolment RPC unmodified | M10 does not `CREATE OR REPLACE` `enrol_athlete_in_catalogue_programme_version` |
| No catalogue/manifest/assignment mutation | no `INSERT`/`UPDATE`/`DELETE` on those tables |
| No coach-role fallback | invite/roster use `content_graph_publisher_may_operate`, not `cohort_auth_is_coach` |
| Pending grants no roster | `inspect_roster` filters `membership_state = 'active'` only |
| Only target athlete accepts/declines | `athlete_id IS DISTINCT FROM auth.uid()` → `unauthorised` |
| Publisher cannot activate | no publisher accept path; accept is athlete-only |
| Direct table writes denied | `WITH CHECK (FALSE)` / `USING (FALSE)` for INSERT/UPDATE/DELETE |
| Capability keys ≠ data access | caps are a probe; RLS/RPC still require uid + principal/membership |

v1 invitation target is an existing `profiles.id`. No email search, token, or
account-existence oracle.

---

## F. Roster projection

Security-invoker view `publisher_athlete_roster` columns returned to
publisher clients (via `inspect_roster` after **active** membership):

| Column | When visible |
|--------|----------------|
| `membership_id` | always (active row) |
| `publisher_id` | managing publisher |
| `athlete_id` | canonical profile id |
| `athlete_display_name` | existing profile policy field |
| `membership_state` | `active` on this projection |
| `activated_at` / `revoked_at` | membership dates |
| `assignment_visibility` | `none` / `own` / `foreign_hidden` |
| `assignment_id` | only if `own` |
| `programme_version_id` | only if `own` (immutable pin) |
| `programme_version_name` | only if `own` |
| `programme_version_lifecycle` | only if `own` (retired pin stays factual) |
| `graph_status` | `missing` or `published` when `own`; null when hidden/none |
| `graph_composite_identity` | only if `own` and published manifest matches publisher + version |

**Not selected:** email, phone, auth/provider metadata, health, recovery,
wearables, notes, result trees, other-publisher memberships, foreign pin /
title / version / publisher / composite.

Own-publisher join is exact (`content_graph_manifests.programme_version_id`
AND `publisher_id`, or first-party `library_scope = cohort_global`). Foreign
assignment sets `foreign_hidden` and nulls enrichment columns. Missing
assignment → `none`. Domain layer can mark a declared composite `stale`;
SQL does not fall back to title matching or assignment-count identity.

---

## G. CoachAthleteService isolation

| Question | Finding |
|----------|---------|
| Storage | `coach_athlete_relationships`, `coach_athlete_invites`, RPC `accept_coach_athlete_invite` |
| Field Manual rows | **0 / 0** |
| RLS | coach/athlete SELECT on the **legacy** tables only |
| M10 calls legacy? | **No** (`lib/domain/athlete_coach_isolation` has no import) |
| Legacy rows satisfy M10? | **No** — M10 reads only `publisher_athlete_*` |
| Dual exposure today | **No** — legacy empty; M10 absent |

**Verdict:** legacy remains a separate, unused hosted authority. It cannot
bypass M10 isolation after schema-only apply. No backfill is proposed.

---

## H. Local production-shaped simulation

Executed via `./supabase/tests/run_local_db_gate.sh` (fresh reset +
upgrade/reapply + **Gate AY**), not against Field Manual.

Generic UUIDs only (`e0000001-…`). No hosted Lee / Apollo / Spartan ids.

| Step | Result |
|------|--------|
| Hosted-shaped ledger then M10 files | local chain includes M9 then `19120000`–`19120400` |
| Zero M10 rows at migrate | Gate AY first assertions |
| Assignment ≠ roster | pending invite → roster `empty` |
| Coach-only invite | `unauthorised` |
| Accept → roster `ready` | yes |
| Double accept | `already_active` |
| Athlete revoke | roster returns `empty`; `already_revoked` |
| Reapply | second pass of the same gate |
| Pins/manifests | M10 RPCs do not write assignments or manifests |

---

## I. RLS simulation (local Gate AY + SQL)

| Actor | Result |
|-------|--------|
| Anonymous | `auth.uid()` null → RPC `unauthorised`; table REVOKE from `anon` |
| Athlete | accept/decline/revoke own; inspect own memberships/audit; cannot inspect another publisher’s roster |
| Publisher principal | invite/cancel/roster own namespace after accept; cannot accept for athlete; cross-publisher roster `unauthorised` |
| Inactive principal/publisher | `principal_inactive` / `publisher_inactive` |
| Coach-only | invite `unauthorised` |
| Service role | `content_graph_publisher_may_operate` true — **explicit elevated path only**; not granted to `anon` |

SECURITY DEFINER RPCs set `search_path = public, pg_temp`, owned by
`postgres`. Client EXECUTE is `authenticated` only. Internal expire/record
helpers are revoked from `PUBLIC`/`anon`. Roster view is
`security_invoker = true`.

---

## J. Capability / build 7

Hosted today: `cohort_athlete_runtime_capabilities` **schema_version 2**,
postgres, SECURITY DEFINER. After `120400`: version **3** with
`publisher_athlete_membership_read|invite|manage`.

Before any membership (schema-only apply):

| Actor | Expected |
|-------|----------|
| Lee (founder principal, not solely athlete) | invite/manage/read **true** from principal authority; **roster empty** (no consent rows) |
| Ordinary athlete | membership read/manage true if `cohort_auth_is_athlete`; invite **false** |
| Anonymous | `authentication_required` |

Build 7 (`1.0.0+7`): unknown JSON keys ignored; Dart maps absent keys to
`false`. Home / Calendar / Programmes / Progress / workout do not start
M10 RPCs. No startup path inserts relationships.

---

## K. Performance / query

Indexed predicates (created by `120000`):

- unique pending invitation `(publisher_id, athlete_id) WHERE pending`
- unique active membership `(publisher_id, athlete_id) WHERE active`
- publisher roster `(publisher_id, activated_at DESC) WHERE active`
- athlete memberships `(athlete_id, activated_at DESC)`
- athlete pending inbox `(athlete_id, invited_at DESC) WHERE pending`
- publisher invitation list `(publisher_id, invited_at DESC)`
- audit idempotency `(request_id, transition)` where request_id present

Roster enrichment is two `LEFT JOIN LATERAL … LIMIT 1` lookups (latest
active assignment, latest published manifest for **that** publisher +
version). No `canonical_payload` / result-tree scan. Pagination: `limit`
clamped 1–200, `offset >= 0`, `ORDER BY activated_at DESC` /
`invited_at DESC` / `created_at DESC`.

---

## L. Secure checkpoint (no secrets)

| Item | Value |
|------|-------|
| Target | Cohort Field Manual / `otnhhdxstdnwccehacku` / eu-west-1 / ACTIVE_HEALTHY / PG 17.6 |
| Ledger | 90 versions, max `20260918120400` |
| M10 objects/rows | absent / n/a |
| Publishers / principals / manifests / jobs | 1 / 1 / 2 / 0 |
| Assignments | 1 active Apollo v2 |
| Legacy coach-athlete | 0 + 0 |
| Capability | schema_version 2 |
| Training | 36 sessions, 84 occurrences, 8 slot outcomes, 13 records |
| Post-migration expected rows | invitations 0, memberships 0, events 0 |

### Recovery (do not execute)

New objects: three tables, roster view, helper/RPCs, RLS policies,
capability function replacement.

Reverse-drop order if a founder-authorised abort is required **before any
consent rows exist**: `120400` (restore v2 caps by re-applying
`20260918120300` capability body or forward-replace), then revoke/drop
`cohort_publisher_athlete_*` / view / tables. **Never drop**
`profiles`, assignments, programmes, manifests, or training tables.

Ledger: after a successful apply, five versions appear. Leaving objects
while repairing ledger is unsafe. Prefer **forward repair** of DDL if a
file fails mid-apply. Schema-only apply creates **no** memberships, so no
membership cleanup is required.

Stop if: ledger max ≠ `20260918120400` before start; any M10 version
already present; invitation/membership/audit count ≠ 0 after any file;
publisher/manifest/assignment hashes change; pin rewrite detected.

---

## M. Proposed hosted rollout (not executed)

### Phase 1 — schema only (next authorised task)

1. Re-verify target, ledger 90 / max `20260918120400`, file hashes.
2. Apply the five files **individually** in timestamp order.
3. After each: confirm version in `schema_migrations`; M10 row counts = 0.
4. After all five: invitations/memberships/events = 0.
5. As founder principal, `inspect_roster(cohort_global)` → `empty`.
6. Confirm Apollo assignment pin unchanged; two manifests unchanged;
   capability schema_version = 3.
7. **Stop.**

### Phase 2 — later consent smoke (separate authority)

Must use a designated **non-production** test athlete, or a separately
authorised relationship. **Must not** use Lee’s production Apollo
assignment without explicit founder consent. Invitation, acceptance, and
revocation each need their own authorisation. **No backfill.**

---

## N. Permission boundaries

Do not: apply hosted DDL from this document alone; create hosted
invitations/memberships; infer membership from Apollo use; modify
manifests; repin assignments; push this branch; rebuild the phone; start
Sprint 3.

---

## O. Blockers

**None.** Compatibility is exact, compatible, or expected-missing. Legacy
coach-athlete cannot bypass M10. Hashes match the approved Sprint 2
commit.
