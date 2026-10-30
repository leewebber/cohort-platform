# M1.1 — authenticated six-record catalogue lookup

2026-10-30 (Asia/Makassar). Base `b220f42dcf038e14161d3088c7819c7be8ff853f`.
**Three new exact rows retained; three setup records remain. M1.1/Gate A OPEN.**

## Actual authorised lookup

Configured Field Manual target `otnhhdxstdnwccehacku` was verified from its linked
reference and URL host. One authenticated [project-status GET](PROJECT_STATUS.json)
returned **ACTIVE_HEALTHY**, HTTP 200 at 11:28:38 UTC / 19:28:38 WITA.
An existing Supabase CLI Keychain credential was used without printing, storing,
issuing or changing credentials. No project resumption/upgrade/configuration change.

The [reviewed bounded SELECT](CATALOGUE_SELECT.sql), through the documented
dedicated read-only API, returned **six relevant rows**, HTTP 201 at 11:30:44 UTC /
19:30:44 WITA. See [receipt](LOOKUP_RECEIPT.json),
[exact raw response](CATALOGUE_ROWS.raw.json) and [sources/read boundary](SOURCES.md).
The raw response, query, status projection and receipt have SHA-256 pins checked
before source/graph generation. Only necessary catalogue/setup/publication fields
were retrieved; no athlete data, full-catalogue export or hosted mutation.

## Retained identities and remaining approval

- **`EX-053` initial strict bodyweight pull-up**: actual published row, Pull-up Bar,
  Vertical Pull/dead-hang control cues, combined with the existing approved strict/
  bodyweight bridge. It is not replaced with weighted/chin-up identity.
- **`EX-044` DB lateral raise**: actual published row explicitly supports one/two
  dumbbells and controlled shoulder-height raise/lower.
- **`EX-038` bench-supported single-arm DB row**: actual published row explicitly
  supports Bench + One Dumbbell, Horizontal Pull, controlled elbow-to-hip execution.

NULL source fields remain NULL. All are trusted legacy v1/v2 caller-catalogue
facts, not new canonical ExerciseDefinition versions/events or a global seed.

The exact remaining facts are insufficiencies, not fabricated “absent everywhere”
claims: `EX-090` has Machine-or-Bench equipment but no DB branch/setup; `EX-037`
has dumbbells but no seated/back-supported neutral-grip setup; `EX-026` has NULL
equipment/setup/execution and no exact loaded two-DB candidate was returned.
[SETUP_PROPOSALS.json](SETUP_PROPOSALS.json) prepares the three smallest source-faithful
setup/identity proposals. **Separate bounded catalogue-owner/producer approval and
genuine record publication/retention are required**; approval alone is not evidence.
Existing IDs should be reused only if normal identity review supports those
variants; actual new IDs are assigned only by the legitimate process if needed.
No new coaching doses, invented publication events or deferred v3 producer work.

## Actual local admission and checks

[ADMISSION.json](ADMISSION.json) records full v1/v2 schedule compilation/reverification,
trusted exact-row resolver intake and native graph/codec probes. Three new bindings
are used through the existing caller-supplied catalogue boundary. All twenty
strength bodies now have known-identity partial extracts that pass private graph
and serialization/restore checks. **Complete admitted strength graphs remain 0/20**:
every full session still contains one of the three unresolved setups. The guard
refuses those candidates rather than passing null IDs or similar movements.

The coaching SOURCE.json and every RUNNING_BODIES.json byte are unchanged from
`b220f42`. The complete [TEN_WEEK_REVIEW.md](../../programmes/hybrid_10k/founder_selected_2026_10_30/TEN_WEEK_REVIEW.md)
updates only identity evidence/status. D8 remains pending, and the final 10K stays
distance-ended with its existing runner gap. No genuine programme publication,
acquisition/start/completion, eligibility/account or assignment mutation occurred.

[Verification](VERIFICATION.json): five focused snapshot/integrity/substitution
checks and four focused intake/graph/codec probes pass; new Dart analysis has no
issues. Existing `b220f42` dose, protected safety/runtime and Garmin evidence is
reused, not rerun. No broad suite or broad audit. All earlier checkouts, indices,
HEADs, dirty files, `.temp`, complete chain and five prior bundles are preserved.

Normal Git HTTPS access succeeded with authorised host access; a main-only fetch
into this task clone's FETCH_HEAD verified live remote main at `1cca598`, an exact
ancestor of the full local chain. Publication uses only a normal non-force main
push after clean-state/range checks; final outcome is recorded in the separate Git
receipt. No alternative network route or existing checkout/ref change is used.

**Next single point: review the three bounded setup proposals for separate trusted
producer action, retain actual supporting records, then complete full local graph
admission. D8/full-programme approval remains an independent pending review.**
