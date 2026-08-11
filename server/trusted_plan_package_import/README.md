# Trusted Plan Package import runtime operations

This package is the founder-only server boundary for compiling authored Plan
Package YAML and invoking the existing atomic import RPC. It is not a general
backend and must not publish, assign or materialise programmes.

## Runtime configuration

Required:

- `SUPABASE_URL` — fixed to Cohort Field Manual
- `SUPABASE_ANON_KEY` — non-secret Supabase client configuration
- `SUPABASE_SERVICE_ROLE_KEY` — Secret Manager reference only
- `FOUNDER_EMAIL_ALLOWLIST` — Secret Manager reference only

Optional:

- `BIND_ADDRESS` — `0.0.0.0` on Cloud Run
- `PORT` — injected by Cloud Run
- `MAX_PLAN_PACKAGE_YAML_BYTES` — defaults to 1 MiB

Startup fails closed when required configuration is absent or malformed.

## Build and deployment

The bounded deployment entry point is:

```bash
tool/deploy/deploy_trusted_plan_import_cloud_run.sh
```

It requires the exact selected project `cohort-platform-production`, accepts
only the two known `supabase/.temp/*` changes, archives the committed `HEAD`,
tags the image with that full commit, resolves the pushed digest, and deploys
that digest. `SUPABASE_ANON_KEY` must be injected into the script process
without placing its value in source, shell history or logs.

The approved Cloud Run Gen2 resource profile is 1 CPU, 512 MiB memory,
concurrency 4, a 30-second timeout, zero minimum instances and two maximum
instances.

Automatic deployment, custom domains and CI/CD are intentionally absent.

## Smoke checks

Permitted deployment checks:

- `GET /healthz` → `200` with only `{"status":"ok"}`
- unsupported route → `404`
- unsupported method on the import route → `405`
- missing bearer token → `401`
- intentionally invalid bearer token → `401`

Never use a valid founder token or submit valid Plan Package YAML during a
deployment smoke check.

## Rollback

For a later failed revision, restore traffic to the previously verified
revision with Cloud Run traffic controls. For a failed first revision, remove
public invocation and retain the revision for diagnosis. Do not delete
resources or attempt compensating database writes automatically.

## Secret rotation

Create a new Secret Manager version through a non-echoing mechanism, grant the
runtime identity access only to the required secret, and deploy a separately
authorised revision pinned to the explicit new version. Never overwrite,
download, print or log a secret payload, and never use `latest` as the
deployment reference.

## Logging prohibition

Production logs may contain a generated request correlation ID, route class,
method, status class and duration. They must never contain bearer tokens, YAML,
canonical package data, package hashes tied to user data, database response
bodies, founder addresses, secret values or environment dumps.
