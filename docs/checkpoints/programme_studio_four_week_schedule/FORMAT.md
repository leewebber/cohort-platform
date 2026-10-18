# Supported schedule and workspace v2

The editable canonical Plan Package v1 source is authoritative for supported schedule
edits. There is no independent schedule schema, store or prescription authority.
Supported shapes are the retained one-week/two-day source and four weeks of seven days.
Four-week setup takes two distinct day numbers and exact immutable A/B versions. It
preserves the existing original occurrence, including its selected A version and key,
and creates seven new occurrences. Setup refuses a schedule with other occurrences;
it cannot overwrite independently chosen later versions. Existing per-occurrence
choose, move, reorder, remove, metadata and training/rest controls remain available.
An invalid rest-day draft remains unvalidated and portable until explicitly corrected.

Identifiers are generated internally using existing WnDnSn/day_n conventions. A key
stays with its occurrence when moved; it is not recalculated from its new location.
The original W1D1S1 can therefore appear on another day. New IDs avoid that key even
if B is placed on day 1. No user-entered programme/session identities are required.

All global phase/adaptation/invariant/assessment/evidence/comparison declarations stay
exactly once and byte-equivalent in meaning. New slots reuse the existing required
completion/progression template, not copies of global assessment declarations. This is
synthetic source reuse, not generated training progression. Week/day phase/intent and
other unsupported fields remain locked. Existing editable labels/notes are preserved
where retained; labels do not determine placement or identity.

Removal of a referenced occurrence is refused before changing source or its receipt.
A locked assessment's comparison lineage must still match the selected session lineage;
its A occurrence may choose another A version but cannot silently become B. Unreferenced
new occurrences can choose exact versions independently. No reference is automatically
retargeted or deleted. Unsupported imported structures or locked-field changes are
refused rather than represented partially. The fixed synthetic EX-9001/9002 profile,
two lineages, straight sets and immutable source/exercise bindings remain explicit.

`cohort_editable_workspace` v2 retains the existing strict envelope keys and history
model: exact programme source, both owners, frozen/private versions, parent edges,
reservations/abandoned numbers, admission, selections and invalid session drafts. All
existing size/depth/node/YAML/revision bounds remain. No successful receipt is serialized.

- Save now emits v2. Old readers reject v2 as an unknown future format.
- Open accepts v1 only with its original schedule skeleton, intact declarations and
  current exact binding checks. Reconstruction is independent; explicit replace installs
  the candidate atomically. Subsequent save emits v2. The original file is untouched.
- Historically inconsistent lineage/reference input is refused, never silently repaired.
- Versions above 2, duplicate/foreign/unsupported fields, profile/history conflicts and
  inconsistent source are rejected before any live replacement. No cross-file merge.
- Source TAR and read-only review JSON keep their existing formats. Valid existing
  review v1/v2 remain supported; source/profile/locked-reference checks still apply.
  Neither becomes an editable workspace by reinterpretation.

Preparation, cancellation and failure leave source/catalogue/history unchanged. Still
current receipts survive non-mutating version/setup preparation; any relevant real edit,
new operation, reset or disposal expires pending consent. Installation reuses the existing
one-notification atomic catalogue-and-source commit. File-open ownership, replacement,
save consumption and pending-operation guards are unchanged.
