# Content graph publication artifacts v1

Exact immutable publication inputs for first-party `cohort_global` programmes.
These files are reviewable source-controlled payloads. **Committing an artifact
does not authorize hosted publication.** Hosted `publish_content_graph_manifest`
requires a separate founder decision per programme.

Field Manual now holds the reviewed Apollo v2 and Spartan v3 manifests. See
[`docs/checkpoints/M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](../../../docs/checkpoints/M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md).

Operational hosted comparison (external secrets; not CI):

```bash
M9_VERIFY_HOSTED=1 ./tool/content_graph/verify_hosted_published_artifacts.sh
```

## Authoritative source inputs

| Candidate | Inputs |
|-----------|--------|
| Apollo | Frozen Plan Package v1 `tool/programmes/apollo_build_12_week_v1.plan-package.yaml` plus approved committed Apollo SQL relationship sources (`supabase/migrations/*apollo*.sql` containing `EX-*`, including structured warm-up relationships). |
| Spartan v3 | Exact canonical Plan Package v1 `tool/programmes/spartan_physique_block1_week1.plan-package.yaml` plus hosted-compatible canonical exercise relationships in `sources/spartan_physique_v3.relationships.json`. |

Spartan must not reuse Apollo supplemental SQL. Plan Package v1 remains the
prescription source; it has no exercise identities.

## Compiler and format

- Compiler version: `content-graph-compiler/v1`
- Graph format version: `1`
- Publisher id (publication request only): `00000000-0000-4000-8000-00000000c001`

## Canonical JSON rules

- Manifest artifacts contain only the compiled structural `canonical_payload`.
- Publication artifacts contain only the stable `publish_content_graph_manifest`
  fields: publisher id, programme version id, compiler version, graph format
  version, source / supplemental / graph / composite hashes, canonical payload,
  unresolved references, and `require_full_resolution`.
- Encoding is UTF-8 JSON with two-space indent and a trailing newline.
- Identity hashes are those computed by `ContentGraphBinding` / the compiler,
  not SHA-256 of the pretty-printed files.
- Forbidden in artifacts: assignment ids or counts, athlete/profile ids,
  catalogue-default flags, operational lifecycle counts, generated-at timestamps,
  local filesystem paths, database connection data, credentials, publication
  actor authentication, and private impact analysis.

Apollo’s explicitly permitted `name_only_block:*` unresolved relationships stay
in the publication request. They are not guessed away.

## Regeneration

From the repository root, in a clean process:

```bash
dart --packages=.dart_tool/package_config.json \
  tool/content_graph/generate_publication_artifacts.dart
```

Regenerate each candidate independently (the generator builds Apollo, then
Spartan, from their own inputs). Run the command twice and require byte-identical
outputs.

## Checksum verification

```bash
(cd content/content_graph/v1 && shasum -a 256 -c checksums.sha256)
flutter test test/content_graph/publication_artifacts_test.dart
```

`index.json` is the machine-readable candidate set. Adding an unapproved
candidate, changing bytes, or disagreeing hashes fails the test.

## Publication procedure

1. Review the committed manifest and publication request.
2. Obtain a separate founder authorisation for that programme only.
3. Apply `publish_content_graph_manifest` with the publication JSON against the
   intended hosted database.
4. Expect first apply `published` and exact retry `already_published`.
5. Do not create a reconstruction job unless a later binding change makes it
   mandatory. Publication SQL has no reconstruction-job prerequisite.

Apollo: `require_full_resolution=false`.
Spartan v3: `require_full_resolution=true`.

## Immutable-review rule

Published hosted rows are immutable. Do not rewrite a committed artifact in
place to “fix” a hosted row. A hash or payload change is a new candidate and
needs a new review.

A committed artifact is an immutable publication *input*. It is not a hosted
publication, not a catalogue/default change, and not an assignment pin change.
