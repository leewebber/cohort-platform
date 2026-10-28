# Smallest M2.5 end-to-end alpha plan

**Proposal only, 2026-10-28. No implementation authorised by this checkpoint.**
[Access/contracts](SOURCES.md) · [mapping and supported subset](MAPPING.md).
Do not start a speculative HTTP client using guessed URLs or payloads.

## First useful local build — no Garmin access required

Implement one network-free converter and deterministic state-machine harness, using
existing RunningWorkout/codec/target resolution. Input is one owner-scoped, canonical
**already accepted/frozen** fixed v1/v2 timed body; output is a versioned delivery
manifest and documented FIT representation/validation. This harness does not add
phone-start behavior, live connection UI, tokens, hosted tables or guessed Training
JSON. Pin an official FIT SDK source/version/licence before binary encode/decode;
if unavailable, test manifest/conversion only and explicitly leave binary proof open.

Proposed paths: `lib/domain/running_workout/` for unit-safe conversion/manifest,
`test/running_workout/` for labelled synthetic fixtures, a small local-only harness
under `tool/`. Do not wire into production until a separately approved live slice.
Use local abstract events like `DeliveryAcknowledged` / `ExternalActivityObserved`
as domain fixtures, **not** purported Garmin callback samples.

Acceptance for this bounded first task:

- Preserve exact role/order/repeats/total and source/admission digests; validate
  ownership/scope and resolve only frozen marked targets. Cross-owner/version/body
  substitution, unresolved references, unsupported shapes fail before output.
- Replay the existing 1140 s fixture, a confirmed BPM vector and known pace-range
  inversion/rounding vectors including edge/collapse/overflow cases. Freeze-version
  equality survives JSON ordering and later benchmark update/withdrawal.
- Same manifest yields same payload/digest; retry/lost acknowledgement cannot mint
  a new logical delivery. A changed accepted revision differs explicitly. Test
  duplicate/out-of-order domain events, activity-before-receipt, reconnect generation,
  two candidate occurrences, already-completed/manual result and correction cases.
- Allowed actuals remain separate; unmatched/ambiguous evidence produces **zero**
  completion/advancement effects. Coordinates and raw FIT never persist or log.
- Run focused affected tests, changed-file analysis and the architecture safety gate
  if architecture changes; no unrelated broad rerun. This is fixture proof only.

## Live build contract gate

First obtain current legitimate Training + Activity/OAuth contracts and sanitised
Cohort access receipt; confirm first watch. Close every unresolved row in SOURCES.
Record exact API version, units/limits, tier capacities, test/production configuration,
callback validation, create/schedule/reconcile behavior and correlation limitations.
If an identifier is not echoed, plan the explicit review path below. If an unknown
send outcome cannot be safely reconciled, pause delivery for operator/athlete review;
never blind-create another workout. No unofficial Connect API/scraped password flow,
Connect IQ side project, intermediary subscription or purchase is substituted.

Proposed minimal live scope: one founder-owned connection, one original fixed
v1/v2 timed running body with accepted pace **or** BPM ranges, explicit delivery of
that occurrence on its existing Cohort training date, one watch run and Activity
push return. Prove the second target type with a separate vector/device test before
claiming both are supported. No whole-programme sync, historical backfill, live
phone GPS/HR, automatic adaptation, benchmark ingestion or progression engine.

## Minimal server authority and flow

Logical records below are design responsibilities, not approved table names or an
existing Garmin schema. Implement in the trusted server boundary with least-privilege
DB operations, authenticated owner reads/actions and private provider ingestion.
No credential or provider-controlled owner ID is trusted from the mobile client.

