# Editable workspace file v1

The `cohort_editable_workspace` JSON envelope (version 1) resumes local authoring.
It is distinct from canonical source YAML/TAR for compiler/tools and complete review
JSON for separate read-only inspection. No migration/reinterpretation of those products.
No browser autosave, cloud backup, cross-file merge or external history/approval proof.
Keep the downloaded JSON somewhere safe. Download requested means the browser was asked
to save; Studio cannot prove the user retained a file. The in-memory comparison reports
changes since the last requested download or successful open, not filesystem sync.

## Retained state

The top level has exactly kind, version, fixture_profile, owners, admitted and
programme_source. Keys serialize in sorted order; arrays use existing deterministic
owner/revision/catalogue/slot order. Frozen source strings retain exact bytes.

Each of the fixed A/B owners retains its lineage ID, catalogue, opened revision,
standalone selected revision/available entries and optional active draft. The catalogue
retains highest_reserved, explicit compressed abandoned_ranges, sorted frozen revisions
(number, parent, exact source), and at most one reservation (number, parent). The full
fixed identity derives from owner and number; programme admission carries complete
protocol_id/session_lineage_id/revision_number tuples. No lookup uses titles.

The draft carries its reserved/root number, parent and supported form tree, including
invalid strings/numbers, or retained opaque rejected source. Invalid inputs are not
validated/frozen. Rejected source cannot be validated or frozen: reopen supported source,
reset or discard that draft. Already normalized form values are saved, not keystroke
history, numeric formatting or cursor state. Programme edits use the existing writer's
unvalidated YAML output with exact catalogue references and slot selections. Invalid
scalar/placement semantics remain draft; unsupported structure cannot become authority.
Programme textual diff history resets to the fixed seed on reopen; authored edits survive.

Every frozen revision is compiled afresh under the exact existing immutable exercise
profile; tuple, wrapper, profile, source and exercise-version restrictions still apply.
A R1 must match its original bytes. Parents must exist, descendants cannot be semantic
no-ops, reservations cannot overlap frozen versions, and abandoned ranges must exactly
account for gaps through the high-water number. Both private and available versions
survive; explicit programme selections are preserved, never inferred. Reconstructed
entries are new objects owned by their new existing catalogues, not live foreign entries.
Reopening an older file deliberately creates a separate local branch; this is no global
identity allocator, cross-file reconciliation or guarantee that old files reflect history.

## Input limits and exclusions

UTF-8 file <=2 MiB; JSON nesting <=32; <=30,000 values/keys; individual strings
<=262,144 code units; finite numbers only. Reject duplicate keys including escaped
spellings, unknown/missing fields, foreign profiles/identities and inconsistent graphs.
Exactly the existing two owners, <=128 frozen versions per owner, <=256 admitted entries,
at most one active descendant reservation per owner, revision high-water <=1,000,000,
and <=64 slots per existing day. No new schedule/representation/profile support.
Canonical YAML lanes are bounded before parsing (<=16,384 lines, <=64 indentation,
<=32 flow nesting); aliases, anchors, tags and block scalars are refused. Existing
frozen bytes are not rewritten or normalized. Rejected opaque draft text is not parsed.

No successful validation/review receipts, pending operations, busy state, dialogs, focus,
tabs, clipboard or rejected review packets are saved. Unsupported raw programme source
that the existing editor cannot represent is not made editable; saving refuses invalid
structural state instead of silently dropping it. Reviews/exports must be refreshed.

Open reconstructs and verifies a disposable independent candidate before presenting
counts/name and Replace current workspace / Keep current workspace. Any relevant live
change invalidates confirmation. Failure, cancellation or staleness leaves live owners,
selections, reservations and receipts unchanged. Replacement installs the complete graph
atomically; it never merges with existing owners. Save likewise checks source freshness
before download and success notification. Existing review transport remains read-only.
