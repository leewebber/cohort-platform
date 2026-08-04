# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.9 local Journey J live-cursor bind + typed Undo reporting
remediation (no staging contact).

**B4d.8 diagnosis SHA:** `bc972e6e3f97d6706370abc9e4a530fac9b5246b`  
**B4d.9 branch:** `codex/b4d9-undo-cursor-bind`

## B4d.8 accepted conclusions

* Primary: `HARNESS_REQUEST_CONSTRUCTION` — J `reloadSnapshot()` omitted cursor
* Secondary: `HARNESS_TYPED_RESULT_COLLAPSED`
* Product Skip/Undo defects: not proven
* Staging retry: unsafe until remediation

## B4d.9 remediation

### Cursor bind (primary)

Journey J now:

1. Reloads current assignment projection after I PASS
2. Loads authoritative live assignment cursor coordinates
3. Resolves to exactly one occurrence (`resolveAuthoritativeLiveCursor`)
4. Fail-closes on missing / malformed / unresolvable / ambiguous / stale
5. Binds cursor into the Undo snapshot before preview/apply
6. Uses the same snapshot for preview fingerprint and apply command

Revision contract unchanged: Undo expected revision = post-Skip current
(B4d.7-shaped: **6**).

### Typed reporting (secondary)

Journey J detail preserves `status=`, `code=`, `apply_invoked=`,
`cursor_bound=`, `expected_revision=`, and typed classification. Opaque
`apply unsuccessful` is not emitted when a typed result exists.

## Next authority

```text
B4d.10: separately authorize exactly one fresh cursor-aligned I→J
staging evidence run using the remediated harness, with one Skip,
one immediate Undo, no retries, and typed status/code capture
```

Do not combine with Journey D. B4e remains blocked until J and D have valid
staging evidence. Production rejected.
