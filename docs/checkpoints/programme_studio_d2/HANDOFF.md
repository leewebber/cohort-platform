# Programme Studio D2 — locally verified, awaiting founder visual review

2026-10-12. **D2_IMPLEMENTED_LOCALLY_AWAITING_FOUNDER_VISUAL_REVIEW**.
No integration, fetch, push or publication. Base/cached origin/main:
`6318f319db15ff7a42283c7719dc22a6dc28daa5`; cached ref is not a fresh remote check.
Branch `codex/programme-studio-d2`; managed worktree
`/Users/leewebber/.codex/worktrees/programme-studio-d2/cohort_platform`.

Authority: [approved scope](./APPROVAL.md), retained [allocation](./ALLOCATION.md)
and [implementation instructions](./IMPLEMENTATION_HANDOFF.md). Preparation
wording in those byte-identical files is historical. This implementation does
not accept broader Stage 2 or Sprint C; four record-dependent phone checks remain
pending. [D1 acceptance](../programme_studio_d1/FINAL_REVIEW_AND_ACCEPTANCE.md),
[Studio contract](../../architecture/Programme_Studio_v1.md) and
[launch roadmap](../../architecture/Launch_Programme_Library_v1.md) remain binding.

## Delivered workflow and boundaries

The dedicated [entry](../../../lib/main_programme_studio_protocol_authoring_preview.dart)
opens the exact comment-bearing R1 fixture source, retaining its tuple, bytes and
SHA-256. Create a separate reserved draft; edit one straight-sets strength block
with one or two distinct fixture exercises. Supported: session/block titles and
notes, optional positive integer estimated minutes, exact exercise selection/order,
positive integer sets/exact reps, optional positive integer rest seconds/tempo/cue,
and unspecified/bodyweight/positive finite kilograms/integer RPE 1–10. The minute
field is explicitly included in the approved allocation. RPE ceiling applies only
to this authoring intake. Names and editable labels never resolve identity.

Strict complete-tree intake precedes the existing Founder parser, validator,
transitional-ID bridge, canonical resolver and prescription mapper. Missing,
ambiguous, unpublished, retired or conflicting targets fail closed. Extra source
fields, unsupported prescription modes, overlapping aliases, extra blocks/nodes,
duplicate keys, YAML extensions and malformed values are refused with locations;
rejected source remains available for correction/reset. No partial export.
Absent optional values remain absent; bodyweight has no invented numeric value.
Exact-map reps and the supported RPE intake alias normalize to canonical scalar
reps/load. Parser-defined trimming/empty normalization is explicit.

The deterministic writer emits the complete supported Founder tree with stable
key ordering, quoted strings and one final LF. Validation compiles exactly those
exported bytes. The pure application adapter checks complete typed prescription
JSON, block validation and executable projection. A local derived reader-text
adapter feeds actual Studio from an exact Plan Package export. It independently
checks tuple, source digest, protocol ID, exercise bindings and body; it omits
Founder title lookup. Same-title/different-dose revisions are tested. Derived
reader text is recomputable data, never executed or persisted.

All edits, reopen/reset/cancel/selection and failed validations clear current
review/hash/export. Generation checks discard stale validation/export/freeze/
selection results. Open review/export views observe invalidation; a stale export
loses its bytes and Copy action. Freeze revalidates and appends an immutable,
unpublished local snapshot. It cannot replace R1 or select the programme.
Selection is a separate confirmed action against an exact frozen revision; R1
catalogue/source and earlier programme entries remain intact. Editing after
freeze requires a separate later draft.

Tuples use the existing revision identity and protocol-ID generation conventions.
Founder YAML does not encode that tuple: this transient local catalogue binds it
to exact source bytes/SHA-256 and typed body. Source-byte SHA-256 is displayed
separately from the unchanged Plan Package hash, which excludes session bodies.
A body edit can leave that package hash unchanged. Diff baseline is the original
parent snapshot's exact bytes, including formatting/comments, never a rewritten
baseline. Canonical draft export promises supported semantics, not formatting
preservation. Semantically unchanged drafts cannot freeze redundant revisions;
edit/cancel remains available. Abandoned reservation numbers are not reused.

The catalogue and programme are in memory only; reload discards additions and
restores exact R1. YAML alone cannot restore immutable catalogue identity across
processes. No autosave, persistence, production navigation, real content,
profiles, hosted import/publication, athlete writes, v2 running editing, tracking,
migrations, release changes or device build/install.

## Bounded adapter deviation

