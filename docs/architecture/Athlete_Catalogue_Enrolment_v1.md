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
