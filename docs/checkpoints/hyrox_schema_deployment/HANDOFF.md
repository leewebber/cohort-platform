# Approved schema deployment — stopped before dry-run at access boundary

2026-10-25. **NOT APPLIED.** Reviewed source/remote main was
`fe0454edd0d1ac533337d288b89f6e7018ae6d70`. Founder approval covers exactly the eight
hash-pinned schema files. Their manifest, filenames, order and bytes remain unchanged.
[Manifest copy](APPROVED_MANIFEST.json) · [prechecks](PRECHECKS.json) ·
[protected/source comparison](PROTECTED.json) · [actual ledger](LEDGER.json) ·
[access decision](ACCESS_BOUNDARY.md) · [access receipt](ACCESS_GATE.json) ·
[verification](VERIFICATION.json) · [preservation](PRESERVATION.json).

## Result

| Gate | Result |
|---|---|
| Target | Field Manual `otnhhdxstdnwccehacku`, eu-west-1, ACTIVE_HEALTHY; all five services healthy |
| Git/source | HEAD and fetched origin/main matched the reviewed SHA; all 130 migration bytes and reviewed inputs unchanged |
| Exact schema approval | Eight unchanged filenames/order/SHA-256s, copied verbatim from the approved manifest; no added migration |
| Ledger | Still **122 / `20261009120000`**; exact reviewed version/name/statement-array fingerprints; **zero applied entries** |
| Prerequisites | All 173 existing function bodies/expected ACLs match; fourteen security groups pass using the retained corrected native-array policy comparator |
| Data | All **25** fresh protected/source aggregates match the reviewed baseline and remain exact during this renewed held window |
| Historical differences | The same three documented differences remain; no unexplained new data or schema drift |
| Writer/drain | Clear observed drain; no unexpected database jobs/queues/subscriptions/writers; disabled external API inventory limits remain explicit |
| Disposable method | Fresh copied config + all 130 migrations, no `.env`, seeds or old `.temp`; supported CLI link succeeded for the exact target |
| Exact dry-run | **Not executed**: ordinary connection would request a new temporary read-write CLI credential |
| Apply / post-apply | **Not executed**; ledger 130 and post-apply success are not claimed |

## Why the approved apply has not run

No database password is present in the current operational process (including standard
Supabase/PostgreSQL variables and connection URL variables), standard PostgreSQL password
store or known target-scoped repository environment metadata. No secret value was printed
or copied into task artifacts. Existing Management API access supports the read-only
prechecks and metadata link; it is not an existing password for the normal migration
connection.

The installed CLI's missing-password connection path calls `v1CreateLoginRole`:
`POST /v1/projects/otnhhdxstdnwccehacku/cli/login-role` with `read_only=false`, described by
the SDK as creating a CLI login role with a temporary password. This may create/refresh
the provider-managed temporary operational credential. It is separate from an exercise
producer, but the reviewed [deployment procedure](../hyrox_resumed_readiness/DEPLOYMENT_PLAN.md)
explicitly requires a stop for a new password/credential/role-capability operation.

No such endpoint was called, no credential was created/refreshed, and no dry-run/apply was
attempted. No manual Management API migration runner, ledger repair, fake dry-run, alternate
connection proxy or permission workaround was substituted. The original manifest's
`apply_authorised=false` is retained historical metadata; **the founder's current approval
of the eight schema files is acknowledged**. The separate access action is the blocker.

The concrete access decision is in ACCESS_BOUNDARY.md: authorise the standard temporary
operational CLI login/refresh only for this deployment's ordinary dry-run, exact approved
apply and final dry-run; or make an already existing, target-scoped credential available
through an approved secure mechanism. Do not paste a password into chat. No producer
identity, publisher membership, long-lived secret or receiver configuration change or
additional schema/content action is requested by that access decision.

## Hold, recovery and continuation

The renewed founder client/script hold was maintained throughout the prechecks and while
the access decision is pending. This is **not a partial migration failure**: no schema or
ledger change needs recovery, and the existing target remains healthy. No client reopening
or device action was performed. Do not claim the full-success deployment hold-release
gate passed. If this attempt is deferred, the operator can explicitly end this unchanged
legacy-workflow window; a later attempt still requires a new hold and fresh checks.

After an access decision, revalidate exact target/health, source/remote alignment,
manifest/hash bytes, ledger 122 and narrow writer/drain/baseline checks. Require the actual
normal dry-run to list only the approved eight files. Only then apply through the reviewed
procedure and keep the hold through every prescribed postcheck, all 25 unchanged data
fingerprints, final ledger **130 / `20261024130000`**, empty final dry-run and healthy
services. On any failure inspect ledger and catalogs, retain the hold as required and
follow the existing per-file recovery plan; no blind rerun, edited applied SQL, weakened
checks or ad hoc repair.

No producer was provisioned, no usable publisher capability or accepting transport was
enabled, no definition/programme was published, no athlete was assigned/written, and no
write-based smoke test or device build/distribution occurred. The eleven new v3 tables and
publisher role remain absent. Schema deployment, v3/HYROX Base availability and the real
T1/B3 activation sequence remain incomplete and distinct.
