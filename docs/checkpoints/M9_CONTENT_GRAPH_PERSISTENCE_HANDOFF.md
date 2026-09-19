# M9 Sprint 2 — content-graph persistence checkpoint

> **Superseded.** M9 is closed. See
> [`M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](./M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md).
> This file is the historical Sprint 2 pause record.

**Status:** Historical Sprint 2 pause. Hosted schema and publication later
completed under the M9 closeout.

**Branch:** `feat/m9-content-graph-persistence-v1`  
**Base:** `origin/main` `0d3bc7f0b040edbf7b92d9b0877113e92ed090d2`

**Do not:** apply these migrations to Field Manual, push, start M10, rebuild the
founder iPhone app, mutate Apollo hosted content, repin any athlete, or change
repo `.env`.

## Binding

- [`../architecture/Content_Relationship_Graph_and_Versioning_v1.md`](../architecture/Content_Relationship_Graph_and_Versioning_v1.md)
- [`../architecture/M9_Content_Graph_Persistence_v1.md`](../architecture/M9_Content_Graph_Persistence_v1.md)
- [`../architecture/M9_Legacy_Reconstruction_Runbook_v1.md`](../architecture/M9_Legacy_Reconstruction_Runbook_v1.md)

## What remains local

Additive migrations `20260918120000`–`20260918120400`, Dart persistence
services, Gate AX, and the fixture preview. No hosted apply.

## What requires Field Manual approval

Applying the five migrations, any hosted reconstruction job, and any later
used-by UI.

## Future client/UI work

Coach Studio used-by/impact screens, athlete-facing graph (none in this
sprint), M10 isolation.

## Unresolved legacy identities

Name-only session blocks (including Apollo W12 Thu/Sun prose blocks) stay
explicitly unresolved. They are never inferred by display name.

## Why Plan Package v1 is unchanged

Plan Package v1 has no exercise IDs. Apollo graph edges come from the
separately hashed committed SQL relationship source. Package SHA-256 remains
`810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83`.
Plan Package v2 is proposal-only.

## Local preview

```bash
flutter run -d chrome --web-port 4187 -t lib/main_m9_content_graph_preview.dart
```

http://localhost:4187 — internal architecture preview, fixtures only.
