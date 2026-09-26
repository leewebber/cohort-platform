# Private programme publication and activation — implementation contract

**Status:** Authorised completion slice for the approved private-programme
architecture.
**Base:** `origin/main` `d7172391bc901f6d58511f26a0295679297dd69e`
**Branch:** `feat/private-programme-publication-activation-v1`
**Infrastructure:**
[`Private_Programme_Infrastructure_v1.md`](./Private_Programme_Infrastructure_v1.md)
**Programme:**
[`Lee_Bali_Hybrid_Base_Implementation_v1.md`](./Lee_Bali_Hybrid_Base_Implementation_v1.md)

```text
LEE_BALI_HYBRID_BASE=PRIVATE_PUBLICATION_ACTIVATION_IN_PROGRESS
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
BALI_HOSTED_PRIVATE_PUBLICATION=false
PRIVATE_PROGRAMME_INFRASTRUCTURE=HOSTED_APPLIED
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This slice privately publishes an exact authored Plan Package, lists it
only to the owning or entitled athlete, and lets that athlete activate it
with an explicit local start date after confirmation in the app. It is
not B2, not commercial HYROX Base, and not a public catalogue feature.

Do not embed athlete UUIDs in source or committed artifacts.

---

## Publication authority

Service-role-only RPC
`publish_private_exact_programme_version(payload jsonb)`.

The caller supplies a compiled Plan Package payload plus a publication
envelope. The envelope is required and validated:

| Field | Rule |
|-------|------|
| `publication_kind` | `private_exact_version` |
| `programme_version_id` | exact UUID |
| `library_scope` | `coach_private` or `organisation` |
| `owner_id` | UUID of the authorised owner, supplied operationally |
| `package_content_hash` | 64 lowercase hex, must match the compiled package |
| optional `authorised_timezone` / `authorised_local_start_date` | civil date + IANA name stored on the version |

The RPC:

- persists the exact version identity, lineage code, version number, hash,
  protocols, and 71 session slots when those are in the package
- sets `lifecycle_status = published`, `archived_at IS NULL`,
  `approved_for_global = FALSE`, `owner_type = coach`
- does not call `publish_cohort_global_programme_version`,
  `approve_cohort_global_programme_version`, or catalogue-default RPCs
- does not create catalogue rows or change catalogue defaults
- rejects global / draft / archived misuse
- is idempotent for the identical identity + hash + owner + scope
- fails closed on identity or hash conflict
- cannot overwrite an existing immutable version

Execute: `service_role` / owner `postgres` only. Revoke `PUBLIC`, `anon`,
and `authenticated`.

A repository-owned CLI verifies the compiled hash and approved
publication artifact before invoking the RPC with `--owner-id`.

---

## Discovery authority

Authenticated RPC `list_my_private_programme_versions()`.

Returns only published, non-archived, non-catalogue versions the caller
may activate: they own `owner_id` or have an active coach–athlete link to
the owning coach. The caller must be an athlete. Missing identity and
unrelated principals receive an empty list. Guessing a version ID through
this list cannot reveal another owner’s programme.

Athlete-facing fields only: version id, title, summary, duration,
schedule description, level/equipment when present, private
classification, start eligibility, authorised start date/timezone when
stored, and whether that version is already the caller’s active
assignment. No package hashes or engineering paths.

---

## Explicit start-date enrolment

Keep
`enrol_athlete_in_private_programme_version(uuid, text, boolean)`
unchanged (derives `started_at` from the invocation civil date).

Add overload
`enrol_athlete_in_private_programme_version(uuid, text, date, boolean)`.

The date is a civil date in the supplied IANA timezone and is stored as
`assignment.started_at`. Occurrence dates derive from that date. This
path is private-enrolment only. Catalogue enrolment is unchanged and
must not gain arbitrary backdating.

Idempotent retry: same athlete, version, timezone, and start date.
A conflicting date or timezone on the same version fails closed.

Approved Bali activation values (supplied by discovery + athlete
confirmation, not by hard-coded production UI identities):

- timezone `Asia/Makassar`
- local start date `2026-09-26`
- `replace_active = true`

---

## Athlete UI

Programmes → **My private programmes**. Hidden when the list is empty.
Activation requires an explicit review and confirmation. Cancel mutates
nothing. Success reloads authoritative assignment state. Failure retains
the current assignment and shows a typed error.

---

## Non-goals

No B2 pace work, Garmin, metrics profiles, commercial programme
authoring, public catalogue cards, or automatic assignment change.
