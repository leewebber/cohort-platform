# M1.1 local transport and source policies

Controlling authority: [allocation](../ALLOCATION.md) and [M0–M10](../../../planning/Founder_Release_Plan_M0_M10_v1.md).
This documents the implemented transport before implementation review. No canonical
package, athlete-runtime or publication contract is replaced.

## Editable JSON v4

Exact envelope keys: `kind`, `version`, `profile`, `programme_source`, `available`,
`owners`, `catalogue_evidence`, `origin_inventory`. Kind is
`cohort_editable_workspace`; version is 4; profile is
`hybrid10k_native_v2_legacy_rows_v1`. Catalogue evidence is a bounded exact JSON
source string, independently compared with trusted retained evidence. Origin
inventory pins the repository source bytes. Neither a profile label nor a
self-supplied hash establishes published identity.

An owner has exactly `lineage`, `high_water`, `parents`, `reservations`,
`revisions`, `draft`. A revision has `number`, `protocol_id`, `title`, `source`,
`sha256`, `origin`. Draft is null or exactly `number`, `parent`, `title`, `source`.
Native source strings retain invalid ordinary input without inventing an executable
null-ID graph. Frozen sources are immutable strings; edits reserve a fresh number.
Cancel consumes the reservation number. Imported historical parents remain unknown.
Programme availability and exact occurrence selection are separate from owner history.

Origin variants are exact-key objects: retained source (`kind`, `path`, `sha256`,
`source_week`, `source_day`); local revision (`kind`, `parent`, `parent_sha256`);
explicit copy (`kind`, `source_sha256`); imported native snapshot (`kind`,
`source_index_sha256`, `path`, `sha256`); new local unvalidated root (`kind`).
Retained source weeks/days are human chooser context, not athlete schedule authority.

Limits: existing 2 MiB UTF-8 envelope, nesting 32, 30,000 parsed values, bounded
text 262,144 characters, 128 owners, 128 revisions per owner, 128 native session inventory entries,
32 blocks/session and 32 exercises/block. Programme is one to ten seven-day weeks.
The real selected ten-week draft fits; no size-limit increase or truncation is used.
Unknown envelope/graph/prescription fields and inconsistent identities/digests are
refused. Invalid field strings stay editable. A detached open candidate replaces
the workspace only after explicit confirmation and a current-generation check.
No valid review, approval, publication or started-athlete receipt is serialized.
The separate operator receipt reader has an explicit 8 MiB/300,000-node bound
with 2 MiB raw-response text fields for full catalogue preflight/readback. Those
larger operator files are not embedded in the editable envelope; its defaults
and all older readers remain at the original limits.

V1/v2/v3 remain on the existing synthetic editable readers, with their original
profiles and semantics. The dedicated native entry handles v4; it explains a
profile mismatch rather than rewriting an older file. Keep old preview entries
for old files. Native file picker adapters remain web-only; native/device file
picker success is not asserted.

## Canonical source TAR index v2

Existing bounded USTAR parser/writer is reused. Index v1 defaults retain their
original path allowlist. Explicit native intake adds the fixed native members and
`native-graphs/graph-NNNN.json`, then requires a complete index v2 inventory.
Index keys are exactly `kind`, `version`, `profile`, `package_sha256`, `sessions`,
`files_sha256`. Each session row is exactly `path`, `type`, `identity`,
`session_key`, `title`, `source_sha256`. Identity contains `protocol_id`,
`session_lineage_id`, `revision_number`; type is `native_reviewed_protocol_graph`.

Members: exact v2 package YAML, canonical package JSON, aggregate native graphs,
individual native source graphs, catalogue evidence, source origin hashes,
readable occurrence review, validation status and README. All body/source hashes
are distinct from the canonical package hash. Individual sources, aggregate
graphs and declared revisions must mean exactly the same thing. No unrelated or
duplicate member is accepted. Only the explicitly declared programme inventory
is exported; unused private history remains in the editable file.

Opening native canonical sources creates local snapshots with unknown history.
It validates actual TAR bytes, compiler canonical output, graph scope, native typed
prescriptions, execution codec equality and trusted catalogue evidence. It restores
no approval or hosted ownership/version/activation metadata.

## Local review boundary

`ProgrammeAuthoringSource` has an optional native policy for v2 serialization and
bounded schedule validation. Old v1 writer semantics stay unchanged. The native
session adapter uses `SessionRevisionIdentity`, shared reservation bookkeeping,
`StrengthExercisePrescription`, `TimerConfiguration`, execution-plan codec,
`ReviewedProtocolGraphArtifact` and the existing Studio projector.
`localNativeGraphSha256` is an explicit local-draft inspection input. It cannot be
combined with publication evidence or a published classification. The published
artifact path continues to require its existing package/path/graph attestation.

Catalogue operation intake additionally requires a receipt digest and audit
reference established outside the untrusted bundle. Synthetic rehearsal is
rejected even with consistent hashes. No trusted operation receipt is installed
by this implementation. Real receipt provisioning is still a separate milestone.