1. **Connect/disconnect:** athlete selects Connect Garmin while signed into Cohort;
   explain both data directions/allowed metrics, then run Garmin's documented OAuth
   consent. Bind one-time state to current owner/session and expiry; follow required
   PKCE/client rules. Server obtains stable provider user identity and enabled scopes.
   Proposed alpha policy: one active Garmin identity per Cohort athlete and one
   Cohort owner per provider identity; reject conflicting links. Credentials stay
   server-side encrypted and absent from client/logs. Use documented refresh/rotation,
   concurrent refresh locking and reconnect UI. Denied/partial consent is explicit.
   Disconnect immediately blocks new sends/imports, invalidates queued jobs using a
   connection-generation check and revokes via documented provider route; report a
   pending remote revoke honestly. Provider-side revocation has the same local effect.
   Retain lawful prior evidence separately from credentials; account erasure follows
   actual consent/retention terms, never promises blanket indefinite retention.
2. **Accept and commit before send:** prepare the exact owner/assignment/occurrence,
   resolve the existing approved target rules, show complete body/targets and explicit
   **Accept targets and send to Garmin**. Persist immutable accepted source/input/rule
   and delivery bytes/digest with an outbox operation **before** any external side
   effect. The current snapshot table requires a canonical training_session_id and
   freezes only at first phone start. It cannot simply be reused for pre-delivery
   acceptance. A bounded server/schema extension must establish a shared occurrence
   execution commitment, later adopted unchanged by canonical in-app start. Do not
   create a fake active/completed phone session to satisfy that foreign key. Existing
   started occurrences export their frozen snapshot only. This dependency needs its
   own review/tests; held migrations are not silently edited/applied.
3. **Deliver and schedule:** outbox serialises by owner/connection/occurrence/revision;
   same accepted manifest reuses one logical send. Record remote workout and schedule
   IDs distinctly, plus exact request/response receipts free of secrets/location.
   Schedule the existing occurrence/date under confirmed training timezone using the
   documented Garmin calendar semantics. Garmin scheduling never reschedules Cohort.
   States distinguish queued, sending, outcome unknown, Connect accepted, scheduled,
   failed/reconnect-required and athlete-confirmed device visible. An API success
   does not prove device download. Retry documented transient failures with bounded
   backoff/jitter/Retry-After; persist across server restart. Use documented remote
   idempotency or lookup/reconciliation. Unknown creation outcome without safe lookup
   stays outcome unknown, blocking a duplicate create.
4. **Benchmark change after delivery:** exported/started commitment stays immutable.
   Future occurrences require fresh review. No background update overwrites a Garmin
   workout or silently accepts new targets. Smallest alpha policy refuses replacement
   on an already committed occurrence and explains the frozen values. If replacement
   becomes essential, add a separate explicit cancel/review/re-deliver revision flow,
   exact-ID schedule removal and acknowledgement; keep both receipts and old-return
   association. Never delete by title, overwrite a shared reusable workout or claim
   deletion removed a copy already on a watch. Stale/outcome-unknown revision blocks
   automatic replacement; a late activity still references its original revision.
5. **Return and ingest:** implement only documented push callback authentication,
   ownership and acknowledgement semantics. Never infer a signature header/secret.
   Verify provenance and stable provider user via the active connection/generation;
   reject forged/unknown/foreign/revoked input. Persist a sanitised allowlisted event
   durably before acknowledgement, process asynchronously with per-activity locks and
   dedup key `(athlete, provider, provider_activity_id)`. Preserve ID across reconnect;
   do not dedup only by callback transport ID, title, time or FIT file hash. Save
   processing digest/version to separate exact replay from conflicting update.
   Return-before-send-receipt remains pending and re-evaluates after reconciliation.
   Handle delayed/repeated/update/delete notifications per actual contract; if there
   is no authoritative revision order, quarantine conflicts rather than last-arrival
   wins. Missing details/corrupt/truncated or unsupported/multisport data remain
   incomplete, not a reconstructed success. A missing field stays missing.
