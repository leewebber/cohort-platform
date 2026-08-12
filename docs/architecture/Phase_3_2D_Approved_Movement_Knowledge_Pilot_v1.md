# Phase 3.2D — Approved Movement Knowledge Pilot

**Status:** Founder-approved local text-only implementation
**Scope:** Eight canonical Exercise Knowledge aggregates; no consumer or hosted
integration

## Founder approval

The initial production-content pilot covers exactly:

- `EX-012` Push Up
- `EX-021` Plank
- `EX-025` Walking Lunge
- `EX-049` Row Erg
- `EX-050` Ski Erg
- `EX-052` Wall Ball
- `EX-057` Kettlebell Swing
- `EX-130` Burpee Broad Jump

The content source is
`FounderApprovedMovementKnowledgePhase32d`. It supplies one
`MovementStandard` and one `CoachingContent` record for each identity. It does
not supply canonical definitions: publication requires repository-authoritative
definitions with the exact approved IDs and names and fails closed if any are
missing or renamed.

## Variant decisions

- `EX-021` is exclusively a forearm plank: both forearms and the feet provide
  support, with elbows approximately beneath the shoulders and controlled,
  approximately straight trunk and pelvis alignment. It is not a high,
  straight-arm, side, or dynamic plank.
- `EX-057` is exclusively a Russian Kettlebell Swing terminating approximately
  at chest height. Intentional overhead completion is outside its applicability;
  chest height is not a competition rule and minor natural peak-height
  variation is not independently invalid.
- `EX-130` requires chest or front-torso floor contact, return to standing
  movement, two-foot forward take-off, and a controlled two-foot landing before
  continuation.
- Wall Ball, Ski Erg, Row Erg and Burpee Broad Jump contain generic training
  standards only. HYROX-specific applicability, interpretation, judging and
  no-rep criteria are deferred.

Movement standards contain only observable identity, execution and completion
boundaries. Preferred technique remains in coaching content. Ordinary anatomical
variation is not made invalid.

## Legacy wording and programme authority

Approved lawful catalogue cues are retained or explicitly revised as recorded in
the Phase 3.2C founder review. Walking Lunge knee tracking is coaching guidance
about a stable hip, knee and foot relationship, not a validity rule. Ski Erg
uses the founder-corrected downward sequence: arms and trunk initiate, handles
travel down, the trunk flexes or hinges forwards, knees flex as appropriate,
arms finish, and the body and handles recover upwards under control.

The six programme-specific Easy Run, Threshold Run, Strides, Trail Run, Walking
and Light Loaded Carry cues are not present. Sets, repetitions, load, targets,
pace, duration, scheduling, athlete actuals, adaptation acceptance, automatic
selection and comparison grants remain outside Exercise Knowledge.

## Provenance and publication

Records use generic actor identities and truthful
`founder_approved_cohort_content` provenance. Coaching provenance identifies the
Phase 3.1F review export as the source of retained or revised legacy cues. New
wording is attributed to the completed Phase 3.2C founder review; no external
source, licence or governing-body authority is claimed.

Records begin as immutable repository-owned drafts. Canonical definition
references and a new definition version are prepared deterministically, then
publication delegates to `ExerciseKnowledgePublicationService`. Only the
existing founder authority may publish, an explicit reviewer is required, and
published content cannot change at the same content version.

## Media and compatibility

No `VideoReference`, provider, URI, upload, playback, database migration or
hosted persistence is added. Operational lookup returns complete textual
guidance with an empty playable-video list.

Plan Package v1, canonical hashing, prescription, completion, evidence,
adaptation, substitution, comparison, canonical identities and relationships
are unchanged. No athlete UI or application consumer imports the pilot.

Deferred:

- HYROX-specific standards and sources;
- VideoReference selection and governance;
- database or hosted persistence;
- athlete and authoring UI;
- Product-UI Gate 2 and live-consumer rollout.
