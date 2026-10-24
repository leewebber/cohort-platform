# HYROX source lowering and athlete duration choice

2026-10-24. **LOCAL_IMPLEMENTATION_VERIFIED; REAL_BINDINGS_AND_PUBLICATION_BLOCKED.**
Implementation `89059fd90b0ccee8b915e4310c7860534370eb5e` follows published `8f4e57c4f1f61eb28c745cf3e9c0603c0d26f16b`. Normal Git main publication
is authorised by the current request; it does not publish a programme or deploy SQL.

[Master specification](../../programmes/hyrox_base/MASTER.md) ·
[48-session audit](../../programmes/hyrox_base/COVERAGE.md) ·
[Exact candidate register](../../programmes/hyrox_base/EXERCISE_CANDIDATES.md) ·
[Capture/preparation contract](../../programmes/hyrox_base/CAPTURE_AND_PREPARATION.md) ·
[Verification](VERIFICATION.json) · [Migration](MIGRATION.json) · [Preservation](PRESERVATION.json).

## Delivered and reviewed

The six explicit founder decisions are retained verbatim in the current approval record.
W1 row is 3×10/side at 2 RIR, plank is 3×20 s, every long run adds exactly five minutes
before and five after, and squat working sets rest 150–180 s separately from ramps.
Approved supporting prescriptions and core/finisher progression remain complete.

The canonical JSON source adapter lowers all 48 main prescriptions into established
SessionBlock/strength/timer/runner contracts. Explicit exact published definitions,
version/digest pins and verified publication events are mandatory. Missing authority
refuses; software fixtures establish no real exercise binding. Supersets, positions,
rep/RIR/rest ranges, unilateral carries, timed/extended holds, minute work/recovery,
full final rest and between-only interval recovery survive lowering and save/reopen.
Confirmed codec defects that lost group fields, exercise positions and capture modes
are fixed. Original source and complete graph round-trip through a distinct canonical
source JSON export; reopen recompiles and checks equality. Existing Studio TAR intake
and its authority boundary are unchanged. Human review retains load/height/effort intent.

For easy/long main windows, the launcher requests an explicit in-range duration with no
default. Cancel creates no start. The additive RPC retains the original physical source
range and chosen seconds in an immutable FK-linked packet within the existing owner/
consent/start transaction. Retry returns that packet; replacement/withdrawal cannot
rewrite it. A record guard requires the packet through draft save, completion, correction
and History. Saved plans must match original source, duration and bound prescription.
No chosen target becomes an actual. Existing strength/endurance/interval actuals and
completion/optional notes for core/finishers are reused; no new mandatory result fields.

The new migration is **local only**. All 129 previous migration files are byte-identical;
130 source files is not a hosted ledger/pending/apply claim. Existing packages/compiler,
trusted server runtime, old SQL and importer source outside the changed adapter remain
unchanged. No producer authority, historical protocol revisions or physical IDs are
invented by local source addresses. Test Week remains separate.

## Remaining blockers by session/category

| Category | Sessions | Remaining dependency |
|---|---|---|
| T1 | All 48 | Real exact reviewed ExerciseDefinitions, versions/digests/events, operational lifecycle and explicit variant bindings. |
| B3 | All 48 | Complete immutable physical protocol/session/block/step versions and producer-approved programme artifacts. |
| B2 / D4 | Eight Gym C | Verified selected-division wall-ball race weight/height mapping. Approved intent is retained. |
| P1 | All 24 gym | Unquantified ramp-set counts/reps/loads/rest and full timing. Existing instructions remain visible; no working-set doses are missing. |
| P2 | Eight quality runs | Unspecified dynamic preparation. Existing ten-minute easy run and three 20/40 accelerations are structured; cooldown window stays authored. |
| C1 | All 24 gym | Existing capture cannot assert separately measured per-side/hold/height/RIR/rest/station outcomes. Completion/optional notes remain usable; these are capability limits, not new required results. |

