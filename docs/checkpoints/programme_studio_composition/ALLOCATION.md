# Proposed Programme Studio composition slice — allocation only

2026-10-12. PROPOSED_AWAITING_FOUNDER_IMPLEMENTATION_APPROVAL. No implementation,
repository edit, commit, test/build, fetch or hosted contact performed for this allocation.
Inspected clean `codex/programme-studio-d2` at exact published baseline
`6f83f7324fe0ea585f6c7f3a4ba34151ee588ec6`. Local origin/main equals that SHA,
but is a cached tracking ref in this task; no new remote verification was authorised.

The binding roadmap names Sprint D (controlled structured authoring), not a
numbered composition sprint. Call this the **proposed composition slice**.
Accepted D1/D2 supply its bounded foundations; broader Stage 2/C remain open,
four record-dependent phone checks remain pending. Committed D2 evidence records
non-green full analysis: 367 diagnostics, 110 warnings, 257 info, zero errors.
Those checks are historical here, not rerun or claimed as new allocation passes.

## Recommendation and exact scope

Compose the existing D1 and D2 authoring components in one isolated transient
preview. Use exactly one synthetic v1 programme, initially the accepted
`d2PackageTree` shape: one week, two existing days (training/rest), one required
slot, existing nonempty locked contracts and D2 R1. Keep one D2 strength lineage;
local frozen revision numbers may increase, with cancelled reservations retaining
gaps. This does not create a new strength representation or a second editor.

Programme operations reuse D1's existing allowlist: name, description,
coaching_intent, primary_goal, sessions_per_week; existing week/day title and
coach_note; existing training/rest day type; required-slot add/remove/move/order,
time_of_day, display_title, coach_note and explicit exact session_key choice.
New required slots reuse the existing locked template. Existing identity, owner,
version, duration, phase/week/day keys/counts/intents, optional semantics,
progression, adaptation, invariants, assessments, evidence and comparison
contracts stay locked. Invalid intermediate edits are allowed to remain visible
but never export/review as successful. For example removing referenced W1D1S1
fails existing contract validation; the editor must not repair its assessment.

Session operations remain precisely accepted D2: one strength block, one/two
distinct fixture exercises; session/block titles and notes; optional existing
session duration; exercise selection/order and optional display label; positive
integer sets/exact reps, optional positive rest seconds, opaque tempo/cue;
unspecified/bodyweight/positive finite kg/integer RPE 1–10. Do not infer values.
Optional absence stays distinct from authored values. The ceiling is a local
D2 authoring restriction, not a global schema rule.

There are three distinct actions: **freeze session**, **admit frozen revision**,
**select admitted revision for a required slot**. R1 starts admitted/selected as
an explicit seed. No subsequent freeze/admission automatically changes a slot.
The programme session list contains all admitted revisions (including unselected
ones); admission is append-only for this slice. Catalogue removal/replacement,
multiple session lineages and arbitrary imported revisions are excluded.

## Repository evidence and actual prerequisite gaps

All references are relative to the clean D2 root given above.

- `docs/architecture/Programme_Studio_v1.md:81` and `:164`: Plan Package YAML
  and protocol authoring YAML remain canonical; Stage 2 generates those sources,
  never a parallel programme store. Existing compiler/import authorities remain.
- `docs/architecture/Launch_Programme_Library_v1.md:330` and `:466`: author
  bodies and package, compile and review, with publication separately approved.
  No named/approved composition sprint is established by the roadmap.
- `docs/checkpoints/programme_studio_d1/FINAL_REVIEW_AND_ACCEPTANCE.md` and
  `docs/checkpoints/programme_studio_d2/FINAL_REVIEW_AND_ACCEPTANCE.md`: accepted
  bounded authoring, immutable identities, current-source review and qualifications.
- `lib/features/programme_studio/authoring/programme_authoring_fixtures.dart:20–36`: sourceTree is recreated
  from fixture ID (`contracts`/`empty`), not parsed from a supplied source;
  bundle bodies are fixed protocolSql. A new ID would not supply a new trusted tree.
