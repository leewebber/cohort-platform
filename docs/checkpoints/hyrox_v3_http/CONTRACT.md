# Trusted v3 HTTP and publication-event contract v1

2026-10-24. Local supported receiver/adapter contract. This does **not** assert an existing
upstream producer, deployed receiver, provisioned credential or actual content approval.
Extends [authoritative retention/admission/start](../hyrox_authoritative_start/CONTRACT.md)
and the existing Founder-only Cloud Run transport; creates no independent publication
registry, athlete authority, approval UI or session creator.

## HTTP composition and caller authentication

The existing `TrustedRuntimeHandler` still handles `GET /healthz`, the unchanged
`POST /v1/founder/plan-packages/import` YAML endpoint and its v1/v2-only draft behavior,
unknown routes, safe logging and graceful shutdown. The same executable now composes:

- `POST /v1/founder/exercise-publication-events/receive`
- `POST /v1/founder/plan-packages/publish-v3`

Both require `Authorization: Bearer <existing Supabase Auth user session token>`.
`SupabaseAuthTokenVerifier` obtains identity/email from `/auth/v1/user`, then the existing
server-owned `AllowlistedFounderAuthority` checks the email. Caller profile roles,
user metadata, submitted founder/approved flags and unverified JWT claims are not used.
An ordinary service key is not a Founder user session. Authentication/Founder checks
precede request-body consumption, upstream fetch and privileged writes. Missing/invalid
user identity is 401; valid non-Founder is 403; unavailable verification is 503.

The only supported caller is an existing authenticated allowlisted Founder. This is a
synchronous receipt endpoint, **not an automatically subscribed producer webhook**. A
future automated deliverer must satisfy this contract or receive separately reviewed
non-athlete authentication support; no imaginary upstream identity is provisioned here.

Content type is `application/json`, UTF-8, at most **256 bytes**, with exactly one key:

```json
{"event_id":"00000000-0000-4000-8000-000000000001"}
```

IDs are lowercase UUID strings. No canonical text, source, hash, owner/version, publication
proof, rule approval, service token, role or target may be supplied. Extra/malformed fields
refuse (422); oversized bodies refuse (413); wrong content type is 415. Wrong methods are
405. The event ID is a delivery hint; possessing it grants no approval or SQL capability.

## Configured trusted-source retrieval adapter

`HttpVerifiedPublicationEvents` implements a **supported external integration contract**,
not a discovered real service. It performs authenticated `GET` to
`PUBLICATION_EVENT_SOURCE_URL + event_id` with the configured server-owned
`PUBLICATION_EVENT_SOURCE_TOKEN` bearer credential. Incoming user tokens are never forwarded.
The base URL is operator-configured, must end in `/`, and cannot contain userinfo, query
or fragment. HTTPS is required except explicit loopback HTTP for disposable local tests.
There is no default producer URL. Redirects are refused. JSON responses are bounded to
**2 MiB**, with a 10-second header wait and a 10-second body deadline. Requests and bodies
are not logged. Source 404 returns retryable `event_not_ready` (409); unavailable source,
invalid records or missing authentication refuse without writes.

The upstream must authenticate this receiver and return the **verified approval record**
from its established publication/approval system. TLS authenticates the configured source
origin; this is service-authenticated retrieval, not a client-supplied signature scheme.
A service that echoes caller JSON or merely validates a file/hash is not a valid producer.
Approval verification itself is upstream work, not inferred from the record's shape.

Successful response: `application/json`, UTF-8, exactly these envelope keys:

```json
{
  "contract":"cohort.trusted-publication-event.v1",
  "event_id":"00000000-0000-4000-8000-000000000001",
  "kind":"exercise_published",
  "approval":{"status":"approved","reference":"authoritative-approval-record-reference"},
  "artifact":{}
}
```

`artifact` above is schematic: the full required shape below must be supplied. No example
is a real approval, source or producer. `approval` has exactly `status` and nonblank
`reference` (at most 1024 characters). Pending/rejected/withdrawn approval is not admitted
(409). Missing or mismatched record identity, issuer, schema or content refuses. The
received artifact is deep-frozen before privileged use. Event identity/approval records
must be immutable in the upstream; conflicting historical records cannot be replaced to
make a retry pass. Current retirement metadata may be added to a publication lookup.

### Exercise publication and retirement

Kinds: `exercise_published` or `exercise_retired`. Artifact has exactly:

| Field | Required value |
| --- | --- |
| `canonical_text` | Exact complete canonical JSON text of the published Founder ExerciseDefinition; UTF-8 ≤262144 bytes. Exact string version retained; no latest/coercion/catalogue reconstruction |
| `publication` | Existing retained provenance object with exactly `issuer`, `event_id`, `source_reference`, `published_at`, `approved_binding_kinds` |
| `retirement` | null, or existing retirement object with exactly `issuer`, `event_id`, `publication_event_id`, `source_reference`, `retired_at` |

Issuer remains `founder_exercise_publication_v1`. For a published event, the outer event ID
and approval reference match `publication.event_id` and `publication.source_reference`.
For a retirement, they match the retirement event and reference, and the linked original
publication event must match the complete publication proof. Publication and retirement
IDs differ. Publication timestamps must identify the same instant as the canonical
published definition; original text is not reformatted. SQL performs the existing full
closed-shape/lifecycle/catalogue/kind/date/conflict validation. No catalogue row or digest
alone is publication authority.

The upstream must return the full exact publication proof even if retirement is delivered
first, and include a known retirement when resolving a publication event for that version.
If it cannot supply that authoritative bundle, refuse and retry later; do not synthesize
history. The added producer-only SQL wrapper retains the publication and known retirement
in **one transaction**, delegating to existing immutable capture/retirement functions. A
retirement failure rolls back new retention. For an already retained exact version,
retirement reuses that immutable proof even after catalogue identity withdrawal; it does
not require a new operational publication capture. Late publication/replay never removes an
existing retirement. Publishing a different version does not retire any earlier version.

The database credential must authenticate as the established
`cohort_exercise_version_publisher` capability through the approved gateway. The ordinary
service role, authenticated users and anon cannot call the wrapper. Its internal role
check rejects them even if EXECUTE were accidentally granted. No role membership, signing
key, JWT minting, credential issuance or production capability is installed by this code.
Local test JWT/capability grants are disposable fixtures only.

### Approved private programme artifact

Kind: `programme_approved`. Artifact has exactly:

| Field | Required value |
| --- | --- |
| `source` | Approved authored source accepted by existing compiler, UTF-8 ≤1 MiB; a retained canonical package is also accepted |
| `canonical_sha256` | Lowercase SHA-256 of the **compiler's approved canonical package**, not raw YAML/JSON bytes |
| `programme_version_id` | Exact approved private version UUID |
| `owner_id` | Exact approved private owner UUID |

The approval reference must resolve this exact source/version/owner combination in the
upstream's audit records. The receiver obtains all fields from that trusted record, uses
the verified caller ID for `imported_by`, and reuses `AuthoritativeV3Publication` and
`SupabaseV3PublicationAuthority`. SQL resolves retained exact definitions/approved kinds,
rule/benchmark versions and actual published session graph. The adapter recompiles and
requires the resulting canonical fingerprint to equal the approved record **before**
publishing. The existing service-only `publish_private_exact_programme_version_v3` remains
the atomic publication/admission operation. Returned status/version/schema/hash must match.
V3 RPC response bodies are bounded to 8 MiB with transport timeouts and no redirects.

Missing definitions/dependencies, retirement, unsupported source shapes, wrong approvals,
unknown capabilities and backend failures refuse; there is no synthetic source, v1/v2
fallback, inferred approval or registration through the normal service credential. The
legacy global-draft importer is not broadened.

## Receipt, admission and approval remain distinct

A successful HTTP receipt has `event_received:true`, the event ID,
`approval_evidence:"verified_producer_record"`, and technical status `retained`, `published`
or `already_published`. Exercise receipts include the database's `retired` state; programme
receipts include version ID and `approved_for_global:false`. No raw source, SQL message,
credential or target is returned. This acknowledges successful synchronous technical work
against a previously approved producer record; the request does not create content/global
approval. It creates no enrolment, assignment, benchmark, consent or started session.

There is no new inbox/queue or automatic upstream subscription. The upstream/deliverer must
retain approved events and retry the same ID after timeouts/unavailability; a lost response
can follow a committed transaction. Replays return the same immutable state. Conflicting
version/event/retirement content returns 409; invalid admission refuses (422); technical
unavailability returns 503. Never change the event to hide a conflict or compensate by
removing history. Overall requests may exceed the existing host's timeout when several
stages are slow; a timeout is not proof of rollback. No Cloud Run timeout/config changed.

Both old canonical start overloads, calculations, consent, source seals and started/completed
snapshots remain unchanged. Retirements affect later admission/starts under their existing
locks; they cannot recalculate or rewrite historical targets or actuals.
