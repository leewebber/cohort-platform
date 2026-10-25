# Field Manual resumed — read-only schema readiness

2026-10-25. Reviewed main **`4bc3b0f406aa71deeabd8da7a533477467326335`** was freshly fetched
and exactly matched HEAD, origin/main and FETCH_HEAD. The existing safe checkout was reused.
**Only the founder-authorised project resumption was performed. No schema/content/athlete
mutation, producer provisioning, permission/configuration change or client/device operation
was performed.**

[Exact pending manifest](MIGRATIONS.json) · [actual ledger](LEDGER.json) ·
[deployment/hold/postcheck/recovery package](DEPLOYMENT_PLAN.md) ·
[inspection](INSPECTION.json) · [security results](SECURITY_CHECKS.json) ·
[full catalog metadata](CATALOG.json) · [protected data](PROTECTED.json) ·
[expected function changes](FUNCTION_EFFECTS.json) · [verification](VERIFICATION.json) ·
[preservation](PRESERVATION.json).

## Confirmed state

| Item | Fresh result |
|---|---|
| Target | Cohort Field Manual, `otnhhdxstdnwccehacku`, eu-west-1; original host and PG17.6 identity retained |
| Resumption | One supported Management API `v1RestoreAProject`, `POST /v1/projects/otnhhdxstdnwccehacku/restore`, no request body; accepted 07:09:14 UTC. No backup restore, replacement project, region/plan/billing/credential/deployment change requested |
| Availability | First SQL success 07:13:16 UTC; project ACTIVE_HEALTHY observed 07:14:33 UTC. Independent db/auth/REST/storage/realtime health all healthy after startup; final observations are in INSPECTION.json |
| Read-only enforcement | `supabase_read_only_user`, `transaction_read_only=on`; catalog visibility and BYPASSRLS verified, no protected table filtered by RLS |
| Actual ledger | **122**, tip **`20261009120000`**, complete exact version/name prefix of the reviewed 130-file source inventory; no unknown version, name mismatch or gap |
| Pending | **Exactly eight** ordered files below; no link, dry-run, migration apply or ledger repair was run |
| Security | All **173** existing function bodies and expected ACLs match the retained source checks (155 unchanged plus 18 security functions). Fourteen prerequisite groups pass using the corrected policy comparator; original false result is preserved |
| Data/links | Nineteen protected and six source aggregate baselines remain unchanged during the measured held inspection. No parent/owner/protocol contradictions |
| v3 authority | All eleven new authority/evidence/duration tables and the publisher role are absent. No v3 programme schema, bound record packet or duration packet was found. The 48 proposed source namespaces have no collisions |
| Exercise identity leads | All 17 existing catalogue leads are present/published. The catalogue's 169 rows are **not** canonical definition/version/event authority; no T1 binding is resolved |
| Receiver | Same legacy Cloud Run revision/image, six existing environment names and two enabled pinned secret references; no v3 producer/event-source/capability configuration or verified durable delivery |

## Exact next schema scope — not executed

Every SHA below is the **reviewed raw SQL file hash**, not a reconstruction from ledger
statement-array hashes. All 130 migration bytes match reviewed Git source. Five preceding
security migrations are already applied and freshly verified; no expanded prerequisite
batch is needed.

| Order | Filename | SHA-256 |
|---|---|---|
| 1 | `20261022120000_hyrox_base_declared_evidence.sql` | `2ad14f089cd035bda16599214623a2d3cba9ec178be6855bdf88b71aa647e444` |
| 2 | `20261022121000_v3_unresolved_authority_guard.sql` | `bffce413245eb8d71e5a4dcbc9f73ab36c91c58ec5ee8fec6e23c71dedba6cf0` |
| 3 | `20261023120000_authoritative_exercise_versions.sql` | `78e392109342873d74125982763e6c4629508c9e7282ddd9bd66ba4bc39baa61` |
| 4 | `20261023121000_v3_authoritative_publication.sql` | `3bbb2534706a633e7584a76f076c30e5a815ecf84f55ef85a51c6ebb40b33ef1` |
| 5 | `20261023122000_v3_programme_consent_start.sql` | `33f7b9ef63bea7393c1355319b3812cd7d4c461efcb686b9b6aaa7ab0dd97398` |
| 6 | `20261023130000_v3_athlete_review_state.sql` | `261619275e9007446f9502b24f61bf3e1d085f50562600e9ab8bb1e9b22cc98d` |
| 7 | `20261024120000_atomic_exercise_publication_event.sql` | `486e3ad3ec7505330978407d7a2bd1a306a46e9c28eaaf7f92b73fe3c8468359` |
| 8 | `20261024130000_source_duration_choice.sql` | `e8c7209635bfb7ff83ba7d9962230613c71704925a8d4eab413e71c81efe8522` |

[Deployment plan](DEPLOYMENT_PLAN.md) specifies target, inputs, eleven new tables, three
rule/benchmark dependency seeds, the unusable capability role, exact wrapper changes,
writer pause/drain/resume receipt, postchecks and per-file/ledger failure limits. It does
not authorise exercise/source/artifact publication or a usable producer. A fresh exact
ordinary linked dry-run is a prerequisite **after** later apply authority; none ran here.

