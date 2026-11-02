# Manual coach-builder walkthrough

Updated 2026-11-02 after Lee withheld usability acceptance of the initial workspace.
[Redesign handoff](../coach_redesign/HANDOFF.md) · [Readability/structured preview follow-up](../readability/HANDOFF.md). **Manual acceptance remains pending.**

Start from the repository root:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8313 --target lib/main_programme_studio_founder_preview.dart --no-pub
```

Open the printed URL manually. No browser/desktop automation is required or authorised.
The entry starts with the selected ten-week programme, not an empty workspace.
Use Ctrl-C in the launching terminal to stop it.

1. Select **Week 1**, Monday's **Open session**, then **Edit session**. Change the
   first exercise's **Sets** from 3 to 4 as a disposable usability exercise, then
   **Save changes**. Expect the five complete exercise prescriptions, warm-up,
   notes and finish to remain. The message says the changes are kept in this
   workspace; the chest-supported row is still **Awaiting library approval**.
   Save retains editable intent without fabricating a publishable strength version.
2. Choose **Copy to day**, select **Saturday** under **Week 1**, then **Confirm**.
   **Back to programme** → Saturday's **Open session** → **Edit session**. Change
   the first exercise's Sets to 5 and **Save changes**. Expect Saturday to show 5
   while Monday remains 4. These are independent copies. **Move** relocates a
   session while keeping other sessions on its destination day. **Duplicate week**
   replaces a named target week only after confirmation and creates independent
   session copies. None of these actions calculates progression.
3. **Back to programme** → **Week 4** → Tuesday's **Open session** → **Edit session**.
   Expect **4 × 5 min — threshold pace, 90 sec easy between** and **42:30** total:
   10 min easy + three 20 s accelerations/40 s recoveries; four 5 min work periods
   and only three 90 s recoveries; 5 min very easy run/walk cooldown. Expand a work
   step to see **Training target: Personalised threshold pace**. This references
   the existing approved target rule; athlete inputs are selected/confirmed separately.
   Use **Cancel** to leave the prescription unchanged, or save an intentional edit.
4. Use **Preview as athlete** directly from a session. Expect ordered warm-up items, separate movement cards or grouped running intervals, labelled dose/load/rest/RIR and expandable coaching notes. Inline and modal use the same renderer. The amber **Coach readiness** panel is separate from athlete instructions. Expect the exact selected
   saved prescription, or explicitly labelled **Unpublished changes** when pending
   intent is being previewed. Then **Download backup**, check that the JSON file is
   present, and **Open backup** → select it → confirm **Open backup**. Expect the
   Monday/Saturday differences, notes, full running steps and unresolved status to
   survive. Read-only preview is not editable reopening; the backup is the editable file.

**Save changes** keeps work in the current in-memory workspace. **Download backup**
requests a local editable JSON file and marks that snapshot as the backup baseline;
the browser owns actual delivery, so check Downloads. There is no autosave, local
recovery or cloud storage. Reload returns to the initial selected programme and loses
work since the last backup. Open the downloaded backup manually to recover that
snapshot. Where the browser permits it after user interaction, leaving/reloading with
changes requests its generic warning; browsers can suppress it.

**Cancel** restores the last kept session intent. A cancelled newly added session is
removed from its day; private identity/reservation history may remain. New valid
saves select a fresh immutable saved version for the edited occurrence. Other uses
stay unchanged. **Advanced session tools → Update multiple sessions…** is the separate
operation for replacing explicitly selected days, with an affected-day confirmation.

Exact rest is one field; **Prescription options → Show rest range bounds** reveals separate bounds without changing the dose. Rep/RIR modes and detailed source guidance are disclosed only when needed.

The three missing library setups still block 28 exercise occurrences and all twenty
complete strength sessions. The full selected programme cannot yet be prepared for
athlete delivery. Corrections to invalid doses remain required; a backup can retain
invalid text for later repair. No library substitution or invented published identity
is used to bypass this boundary.

**Advanced tools → Advanced inspection & export** retains the existing source,
validation and prepared canonical export path. A prepared file is not programme
publication. Complete export still requires validated selected sources, no pending
session drafts and genuine library evidence. Importing canonical sources creates
editable snapshots with unknown historical authority, not restored private editing
history or approval. Older synthetic v1/v2/v3 backups continue to use the original
`lib/main_programme_studio_composition_preview.dart` entry; this founder entry uses
native v4 backups.

The final Sunday test is unchanged: 15 min easy, three cycles of 20 s stride plus
100 s recovery (including after the third), 2 min easy settling, 10,000 m, 10 min
cooldown. That is 23 min before + actual 10K time + 10 min after. The general source
also retains 3–5 min walking and untimed mobility before, plus 3–5 min walking after,
outside the native 33-minute body. This is a retained proposal, not blanket coaching
approval. The native body is not the entire preparation/finish allowance.

Record Lee's actual result separately. Automated checks do not establish usability,
browser picker/download acceptance, coaching approval or D8. Gate A remains OPEN.