- `lib/features/programme_studio/authoring/programme_authoring_controller.dart:17–26,341–483`: trusted baseline
  is fixed; scopeSkeleton retains sessions; only two fixture IDs pass; catalogue
  validation requires fixed SQL column declarations, exact draft/unpublished
  tuples and equal source/catalogue counts. D2 reader text uses positional rows
  without those declarations. Passing D2 text to D1 unchanged cannot work safely.
- Both existing screens accept externally owned controllers. D1's fixture picker
  still enumerates only D1 fixtures; D2 exposes its fixed-wrapper programme
  selection/export. Composition needs narrow embedding hooks to show the proper
  source label and route programme actions to the composed programme.
- `lib/features/programme_studio/protocol_authoring/synthetic_session_revision_catalogue.dart:7–85`: immutable
  exact-source snapshots, max+1 reservations, no-op refusal, post-await collision
  checks exist. Freeze does not admit into a separate programme catalogue.
- `lib/features/programme_studio/protocol_authoring/protocol_authoring_controller.dart:346–462`: async generation
  guards, freeze and standalone selection exist. The standalone selection also
  adds a revision to its own package; it cannot be reused as the composition's
  separate admission action. Read-only `revisions` and compiler access suffice
  to consume genuine frozen entries without changing revision allocation.
- `lib/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart:36–89`: exact UTF-8
  source digest, identity, immutable exercise version bindings and typed meaning;
  existing parser/validator/resolver/mapper/block/execution composition is reusable.
- `lib/features/programme_studio/protocol_authoring/synthetic_strength_review_bridge.dart:28–94`: project()
  recreates a fixed package and assumes one week/first day/one session.
  It cannot review D1 schedule edits. Its readerText/verifyReaderText methods
  at :195/:209 are reusable independently of that fixed project() method.
- `lib/features/programme_studio/projection/programme_review_projector.dart:587–600`: Founder fallback uses
  title lookup; SQL reader path uses protocol ID. Reuse actual Studio through
  verified in-memory reader text; do not populate founderYaml or use title fallback.
- D2 has no complete combined handoff/reopen mechanism. Founder YAML does not
  contain protocol/lineage/revision tuple; programme YAML contains references but
  no bodies, mappings or digests. This missing transport is an allocated local
  review-reconstruction feature, not a shared compiler defect or Stage 3 import.

These are concrete composition gaps to implement after approval. There is no
identified external/hosted prerequisite, missing exercise identity foundation or
need to change shared schemas/hashes. A shared-contract requirement discovered
later is a report/stop boundary, not permission to broaden this allocation.

## Smallest compatible D1 extension

Add an explicit local authoring source/provider contract: original programme
bytes, deeply detached trusted baseline, fixture classification/label, exact
catalogue check and bundle construction from captured inputs. Keep the existing
ProgrammeAuthoringFixture path as the default adapter, retaining its present
ID-derived baseline, fixed SQL validation, refusals and tests. Do not merely add
`composition` to its ID allowlist or make arbitrary caller JSON trusted.

The dedicated composition provider takes a fixed trusted synthetic seed plus an
immutable admitted-source snapshot. Preserve D1's entire locked skeleton except
that `sessions` is checked against **exactly** that snapshot through a separate
catalogue rule. This is not free session authoring. A controlled admission action
appends one compiler-verified reference and bound source atomically, invalidates
review and retains every unrelated draft edit/locked contract/original diff
baseline. Do not reconstruct the D1 controller to refresh its catalogue.

Reuse D1 edit methods and YAML writer. Its legacy synchronous validation remains
unchanged by default; composition prepares verified bodies with the async joint
coordinator, supplies a captured source bundle, then checks D1's exact candidate
and actual Studio review. Avoid mutable provider state being read midway through
validation. Existing D1 screens/entries must retain their current behaviour.

## Concrete author workflow

1. Open the dedicated combined preview. Show original frozen R1 and a programme
   with R1 explicitly seeded in its catalogue/required slot. Clearly label synthetic,
   unpublished and transient. No validation success is assumed on opening.
2. In the reused D2 editor, open a frozen revision, create a separate reserved draft,
   edit supported fields, validate exact deterministic writer bytes and inspect
   original-parent source diff. Invalid/unsupported drafts retain actionable errors
   and source; no current draft review/hash/export. No-op freeze remains refused.
