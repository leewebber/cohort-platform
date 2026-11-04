# One authorised live attempt — no apply; login revoked; preparation fixed locally

2026-11-04, Asia/Makassar. Source/live main matched
8618697284e056bbcae0714aca4c484b205e3042 before the authorised attempt.
**FRESH_PREFLIGHT_MATCHED; NO_CATALOGUE_TRANSACTION_SENT; LOGIN_REVOKED;
LOCAL_SERIALIZATION_REPAIR_VERIFIED; M1.1/GATE_A_OPEN.**

## Actual live result

Exact Field Manual target otnhhdxstdnwccehacku / eu-west-1 and all five services
were healthy. No resume was requested. Reviewed package/input hashes matched.
Fresh complete inventory/schema and all five protected consumer counts/digests
matched the prior genuine preflight: 169 rows, including unchanged EX-029/EX-141
and protected EX-026/037/090. Corrected target-scoped guard found no target exact
match or slug collision. Normal client-to-pooler TLS verification passed with the
pinned official CA. The actual backend pg_stat_ssl flag remains recorded false;
that upstream pooler/backend observation is not the frontend TLS check.

One temporary CLI login was issued through the authorised route. Existing
cli_login_postgres / postgres membership and actual role/expiry were verified.
Supavisor ignored startup application_name, so the task set only that ordinary
session label explicitly on the same route/login. No permission or identity change.

A genuine fresh manifest proposed EX-170/171/172 for the three exact approved
setups. These IDs are **proposals only**, not genuine created/retained rows.
Manifest SHA-256:
77755d4f50d5fadc219d25fb9f51e3a1c1db31286f2556676f6ccb9115f52e5d.

Before database apply, the unchanged published hash gate refused the generated
seed: 'Seed is not the exact data-only operation generated from the manifest'.
The generator used dict insertion order for INSERT column/SELECT lists, while
canonical manifest JSON sorts object keys. Reloading the manifest therefore
regenerated different SQL bytes. Earlier direct-call transaction rehearsal had
missed this serialization boundary.

Original seed SHA-256:
e153f2cb70f4fa9b9a0504f34a3a5f8994153287263a293c37dc68b067447b23.
Regenerating through the same published generator from the canonical manifest
produced 11c89dd0f799b1d26547127cc8475975e86e4dfd3eb8952b596c496174c7037c.
Only three INSERT column/SELECT list orderings differed; values, manifest,
predicates/checks and code were identical. The new canonical pin check passed.

At that point only 74.343577 seconds remained before native credential expiry,
below the helper's 90-second reserved execution/readback window. Apply stopped.
The reserve was not reduced and no replacement login was issued. No database
apply-attempt marker was created, and op.apply/seed transaction was never sent.
Validation-only failures and the original/canonical preparation are preserved;
none is relabelled an applied operation.

**Executed catalogue write set: empty. Associated writes: empty. New genuine
records created/retained: zero.** No schema/migration/ledger, existing meaning,
programme publication, account/eligibility/assignment or athlete mutation occurred.

## Actual credential closeout

Issuance: 04:33:02 UTC, provider TTL 300 seconds. Native rolvaliduntil:
**04:38:02.986612 UTC / 12:38:02.986612 WITA**, earlier than the 30-minute cap.
Temporary password/service files were removed before supported revocation.
The cleanup precheck found only the task principal and no active/idle CLI backend.
Supported DELETE login-role returned HTTP 200. At
**04:37:47 UTC / 12:37:47 WITA**, independent SELECT-only postcheck verified
**zero CLI roles and zero CLI backends**, before native expiry.
No secret material remains and no login was reused/replaced. Existing Keychain
authentication and global settings remain unchanged. Provider expiry, task limit,
local deletion and actual revocation are recorded separately.

## Protected postchecks and admission

Independent authenticated SELECT-only postflight confirms all 169 catalogue rows,
columns/constraints/indexes and five protected consumer counts/digests unchanged.
Final service health is 5/5 healthy. This is measured interval evidence, not a
claim about every hosted permission or all prior history.

Actual local strength admission attempted all 20 sessions using current genuine
workspace/compiler sources: **0/20 admitted**, with 28 unresolved occurrences.
Whole-programme review and export refuse; old revision bytes are unchanged.
One focused Flutter check passed. No synthetic receipt or uncreated ID was installed.

[Verification](VERIFICATION.json) and [hash inventory](PACKAGE_SHA256.json) retain
fresh genuine preflight/role/expiry/health/postchecks, preparation failure and
credential closeout. The unapplied manifest/seed remains visibly unapplied and
expired; there is no fabricated publication/version/audit event or operation receipt.

## Local preparation repair after access closed

Normal local operator-tool work corrects only INSERT list ordering:
names = sorted(fields), replacing names = list(fields).
The same ordered keys drive both the INSERT columns and SELECT projections.
No source values, hash gate, manifest/receipt format, state query, target guard,
authorization, lock, rollback/retry or pre/post-state checks changed.

The failure is reproduced against immutable 8618697 code with valid canonical
JSON. A new pure regression checks canonical serialization and arbitrary field
dict reordering. The existing retained-169-row PostgreSQL positive rehearsal now
uses the **real prepare CLI -> canonical files -> op.pinned -> apply/retain/retry**
path before database writes. All **24 focused Python checks pass**. Local fixture
rows reach 172, preserving all 169 old rows, duplicate groups and synthetic consumer
links. All existing ambiguity/collision/drift/role/concurrency/rollback controls pass.
The rehearsal is explicitly synthetic and is never substituted for hosted results.

The first new regression fixture had a literal newline-escape encoding error;
correcting that fixture allowed the real original serialization defect to be
reproduced. Final tests pass. No broad architecture/UI suite was repeated for
this local serialization-only repair; unaffected prior evidence remains valid.

[Next attempt package](NEXT_ATTEMPT.md) pins the repaired code and required
roundtrip before a later operation. This task makes no post-repair live retry
and grants no new login. The previously published 8618697 package remains
historical; its recorded old source hash is not silently updated.

## Preservation and boundary

Normal non-force main-only publication follows fresh ancestry/equality. Same
detached M1.1 checkout reused; older dirty Developer main, checkouts/indices/HEADs,
refs/FETCH_HEAD, measured files, .env/.temp and bounded backups are preserved via
the existing comparison procedure. Final separate receipts use
/private/tmp/m11_live_apply_8618697_*_20261104.json.

UI acceptance stays recorded and discretionary polish frozen. Next single point:
a separately authorised later live operation using the corrected deterministic
preparation, fresh target/inventory/role/expiry and hashes, genuine retention and
complete strength admission. D8, publication/access and installed journey remain
separate. M1.1 and Gate A are OPEN.
