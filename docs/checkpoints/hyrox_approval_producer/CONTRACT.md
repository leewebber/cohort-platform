# Durable Founder approval and delivery — local extension v1

This extension implements an upstream producer **inside the established trusted backend**.
It extends the [existing receiver contract](../hyrox_v3_http/CONTRACT.md); it does not turn
its old external-source adapter, catalogue or Git inputs into authenticated approval.
No existing canonical retention/admission/start function or previous migration is changed.

## Trust chain and authenticated actions

Prior Founder content decisions and the 27 approved templates / 29 labels / 48 proposed
session graphs are pending inputs. IDs, exact retained versions and real graph/artifact
bindings remain unresolved. A future publication operator must first complete those
inputs through the existing trusted identity/source boundary. This implementation assigns
new **event UUIDs only**; it cannot invent exercise identities, versions or source history.

All new routes are POST `/v1/founder/publication-approvals/{action}`. They verify the current
user through Supabase `/auth/v1/user` and the unchanged server-owned Founder allowlist,
**before reading a body or accessing the store**. Profile roles, user metadata, ordinary
service tokens, capability tokens and submitted Founder/approval fields are insufficient.
The server supplies `p_actor` from the verified identity; no request may supply it.

| Action | Exact JSON keys | Effect |
|---|---|---|
| `prepare` | `request_id`, `kind`, `input` | Backend reserves a new event UUID and proposed publication metadata; stores immutable exact draft and artifact digest; no approval or delivery |
| `review` | `event_id` | Same preparing Founder can reopen the complete artifact, digest, prepared time and approval state |
| `approve` | `event_id`, `artifact_sha256` | Explicit new authenticated approval, requiring the exact immutable review digest and same Founder; atomically inserts an immutable approval/event record and one pending outbox row |
| `pending` | none (`{}`) | Lists at most 100 not-delivered events for that Founder, oldest first, with persistent state/attempt/backoff/lease metadata |
| `deliver` | `event_id` | Claims a fenced lease, re-enters the existing Founder-authenticated receiver with the same session and ID only, then records a safe acknowledgement or retry/block state |
| `retry` | `event_id`, `artifact_sha256` | Explicit review of a blocked event; same owner/exact approved digest, requeues the **same** event without changing approval/source or resetting attempt history |

Only `prepare` admits a larger body (2 MiB); other bodies are limited to 256 bytes.
Wrong keys, self-asserted actor/status/proof, invalid types/IDs and content types refuse.
All responses are no-store. Route-class/status/timing logging excludes event IDs, payloads,
credentials and approval/source details. The prepared digest is the existing canonical
JSON SHA-256 of the **complete artifact**, including exact source/canonical-text strings.
Preparation retries require the same request UUID, owner, kind and exact input; changed
input conflicts. Approval retries do not duplicate events, reset leases or requeue delivered
work; their response includes actual current `delivery_state`.

## Prepared inputs and exact records

- `exercise_published`: `input` has exactly `canonical_text` and `approved_binding_kinds`.
  Text is canonical JSON of a Founder-owned **draft** with explicitly assigned `EX-*` ID
  and exact string version; `published_at` must be absent. Null candidate IDs/versions
  refuse. SQL preserves content/version, reserves its own proposed publication timestamp,
  sets the final lifecycle metadata and generates the publication event/reference. Founder
  then reviews **these final bytes** before approval. The reserved timestamp is preparation
  metadata until that explicit action; it is not evidence of a past publication. Full
  canonical definition/catalogue/kind validation still occurs at existing retention.
- `exercise_retired`: `input` has only `publication_event_id`. SQL reads the **actual exact
  retained original** definition/proof, never a submitted reconstruction, and proposes a new
  retirement event/time/reference. It refuses an absent original. Only one distinct approved
  retirement per original event is allowed by the approval boundary.
- `programme_approved`: `input` has exactly `source`, `canonical_sha256`,
  `programme_version_id`, `owner_id`. The backend checks the bounded source using the
  existing compiler's provisional review path and requires its canonical fingerprint.
  This preview grants no admission: the existing receiver recompiles against actual
  retained dependencies and published physical sources at delivery. Exact original source
  bytes, target owner/version and canonical digest are all covered by the review digest.

