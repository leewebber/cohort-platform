# Phase 3.2B — Canonical Movement Knowledge Contracts

**Status:** Local domain and publication-gate foundation  
**Scope:** Repository-owned contracts and synthetic verification only

## Authority allocation

Exercise Knowledge owns reusable global facts attached to canonical `EX-*`
exercise identities: observable movement standards, reusable coaching guidance,
non-clinical safety boundaries, neutral regression/progression explanation, and
governed media metadata.

It does not own exercise selection, dosage, programme/session placement,
contextual prescription, adaptation acceptance, scheduling, athlete actuals,
completion, comparison grants, or performed evidence. Programme-level coaching
emphasis may override display emphasis for one occurrence without mutating
global knowledge. Typed exercise relationships remain the only structural
relationship source, and comparison protocols remain the only positive
comparison authority.

## Contracts

`MovementStandard` is a versioned, variant-scoped description of observable
start position, ordered execution, completion criteria, optional invalid-
repetition criteria, and non-clinical safety boundaries.

`CoachingContent` is versioned reusable setup, execution, cue, fault/correction,
breathing, safety, and neutral regression/progression explanation. It carries no
selection, substitution, adaptation, or comparison permission.

`VideoReference` is provider-neutral governed metadata. Provider keys are open
validated values; the domain has no provider enum, SDK, player, upload, network
check, or hosting concern. Published and available records require canonical
HTTPS delivery metadata, provenance, rights, owner/licensor, attribution, last
verification, and explicit accessibility states.

All contracts use canonical `ExerciseId`, existing
`ExerciseLifecycleStatus`, stable `KnowledgeReferenceId`, generic
`KnowledgeActorId`, explicit provenance, authored/reviewed/publication
timestamps, content versions, and optional replacement IDs. Schema version 1
is explicit and unsupported versions or fields fail closed.

## Aggregate and publication policy

`ExerciseCatalogueSnapshot` contains deterministic, ID/version-sorted content
bodies alongside definitions, relationships, and comparison protocols.
Published definition references must resolve to a published compatible body in
the same canonical exercise scope. The existing in-memory repository exposes
operational, historical, and authoring visibility and supports lookup by
canonical exercise identity.

Draft content is authoring-only. Published content requires the existing
founder publication authority plus a generic reviewer identity. Published
meaning is immutable at a content ID/version; changes require a new version.
Retired records remain historical and are not current. Replacement links must
resolve exactly once, preserve content kind and exercise scope, remain acyclic,
and stay within the bounded depth.

Strict deserialization rejects unknown fields, including prescription,
athlete-evidence, adaptation, scheduling, automatic-selection, comparison, and
programme-invariant concepts.

## Media fallback

Unavailable, removed, draft, or retired video records never resolve as playable
media. Textual movement standards and coaching guidance resolve independently,
so missing media safely produces text-only knowledge. Replacement video is
never inferred.

## Compatibility and deferred work

Plan Package v1 schemas, serialization, canonical hashes, prescription
contracts, completion/evidence, adaptation, substitution, and comparison
authority are unchanged.

Deferred under separate authority:

- production movement wording or migration of legacy catalogue cues;
- production provider selection, URLs, media hosting, playback, and network
  verification;
- Supabase schema, migrations, persistence, RLS, and hosted publication;
- athlete or authoring UI, Exercise Detail, Workout Player, and Product-UI
  Gate 2;
- production-consumer migration and Phase 3.2C.
