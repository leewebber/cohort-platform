# Decision required before canonical v3 integration

2026-10-22. **Independent prerequisites implemented; requested full v3 milestone blocked
at authoritative dependency retention.** This is not an allocation-only checkpoint.
[Scope](SCOPE.md), [delivered storage contract](STORAGE_CONTRACT.md).

## Established authority, inspected before implementation

- [Canonical architecture freeze](../../architecture/Canonical_Programme_Architecture_Freeze_v1.md):
  programme/version/slot and published session revision are operational source authority.
- [Accepted canonical mappings](../../architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md)
  and [identity audit](../../architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md):
  `exercises_v2` is the authoritative published identity catalogue, with one current row
  per ID and **no definition-version column**. Bridge revision is not definition revision.
- [Accepted definition lookup](../../../lib/domain/exercise_knowledge/models/exercise_definition_lookup.dart):
  operational resolution requires a published canonical definition; missing/draft/retired
  cannot become a newly operational prescription by name/alias/relationship inference.
  [ExerciseDefinition](../../../lib/domain/exercise_knowledge/models/exercise_definition.dart)
  retains its version as a string. The accepted Founder YAML importer receives published
  definitions through a caller-supplied authority port; this is not a server publication store.
- [Retained publication artifacts](../../../supabase/migrations/20261005140000_tracking_publication_artifact_retention.sql)
  accept only v1/v2, independently seal the actual physical protocol/block/exercise graph,
  and are private and immutable. They do not retain published ExerciseDefinition artifacts.
- [v3 binding](../hyrox_bound_prescriptions/CONTRACT.md) pins integer reference versions
  and exact body/block/step identities. Its only installed resolver/source registry contains
  explicit synthetic fixtures and rejects canonical exercise dependencies.
- [B2 canonical start](../../../supabase/migrations/20260927150000_occurrence_running_target_snapshot.sql)
  already owns fixed-occurrence creation, exact assignment/source links, locking, retries
  and snapshots. [Completion ownership](../../../supabase/migrations/20261007130000_completion_ownership_and_parent_guard.sql)
  and subsequent identity/link protections remain separate and preserved.

## Exact decision and recommendation

Authorise the trusted publication/resolution mechanism for **retained immutable published
canonical ExerciseDefinition versions**, and settle how their exact version strings bind
to the integer v3 exercise reference. Neither a current SQL catalogue row, an athlete's
file/hash, a bridge mapping revision nor `synthetic_fixture` is that version authority.

Recommend extending the accepted published-definition lookup/publication boundary with
trusted server retention, rather than creating an independently writable identity registry:

1. A trusted publication adapter must obtain the complete published canonical definition
   from its authorised producer, retain its exact identity/version/body/digest and issuer
   proof, and verify the catalogue identity/lifecycle. No athlete/service API can turn an
   arbitrary supplied object or matching hash into publication authority.
2. Resolve the actual version representation explicitly. v3 can resolve only an explicitly
   published positive integer version whose exact string equals that integer's decimal
   representation; do not assume version 1 or coerce arbitrary strings. If approved real
   definitions need other strings, use an explicit additive contract version and preserve
   existing v3 bytes/golden. The string/integer difference alone is not proof that real
   versions are incompatible; the authoritative version artifacts have not been transferred.
3. Retain v3 canonical package and actual session bodies/block/work-step mappings through
   the existing private publication transaction and independently constructed physical seal.
   Define/verify the source-body serialisation against real canonical sources. The synthetic
   JSON body is not the SQL graph's canonical body merely because both have a SHA-256.
4. Add server-issued programme/assignment/target/rule/equipment-scoped review and explicit
   consent. Existing declared-benchmark selections cannot be silently upgraded to this
   consent. Missing evidence may retain only approved authored-effort fallbacks after
   explicit review; missing/stale/unresolved consent cannot start a bound prescription.
5. Extend **the existing** `cohort_create_or_resume_fixed_occurrence_at` transaction,
   with consistently ordered locks shared with evidence/consent replacement, authoritative
   source rechecks and SQL calculation. Insert an immutable FK-linked occurrence snapshot
   in that same transaction. Existing owned snapshot retries return the original; rollback
   must remove both new training session/outcome and snapshot. No second start system.

The private SQL arithmetic kernel is now available for that trusted path and matches
136 outputs from the actual Dart rules. It does not resolve an exercise, admit a target,
attest a benchmark or accept programme consent. Full v3 server validation, retained-source
publication, materialisation and source-to-execution mapping are still required before
removing any import/start guard. No production v3 snapshot table or start overload was
invented around this missing authority.

## Explicitly open proof

v3 compile → authoritative admission → programme consent → canonical start/freeze,
concurrent v3 start/replacement in both orders, v3 duplicate start, rollback, snapshot
update/delete/ref-integrity and real row/squat runner capture remain **unproved/unimplemented**.
The previous in-memory compiled fixture proof and current real PostgreSQL B2 start proof
are useful separate evidence, never substitutes. Production storage of declared evidence
is implemented locally, not deployed; production v3 admission/storage/start is not delivered.
