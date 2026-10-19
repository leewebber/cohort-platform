# Bounded canonical intake and editable workspace v3

Canonical-source reconstruction and saved-workspace restoration are distinct actions.
The source archive supplies authored sources and consistency claims; it does not supply
live owner authority, historical freezes, approval, drafts, private versions, reservations
or omitted history. A separately reconstructed candidate becomes new local ownership
only after explicit, still-current replacement confirmation. No merge occurs. Ordinary
live admission still requires the exact immutable object owned by the current controller.

## Eligible source archive

Reuse the existing uncompressed USTAR export, source-index v1 and existing read-only
review v1/v2. Required ordinary UTF-8 files:

- `programme.plan-package.yaml`
- every index-declared `sessions/session-a-vN.founder.yaml` and/or B equivalent
- `source-index.json`, `review.json`, `README.md`

No missing, duplicate or additional files. Exact generated filename, session key,
protocol ID, lineage ID and revision number must agree. Every supplied lineage needs
root 1; A1 remains the exact original retained source. Only the existing A/B identity
conventions, synthetic EX-9001/EX-9002 fixed profile and accepted straight-sets grammar
are eligible. Programme shapes remain the legacy one-week/two-day template or supported
four-week/seven-day shape. Supported schedule edits remain canonical programme YAML;
no independent schedule format or automatic progression is added.

Header checksum, USTAR version, ASCII safe paths, ordinary-file type, lengths, body
padding and complete terminator are checked in memory; nothing is extracted. Reject
compressed, PAX/GNU, directory, symlink/hardlink, prefixed/absolute/traversal paths,
nonzero padding, trailing data and invalid UTF-8. Metadata never controls filesystem
permissions or paths. Maximum archive 8 MiB / 260 files, individual file 2 MiB, total
payload 6 MiB, README 64 KiB. Existing stricter JSON/YAML string/node/depth bounds still
apply. At most 128 supplied revisions per owner, 256 overall; numbers 1..1,000,000.

Duplicate JSON keys (including escaped equivalents), duplicate YAML keys, unknown
versions/fields/constructs and conflicting identity/profile/bindings refuse. Recompile
exact session bytes and programme source; recompute source/file digests, exercise/profile
bindings, canonical programme hash and all-slot prescriptions through existing compiler,
resolver and review components. The index includes hashes of programme/session/review
files, not itself or README; README is inert. Included review must equal freshly derived
review meaning; it is never accepted as approval or a saved successful receipt. A change
made outside Studio must supply the same complete, internally consistent export contract.
A coherent digest alone cannot admit unsupported content or alter locked declarations.

## Honest new local ownership

Imported source revisions are validated snapshots with no inferred historical parent.
Their original exact IDs/digests/bytes are retained. `source_import` stores the ordered
supplied revision numbers and their initial maximum. Missing numbers at or below that
maximum remain unavailable with unknown history, rather than invented abandonments.
Subsequent local allocation starts strictly above that maximum, retaining actual new
parent edges, reservations, cancellations and invalid drafts. It refuses at the numeric
limit without wraparound/reuse. It has no knowledge of omitted higher private versions
or another workspace's allocations. Cross-workspace collision-free merging is unsupported;
source intake creates separate ownership and never claims globally fresh historical IDs.

Locked phase/adaptation/invariant/assessment/evidence/comparison declarations remain
meaning-equivalent. Original referenced occurrence cannot be deleted/retargeted, and
its selected lineage cannot change from A to B. No declarations are duplicated, discarded
or silently retargeted. Unsupported locked-contract authoring remains refused.
Programme YAML formatting/comments remain exact until a deliberate form edit; subsequent
writer output preserves supported canonical meaning. Session source bytes stay immutable.

## Saved formats and freshness

Ordinary editable workspaces still save v2. Open still accepts v1/v2 with their existing
strict checks. New source-derived workspaces save `cohort_editable_workspace` v3, with
explicit owner `source_import: {high_water, revision_numbers}`. This basis is retained
alongside genuine subsequent local history/drafts. v3 must have an imported owner;
imported rows cannot claim historical parents, missing snapshots or invented abandoned
gaps. Older readers reject v3 safely; v1/v2 files are not rewritten. Future versions
refuse before replacement. Source TAR/index/review formats remain unchanged.

Reopening editable v3 retains exact source-import basis and subsequent history but no
review receipts. Source intake also starts unreviewed and unsaved as an editable file.
Prepare is non-mutating; cancellation, failure, live edits, reset, disposal or a newer
transfer prevent stale installation. Existing one-step candidate replacement is reused.
Save/edit/review/export freshness and exact source/profile checks remain mandatory.

Three separate controls remain visible: Open canonical sources (complete TAR, new
source ownership), Open editable workspace (JSON, retained local editing state), and
Open exported review (JSON, read-only). There is no autosave, cloud backup or publication.
