# Local Apollo format and compatibility boundary

The pilot has a dedicated entry `lib/main_programme_studio_apollo_pilot.dart` and is
unreachable from production, older Studio entries and synthetic authoring. It uses the
existing package projector, ordered SQL replay, strict bounded JSON reader and
MovementPrescriptionReview. It does not pass Apollo through the synthetic compiler or
claim the general Founder importer preserves these prescriptions.

Two new, explicit JSON kinds use the existing 2 MiB / depth 32 / 30,000-node reader:

- `cohort.apollo-local-session-source.v1`: `kind`, exact `profile`, all exact `sources`,
  `local_lineage`, `revision`, absolute field `patches`, `digest`. This is the pilot's
  deterministic canonical **source envelope**, not a change to shared canonical
  Programme/Exercise schemas, Founder YAML or a Plan Package publication input.
- `cohort.apollo-local-workspace.v1`: `kind`, exact `profile`, `sources`, consecutive
  immutable `revisions` (number/patches/digest), independently editable `draft`, `selected`.
  It is neither synthetic workspace v1/v2/v3 nor the complete read-only review transport.
  Files from those contracts fail this boundary; those contracts do not gain Apollo intake.

All 21 source texts are copied exactly, including unselected sessions and original SQL
columns not used by the derived review. Overlays address **block source ID + movement
position + exact exercise ID**, never display title. Only the selected session's five
main movements accept existing fields: positive integer sets; existing exact integer,
ordered range-string or `/leg` rep form; integer RIR (zero allowed); ordered range-string
rest in seconds. Integer types stay integers, strings stay strings. Range syntax uses
its existing hyphen form. Editor bounds (sets 1–100, reps 1–1000, RIR 0–100, rest range
1–3600 seconds) are software input limits, not coaching recommendations. No arithmetic,
unit conversion, inferred load, new fields, movement reorder/add/remove or shape change.

Distance and all preparation, identities/order, titles, purpose, session/block notes,
source default rest/tempo guidance and other fields remain read-only. Load is absent in
this exact source and stays **Unspecified**; the existing effort field is RIR, which is
editable. No kg/RPE target is added. Original raw JSON stays in the pinned source; only
edited display JSON is re-encoded. Comparison normalises JSON key formatting and compares
actual authored values, using the same readable renderer for before/after. Contextual
notes/default guidance remain visible and unchanged; the author reviews them alongside
edited doses, without automatic editorial reconciliation.

R1 is the immutable original local working copy; subsequent local revisions contain
validated absolute overrides against it. A revision digest binds the exact source-envelope
digest, explicit local row profile, local lineage, number and all edits. A maximum of
128 revisions is enforced before mutation. Freeze does not select. “Use this version…”
shows current/proposed local versions, exact local Week 4/Saturday/workout 1, descriptive
changes or no prescription change, and unchanged shared/original occurrences. Confirmation
is bound to controller ownership and generation. Every successful edit/freeze/selection
invalidates prepared consent, even if values later return to the same bytes.

Save/open uses the existing file picker/download logic, extracted to neutral
`local_files` so the Apollo entry cannot reach isolated composition. Existing callers
retain their default filename and formats. Apollo files use distinct names. Open fully
validates a candidate before asking for explicit replacement; cancellation, failure or
an intervening edit leaves the current workspace intact. No merge/autosave/persistence
service is introduced. The terminal/native file helper still reports unsupported; actual
browser picker/download behavior remains pending browser evidence.

“Export Rn source” emits the source envelope; “Recompile pilot source” validates all
pinned bytes, local identity profile, edits and digest without installing a revision or
selection. `ApolloPilotSource.recompileCanonical` is the same local compiler entry used
by integration tests. Re-export is byte-identical. This does not make Apollo editable
in the existing synthetic canonical TAR/Founder transports or publishable through the
shared importer. Shared compiler/schema/hash/resolver/mappers, existing workspace and
source/review transports, package hashes, published artifacts and goldens remain intact.
