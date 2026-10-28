# M2.5 — bounded local workout conversion and association harness

2026-10-28 (Asia/Makassar). **LOCAL REPRESENTATION / FIXTURE HARNESS VERIFIED.**
Implementation `7d53cbd2212c6af451913455e420abe813e90311`. **M2.5 OPEN; GATE A OPEN.** Garmin account/API access,
portal contracts, watch compatibility and a genuine round trip remain unverified.
No hosted state was inspected. Supabase's inactivity warning remains unverified;
no restore, resume or keep-alive request was made.

Binding: [controlling plan](../../planning/Founder_Release_Plan_M0_M10_v1.md),
[Garmin audit](../m25_garmin_round_trip/HANDOFF.md),
[public source register](../m25_garmin_round_trip/SOURCES.md),
[M2.4 retained retry/triage evidence](../m24_terminal_completion_retry/HANDOFF.md).
[Verification](VERIFICATION.json) · [generated synthetic representation](FIXTURE_REPRESENTATION.json)
· [reproducible local commands](../../../tool/garmin_local/README.md).

## Delivered scope and exact shapes

`FrozenRunningFitExport.fromAcceptedPlan` consumes an already started original fixed
v1/v2 Programme Athlete plan, its trusted execution context, expected owner/session,
and independently retained accepted-snapshot digest. Available occurrence/assignment/
version/package/protocol/body/review/rule/input bindings are checked using existing
admission validation. It resolves marked steps through the existing frozen target
projection, makes an immutable copy, and retains original source plus accepted packet,
resolved body, source/admission hashes, scope and versioned conversion policy.
No current benchmark, date, provider state or later input revision is read.

The caller must load the genuine canonical plan/context/snapshot. A digest computed
from arbitrary caller JSON is not authentication. All provided exercise/run examples
are explicitly synthetic canonical-shaped inputs, not fresh authenticated server
proof. No production launcher/store/UI composition or new start/freeze RPC was added.

| Supported locally | Exact boundary |
|---|---|
| One complete running body | Original fixed v1/v2 occurrence, one block, exact accepted session snapshot. No automatic pre-delivery commitment. |
| Time-ended atomic steps | Positive whole seconds represented as ms, within FIT raw uint32 excluding invalid sentinel. No duration rounding. |
| Warm-up/work/recovery/rest/cooldown | Preserve role, order, labels, notes and every authored final recovery. No implicit phase creation. |
| One-level repeated atomic groups | 1..32 repetitions; compact indexed repeat marker; ≤512 expanded phases. These are Cohort local limits, not certified Garmin/device limits. |
| No target | Open FIT target while retaining the timed ending. |
| Explicit accepted pace ranges | Canonical ms/km inverted to m/s; FIT raw speed scale 1000. Integer outward quantisation at 0.001 m/s, separately versioned and retained. |
| Explicit numerical BPM ranges | Ordered 1..250 BPM; custom HR target with FIT absolute +100 offset, never user-zone/max-HR substitution. |
| Marked quality/Zone 2 source | Resolve only using the original accepted snapshot, preserving source/rule/input/step identity. |

Refusals include missing acceptance/digest/session identity, foreign owner or changed
scope/body/rule; v3/nonfixed/adapted/multiple-body export; invalid/empty/duplicate-ID
source; distance/manual-lap/open-role/subsecond/out-of-range time; unresolved markers;
scalar pace/HR, RPE (including an authored fallback), power/cadence; nested/invalid
repeats, >512 expanded phases and unrepresentable pace/BPM bounds. Invalid packets
fail rather than silently remove targets, alter durations or invent coaching intent.
The old quality fixture has recovery RPE 2 and is therefore **refused**; it was not
edited into exportable content. A new clearly labelled software-only mixed-target
fixture checks pace plus numerical HR conversion without approving a real workout.

The output is a **raw FIT field representation in JSON**. It contains no binary
header/CRC/file_id, assigned manufacturer identity, Garmin Training JSON, account,
remote workout/schedule identifier or delivery transport. Names/scopes in the manifest
are Cohort metadata, not fields claimed to be echoed by Garmin. The local outward
rounding proposal is not a live Garmin API contract or a change to stored prescription.

## Independent proof and limits

