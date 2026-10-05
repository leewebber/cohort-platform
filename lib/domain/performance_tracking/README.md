# Observational tracking contracts (C1)

`performance_tracking.dart` is a pure Dart domain entry point with no runtime
consumer. It uses core Dart and the repository's existing `crypto` dependency.
No Plan Package, B2 evidence, persistence, UI or production API is imported.

Build artifacts from caller-supplied **supported synthetic definitions**, then
run `TrackingValidator.validate` on their complete dependency closure (including
predecessor revisions). Empty issues means structural consistency only. It does
not establish registry approval, authenticated ownership, source existence,
performed test proof, freshness at a query date or prescription eligibility.

`TrackingCodec` strictly decodes schema-1 tracking artifacts, rejecting unknown
fields/enums, formulas and prescription/scoring fields. Encode recursively
sorts object keys; source/context policy sets are sorted, while profile display
order and method argument order are retained. SHA-256 covers canonical UTF-8
JSON including artifact kind/schema and exact dependency digests. Encoding and
hashing do not replace validation. This format is independent of every Plan
Package schema; the optional binding value is not a package wire format.

Profiles pin metric versions. Custom composition and selection revisions pin
predecessors; changing a selected profile version requires an explicit upgrade.
No definition/profile update silently changes an existing reference. This is
in-memory validation of immutable values, not storage enforcement.
Duplicate artifact identities cannot be resolved by choosing the first supplied
definition. A stable profile ID cannot change curated/custom authority or owner.

A History source has a record ID, block-result and source-block IDs, field
path, optional exercise/set IDs, optional exact running step/repeat IDs,
input digest and optional existing correction audit ID. Array positions or
names cannot stand in for those identities. C1 does not resolve the field path
against a live result shape; a future supported adapter must prove that scope.
The contracts prohibit embedding copied History values in a measurement.
Exercise/set row scopes and running repetition scopes cannot be combined into
one field identity. Within the supplied closure, one History row cannot declare
conflicting parents, athletes or programme origins; an audit ID cannot declare
different records/athletes. One record audit may cover multiple distinct fields
or blocks. Absent optional links remain unknown, not reconstructed.

Manual values use nonnegative canonical decimal strings (no exponents, trailing
fractional zeros, NaN or infinity; count is integral). Units are closed, with
no implicit conversion. Difference methods have type signatures only; no
numeric metric evaluation exists. Evidence states and quality are declarations;
manual entry cannot claim performed-assessment or programme authority.

UTC timestamps and performed-vs-recorded chronology are explicit. Civil dates
need exact valid YYYY-MM-DD and a caller-supplied known IANA zone ID. C1 does
not resolve zone offsets, evaluate freshness or compare civil date to query
local time. Unknown chronology remains explicit; it cannot support a declared
freshness-limited available observation.

Correction chains must retain athlete, metric, source identity and origin
scope. History corrections retain performed chronology; changed input digests
require a new correction audit reference. Corrections remain annotations, not
an alternate evidence state. Source aliases cannot create another measurement
of the same History field for the same athlete/metric version. Undeclared
manual duplicates cannot be discovered by these contracts alone.

A correction ID plus digest is **not** historical reconstruction. History
sources always report `canReconstructHistoricalInputs == false`. Measurement
contracts always report `grantsPrescriptionEligibility == false`. Any later
prescription consumer must use its own separately authorised evidence policy.