3. Freeze a changed draft using existing D2 rules. The resulting revision is frozen
   locally but **not admitted**; programme references still point at R1. Editing it
   again requires a new reserved draft. No mutable alias to its tree/body is retained.
4. Explicitly choose and confirm **Admit frozen revision**. Recompile its retained
   exact bytes/tuple with the fixed fixture profile; compare digest, semantic meaning,
   resolved bindings and expected identity to the owning D2 frozen entry. Add its
   deterministic session key/reference to the programme catalogue, without selection.
5. Explicitly choose the admitted tuple for a particular existing required slot,
   confirming the old/new key, protocol, lineage, revision and digest. Cancellation
   changes nothing. Other slot references stay unchanged. Names are display labels.
6. Edit permitted programme fields/placement through D1. Explicitly validate and
   refresh the **combined review**: all declared sources and every programmed slot
   must resolve. Show actual schedule/metadata/full prescriptions plus the binding
   receipt, source diffs and separate package hash/source digests.
7. Export a complete local handoff only from a current joint receipt. Separately
   expose programme YAML and exact selected Founder sources for inspection/copy,
   with a warning in the product wording that programme YAML has no session bodies.
8. Reopen the complete handoff into a separate **read-only reconstructed review**,
   revalidate everything, then re-export deterministically. Do not overwrite the
   live author workspace, select/admit anything there or resume D2 revision history.
   Reload/full workspace reset returns the original synthetic R1 seed and discards
   transient work; pending operations are invalidated before disposal/replacement.

## Admission and immutable ownership

Live admission accepts only an existing frozen D2LocalRevision from this
workspace's owning catalogue, never a mutable working receipt or arbitrary
caller-created tuple. Support only the accepted D2 lineage, protocol-ID derivation,
revision/import-key convention, unpublished local state and fixed fixture profile.
The profile is a frozen snapshot of the exact two definitions/mappings and versions;
compute a deterministic fingerprint from their complete canonical serializations.
Do not import/edit external exercise definitions or resolve names.

Reject missing/unfrozen/foreign/unsupported bodies; tuple/import-key mismatch;
retired/unpublished/ambiguous/conflicting/missing exercise identity; duplicate
exercise targets; source/digest/semantic/binding mismatch; duplicate session key;
protocol ID reuse under another tuple; lineage+revision reuse under another
protocol; or conflicting source for an existing tuple. Repeat admission of the
identical tuple, exact bytes and bindings is an idempotent no-op (no duplicate or
selection change). Packet duplicate entries are malformed and rejected even if equal.

Strings retain exact UTF-8 source bytes; copy/lock tuple fields, binding maps,
reference records and catalogue collections. Never reference a working tree or
resolve to 'latest'. Recompile from retained bytes for admission, joint validation,
export and reopen; cached typed models are derived receipts, not authoring authority.
Admission failures leave the existing catalogue/references intact but clear the
current joint success and expose a located error. Rejected bytes remain available.
Published/withdrawn states are not new authorable lifecycle choices here.

## Joint freshness and review proof

Use a composition controller owning both externally injected authoring controllers,
an append-only admitted catalogue and monotonic workspace/operation generations.
Capture programme revision, admitted-catalogue epoch, D2 controller generation and
joint operation token with immutable input snapshots. A committed current receipt
contains exact programme YAML bytes, its source digest and existing canonical
compiled bytes/package hash, every declared session key/tuple/source digest/
resolved exercise-version binding, and every slot-to-revision binding used in review.

| Event | Required consequence |
|---|---|
| Programme edit/reopen/reset, required-slot selection or placement | Clear D1 current success and joint receipt/export immediately; frozen session sources and D2 standalone session receipt stay intact. |
| D2 draft create/edit/reset/reopen/cancel or failed session validation | D2 invalidates its receipt; conservatively clear joint success/export. Existing programme references/frozen admitted snapshots do not change. |
| A working session draft remains open | Combined validation/export is blocked until freeze or cancel; show that the selected frozen programme source is unchanged. |
| Successful freeze (still unadmitted) | Clear joint receipt conservatively; add only to D2's frozen catalogue, not programme sessions/slots. |
| Successful new admission | Atomically append source+reference, increment admitted epoch and programme revision, clear D1/joint receipts. D2 frozen receipt is preserved. |
| Exact duplicate admission/cancelled confirmation | No catalogue/selection change. A successful idempotent no-op need not invalidate an otherwise current receipt. |
| Failed admission/selection/joint validation/export/reopen | Clear joint success/export; retain prior immutable inputs and actionable errors. Never restore stale success. |
| Dispose/full workspace reset/another async operation | Invalidate operation tokens before replacement; pending success and failure results are ignored. |

