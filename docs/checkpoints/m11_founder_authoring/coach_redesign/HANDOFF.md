# M1.1 coach-facing builder redesign

> The [focused readability/structured-preview follow-up](../readability/HANDOFF.md)
> addresses Lee's subsequent contrast and text-dump feedback. Usability acceptance
> remains pending; this redesign handoff is retained as implementation history.

2026-11-02, Asia/Makassar. Base and freshly observed published main:
`2a648c3421f60a8de7279f2a1f471d04e2b6cbda`.
**IMPLEMENTED; FOUNDER_USABILITY_ACCEPTANCE_PENDING; D8_PENDING; GATE_A_OPEN.**

Lee withheld acceptance of the initial developer-facing workspace. This bounded
redesign changes interaction and layout in the existing native source-policy Studio,
not the programme/execution model or its publication authority.
[Manual walkthrough and launch](../implementation/FOUNDER_WALKTHROUGH.md).

## Coach workflow

The programme name, week chips and readable day cards lead the screen. Open a day
into its focused session editor. Add session, Copy to day, Move and Duplicate week
are visible schedule actions. Copying sessions/weeks creates independent owners,
including exact pending intent. Destination sessions are kept when adding/moving;
week replacement explicitly confirms the entire named target week.

Strength editing uses compact sets/reps-or-hold/rest/RIR fields with ordinary names,
setup descriptions, load guidance and expandable coaching/tempo/side conventions.
Warm-up and finish instructions stay in their training sections. Running shows the
ordered steps, readable interval summary, durations and plain-English target choices.
The selected W4 Tuesday remains 42:30, four threshold repetitions and three recoveries.
Existing personalisation dependencies are retained; no athlete benchmark is entered
or confirmed while authoring a reusable programme.

Edit session / Save changes / Cancel handle version reservation and validation.
A valid save selects the new immutable version only for the edited occurrence.
Unresolved library intent can be kept in the workspace without admitting a strength
revision. Invalid prescriptions receive correction messages and remain editable.
Editing a shared occurrence splits ownership first; Cancel restores its original
selection. Editing an older selected source cannot reuse another occurrence's newer
pending draft. Cancel removes an unsaved newly added session from its day. Private
unselected owners/reservation history remain in the existing editable format.

Preview as athlete directly projects the selected source with the existing loss-aware
compiler. Pending intent is explicitly labelled unpublished/not ready for athlete
delivery. Technical target names are translated for display; raw evidence/source is
secondary. Source bodies and rule markers are unchanged. Open previews expire after
source changes. Update multiple sessions remains separate, explicitly selected and
confirmed with affected days shown. Async file pickers and dialogs reject stale work.

Download backup / Open backup use the unchanged native v4 editable envelope. Save
changes is in-memory; downloading is the durable-copy action. Browser delivery is
requested, not proved by the app; users must check the file. There is no autosave or
reload recovery. A disposable beforeunload listener requests the browser's generic
warning when changes differ from the last downloaded/opened snapshot; browser policy
may suppress it. No local storage or dependency was added.

Advanced inspection/export and canonical-source import remain available through the
secondary menu. The standalone synthetic entries/formats and existing consumers keep
their original routes. There is no new production or athlete entry.

## Fidelity and evidence

All retained selected source assets and coaching prescriptions remain unchanged:
70 days, 60 workouts, 105 working exercise occurrences. The three missing setups
still block 28 occurrences and all 20 strength sessions. A workspace save is not
library retention, admission, content approval or programme publication.

Artifact verification caught and fixed an existing random local-identity defect:
new protocol/lineage/slot IDs could start with a digit and fail the canonical package
identity grammar. Newly generated local IDs now have explicit letter prefixes.
Existing IDs/contracts are unchanged. Empty creation roots remain in private history
but leave the programme export inventory after a valid replacement or cancellation;
otherwise a newly authored valid session would still export its invalid placeholder.

The actual strength JSON backup is written/read back with distinct original/copy doses
and unresolved evidence. An actual copied/edited running TAR is independently opened
and compared phase-by-phase with the original, excluding regenerated copy IDs. The
unchanged selected source and forty-run/final-test archive regressions remain included.
These are contract checks, not complete Hybrid admission or founder acceptance.

The final test remains 10,000 m + 33 timed minutes. Every step and the general source's
outside-body walking/mobility allowance are described in the walkthrough. No numerical
source conflict was found and no coaching correction/approval was invented.

## Public interaction references

Only official public FITR materials were consulted: its
[weekly schedule and exercise tables](https://www.coachwithfitr.com/features/programming),
[exercise creation/search guidance](https://support.coachwithfitr.com/en/articles/10485696-edit-or-create-a-new-exercise-in-sets-and-reps-coach),
and [copying between days](https://support.coachwithfitr.com/en/articles/4757842-cut-copy-and-paste-training-parts-coach).
These informed the schedule-first/edit/copy interaction. No account, proprietary
asset, browser/desktop automation or third-party application interaction occurred.

## Verification and preservation

Final counts, analysis comparison, artifact hashes, preview HTTP checks and preservation
comparison are recorded in VERIFICATION.json. The earlier synthetic-lineage reset test
continues to emit its caught RangeError diagnostic while passing; it also appears in
the retained pre-redesign test log. It is not relabelled as a new failure or fixed here.

The same clean detached checkout is reused. Fresh direct-URL main checks precede work
and non-force main-only publication. Older checkouts/indices/HEADs/refs/FETCH_HEAD,
measured outstanding files and explicit .env/.temp files are compared by hash. No new
worktree, reset/stash/clean, managed lifecycle or old-ref update occurs. The bounded
bundle inventory is retained without inventing evidence about unmeasured locations.
No hosted provisioning, catalogue apply, migrations, programme publication, assignment
or athlete-data action occurs.

## Next single point

**Lee manually exercises the coach-facing workflow and records usability acceptance
or specific remaining friction.** The genuine three-record catalogue operation remains
a separate operational dependency for complete strength admission. D8/content review
and genuine publication/access remain separate. Gate A is OPEN.
