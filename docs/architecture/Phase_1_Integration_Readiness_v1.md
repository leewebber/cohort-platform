# Phase 1 integration readiness

**Intended target branch:** `origin/main`  
**Default GitHub HEAD is not the target:** `origin/HEAD` currently points at
`origin/codex/b4d21b-rebind-path`. Do not fast-forward that wip branch.

## At closeout start

| Ref | HEAD |
|-----|------|
| `codex/apollo-dogfood` | `969ef5bddf143bbdd44383bd740fcb65a669dc51` |
| `origin/main` | `fe7576d76fcaf72388c05cbee32e4315e93cd5b8` |
| `origin/phase1-integration-closeout` | same as `origin/main` |

`origin/main` is a strict ancestor of dogfood HEAD (**0 behind, 138 ahead**).
A clean fast-forward is possible **after** closeout commits land and founder
approves.

## Prepared commands (do not run without approval)

Expected target HEAD before integration: `fe7576d76fcaf72388c05cbee32e4315e93cd5b8`  
Expected target HEAD after a later fast-forward: the then-current
`codex/apollo-dogfood` tip (includes closeout commits).

```bash
git fetch origin
git merge-base --is-ancestor origin/main HEAD
git push origin HEAD:main
```

If `origin/main` has moved, do **not** merge or rebase automatically. Report
divergence and preserve history.

## Gates

Pre-merge: changed-file analyze, `git diff --check`, focused lifecycle +
preview tests, `flutter test`, Phase 2 safety gate, local DB gate.  
Post-merge: same suite on the fast-forwarded `main`; no hosted migration
unless separately authorised.

Rollback: `main` remains at `fe7576d` until push. After push, revert with a
forward commit or reset only with explicit founder authority (never force-push
`main` unless requested).

A remote push is required only when founder authorises publishing `main`.
This closeout does not push.
