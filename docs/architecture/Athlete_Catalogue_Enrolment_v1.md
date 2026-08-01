# Athlete Catalogue Enrolment v1 — Sprint 1.3

**Status:** Binding for Sprint 1.3  
**Depends on:** Sprint 1.2 authenticated catalogue read contract  
(`docs/architecture/Authored_Plan_Package_v1.md`)

---

## User outcome

An authenticated athlete can:

1. Browse eligible Cohort Global catalogue programmes
2. Inspect programme metadata needed to choose
3. Enrol in one exact immutable published programme version
4. See their current enrolment / programme access state

This is **non-commercial test / closed-beta enrolment** for Self-Test 1 and
approved closed-beta users. It is **not** a purchase, ownership grant, or
subscription.

---

## Exact version binding

Enrolment always pins `programme_assignments.programme_version_id` to one
specific `programme_versions.id`.

It must **never** mean “latest version of this lineage.”

---

## Entity

Sprint 1.3 extends existing `programme_assignments` rather than introducing a
competing commerce table.

| Field | Role |
|-------|------|
| `athlete_id` | Owner (`auth.uid()`) |
| `programme_version_id` | Exact immutable version pin |
| `lineage_code` | Denormalised lineage code |
| `status` | `active` / `paused` / `completed` / `reassigned` |
| `enrolment_source` | How access was authorised |
| cursor fields | Existing programme cursor (not materialised prepared session) |

`enrolment_source` values:

- `non_commercial_test` — Sprint 1.3 athlete catalogue RPC
- `coach_assigned` / `dual_role_self` — reserved labels
- `NULL` — pre-Sprint-1.3 or unspecified

`enrolment_source` is **not** a payment, transaction, or subscription record.

---

## Eligibility

A version is catalogue-eligible when all are true:

- `lifecycle_status = 'published'`
- `library_scope = 'cohort_global'`
- `owner_type = 'global'`
- `approved_for_global = TRUE`
- `archived_at IS NULL`

Matches the Sprint 1.2 catalogue RLS contract. Draft, unapproved, and
non-`cohort_global` versions cannot be enrolled.

---

## RPC boundary

`enrol_athlete_in_catalogue_programme_version(p_programme_version_id, p_timezone, p_replace_active)`

- `SECURITY DEFINER` with `search_path = public, pg_temp`
- Athlete identity from `auth.uid()` only (caller cannot nominate another athlete)
- Re-checks eligibility server-side
- `EXECUTE` granted to `authenticated` (and `service_role`); revoked from `anon` / `PUBLIC`
- Idempotent: active enrolment on the same version → `already_enrolled`
- Different active version without replace → `conflict`
- Sets `enrolment_source = 'non_commercial_test'`

No broad authenticated `INSERT` policy is added on `programme_assignments` for
athlete-only clients. Catalogue enrolment uses the RPC.

Import / publish / approve RPCs remain `service_role` only (Sprint 1.2).

---

## Non-commercial authorisation seam

`cohort_athlete_may_use_non_commercial_catalogue_enrolment()`

Temporary Sprint 1.3 gate: authenticated athlete role may enrol without payment.

**Directional future model (not implemented, not fully specified):**

1. A commercial access system confirms valid entitlement (likely recurring subscription)
2. That entitlement authorises catalogue access
3. Athlete chooses a programme
4. Cohort enrols them in one exact version (this contract)
5. A later system materialises an executable athlete plan

No prices, tiers, billing periods, programme limits, trials, cancellation,
expiry, App Store vs web billing, or payment-provider choice are decided here.

---

## Future athlete-plan materialisation handoff

Successful enrolment yields:

- `athlete_id`
- exact `programme_version_id`
- `enrolment_id` (`programme_assignments.id`)
- optional `lineage_code`
- `enrolment_source`

Dart type: `AthletePlanMaterialisationHandoff`

Materialisation (prepared session / executable plan) is **out of Sprint 1.3**.
It must consume the exact enrolled version and must not require payment-provider
details.

---

## Explicitly deferred

