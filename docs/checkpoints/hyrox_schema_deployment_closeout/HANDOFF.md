# Field Manual — eight-file schema deployment closeout

2026-10-26. **APPLIED; READ-ONLY POSTCHECKS PASS.** Target: **Cohort Field Manual,
`otnhhdxstdnwccehacku`, eu-west-1**, PostgreSQL 17.6.1.155.
Reviewed readiness source: `fe0454edd0d1ac533337d288b89f6e7018ae6d70`.
Actual deployment source HEAD and freshly fetched main:
`1b2e8cd0369e8af669d4bfcea7587d263e66ec5a` (the prior no-apply receipt).
The exact eight approved migration files, order and raw SHA-256s match both sources;
all 130 migration bytes are unchanged. No earlier stopped receipt was rewritten.

[Exact applied manifest and CLI receipts](APPLIED_MANIFEST.json) · [ledger](LEDGER.json) ·
[every prescribed postcheck](POSTCHECKS.json) · [complete post-apply catalogs](CATALOG.json) ·
[protected/source comparisons](PROTECTED.json) · [health, roles and writer evidence](INSPECTION.json) ·
[temporary login cleanup](CREDENTIAL_CLEANUP.json) · [verification](VERIFICATION.json) ·
[preservation](PRESERVATION.json).

## Deployment and evidence

| Gate | Result |
|---|---|
| Before apply | Exact intended project ACTIVE_HEALTHY; complete ledger **122 / `20261009120000`**; all eight hashes/order and source/remote alignment revalidated; 173 existing function bodies/expected ACLs, fourteen prerequisite security groups and all 25 held aggregate fingerprints match reviewed readiness |
| Writer hold | Founder renewed client/debug/script hold; bounded GCP/Supabase job/queue/integration/log/catalog/drain inspection found no unexpected writer. Immediately-before-apply drain clear. No traffic/IAM/job was disabled |
| Exact dry-run | Ordinary supported linked CLI dry-run **01:23:46–01:23:52 UTC**, exactly the eight approved filenames in order; no include-all, alternate runner, seed or manual ledger operation |
| Apply | One ordinary `supabase db push --linked --yes`, **01:26:52–01:27:09 UTC**; all eight files in order, exit 0; no apply retry |
| Ledger | **130 / `20261024130000`**; exactly eight additions, all version/name entries match source; original 122 entries and statement-array fingerprints unchanged |
| Existing functions | **170 unchanged** complete function metadata records; exactly three approved body changes, original OIDs/ACLs preserved; two private original-body copies exact |
| New functions | All **33** new functions reconciled: 31 authored bodies (including the renamed duration delegate and both start overloads), plus the two exact legacy copies; latest validator/retention/duration hashes checked |
| Effective security | Three prescribed DO assertions and all seventeen prescribed read-only statements succeed; eleven additional retained security groups pass; 308 new-table and 1,344 column effective privilege checks pass across anon/authenticated/service/publisher; all 44 PostgreSQL 17 MAINTAIN checks deny access. Owner/RLS/PUBLIC, sequence privileges, policies, triggers, constraints, indexes and unchanged global defaults inspected |
| Preserved catalogs | All old relation/privilege/sequence/policy/trigger/constraint/index records remain present and exact; no removed/changed old records beyond the three approved function bodies |
| Data | All **nineteen protected and six source aggregates unchanged** before/after/final. Eleven new tables: three exact approved calculation dependency rows; all ten other tables empty. No athlete/source/content transformation |
| Final dry-run | Ordinary supported final dry-run **01:36:47–01:36:53 UTC**: “Remote database is up to date”; zero filenames, exit 0 |
| Final availability | Exact target remains ACTIVE_HEALTHY; db/auth/REST/storage/realtime all healthy; final drain clear, no CLI login backend; receiver metadata unchanged |

The CLI emitted a **pg-delta cache-export warning**: its runtime lacked
`pgdelta-target-ca.crt`, so no cache output was produced. No cache repair, permission
change or migration retry was attempted. Live ordered ledger, catalog/body/security/data
comparisons and the empty final ordinary dry-run independently establish the database
result; the warning and exit code alone were not used as proof.

