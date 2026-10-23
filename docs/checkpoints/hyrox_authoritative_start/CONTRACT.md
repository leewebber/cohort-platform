# Authoritative retained versions and canonical v3 start

2026-10-23. Local implementation under the founder decision extending the established
published-definition lookup/publication boundary. [Scope](SCOPE.md),
[preceding decision](../hyrox_v3_canonical_storage/AUTHORITY_DECISION.md),
[v3 binding contract](../hyrox_bound_prescriptions/CONTRACT.md),
[approved Base rules](../hyrox_base_personalisation/DECISIONS.md).

## Published ExerciseDefinition authority

`published_exercise_definition_versions` starts empty. The exact complete canonical
ExerciseDefinition JSON text, exact **string** version, computed digest, publication issuer,
unique event, source reference, publication time and explicit approved binding kinds are
retained immutably. The current `exercises_v2` row checks published identity/lifecycle only;
it supplies neither a definition version nor historical publication provenance. No backfill
or new real definition is installed. Lookup returns the exact historical version, never
latest, a name match, bridge revision, catalogue snapshot or a guessed version 1.

The accepted `ExerciseKnowledgeRepository` operational lookup is extended by
`PublishedExerciseVersionRetention`. It requires an exact published Founder definition,
validates the full typed definition and asks a separate authorised publication-event port
for verified provenance **before** invoking retention. This port has no default producer,
credentials or client-supplied approval implementation. Missing source/provenance refuses.

Only `cohort_exercise_version_publisher` may execute capture/retirement RPCs. It is NOLOGIN,
NOINHERIT and has no usable member, superuser, role-management, database-creation or RLS
bypass capability. PostgreSQL 17 can automatically retain the creator's ADMIN-only link;
SET and INHERIT must both be false. This administrative ability is reported and checked,
not described as absence of every membership. No ordinary service JWT, authenticated user,
anonymous user, supplied file/hash or matching content digest can register a publication.
The SQL role check also refuses an accidentally overgranted service EXECUTE. Actual
producer provisioning and its verified approval-record implementation remain deployment
prerequisites. The trusted producer is responsible for exercising already approved
publication authority; a provenance-shaped JSON object is not independently sufficient.

Version retirement is a separate immutable event linked to the original publication event.
It does not mutate/delete the published body or imply that publishing another version
retires this version. Capture is exact-content/event idempotent; conflicting capture or
retirement refuses. Historical lookup returns retirement separately. Operational admission
and future starts refuse retired versions or unpublished catalogue identities.

Existing v3 integer references resolve only where the retained string exactly equals the
positive integer's decimal representation (`7` resolves `"7"`; neither `"07"` nor
`"release-A"` is coerced). Other string versions remain retainable and historically
resolvable, but require a separately versioned binding contract before use. No v1/v2/v3
canonical serialization change is introduced. A canonical physical UUID block ID is now
accepted in `canonical_exercise` bindings; synthetic namespaces retain their previous rule.

## First accepting v3 profile

The explicit trusted private publication adapter authenticates through the existing Founder
ports, compiles provisionally only for internal canonicalisation, obtains actual SQL
source/dependency resolution, recompiles and calls the new service-only private v3 RPC.
There is no installed new HTTP route or broadened global-draft import. The existing v1/v2
publisher is invoked inside the transaction, including its owner/scope/lifecycle retry
checks. A private transaction-ID/hash claim admits schema 3 through the existing version
trigger; client GUCs/hashes do not create a claim. Canonical text, resolved versions and an
independently queried physical graph seal are retained immutably. Rollback removes all
partial publication data and the claim. Existing C2 v1/v2 artifact retention is untouched.

This is a strict accepting profile, not support for every possible v3 package: flat private
coach/organisation source; 1–8 weeks, 1–64 uniquely referenced published session revisions;
ordered days/slots; required, nonoptional, `any` time slots and existing supported progression
notes. `phases`, `adaptation_permissions`, `protected_invariants`, `assessments`,
`performance_evidence_requirements` and `comparison_identities` must be empty. Tracking
bindings and `authored_running_v1` are unsupported in this profile. Unsupported features
refuse rather than being silently dropped by the existing private publisher.