Public Garmin references were retrieved again on **2026-10-28**:
[Workout contract](https://developer.garmin.com/fit/articles/file-types/workout.html),
[official FIT profile](https://raw.githubusercontent.com/garmin/fit-javascript-sdk/refs/heads/main/src/profile.js)
(observed 21.214.0Release), and
[FIT SDK overview](https://developer.garmin.com/fit/overview/).
The official SDK download page returned navigation only through documentation retrieval.
No FIT SDK/parser was installed in the inspected system/bundled runtimes or checked
local caches. Ordinary official GitHub SDK archive acquisition failed DNS (curl exit 6).
No FIT dependency was installed and no alternate download/network/permission workaround used.

`verify_representation.py` is an independent Python inspection, importing no Dart
converter/codec. It reads the actual generated output, derives duration/repetition and
unit checks from the frozen resolved source using Fraction arithmetic, and asserts
separate hand-calculated vectors. It verifies scope and immutable hashes, role/index
order, repeat-back pointer/count, exact raw durations, speed inversion/range/scale,
absolute BPM offset and source expansion.

The emitted fixture has **five step messages, eight expanded phases, 1140 seconds**:
300 s + 3×(120 s / 60 s) + 300 s. Accepted manual-threshold 294..306 seconds/km
encodes raw speed 3267..3402 (3.267..3.402 m/s); 130..145 BPM encodes 230..245.
An additional 300..330 seconds/km vector checks raw speed 3030..3334. Eight deliberate
corruptions of duration, repeat count/pointer, speed units/bound, HR offset, owner and
target type are rejected independently, even after rehashing the corrupt export.

**No authoritative SDK parse or binary-file proof was achieved.** Independent source-
based field inspection is useful local proof, not a replacement label for SDK/vendor
validation. Before binary/live use, obtain an official pinned/licensed SDK normally,
encode/parse independently and verify actual fields. API acceptance, scheduling,
watch display/execution and Activity API return remain wholly unproved.

## Local association semantics

The harness has no network, persistence, authentication or programme-completion port.
Delivery-fixture scope is copied immutably and its identity is derived from the entire
frozen export; caller-supplied unrelated digest/scope pairs are not accepted.

| Evidence class | Harness behaviour |
|---|---|
| Documented FIT `training_file` reference | Public profile describes correspondence with workout/course `file_id`. Exact synthetic tuple may produce a **candidate** against a retained delivery fixture. It does not prove authenticated ownership, actual Garmin echo or watch preservation, and still requires explicit fixture confirmation. |
| Proposed Training workout/schedule IDs | Deliberately named proposed fields. Can suggest candidates or expose contradictions, but their semantics/uniqueness/preservation need portal verification. They cannot disambiguate a reused FIT reference. |
| Name/time/distance similarity | Never creates a candidate or automatic association. |
| No match / multiple matches | Unmatched/ambiguous state; explicit owner-reviewed fixture choice required, or leave unassigned. |
| Contradictory identifiers | Quarantine; confirmation refused. |
| Same fixture activity key, identical data | Idempotent duplicate; same identity, re-evaluation after late delivery registration. |
| Same key, different actuals/reference | Persistent conflict in either arrival order; no last-arrival winner without an authoritative revision contract. |
| New version/occurrence | Separate immutable export/receipt; late original reference stays with the original candidate. |

Observation ownership and stable activity dedup keys are **synthetic assumptions**.
No available API contract attests either for real Garmin returns. Foreign observation
owners, candidate discovery and confirmation are isolated. Manual confirmation is
bound to current observation digest and one owned manifest; stale confirmation and
silent rebinding refuse. It records a local fixture decision only.

Measured fixture duration/distance/HR stay outside the prescribed manifest, with
missing values retained as missing. No actual pace/distance/laps/benchmark result is
manufactured from targets. Even a confirmed association always returns
`authorisesProgrammeCompletion=false`; no completion/correction RPC, programme cursor,
phone session or actual athlete record can be mutated. Manual-completion/import races,
corrections, durable retries and canonical completion bridging are future integration
work, not newly proved by this in-memory harness.

## Verification and preserved gates

- **149 focused checks pass**: all running-domain tests, existing quality/Zone 2
  admission and authored timed runner regressions, plus fixture driver. This includes
  45 new unit checks and one local fixture-driver check; counts overlap.
- **Eight independent corrupted-output controls rejected.** No same-custom-codec
  round-trip is counted as independent proof; no SDK parse is claimed.
- **Six mandatory consolidation safety groups pass.** Final full analysis retains
  **362 identical inherited findings**, zero errors/new/new-file diagnostics. Full
  analysis exits 1, not green. No suppression/configuration/dependency change.
- Diff/link/JSON checks and retained checkout hash comparisons pass. No full Flutter
  suite or DB/HTTP gate was run for this unwired local change. Existing M2.4 SQL/auth
  proof is reused only at its immutable checkpoint, not rerun or broadened here.

Retain the inherited `athlete_runtime_capability_bootstrap_test.dart:124` failure
(expected AthleteAppShell absent), reproduced previously on immutable `a67e69c`.
It remains an open alpha-path triage item, not waived/fixed by local Garmin fixtures.
Genuine programme admission, held migrations, actual personalisation/adaptation,
movement instructions, feedback/distribution, blocking-defect and authenticated
installed-device acceptance remain outstanding. Supabase hosted state stays unknown.

## Git and next single point

Reused clean local `main` at `125ad8d309aa78e8f21c42fafc34798a5e585156` after
M2.4; all 16 preceding commits after `1cca598` and their full ancestry remain exact,
zero merges. The original dirty Developer checkout and 23 retained checkout
inventories/indices/HEADs/files/.env/.temp are unchanged; 28 absent registrations remain
absent. No worktree/clone/cleanup/settings operation. Working main advances only via
linear authorised implementation and documentation commits.

Two ordinary `git fetch origin` attempts failed GitHub DNS. Cached origin/main is
still `a331f52967e1887c4435cccc8f1ecfa192028cd6`, not live ancestry proof. No push was
attempted while live ancestry could not be verified; no alternate route or force.
Normal main-only publication remains pending connectivity and actual ancestry checks.

**Next single Gate A point: M2.5 access/contract verification for the live round trip.**
Founder must establish current application/app status or legitimately obtain Business
Training + Activity access, current applicable terms/capacity and permitted technical
contracts, then supply exact watch model/firmware/Connect platform/running profile/HR
source. Do not guess these or apply on the founder's behalf. Obtain ordinary official
SDK availability for the remaining binary/independent parser proof before that build.
Then scope the reviewed pre-delivery commitment and live adapter against actual
contracts. No speculative transport or automatic next build is authorised here.