The original retained policy query's array-literal/native-array mismatch remains recorded
in the preceding readiness. Its unchanged corrected comparator passes the same 53 records
and all eight logical fields; no policy or old evidence was altered. Dated ledger-122 and
unaffected-155 queries remain historical, superseded here by exact ledger-130 and all-170
comparisons. Three already-documented October 9 data differences (assignments 3→4,
occurrences 159→230, projections 3→4) remain unchanged from the held reviewed baseline;
no new difference or athlete-row attribution is inferred.

## Temporary operational login

Founder separately authorised the supported temporary CLI login/password refresh solely
for this deployment. The normal CLI used `/cli/login-role` with `read_only=false`; the
main database password was **not reset**. No credential values were printed, committed,
placed in command arguments or retained in the sanitised receipts. Existing role attributes
and all 22 pre-existing memberships are unchanged. This access is operational migration
authentication, not exercise-producer provisioning.

The task-owned `SUPABASE_HOME` (including caches/traces) and disposable linked-copy directory
were removed **01:37:13 UTC** after the final dry-run. Preserved repository `.temp`, shared
credentials and global configuration were untouched. The provider-managed temporary login
has a finite expiry of **2026-10-26 01:41:50.052073 UTC / 09:41:50.052073 Asia/Makassar**.
At **01:42:52 UTC**, metadata confirmed the login **expired**, with **zero CLI backends**; the exact receipt is in CREDENTIAL_CLEANUP.json. No remote
shared role drop/revoke/password reset was used as cleanup; expired authentication does
not itself terminate sessions, so zero CLI backends was checked separately.

## Scope, hold release and next activation step

**The client/script hold may end for previously supported v1/v2 workflows now that all
required checks pass.** The operator may reopen those clients; no reopening, hosted
write-based smoke test or device action was performed here. The hold is an operator
procedure, not an invented repository maintenance switch.

The schema creates the specified NOLOGIN/NOINHERIT publisher capability role with only
its expected narrow function grants. Its sole new membership is PostgreSQL 17's creator
ADMIN-only membership (`postgres`, SET=false, INHERIT=false). There is **no usable producer
login/membership**, retained exercise version/event/retirement, v3 artifact/claim, consent,
review, start snapshot or duration row. Ordinary service/athlete roles cannot retain.
The legacy Cloud Run receiver is unchanged: no v3 image/config/event source, secret or
capability provisioning occurred. Scheduler/Tasks APIs remain disabled; their inventories
are unavailable, not certified empty. Bounded regional/catalog/log evidence plus the known
writer hold does not prove every possible external writer anywhere absent.

**Next concrete activation step:** identify the genuine approval-event producer/event
store and durable-delivery owner, then prepare and obtain separate approval for the exact
runtime principal, minimum PostgreSQL capability, secret-reference/configuration and
reviewed runtime deployment. The current legacy receiver is insufficient; service-role
access is not a substitute. No actual producer/event source has yet been identified, so
an executable principal-specific provisioning request cannot honestly be invented.
[Existing producer/configuration contract](../hyrox_v3_http/DEPLOYMENT.md) and
[staged operation package](../hyrox_publication_operations/APPROVAL_STAGES.json) govern
that review. No further schema migration is pending in this source inventory.

After producer readiness, real identity/version/event assignments must populate the
[exact 27-definition/29-label, 48-source operation manifest](../hyrox_publication_operations/OPERATIONS.json),
regenerate real source/artifact digests, and receive their own bounded publication approval.
No real assignment or athlete write follows from this schema closeout. All **48 approved
prescription sources and eight rest entries remain unchanged**; all 48 retain **T1/B3**
real exercise-publication/binding and immutable-source/artifact blockers. V3/HYROX Base
availability, later client/device validation, Test Week, commercial readiness and wider
Stage 2/Sprint C closure are not established.

Only sanitised closeout documentation/checkpoint notices changed locally. Immutable local
fixture/replay/server/safety evidence is reused with exact hashes in VERIFICATION.json;
no app/SQL source change justified a new app test/build. Hosted assertions above are fresh
read-only checks, not borrowed local proof or hosted authenticated write-based testing.
The existing safe checkout was reused; all twenty older inventories, original 95 outstanding
paths, HEADs, indices and `.temp` match task-start bytes. Five earlier restored indices
remain historical exceptions, not claims of byte-identical restoration of lost originals.
No managed-worktree lifecycle/cleanup trigger or global setting change was used.
