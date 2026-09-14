# Phase 1 / dogfood commit chain

**Base:** `origin/main` `fe7576d` (`docs: close Phase 1 integration`)  
**Dogfood HEAD at closeout start:** `969ef5b` (`fix(emom): restore result capture and block completion`)  
**Span:** 138 commits, all retained. Later UI does not justify deleting earlier
history.

Production entry at HEAD is `lib/main.dart` → `CohortPlatformApp` / `AuthGate`.
Preview mains are alternate `-t` targets only.

## Topology

| Range | Theme |
|-------|--------|
| `c9bf996`…`e034ea9` | Journey D staging + Phase 1 sprint close |
| `0f0abcf`…`71b5a54` | Phase 2 consolidation / architecture freeze |
| `5d05e66`…`62e706d` | Phase 3.1 exercise knowledge |
| `6ee30d7`…`bd39888` | Programme execution + Apollo 12-week package |
| `cecb426`…`969ef5b` | Dogfood athlete runtime |

## Required dogfood clusters

| Hash | Subject | Capability | Migration | Later UI? |
|------|---------|------------|-----------|-----------|
| `e034ea9` | close Phase 1 after B4e GO | Sprint 1.1–1.7 closed | — | Docs only |
| `6ee30d7` / `e5ca18d` | execution + atomic resume | Start/complete wiring | `20260813140000_*` | Refined |
| `42c7e2b`…`19006e1` | Apollo weeks 1–12 | Executable protocols | week protocol SQL ×12 | Data series |
| `80e647a` / `bd39888` | Apollo package + publish | Import lifecycle | `20260822120000_*` | YAML later corrected |
| `6f9ba43` | calendar-driven schedule | Occurrence authority | `20260824120000_*` | Home no longer hosts calendar |
| `68efbcf` / `def3e04` | overdue recovery | Incomplete domain | `20260911120000_*` | Athlete copy → Incomplete |
| `544ee4e` | Incomplete language | Athlete-facing copy | — | Required |
| `00b4820` | weekly glance | Week agenda | — | Lives on Calendar tab |
| `f90a875` | Home today-only | Today command centre | — | Required |
| `f6ad96e` | athlete shell | 5-tab production shell | — | Required |
| `09d3963` | month grid + Progress | Calendar month + evidence | — | Required |
| `4c70232` | Train today + Backfill UI | Late training actions | proposal doc only | Persistence in next commit |
| `2586d06` | Backfill persistence | `entry_mode` / `performed_on` | `20260913120000_*` | Required |
| `1a0b925` | strength accordion | Collapsible capture | — | Preview main leftover |
| `76b7370` / `ede9940` / `e4c998c` | intervals / circuits | Capture modes | interval + W5 SQL | UX refined |
| `3a0a846` | corrections | Audited edits | `20260904120000_*` | Required |
| `33125f3`…`9b70efe` | Train today swap | 7-day bound swap | `20260905180000_*` family | Required |
| `57476f6` | environment-safe config | Production vs preview env | — | Required |
| `969ef5b` | EMOM result capture | Interval score + completion | — | HEAD behaviour |

Full adjacent auth grants, warmup structure, and staging harness commits remain
required for a linear fast-forward. Do not squash.

## Supersession (UI only)

```text
overdue recovery UI
  → Incomplete language
    → week agenda
      → Home today-only
        → 5-tab shell
          → month grid + Progress
            → Train today / Backfill
              → Backfill persistence
                → EMOM capture
```