`publication_approval_drafts` and `publication_approval_events` reject UPDATE/DELETE, even
from the table owner. Approval records contain current database approval time and verified
Founder ID, plus the immutable `cohort.trusted-publication-event.v1` envelope. Source
reference is server-generated `cohort-publication-approval:<event UUID>`. No conversation,
Git commit/hash or prepared record is silently backfilled into this event table. There
are no seeds. Rejected/never-approved drafts cannot be resolved by the receiver.

Approved lookups return the existing receiver envelope. For an original publication,
lookup may add an independently approved linked retirement, as the old contract requires;
it does not rewrite the original event/artifact/approval. Retirement can therefore be
processed before the outstanding publication delivery; atomic canonical retention and
retirement, conflict rules and frozen athlete history remain governed by existing SQL.

## Capabilities and delivery ownership

Two new NOLOGIN/NOINHERIT capability roles have no usable membership after schema install:

- `cohort_publication_approval_writer`: prepare, review and approve only.
- `cohort_publication_event_delivery`: resolve, list, claim, finish and exact-digest retry only.

The existing `cohort_exercise_version_publisher` remains the separate canonical retention /
retirement capability. The existing service-only programme admission path remains unchanged;
service-role access is **not** authority to create approvals or retain exercises. Every new
function checks the actual gateway role internally as well as closed EXECUTE grants.
Tables/columns have no direct grants to these roles, athletes, anon or service; RLS is on,
no PUBLIC grants/policies/default-privilege changes. The trusted host's compromise would
expose its configured capabilities; separate credentials within one host are not claimed
as separate host-level security domains.

**First supported delivery owner:** the existing trusted backend owns the durable SQL
outbox and delivery state machine; the authenticated approving Founder operates its
`pending`/`deliver`/`retry` routes. A fresh valid session is required for each call. No
Founder access/refresh token is stored in SQL or used as a background identity. No new
external producer, scheduler or service is necessary. This is durable **operator-initiated**
redelivery, not an autonomous timer, subscription or promised unattended delivery SLA.
If unattended delivery is later required, its machine authentication and scheduling need
separate review; they are not an invented prerequisite for this bounded first version.

Claims serialize per event and issue a fresh UUID lease for three minutes. Overlapping
workers wait; crashed/expired workers can be replaced. A stale/expired lease cannot finish
another attempt. Retry backoff starts at 30 seconds, doubles and caps at one hour; state
and attempt count survive process/revision/session restarts. No max-attempt discard drops
pending work. Invalid-admission/conflict responses block for review; transient failures and
lost acknowledgements remain pending. The existing unresolved-dependency RPC can classify
missing authority as 503, so approval never implies that those dependencies are ready.

Delivery success requires the existing receiver's verified-event acknowledgement with the
same event ID and expected technical status. Only closed safe receipt fields are retained;
raw SQL/downstream errors and source/credentials are excluded. Timeout may follow a commit:
retry the same event through immutable existing retention/admission. Acknowledgement loss
or finish failure leaves persistent work/lease state; never delete an approval, mutate its
artifact or manufacture a compensating retirement. There is no global transaction across
separate definition/source/programme operations.

## Configuration and scope

`PUBLICATION_APPROVAL_ENABLED=false` and `TRUSTED_V3_PUBLICATION_ENABLED=false` remain the
defaults. `PUBLICATION_EVENT_SOURCE_MODE` defaults to `external` for compatibility; the
new `internal_store` mode uses the SQL producer and **requires no external source URL or
source token**. Approval opt-in requires internal mode plus distinct server-only writer
and delivery credentials. Internal v3 opt-in additionally requires the distinct existing
retention credential. None may equal the service or anon credential. Partial/unknown
configuration fails startup; authenticated disabled routes return unavailable before
store access. Legacy v1/v2 import behavior is unchanged.

Deploying code or installing this schema creates no approval event, canonical definition,
source, programme, consent, assignment or athlete write. Later opt-in/configuration,
explicit exact content approval, technical publication and athlete assignment remain
separate operations. Local GoTrue/SQL fixtures prove mechanism only; they are not genuine
production approvals. V3/HYROX Base availability is not established.
