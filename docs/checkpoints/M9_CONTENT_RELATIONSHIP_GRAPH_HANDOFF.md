# M9 Content Relationship Graph — checkpoint / handoff

**Status:** Sprint 1 locally complete after source-binding correction; **paused for founder architectural approval**
**Branch:** `feat/m9-content-relationship-graph-v1`**Do not:** apply hosted migrations, push, start M10, install a phone build, mutate Field Manual, repin Apollo.

## Binding

[`../architecture/Content_Relationship_Graph_and_Versioning_v1.md`](../architecture/Content_Relationship_Graph_and_Versioning_v1.md)[`../architecture/M9_Manifest_Authority_and_Binding_v1.md`](../architecture/M9_Manifest_Authority_and_Binding_v1.md)

## Local preview

```bash
flutter run -d chrome --web-port 4187 -t lib/main_m9_content_graph_preview.dart
```

http://localhost:4187 — fixtures only. Shows source / supplemental / graph /
composite hashes, stale and mismatch rejection, pinning, and the Apollo v1
compatibility bridge (proposal-only v2 labelled as such).

## Approval needed before

1. Additive hosted schema / views
2. Field Manual backfill
3. Wiring used-by into production Coach Studio
4. Plan Package schema v2 (if ever)
5. M10 isolation work
