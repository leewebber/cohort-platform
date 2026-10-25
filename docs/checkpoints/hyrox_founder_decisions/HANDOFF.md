# HYROX founder decision packet — independent work complete

2026-10-25. **PROPOSED_CONTENT_AND_VARIANTS_AWAIT_FOUNDER_REVIEW.**
Base: `97db4f6ce62da26309f934b0c7e652fb6d454780`.

[Founder-readable decision packet](../../programmes/hyrox_base/FOUNDER_DECISION_PACKET.md)
contains all 29 names, exact proposed equipment/position/grip/execution, existing identity
leads versus new exact-definition proposals, source evidence/distinctions and one
recommendation each. Straightforward variants are grouped separately from materially
different setups. [Definition/movement templates](../../programmes/hyrox_base/EXERCISE_DEFINITION_PROPOSALS.json)
contain 29 label bindings and 27 distinct proposed definitions: easy bike shares the fan-bike
identity and light row shares the chest-supported-row identity. Eighteen label bindings
have existing identity candidates (17 distinct IDs); ten genuinely new exact-definition
proposals remain unassigned, subject to producer deduplication. This is a recommendation
about exact variants, not certification that any published version exists. All actual
version/digest/event authority remains absent. Unknown slots remain null; do not run a
null version through a decoder that supplies version 1.

[Four preparation proposals](../../programmes/hyrox_base/PREPARATION_PROPOSALS.json)
retain supplied five-minute easy starts and two-round circuits. New athlete-readable
ramp guidance fits the existing 12–15-minute gym allowance; RDL/lunge loads remain selected
by feel with no benchmark derivation. The quality proposal adds a two-minute dynamic
circuit using already-listed movements; total preparation is 15–17 min including the
existing accelerations and explicit transition allowance. These proposals are not applied
to SESSIONS/PROGRESSION/master sources. P1/P2 therefore remain pending content approval.

The wall-ball investigation found no retained official division rule table. The accepted
local movement pilot explicitly defers HYROX judging/race standards. The precise required
input is the selected race format’s official governing season/revision rulebook, Wall Balls
section and division weight/height table plus official addendum. Current inputs do not fix
the race/format/season/division or supply document bytes, so no numeric revision/mapping is
invented. Authoring/export retains the unresolved race-standard reference. **Final Base
publication remains blocked** by B2 and all-session T1/B3. There is no dedicated tested
wall-ball null-reference rejection in the current generic trusted publication validator;
audit blocking must not be misreported as server-enforced race-rule admission. Retain the
explicit producer hold and require final reference validation/proof before later publication.
No new rule/reference infrastructure or publication operation was introduced.

Capture review finds C1 optional evidence limits, not a reason to add mandatory fields:
carry/core/finisher completion and notes already work; per-side measured outcomes, actual
hold quality/rest/RIR/height and station scoring are unavailable. Main strength still uses
its existing actual-set/reps completion requirement. B2 prevents choosing verified race
load/height, independently of capture. No additional confirmed runtime defect was found;
no runtime, schema, capture or source-dose change was made.

## Cleanup trigger and founder action

Read-only local logs and installed bundle code identify the desktop’s automatic retention
planner, not Git pruning or an agent cleanup command. First cleanup followed managed
creation on 2026-10-23. The second plan at `2026-10-24T10:50:59.910Z` selected five out of
20 with `keepCount=15`, all app protections zero. The removed owned checkout had
`ownerThreadInProgress=false` and `isProtected=false`. Cached code from that investigation
and the currently installed bundle both enqueue cleanup on connection/startup lifecycle;
creation/attachment completion can enqueue it too. The log has no callback stack, so an
exact individual enqueue callback is not asserted. Avoiding creation alone cannot prevent
this planner. Git locks are not an app-level cleanup setting or a prevention guarantee.

**Founder action:** Codex **Settings → Worktrees → Automatically delete old worktrees →
OFF**, for the local host. The installed UI contains this exact label. Backing key is
`desktop.worktree-auto-cleanup-enabled` (default true); `desktop.worktree-keep-count`
defaults to 15. Read-only inspection found no worktree override in the local config.
Turning automatic deletion off addresses the trigger more directly than a larger finite
retention limit. No setting, pin, global preference or app control was changed here.
Selected code/log snippets, member hashes and configuration digest are in
[CLEANUP_EVIDENCE.json](CLEANUP_EVIDENCE.json). No web search or desktop/browser control.

This task reuses `hyrox-athlete-runner` and creates no managed or disposable Git worktree.
No checkout is removed/recreated, no index regenerated, and no further locks are added.
The dirty original remains main at `a331f52967e1887c4435cccc8f1ecfa192028cd6` with 95
outstanding paths. Current-task before/after evidence is in [PRESERVATION.json](PRESERVATION.json).
Historical restorations remain explicit: four first-incident checkouts and the second
`studio-lineages-final-review` checkout had recorded source/ref/.temp state restored but
lost their original raw indices. Those five are restored resources, not originally
byte-identical resources. The last task’s “19 indices exact” comparison included four
already-regenerated indices; it did not restore their original historical byte streams.
Unmeasured ignored build artifacts are not claimed restored. This task measures against
the current starting inventory, without rewriting either historical record.

## Analysis and authenticated-test evidence

No fresh full analysis is claimed for this documentation task. Prior implementation
`89059fd90b0ccee8b915e4310c7860534370eb5e` removed exactly two diagnostic identities:

| Severity/code | Repository file | Exact removed message |
|---|---|---|
| warning / unused_import | lib/features/session_builder/services/session_execution_plan_builder.dart | Unused import: '../../../models/session_block_exercise_link.dart'. Try removing the import directive |
| warning / unused_import | lib/features/session_builder/services/session_execution_plan_builder.dart | Unused import: '../../../models/workout_format.dart'. Try removing the import directive |

Thus 364 (110 warnings/254 infos) became 362 (108 warnings/254 infos), with zero errors,
zero added diagnostic identities, no suppression and no changed-file diagnostics.
The committed multiset comparison and log hashes are retained in
[prior verification](../hyrox_source_lowering/VERIFICATION.json); line shifts were ignored,
full diagnostic messages were not. This is inherited non-green analysis, not a new baseline.

The exact missing configuration is environment variable `COHORT_LOCAL_V3_CONFIG`, whose
value must be a path to the unique disposable project’s `app-local.json`. The normal gate
writes that file using `supabase status -o json`, restricts its permissions, runs the test,
then deletes it. Required keys are `API_URL` (loopback HTTP), `ANON_KEY`, `JWT_SECRET`;
`TEST_ACTOR` and `TEST_SECOND_ACTOR` are optional fixture identities. No values are printed
or committed. The current variable is unset. The skipped test signs local fixture JWTs
and exercises authenticated repository/RPC/start/runner/save/completion/correction/History;
it is not a GoTrue login test, and the fixture does not itself prove the new duration RPC.
Without it, there is no fresh end-to-end authenticated Flutter transport proof. The prior
SQL role/transaction and unit tests do not close that gap. The complete gate also invokes
denied Python HTTP probes; it was not rerun, bypassed or supplied another project’s config.

Existing domain parsing/validation passes for all proposal shapes using ephemeral in-memory
schema placeholders, never persisted as proposed authority. Seven generated source artifacts
remain exact. Local JSON/links/whitespace and immutable-main-source checks pass. Existing
runner/export/SQL/safety evidence is reused because those sources are unchanged; see
[VERIFICATION.json](VERIFICATION.json). No hosted operation, provisioning, publication,
athlete write, Test Week, device distribution or broader Stage 2/Sprint C acceptance.