Each target must resolve exact slot/week/session lineage/revision/body hash, canonical
physical block/exercise and approved integer rule/benchmark references, units, parameters
and work-step IDs. Only the existing eight-week approved run, dedicated-row and squat rules
are installed. Dedicated interval blocks contain one explicitly approved exercise, closed
timer fields, exact doses and no execution groups; mixed WOD stations refuse even with a
correctly recomputed source hash. Squat requires exact strength prescription, sets/reps/RIR
and no interval steps. No other load or pace transfer is inferred. Existing B2's 5 km policy
and observational C1/C2/C3 remain separate.

## Review, consent, evidence and start

The existing authenticated owner-scoped declared-evidence/correction stream is reused.
Declarations remain declarations, not test/source attestation. Existing preview selections
are **not** upgraded to programme consent. A server-issued review is scoped to athlete,
assignment, exact programme version/hash, complete resolved source, binding/rule, explicit
benchmark revision choices and total barbell increment. It distinguishes authored values,
selected raw evidence, exact calculated targets, authored effort and separate null actuals.
SQL owns calculation; client target/document/hash fields are rejected.

Consent is append-only acceptance of that exact review, using a command ID and expected
consent head. Replacement and withdrawal append a new generation under the assignment lock.
Wrong owner/programme/version, stale head/review, superseded evidence and unresolved sources
refuse. Missing selected evidence or squat increment may be explicitly reviewed/accepted
only as numerical unavailability with approved authored effort; row has no invented effort
fallback. A new independently recorded benchmark does not auto-select itself. Corrections
make an old selected revision stale; a fresh explicit review/acceptance is required for
future unstarted targets. Withdrawal stops future starts without rewriting history.

The existing `create_or_resume_fixed_programme_occurrence_session` gains a consent-token
overload. It calls the existing canonical occurrence transaction/private pre-v3 body,
retaining ownership, exact source links, restoration, completion and parent protections.
There is no new session creator. The original one-argument RPC routes owned v3 first starts
to refusal without consent; frozen retries may resume. Generic legacy JSON starts continue
to refuse v3. Other schema versions retain their exact old path and function identities.

New starts lock occurrence, assignment, programme version, published protocol/catalogue and
retained definition rows, then the same athlete/metric evidence locks used by correction.
Consent updates share the assignment lock; exact version retirement shares the retained
version row lock. Sources are re-resolved and their physical seal compared; review is
recomputed and must match accepted state. One transaction creates the canonical training
session/outcome and immutable FK-linked snapshot. Snapshot contains exact canonical text/
hash, session/slot/occurrence/training references, full source and retained versions,
bindings/rules/benchmark revisions, accepted consent/review/configuration and SQL targets.
Only the selected slot's prescriptions execute. Injected snapshot failure rolls back the
canonical session/outcome. Retries return the original frozen packet; completed retries
preserve the existing canonical refusal/status behaviour plus immutable history.

Assignment/evidence/source/consent races produce a coherent start or explicit refusal.
Later withdrawal, replacement, correction or retirement cannot rewrite a started/completed
snapshot. All retained tables are private or owner-read RLS; no runtime role has direct
mutation, deletion, truncation or column-write permission. Restrictive FKs and immutability
triggers protect retention and ownership links.

## Application boundary and remaining work

`ProgrammePrescriptionRepository` calls authenticated review/consent and delegates start
to the existing start store. Execution context carries the exact token; the existing
launcher validates the returned snapshot's owner, assignment/version/hash, occurrence,
slot, training session, source and created consent, then deep-freezes the handoff. It
never calculates an authoritative prescription. Old B2 launch data stays unchanged.

This delivers callable production-repository integration locally. The production review
screen, authenticated selection/withdrawal UX, token propagation from that screen, and
run/row/squat runner presentation/capture of the new frozen packet are not mounted or
device-proved. Do not claim end-user rollout, production readiness, Stage 2 or Sprint C
closure from the disposable fixture proof. [Deployment prerequisites](DEPLOYMENT.md).