Read-only revision navigation may conservatively invalidate joint receipt because
D2's existing generation changes; it must never rewrite admitted sources/references.
Busy/render notifications alone need not invalidate input generations. Joint
validation calls the pure compiler directly rather than triggering D2.validate()
and changing its own captured token. Check tokens after each await, before any
catalogue/reference/current-receipt commit, after notifying success, and again at
export/copy consumption; cover synchronous listener edits and queued microtasks.
Atomic admission/selection must not partially append records when asynchronous
verification becomes stale. Latest request wins; stale errors cannot replace newer
success either. A previously opened Studio panel/export dialog must lose current
status or close when its receipt changes, not keep a misleading successful view.

For Studio: compile the exact D1-exported programme YAML with unchanged
PlanPackageCompiler; independently compile every exact admitted Founder source
with SyntheticStrengthSessionCompiler; compare tuple/digest/bindings; generate
and verify the existing bridge's complete reader rows; project one immutable bundle
through the actual ProgrammeReviewProjector. No founderYaml/title fallback, SQL
execution, manually transcribed prescription or parallel review model. Inspect
all weeks/days/slots (not the D2 bridge's fixed first-slot check); unresolved,
unsupported or conflicting bodies/errors fail closed. Verify each projected
slot's reference and complete rendered supported body against its exact entry.

## Hash semantics

Existing package hash keeps its canonical schedule/metadata/reference meaning and
continues to exclude session bodies. A body change under a stable tuple can retain
that hash; this must be demonstrated in a pure compiler/hash test, while live
admission still rejects replacement of that tuple. A legitimately selected new
revision may change the package hash because its references changed. A programme
metadata edit changes the package hash while retained source digests remain equal.

SHA-256 of each exact UTF-8 Founder source binds bytes, not approval, publication or
historical freeze provenance. Same-title/different-revision sources remain distinct.
The joint receipt reports ordered **slot → session key → explicit tuple → source
digest → exact exercise-version bindings** plus exact programme bytes/package hash.
There is no new production 'joint programme hash' or reinterpretation of old hashes.
A packet digest, if used for transport checking, must not be a prescription identity.
Text diffs retain original programme imported bytes and each D2 draft's exact
frozen-parent bytes; semantic comparison uses existing canonical/typed meaning.
Canonical export does not promise preservation of comments/formatting. Packet
reopen establishes a new review baseline and does not reconstruct old edit diffs.

## Complete deterministic local handoff and bounded reopen

Use one strict, versioned deterministic JSON **transport envelope** for explicit
copy/paste export/reopen. It is generated source packaging/evidence, not a Studio
programme store, executable import payload, persisted service or new canonical
programme schema. Its authoritative payload remains the existing two YAML lanes.

Required contents:
- transport kind/version identifying only this synthetic composition profile;
- complete canonical v1 programme YAML as an exact string;
- known immutable fixture profile ID/version/fingerprint (complete definition and
  mapping snapshot used by the fixed local resolver; supplied alternate profiles fail);
- exactly one entry for every declared programme session reference, selected or
  unselected: session key, explicit protocol/lineage/revision tuple, exact Founder
  YAML string, computed UTF-8 SHA-256 and exact resolved exercise/version bindings;
- computed existing package hash and derived slot-binding inventory for verification.

Include every declared source, not just selected bodies: admission expands the
package catalogue and D1's equality rule must remain complete. Unadmitted frozen
entries, mutable drafts, reservation high-water marks and freeze histories are
not part of this handoff. Reader text, typed models, review widgets, timestamps,
validation-success booleans and in-memory generations are excluded; regenerate them.
Use stable sorted envelope keys, explicitly sorted source/binding inventories,
existing canonical programme collection order, exact source strings, UTF-8/LF and
one final newline. No filename/path lookup, ZIP, file picker, browser storage,
automatic download/service or dependency is needed for this slice.

Reopen validates kind/version/types/duplicates/unknown fields and all existing
source guards; exact fixed seed locked contracts except allowed D1 edits; exact
catalogue equality, key/tuple uniqueness, profile fingerprint, bytes/digests,
resolved bindings, all slots and package hash. R1 must retain its exact known
fixture source. Never trust serialized validation/approval flags or hashes as
proof without recomputation. Missing/extra source, title substitution, edited
source/digest disagreement, unsupported source or newer transport version fails
closed; preserve rejected input and do not partially replace any prior state.
For every later revision, compare the entire D2 wrapper against the retained
R1 canonical wrapper with only the revision-specific import_key updated and the
session subtree excluded, matching D2 controller intake rules. Descriptions,
week/day wrapper notes or other locked wrapper edits must not slip through the
more permissive pure compiler guard.
Sources altered together with recomputed digests are newly supplied synthetic
inputs, not proof of an earlier freeze/approval; reopening establishes a new
validated read-only source binding only. It must never create live editable D2
catalogue entries or claim signed/historical provenance.

Reopen occurs in a separate read-only review with a new token, rederives the exact
binding inventory/Studio model, and supports export→reopen→export byte idempotence.
It does not restore working drafts, frozen-parent edit history, reservations or
editable revision allocation. Continuing authoring after cross-restart archive
restore is expressly excluded and would need a new allocation. Programme YAML
alone must refuse complete-review reopen with a 'session sources required' error;
it can remain independently compilable/inspectable but is not a complete handoff.

## Expected components (proposed filenames, not existing implementation)

New under `lib/features/programme_studio/composition/`:
- `synthetic_composition_fixtures.dart`: detached accepted D2 seed/profile.
- `synthetic_programme_revision_catalogue.dart`: immutable append-only admission
  and source/reference equality, separate from D2 reservation/freezing catalogue.
- `synthetic_composition_review_bridge.dart`: programme-aware wrapper reusing
  existing readerText/verifyReaderText and actual projector, with all-slot checks.
- `synthetic_composition_controller.dart`: joint ownership, admission/selection,
  generation guards, receipt, export/reopen/reset; no persistence/client services.
- `synthetic_composition_handoff.dart`: strict complete source-envelope codec.
- `synthetic_composition_screen.dart`: thin combined shell/admission/actions/receipt;
  reuse D1/D2 forms/screens and actual Studio presentation.
New dedicated `lib/main_programme_studio_composition_preview.dart`.

Narrow existing changes:
- `lib/features/programme_studio/authoring/programme_authoring_fixtures.dart` plus optional new
  `lib/features/programme_studio/authoring/programme_authoring_source.dart`: explicit provider seam with unchanged
  legacy fixture adapter; do not rewrite approved fixture sources.
- `lib/features/programme_studio/authoring/programme_authoring_controller.dart`: provider injection, controlled
  catalogue append/invalidation, isolated composition scope/catalogue validation;
  retain all legacy default policy and allowlisted edit behaviour.
- `lib/features/programme_studio/authoring/programme_authoring_screen.dart` and
  `lib/features/programme_studio/protocol_authoring/protocol_authoring_screen.dart`: optional embedding/source-label/
  coordinated review/export hooks. Hide standalone fixed-programme controls in
  composition mode; default behaviour remains unchanged. Full workspace reset and
  complete-handoff reopen live in the coordinator, avoiding bare-YAML partial reset.
- D2 controller/catalogue/compiler/writers/bridge should remain unchanged unless a
  strictly read-only access seam is demonstrably necessary; exposed revisions and
  public bridge methods already provide the needed data. No new prescription parsing.
New meaningful tests under `test/programme_studio/`; existing D1/D2 tests retained;
durable approved checkpoint under `docs/checkpoints/programme_studio_composition/`
only after implementation approval, plus CURRENT_CHECKPOINT pointer then.

## Acceptance criteria

1. One combined workflow proves frozen changed revision is first unadmitted, then
   admitted but unselected, then selected only for confirmed slot. R1 exact bytes,
   earlier refs and all locked contracts remain unchanged throughout.
2. Admission rejects every identity/source/profile/conflict case above; exact
   repeat is idempotent; duplicate packet entries and unsupported source refuse
   without dropping data. Same-title/different-dose revisions render independently.
   External mutation of exposed lists/maps/trees cannot alter snapshots/receipts.
3. Complete deterministic package/Founder exports and packet round trips preserve
   exact frozen bytes/identity/bindings and existing canonical/typed semantics.
   Programme YAML alone cannot reconstruct full review. Missing/extra/unsupported
   sources and tampered claims fail closed; canonical source/hash rules unchanged.
4. Joint actual Studio rendering follows programme slot moves/additions/order and
   exact references across every slot. No first-slot/title shortcut, dosage loss,
   omitted optional values or misleading hash/body identity claim.
5. Controllable-Future integration races: edits while compile/admit/select/export/
   reopen are pending; success/failure delivered out of order; freeze/cancel/reset/
   disposal; synchronous and microtask listener edits at completion; already-open
   Studio/export views. Stale results never become current or partially change state.
6. Widget coverage for separate admission/selection, no-op/invalid session freeze,
   required-name error, unchanged selected programme during draft, programme edits,
   locked-reference failure, packet rejection/reopen/read-only status, reset/cancel,
   keyboard/mouse, narrow layout and large text. Retain D1 rest-day recovery and
   malformed-extra-row refusals and D2 immutable/async/adapter compatibility.
7. Run existing Studio/D1/D2/Founder/root authored-package, exact identity,
   strength/block/execution/revision and canonical-package regressions; protected
   v1/v2 goldens/published artifacts/compiler/schema/hash stay byte-identical.
8. Fresh full pre-edit/final analysis with exact diagnostic comparison to committed
   367 (110 warning/257 info/0 error) baseline; investigate any difference. Require
   zero errors, zero new diagnostics and zero changed-file diagnostics. Full
   inherited analysis remains non-green; no suppression/shared contract alteration.
9. All six unchanged safety groups pass: architectural_boundaries,
   coaching_integrity, adaptation_contracts, programme_adapt_ui_contract,
   completion_identity, staging_production_isolation. Diff/document links pass.
   Import graph includes nested importer package; no production/other preview entry
   reaches composition, no hosted/auth/persistence/write/athlete service reachable,
   read-only store mutation attempts zero. No DB gate/migration is needed.
10. Compare protected base file hashes and all three preserved checkout snapshots;
    no original 95-path/index/HEAD/.temp change. Record exact commands/results.
11. Start only the dedicated cached local Chrome preview; agent exercises workflow
    and error/race/reopen states, then founder visually reviews: freeze→admit→select,
    metadata/schedule + readable exact bodies, stale/invalid state, complete export/
    reopen and reset. Record accepted HEAD separately from local tests/device proof.
    Founder visual review is required before integration, not a device build.

## Exclusions and implementation strategy

Exclude real content/programme families/identity authoring; persistent catalogue,
workspace archive/resume, browser storage or file services; hosted publication/
import/SELECT/writes; production wiring/athlete state; v2 running-policy editing,
other session/block formats, tracking/profiles/calculations, contract authoring,
migrations/release changes, device build/install, Stage 3 and broader Stage 2/C closure.

After approval create a **new managed worktree** at exact
`6f83f7324fe0ea585f6c7f3a4ba34151ee588ec6`, branch
`codex/programme-studio-composition`; verify clean base/branch and no pre-existing
branch conflict. Do not switch any existing checkout. Preserve dirty original
main at a331f52967e1887c4435cccc8f1ecfa192028cd6 (95 paths), clean D1 at
6318f319db15ff7a42283c7719dc22a6dc28daa5, and clean accepted D2 at the allocation
base. Snapshot indices, tracked/dirty contents, .temp presence/content/index flags
and HEADs with GIT_OPTIONAL_LOCKS=0 before/after. No dirty-file bulk copy, stash,
reset, clean, local-main advance, fetch, integration or publication implied.
Persist approved allocation/authority in the new checkpoint; implement/tests/focused
local commits only if founder grants those actions. Stop for Chrome visual review.
