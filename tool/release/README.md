# Release and preview configuration

Builds must declare `COHORT_BUILD_ENV` explicitly. Flutter debug versus
Release mode is not an environment. Founder loopback previews use Release.

Do not rewrite repository `.env` for release or preview builds.

## Environments

| Value | Allowed endpoint |
|---|---|
| `production` | `https://otnhhdxstdnwccehacku.supabase.co` only |
| `loopbackPreview` | `http://127.0.0.1`, `http://localhost`, or `http://[::1]` |
| `development` | loopback HTTP, Field Manual HTTPS, or Staging HTTPS |

`development` is for local `flutter run` only. It is not an unrestricted bypass.

The client key must be a JWT whose `role` is `anon`. `service_role` and other
roles are rejected before the Supabase client is created.

## Production (do not run in this task)

```bash
./tool/release/build_app.sh \
  --env production \
  --target macos \
  --config /absolute/path/outside-git/cohort.production.json
```

iOS:

```bash
./tool/release/build_app.sh \
  --env production \
  --target ios \
  --config /absolute/path/outside-git/cohort.production.json
```

JSON shape: see `examples/production.defines.json.example`.

## Loopback preview

```bash
./tool/release/build_app.sh \
  --env loopbackPreview \
  --target macos \
  --config /absolute/path/outside-git/cohort.preview.json
```

JSON shape: see `examples/loopback_preview.defines.json.example`.

The packaged app shows **LOCAL PREVIEW** before login.

## Development

```bash
./tool/release/run_development.sh
```

Reads repository `.env` and injects dart-defines. It does not write `.env`.

## Provenance

Each build injects app version, build number, short commit, and environment.
Help & feedback shows those values and never shows URL, project ref, or keys.