6. **Associate without inventing completion:** first map provider identity to the
   exact owner. Then map a verified remote workout/schedule/file reference to the
   retained delivery revision and immutable Cohort occurrence chain. Require one
   compatible candidate, source/version/assignment/body and credible timestamps in
   confirmed training timezone. No arbitrary freshness cutoff is authorised here;
   record a reviewed matching window after portal/device evidence. A workout ID
   reused on several dates still needs an occurrence disambiguator. Name/date/sport/
   duration are suggestions only. Unmatched/ambiguous/conflicting/extra activity
   enters an owner-visible inbox, with reason and candidate previews. Athlete may
   explicitly associate to an eligible occurrence or leave unassigned; this is
   recorded as manual association, never certified machine correlation. Never link
   across athletes or revive a reassigned/unavailable occurrence. Unassigned evidence
   is a successful return observation, not successful programme matching.
7. **Actuals and completion:** show planned immutable workout alongside observed
   duration/distance/HR/pace with provenance, missing data and deviations. Imported
   totals do not create per-phase results; sensor dropout is not zero HR. Do not turn
   an arbitrary run into a qualifying 5K benchmark. One activity has at most one
   primary occurrence association in the alpha; conflicts require explicit review.
   **No webhook completes training.** After confident association (automatic or
   explicitly owner-reviewed), athlete reviews actuals and explicitly records the
   outcome. Bridge into existing block actuals/canonical completion transaction with
   existing owner/link checks and M2.4 logical replay; no direct completed-row writes
   or independent advancement. An existing manual completion gets linked evidence,
   not a second result. Replacing its actuals uses explicit correction/audit. Concurrent
   phone completion/import confirmation uses the same canonical occurrence lock and
   returns one record/session/outcome/advance. Lost acknowledgements replay that
   result; corrections remain authoritative. If external-only execution has no
   canonical session, add a reviewed idempotent begin-from-existing-commitment bridge
   that creates no clock progress/actuals by itself. Its successful creation does
   not assert the workout was performed. Paused/terminal/ineligible conditions retain
   existing refusal/replay semantics. Never reset a cursor to make an import fit.

## Real round-trip acceptance, separately authorised

Record evidence tied to exact client/server commit, actual portal app/API version,
connection identity (sanitised), consenting athlete, real model/firmware and authored
source/version/occurrence/accepted-target digest. A synthetic watch test proves only
transport/device mechanics; genuine programme acceptance remains separate.

| Check | Required observable result |
|---|---|
| Connect | Consent/cancel/deny/reconnect/disconnect work; foreign account and stale-session association denied; no token leakage. |
| Accepted delivery | Exact warm-up, timed repeated work/recovery, cooldown, pace/BPM guidance and training date visible on watch. Record request→Connect→watch evidence separately. Same-send/lost-ack retry creates one remote workout/schedule, or honestly blocks unresolved outcome. |
| Frozen revision | Change/withdraw benchmark after delivery; watch/phone commitment stays original and later unstarted occurrence requires new review. No silent overwrite. |
| Recording/return | Athlete starts/stops/saves real run, syncs Connect; genuine authenticated Activity return reaches Cohort with stable identity and allowed actuals. Replayed callbacks do not duplicate evidence. |
| Association | Exact returned reference chain demonstrated, or explicit owner-reviewed association labelled manual. Two identical-day candidates, absent reference, wrong account and late superseded revision never auto-complete the wrong occurrence. |
| Completion/History | Explicit review saves one canonical result and advances once. Activity-first, phone-first and concurrent cases; dropped response and retry; original/current corrected History identity; actual correction stays distinct from frozen prescription. |
| Failure/privacy | Duplicate/out-of-order/conflicting callbacks, revoked connection, stale jobs, partial/corrupt payload, missing sensor data, auth/rate-limit/offline/server restart and sanitisation tested. No raw routes/GPS persistence or fabricated metrics. |

Only a genuine send → watch execution/save/sync → actual return → correct owner and
reviewed occurrence association → explicit canonical completion/History proves the
alpha path. Local fixtures, a Connect calendar screenshot, phone timers, enum labels
or a manually uploaded FIT do not prove that complete path. M2.5 and Gate A remain
open until this evidence and the other release-plan gates are accepted.