All 48 **main working prescriptions are source-complete**; only 16 have fully quantified
preparation. The audit records all categories for each session rather than hiding them
behind a primary status. Zero real bundles are authoritatively bound. The 29 explicit draft
candidates include nine known identity candidates (EX-073, EX-078, EX-088, EX-053, EX-129,
EX-049, EX-050, EX-052, EX-022) and 20 unresolved identities. Every exact version, event and
digest remains null. Candidate equipment/classification/dimensions need producer review;
no catalogue row, draft derivative, name similarity or synthetic EX-900x is authority.

Only material content/variant inputs remain: exact dynamic preparation and any required
numeric ramp programming; exact unresolved implement/preparation-row variants in the
candidate register; and verified external race-division mappings/selection. These are
one consolidated list in [DECISIONS.md](../../programmes/hyrox_base/DECISIONS.md).

## Verification and limits

13 offline source tests and seven deterministic artifacts pass. The affected Flutter
suite passed 489 with one explicit authenticated-test skip. Final source lowering/export/
runner tests passed nine (including all 48 source round trips); duration launcher tests
passed 20. Shared compiler/goldens passed 41 and trusted-server unit tests 57. All six
mandatory safety groups pass. The final review-only copy/audit fix passed focused tests
and analysis; unchanged broader/safety evidence is reused. Whitespace and local links pass.

Fresh and repeat disposable Docker/psql gates replay the full migration chain and existing
v3 admission/consent/start/security/rollback/completion/History checks. New tests cover
inclusive endpoints, explicit/invalid/missing/foreign choices, atomic rollback, immutable
retry/withdrawal, owner isolation, ACL/private-helper revocation, and prescribed packet
retention/refusal through draft/completion/History. No new choice-race proof is claimed.

Fresh analysis is 362 inherited findings (108 warnings, 254 infos, zero errors), down from
364 by removing two unused imports. Diagnostic identity comparison shows zero additions;
23 changed Dart files have zero diagnostics. This is not a green full-analysis claim.

`athlete_authoritative_local_test.dart` skips because `COHORT_LOCAL_V3_CONFIG` is absent;
it explicitly requires a task-owned authenticated local gate. The normal gate also runs
denied Python HTTP probes. It was not bypassed, and no other project's config was borrowed.
SQL-role proof uses psql stdin, not Python networking, and is not GoTrue/HTTP/app proof.
Prior committed HTTP evidence remains historical and is not new duration transport proof.

Hosted state/provisioning/real artifacts, authenticated native/browser/device review,
commercial readiness and broader Stage 2/Sprint C closure remain open. No hosted operation,
producer provisioning, real publication, athlete assignment/write, device distribution or
computer/browser control occurred.

## Preservation incident and exact exception

The desktop restarted and ran automatic keep-15 cleanup at
`2026-10-24T10:50:59.910Z`, removing the old `studio-lineages-final-review` checkout.
This task created no managed worktree and invoked no managed cleanup. Its retained
snapshot/branch still referenced `0767ac6a80fc6611598b9ca5f2c991d3f76125a6`.
The checkout was recovered at its original path/branch from recorded files in an existing
identical clean checkout. All recorded file bytes, HEADs, branches, status, original 95
outstanding paths and `.temp` state now match across all 20 older checkouts.

**Its original raw index was lost.** A logically equivalent clean same-HEAD index with
identical skip-worktree flags replaced it. Original SHA-256
`83f80fcaf28e402f27e47fc888d6bc2a7c1f1ee2723f3cc14f7ef9257e0c5469` differs from replacement
`a3c4c4422a86447937dec88156c62e8643efdf7b447090d2424f8999d94282b8`.
The other **19 older raw indices remain exact**. This exception is not described as full
index preservation. Administrative Git locks were added to 16 worktrees (including the
active checkout) to protect them; no global app cleanup setting was changed. Full hashes,
lock paths and the exception are retained in PRESERVATION.json; raw inventories and
surviving-index backups remain private under `/private/tmp/cohort-hyrox-lowering`.