- Stripe / any payment provider
- Checkout, receipts, refunds, subscription management
- Prices and pricing UI
- Fake subscription / purchase / transaction records
- Per-programme ownership concepts
- Athlete-plan materialisation
- Prepared-session creation / first-session execution changes
- Adaptation, progression dashboards, wearables

---

## Athlete entry points

1. Home → muted **Programme** link (always)
2. Home empty state → **VIEW PROGRAMMES** (when no active plan)
3. Programme screen → muted **View programmes**
4. Selection → confirm → `enrol_athlete_in_catalogue_programme_version`
5. Today refresh via `HomeTodaySessionRefreshController` when wired

Legacy Plan Library remains on the shell **Plans** tab; it is not the
Sprint 1.3 catalogue enrolment path.

---

## UI language

Use: View programme, Choose programme, Enrol, Enrolled, Your programmes,
Programme access.

Avoid: Buy, Purchase, Owned, Order, Checkout, Payment complete, Your purchase.

---

## Cohort Staging verification fixtures (non-production)

Synthetic fixtures may remain in **Cohort Staging** for Sprint 1.3 regression
and Self-Test 1. They are **not** customers, payments, or production content.
They must **never** be copied to production.

Namespace / run label: `s13_stage_20260801T022309Z`  
Display label namespace: `S13-STAGING-FIXTURE`

### Synthetic athletes

| Label | Display name | Purpose |
|-------|--------------|---------|
| Athlete A | `S13 Staging Athlete A` | Catalogue visibility, enrol, idempotency, UI journey |
| Athlete B | `S13 Staging Athlete B` | Cross-athlete isolation + independent enrol |

Emails use the run namespace and `@example.invalid`. Credentials are stored
**outside the repository** (operator secret store / local temp only). Never
commit passwords or tokens.

Stable non-sensitive profile ids (staging only):

- Athlete A: `f55719cd-9721-48af-895c-c5547f8d0ec2`
- Athlete B: `1e268186-281a-464a-b2a4-da2d2cde33ba`

### Programme fixtures

| State | Lineage `code` | Role |
|-------|----------------|------|
| Eligible | `PROG-S13-ELIG` | Published, `cohort_global`, approved — positive catalogue + enrol |
| Draft | `PROG-S13-DRAFT` | Draft denial |
| Unapproved | `PROG-S13-UNAPP` | Published but not approved — denial |
| Private / wrong scope | `PROG-S13-PRIV` | `coach_private` published — denial |

Stable non-sensitive version ids (staging only):

- Eligible: `e9bd7e19-6eb9-4f7e-abf6-d08ac4368748`
- Draft: `0a0c8e5b-13cf-4633-b982-cd59b0524c23`
- Unapproved: `9ea3e34b-e2b3-4cd7-b6af-5af00498f01d`
- Private: `ff107a53-19e2-5996-b144-a498be3d9b1e`

Session prerequisite lineage/protocol used for package import:
`PROT-S13-STAGING-1` (synthetic staging session content only).

Eligible enrolment uses `enrolment_source = non_commercial_test` and does
**not** create payments, ownership, subscriptions, or executable athlete plans.

### Creation method

1. Positively confirm Supabase CLI is linked to **Cohort Staging**
   (`ACTIVE_HEALTHY`; production not linked).
2. Create two Auth users + athlete-only `profiles` via Admin Auth API
   (service role for fixture setup only; never in Flutter client).
3. Author minimal Plan Packages through official import → publish / approve
   workflows for the eligible case; leave draft / unapproved / private in
   their denial states on separate lineages.
4. Do not invent catalogue rows that bypass validation.

### Validate / recreate

- Presence check (fail-closed staging guard):

```bash
CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh --dry-run
CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh
```

- Flutter UI against staging (temporary staging `.env` with anon key only;
  overwrite stub `lib/s13_staging_secrets.g.dart` then restore; never commit
  secrets):

```bash
flutter run -d chrome -t lib/main_s13_staging_verify.dart
```

Opt-in integration test (device/desktop target): set `S13_STAGING_UI=1` plus
external `S13_CREDS_FILE` / `S13_IDS_FILE`.