The repository's existing transitional port adapter is a tool-only file outside
Flutter's `lib` import boundary. It remains unchanged. A D2-only port adapter
wraps the unchanged shared `InMemoryTransitionalExerciseIdBridge` with existing
resolution result types; conformance tests compare resolved/invalid/unmapped/
retired/conflicting outcomes against the tool adapter. Canonical resolution and
shared parsing/validation/mapping/compiler/schema/hash code are unchanged. There
is no new production compiler or mapping dataset. Narrow existing Studio changes
format typed kilograms/bodyweight/RPE, tempo and rest; existing free-text and
athlete-selected presentation regressions remain compatible.

## Fresh verification

[Machine-readable evidence](./VERIFICATION.json) records log digests and commands.
278 affected root tests passed, including writer/controller/widget/adapter,
immutable revision/reference, same-title/different-revision, asynchronous races,
existing Studio/D1/Founder/compiler/model/block/execution/revision regressions.
41 canonical-package tests passed, including protected publication/hash goldens.
All six consolidation safety groups passed after the final source correction.
All 18 changed Dart files have zero diagnostics.

Full analysis is **non-green**, exit 1: 367 inherited diagnostics, 110 warnings,
257 info, zero errors. The exact diagnostic lines match the fresh pre-edit
baseline; zero additions/removals. Initial fresh-worktree analysis temporarily
reported 705 due to absent nested cached package configurations; copying the
four existing ignored local package-config/graph pairs read-only from D1 restored
367 before editing. No dependency resolution/download or source repair was used.
The one new clipboard-style diagnostic was fixed. A final guard regression also
fixes an apostrophe in a plain note concealing a later YAML anchor. No inherited
diagnostics are claimed fixed.

D2 dependency traversal resolves every local app/package/importer edge and checks
actual compiler/Studio inclusion with no network/persistence/write services.
Existing production traversal tolerates inherited unresolved relative edges;
an independent scan of all existing application imports proves none imports D2.
This limitation is explicit rather than claiming a complete production graph.
Base-file hash comparison proves shared compiler/schema/hash/models, published
artifacts, v1/v2 goldens, migrations, release/dependency/production entries and
all other baseline files unchanged. Only two existing Studio presentation files
and the current checkpoint pointer change. Diff whitespace and local document
links/line targets are checked. No hosted/DB/device evidence is substituted.

## Chrome inspection and founder walkthrough

Local preview: <http://127.0.0.1:4195/>. Started from this worktree with:

```sh
flutter --suppress-analytics run -d chrome --web-hostname 127.0.0.1 --web-port 4195 --no-pub -t lib/main_programme_studio_protocol_authoring_preview.dart
```

Agent inspection used native Chrome. Rendered editing cleared current success;
blank session title produced `session.title: Enter a nonblank string`. Corrected
same-title draft changed fixture A from 5 to 6 reps. Export/copy/reopen retained
that complete YAML and required refresh. Freeze showed opened R2/selected R1;
explicit confirmed selection changed selected programme to R2. Existing Studio
then displayed 2 sets, 6 reps, 12.5 kg, Rest 1 min, Tempo 3-1-1 and cue, while
fixture B stayed 1 set/3 reps with unspecified load/rest. Reload restored original
R1 and discarded these manual test revisions. Preview remains running for review.
Widget checks also cover bodyweight/RPE/tempo and 390×844 at 200% text.

1. Validate R1 and open Studio; inspect dose and readable load/rest/tempo. Return.
2. Create a draft. Edit reps; confirm review/export are unavailable. Clear title,
   validate and inspect the error; restore `Synthetic strength session`.
3. Validate; inspect exact source/diff and separate source/package identities.
   Export/copy/reopen Founder YAML and refresh. Freeze the changed draft; confirm
   the programme still selects R1 and frozen source is read-only.
4. Explicitly select frozen R2, confirm, and review the selected programme in
   Studio. Open R1 from the frozen picker to check its retained original source.
   Reload restores the initial synthetic catalogue.

Founder visual acceptance is **pending**, not implied by agent or widget checks.
Stop here; subsequent review/integration needs separate authority.

## Commit and preservation record

Approval commit: `c95b26353ee681ba418034305c418404e8158472`.
Implementation commit: `e3eb2508b773a45d6eac5b461347e9a9d8bd4379`.
This checkpoint is recorded in a following local documentation commit.

Before/after all present tracked files, all 95 original dirty/untracked paths,
index SHA-256, status, HEAD, branch and every existing `.temp` regular-file hash
match in both older checkouts. Original main remains
`a331f52967e1887c4435cccc8f1ecfa192028cd6`, six commits behind cached origin/main;
D1 remains `6318f319db15ff7a42283c7719dc22a6dc28daa5` and clean. Each older checkout
has zero present `.temp` regular files and nine absent tracked entries; their
absence/index flags remain intact. New worktree also retains those nine absent
entries. Nothing was stashed/reset/cleaned/switched or bulk-copied. Only ignored
cached toolchain package files were copied read-only into D2. No dirty evidence
was staged. No ref on either old checkout or cached origin/main was advanced.
