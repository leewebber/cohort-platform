# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.8 local Undo apply-rejection diagnosis (no staging contact).

**B4d.7 execution SHA:** `08625be2f8446a9fbee817489bf415ca6d9a996d`  
**B4d.8 branch:** `codex/b4d8-undo-diagnosis`

## B4d.7 accepted facts

* Selected `I,J`; order `I → J`; I PASS (cursor Skip, rev 5→6)
* Fresh Skip correlated; J entered Undo apply
* J FAIL `UNDO_REJECTED: apply unsuccessful` — RPC status/code **not preserved**
* Hosted post-J mutation state: **uncertain**

## B4d.8 diagnosis (local)

### Primary classification

`HARNESS_REQUEST_CONSTRUCTION`

Journey J `reloadSnapshot()` builds the preview snapshot **without**
`cursorSessionSlotId`. Undo-Skip fingerprints bind live `cursorBefore` from that
field; PostgreSQL always binds the assignment cursor after Skip. Null client
cursor → ready preview + `stale_preview_fingerprint` on apply.

Product UI resolves cursor on snapshot load; product Undo defect is **not proven**.

### Secondary

`HARNESS_TYPED_RESULT_COLLAPSED` — B4d.7 collapsed `applied.status` / `applied.code`
into opaque `apply unsuccessful`.

### Reporting-only correction (this branch)

* `lib/staging/s17_undo_diagnosis.dart` — typed Undo evidence
* Journey J detail preserves `status=` / `code=` / `cursor_bound=` / `typed=`
* Characterization tests in `test/staging/s17_b4d8_undo_diagnosis_test.dart`

### Proposed remediation (NOT implemented under B4d.8)

Bind the live assignment cursor into the Journey J reload snapshot the same way
Journey I and the product controller do, then regression-test null vs bound
fingerprint parity. Do **not** retry staging during remediation.

## Next authority

| Diagnosis | Next |
|-----------|------|
| Harness request/revision defect | Locally remediate cursor bind on J reload; no staging retry |
| After remediation | Separately authorize one fresh cursor-aligned Skip→Undo evidence run |
| Journey D | Separate adaptation-eligible-fixture track |
| B4e | Blocked until J and D have valid staging evidence |

Production rejected. No dry/live run under B4d.8.