## Writers, drift and compatibility

Founder confirms clients/debug closed, no known unresolved submissions and no publication/
import/database scripts during this operation. That statement was not treated as proof
about unknown servers. Before resume, read-only control-plane evidence found:

- Only the known request-driven Cloud Run receiver; no Cloud Run jobs in its region, no
  Pub/Sub subscriptions, and Scheduler/Tasks APIs disabled (not classified as empty lists).
- No global/europe-west1 Cloud Build triggers and no receiver requests in the preceding
  30-minute log window; receiver timeout=30 seconds. No repository GitHub workflow exists.
- No Supabase Edge Functions. Database scheduler/queue/subscription visibility was blocked
  while INACTIVE; that limitation was stated before the one resumption request.

At first successful SQL availability, and again at closure, no cron/pgmq/HTTP queue catalogs,
autonomous job schemas, active replication slots, prepared transactions, enabled logical
subscriptions, other active/open/write/idle transactions, hidden client activity or public
non-read locks were found. The discovered M9 reconstruction-tracking table is empty and
is written only by its explicit reviewed RPC; it is not an autonomous scheduled worker.
Realtime has no subscription rows. No foreign server/wrapper or outbound worker function
was discovered. No job, queue, integration, traffic or IAM was disabled or changed.
These are bounded observations in the identified projects/catalogs, not proof that every
possible external actor anywhere is absent. The founder's known-writer hold remains a
necessary part of the evidence.

The published preserved-policy SQL returned false because its expected role values are
PostgreSQL array-literal strings while native `to_jsonb(pg_policies)` yields arrays.
[POLICY_COMPARISON.json](POLICY_COMPARISON.json) preserves that false result and exact query
hash. [CORRECTED_POLICY_COMPARISON.sql](CORRECTED_POLICY_COMPARISON.sql) is a byte-identical
copy of the retained native-array/duplicate-aware comparator from the protected original
checkout, not a changed baseline. It freshly passes the **same 53 records / all eight
logical fields**, with two-way EXCEPT ALL and duplicate checks. Its unchanged 19-case
local validation is reused with matching hash. No database policy changed, no old query
or historical evidence was rewritten, and no original outstanding file was staged.

Current default ACLs include retained broad creation defaults; effective privileges,
implicit PUBLIC access, column/sequence grants, memberships, ownership, RLS, policy and
trigger/constraint metadata were inspected rather than inferred from direct ACL text.
All existing security contract checks pass. No unexplained **schema/security** drift was
found. The pure interval normalizer's pre-existing public invoker access is preserved,
not misclassified as new producer authority. The live generic-start service grant matches
the reviewed retained contract and must be preserved by the pending wrapper migration.

Compared with the dated 2026-10-09 pre-apply protected baseline, three data aggregates
already differ in this first available snapshot: assignments **3→4**, occurrences **159→230**,
projections **3→4**, with their recorded digests. The other sixteen match. We did not inspect
individual athlete rows or reconstruct their cause. These are historical data differences,
not inferred schema drift or a silently replaced baseline. All nineteen current aggregates
and six source aggregates remained exact over this task's measured held window. Since SQL
was unavailable before resumption, unchanged data across the inaccessible startup interval
itself is not claimed.

Existing v1/v2 and B2/History server bodies, grants and link invariants match their reviewed
contracts. Six existing interval blocks use `sec_per_km`; no pre-existing bound/duration
packet needs a v3 migration recovery path. No authenticated application command, login,
real start/save/completion or native/device test was used to manufacture compatibility
proof. Existing backdated private-enrolment limitations remain as recorded in the preceding
handoff. No prescription, definition proposal or approved variant was rewritten.

## Hold release and next authority

The founder hold was maintained throughout resumption and read-only readiness. **It is safe
to release it for previously supported v1/v2 workflows when this readiness report is
complete**, based on final health, stable measured aggregates, preserved contracts and
zero observed writers/drain contradictions. This is a recommendation; no client reopening
or device action was performed. A later schema deployment requires a fresh demonstrated
hold/drain/baseline and exact dry-run. It is not authorised by resumption or this report.

**Next precisely scoped approval:** apply only the eight hash-pinned migrations above to
`otnhhdxstdnwccehacku` under that renewed hold, through the ordinary supported migration
flow after an exact eight-file dry-run, then run the specified read-only postchecks. This
includes only the reviewed schema/ACL DDL and unassigned role, not a usable producer,
credential/configuration change, real definition retention, source/artifact publication,
programme assignment or athlete write. If any new prerequisite or recovery mutation is
needed, stop and obtain its own exact authority.

All 48 content-complete Base prescriptions and eight rest entries remain unchanged; T1/B3
remain unresolved on all 48 real sessions. Active project status does not make v3 or Base
available. Producer provisioning/real event delivery, exact content publication, client/
device validation, Test Week, commercial readiness and wider Stage 2/Sprint C remain separate.
