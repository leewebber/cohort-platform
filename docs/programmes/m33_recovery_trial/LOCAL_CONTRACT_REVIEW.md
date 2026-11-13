# M3.3 private Recovery approval — local contract review

## Generated-ID verification

The later [provisioning proposal](PROVISIONING_PROPOSAL.md) is implemented
locally. The fixture review below records the earlier contract and its original
evidence. The current migration pins the distinct Recovery package and protocol.
The issuer binds the real slot and occurrence to the athlete, assignment,
scheduled date and retained seal. Its one immutable row also serves as the
receipt for an identical retry. The reader checks the athlete's active
assignment and due, unstarted occurrence using the runtime IDs.

The disposable gate applied only the Recovery migration and found an empty
final dry-run. Normal retained publication and athlete acquisition generated
both IDs. Exact publication and acquisition retries reused the same records.
Two concurrent issue requests returned one `approved` and one
`already_approved`. A changed request conflicted. Separate transactions held
the real start and end operations open until the issuer was observed waiting.
After each operation committed first, issuance refused and the table was
still empty. The issuer refused both a wrong seal pin and drift in the live
workout. The reader also refused drift after issuance.

The authenticated Recovery journey preserved Keep Original, refused stale
acceptance, accepted only the optional lateral-raise omission and restored
the saved session and actuals through a restart simulation. It produced one
History entry. The before and after digest of the existing disposable M3.2
full and partial History rows, actuals, outcomes, approval and publication
matched. Three source checks, four authenticated M3.1/M3.2 journeys, the
Recovery journey and all six safety groups passed. Changed Dart analysis
reported no issues.

## Fixture-based review

Base: `e7cadfc4eb4ef7e665770d91fadabb28d5a3ebc3`. This is the first bounded
M3.3 suggestion in the [Founder release plan](../../planning/Founder_Release_Plan_M0_M10_v1.md).
The schema migration installs no approval and performs no publication or athlete
writes. The Time approval and generic adaptation contracts are unchanged.

| Pin | Value |
|---|---|
| Private v2 version | `7e1d15e7-20ee-46d4-b5e9-0d6449010330` |
| Slot | `7e1d15e7-20ee-46d4-b5e9-0d6449010331` |
| Occurrence | `7e1d15e7-20ee-46d4-b5e9-0d6449010332` |
| M3.2 canonical package | `a8c76e1f4745929da17c9a929b169372c6475db21755f870dcb4100ead8d9050` |
| Protocol / slot key | `protocol-cfdd230d-4fbc-42fa-b571-b10d48bc06e9` / `M32-W01-D01-STRENGTH` |

The service-role-only issuer attaches one immutable approval to the retained
publication after the exact occurrence has been materialised. It checks the
retained package and current scope seal and verifies the exact authored graph.
It accepts only the three identity pins and cannot take a caller-authored
workout, amount of rest, or omission. The stored scope fixes the athlete,
assignment, local date, seal and omitted block ID. The authenticated reader
checks the caller via `auth.uid()`, rechecks the same active, due and unstarted
occurrence and returns no approval if any part of that scope differs.

The app compares the sealed original with its cached and persisted prepared
workout. A fresh **Poor Sleep** response belongs to the open review. Keep
Original makes no write. Accept rereads the approval and applies only the
reviewed omission: **45 → 30 min estimated**, retaining the five-minute easy
walk and bench press **4 × 8 with 120 seconds’ rest** and omitting the optional
lateral raises **3 × 12 with 60 seconds’ rest**.

Run the [disposable gate](../../../supabase/tests/run_m33_recovery_trial_gate.sh)
to apply the exact migration, provision synthetic local accounts and exercise
the authenticated boundary. Disposable triggers supply the slot UUID before
the real retained publisher seals the graph, and the occurrence UUID before
the real acquisition RPC inserts it. The test uses the real Recovery reader,
start, result save, completion and History services. It simulates restart with
a fresh prepare service and copied persisted bytes. The review and result
screens run as Flutter widgets; there is no installed-device evidence.

Before a hosted proposal, review the trial source and identity provisioning.
The current publication and acquisition paths generate slot and occurrence IDs.
The published M3.2 package also owns its original programme lineage/version;
the same canonical package cannot be published a second time with a new UUID on
that lineage/version. A production proposal must resolve those constraints with
an explicitly reviewed Recovery identity and source pin that preserve the exact
workout, without reusing M3.2’s existing publication or mutating its trial.

## Fixture-based verification

The gate passed with only the Recovery migration pending before apply and an
empty dry-run afterward. Real authenticated reads allowed only the pinned
athlete and occurrence. Wrong athlete, assignment, version, slot, occurrence
and protocol, Time-only approval, future and overdue dates, ended assignment,
started occurrence and graph drift were refused. The real End RPC was exercised
inside a rolled-back disposable transaction. Date and graph drift were
introduced only in disposable SQL. Athlete table reads and writes and issuer
calls were denied; the trusted issuer was idempotent and the storage trigger
rejected an update.

The widget comparison used the authenticated reader with no approval fixture
loader. Keep Original preserved the persisted plan. A closed review and a
changed date before acceptance were refused. A new Poor Sleep review accepted
only the omission. Restart replay restored the same session and four logged
bench sets of 8 reps at 16 kg. Completion yielded one outcome and one History
entry. Both existing source-pin checks and all six local safety groups passed;
changed Dart analysis was clean.
