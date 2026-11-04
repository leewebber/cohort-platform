# Bounded catalogue guard compatibility — locally proved

2026-11-04 (Asia/Makassar). Fresh live main and clean task checkout matched
e1115e8d99dc7c2330d9e74ef0596213254152ea before work.
**LOCAL_IMPLEMENTATION_AND_REHEARSAL_VERIFIED; NO_HOSTED_ACTION;
THREE_GENUINE_RECORDS_AND_COMPLETE_STRENGTH_ADMISSION_PENDING; GATE_A_OPEN.**

## Root cause and dependency determination

The duplicated field is nullable exercises_v2.slug, shared by EX-029 and EX-141.
Their exercise_id primary identities are distinct. The retained schema has only
the exercise-ID primary key/index, with no unique slug constraint. The new operation
tool incorrectly promoted a global slug uniqueness assumption into a prerequisite.

[Original failure reproduced](evidence/REPRODUCTION.json) from the immutable
169-row retained operator snapshot before editing. The local replay is explicitly
synthetic; no expired hosted authorisation is refreshed or represented as usable.

Neither legacy ID/slug appears in the three semantic intents, three proposed slugs,
or eight previously retained identity bindings. Both rows participate only as part
of the complete inventory scanned for conflicts/allocation and pinned for preservation.
Their unknown setup/execution and different equipment cannot establish equivalence.
No identity substitution or claim that their duplicate is harmless for all consumers.

Legacy FounderProgrammeExerciseResolver trims slug references and requires exactly
one matching supplied row; an actual request for this duplicate remains ambiguous.
The three unique target references resolve independently. Studio native catalogue
intake binds reviewed variant keys to exact exercise IDs and exact retained row
bytes; it does not resolve the full catalogue by slug. No downstream resolver changed.

The governing catalogue specification already requires checking real constraints
and target ambiguity rather than assuming a slug constraint. Global cleanup is
unnecessary for this operation's correctness; it would alter out-of-scope legacy
records and might affect their existing consumers.

## Bounded implementation

- Keep global primary-ID uniqueness/protected-record checks. Keep every existing
  row, including duplicate-bearing rows, in the complete expected-state pin.
- Replace the global slug veto with target-dependent collision checks. Creation
  requires a new unique canonical slug absent from every existing row. Exact reuse
  requires one exact setup row AND one unambiguous target slug lookup for its ID.
  Whitespace/BOM edges are considered conservatively for collision detection,
  matching the legacy trimmed-lookup dependency; no lowercasing or fuzzy binding.
- Preserve exact-setup ambiguity refusal, distinct planned IDs/slugs, actual
  constraints, required-field review, transaction holds, whole-inventory/schema/
  consumer pre/post equality, partial/conflict refusal and exact same-ID retry.
  No ID-specific exemption and no filtered inventory hides the two legacy rows.
- Select only the pinned existing operator role via a fixed quoted SET ROLE.
  The live pooler had ignored startup role options. This initialization uses
  existing membership; no credential, grant or free-form SQL/role CLI is added.

The generated transaction algorithm and state query are unchanged; only the
applicable prepared manifest/seed hashes differ. Existing genuine receipts,
query digest pins and receipt format remain compatible. The approved semantic
WRITE_SET and offline OPERATION_REQUEST are byte-exact.

## Local rehearsal and negative results

All **23 focused Python checks pass**, including the existing seven real-PostgreSQL
transaction/role/concurrency/rollback cases and ten retained-inventory cases.
Two cached disposable PostgreSQL containers run with --network none and --pull=never;
only task-owned containers are removed. No stack, hosted server or credential is used.

The real local database loads all 169 retained public catalogue rows exactly.
Its five consumer tables/guards and exact-ID references to EX-029/EX-141 are
explicitly synthetic; no athlete rows or original consumer digests are reconstructed.
Prepare/apply/readback/retain reaches 172 fixture rows; all 169 old rows and consumer
links/guards stay exact. Same-operation replay is the explicit no-op audit case;
three uniquely identified reuse operations also succeed. This is software evidence,
not three genuine records, hosted retention or programme admission.

Negative cases refuse: two planned records sharing a new slug; duplicate primary ID;
target collision with the legacy duplicate; whitespace/BOM target aliases; exact-ID
reuse with an ambiguous slug dependency; two exact setup candidates even with
different slugs; changed/added legacy duplicate member; post-prepare target alias;
changed duplicate during replay/retention; partial/mismatched state, constraint or
consumer drift; unauthorised role, manifest/receipt tampering and insert/deferred
side effects. Failed batches do not leave any of the three planned fixture rows.

Two focused Flutter intake checks pass against the final local bundle. The actual
legacy resolver resolves all three unique target references in the full 172-row
fixture but refuses a requested legacy duplicate and a trimmed target alias.
The actual Studio reader rejects the synthetic receipt even with matching file
hashes: no genuine receipt trust pin or session binding is installed.

The first test runs exposed fixture-only role ADMIN and socket-peer setup mistakes.
The fixture now uses a role it owns and the container's already configured trusted
loopback. The complete final suite passes; no production permission/auth behavior
was relaxed. Product runtime, UI and Dart implementation are unchanged. Unaffected
architecture/Studio/source/rehearsal evidence is reused rather than broad reruns.

## Refreshed later-attempt package

[LIVE_ATTEMPT.md](LIVE_ATTEMPT.md) specifies exact steps, role setup, fresh preflight,
hash review, apply/retain/recovery and supported credential closeout for ONE later
authorised attempt. [DECISIONS.template.json](DECISIONS.template.json) leaves actual
fresh-review references null, so it cannot be mistaken for approved live input.
[SHA256.json](SHA256.json) pins code, unchanged write content/query and all synthetic
rehearsal artifacts. [VERIFICATION.json](VERIFICATION.json) records exact counts,
classifications and file digests. The synthetic candidate IDs are not hosted
allocations, reservations, publication events or future live approval.

No live preflight/login request, secret read/issuance, hosted write, role/grant/
password/schema/ledger/migration, legacy repair, assignment or athlete action
occurred. The former one-login authority is consumed/closed and not reused.

Normal non-force main-only Git publication follows fresh live equality/ancestry.
The same detached checkout is reused. Older dirty work, checkouts/HEADs/raw indices,
refs/FETCH_HEAD, measured files, explicit .env/.temp and bounded backup inventory are
preserved by the existing comparison; final external receipts are under
/private/tmp/m11_guard_compatibility_*_20261104.json.

Bounded founder UI acceptance remains recorded and discretionary polish frozen.
Next single milestone point: one separately authorised later live attempt with
fresh target/inventory/role/expiry, genuine three-record retention and complete
local strength admission. D8, publication and installed-device journey stay separate.
M1.1 and Gate A remain OPEN.
