# Programme Studio Stage 1 — closeout handoff

**Recorded:** 2026-09-25
**Status:** Visually approved. Integrated to `origin/main`
`82ddb176d4df9f493d577001091ee9c1d6c404ad`. Live flag
`PROGRAMME_STUDIO_STAGE_1=COMPLETE`.
**Branch (implementation):** `feat/programme-studio-review-v1`
**Base:** former `origin/main` `3df1442ce035df5d45370cd0a528cc18f14bdfe3`
**Implementation range:** `b91daae`…`82ddb17`
**Contract (historical):**
[`../architecture/Programme_Studio_Stage_1_Implementation_v1.md`](../architecture/Programme_Studio_Stage_1_Implementation_v1.md)

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
RUNNING_PACE_FOUNDATION_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
INTEGRATED=true
INTEGRATED_SHA=82ddb176d4df9f493d577001091ee9c1d6c404ad
```

### Historical closeout flags (preserved)

The closeout commit `82ddb17` recorded these flags **before** the
fast-forward of `origin/main`. They are evidence, not the live
pointer.

```text
PROGRAMME_STUDIO_STAGE_1=COMPLETE_AWAITING_INTEGRATION
PUSHED=false
PREVIEW_STOPPED=true
PORT_4195_FREE=true
```

## Founder visual approval

Founder reviewed the redesigned coaching workstation and approved
Stage 1:

- Coach Review is substantially clearer
- Programme navigation is useful
- Session review is coach-friendly
- Quality Gate is understandable
- Technical evidence is appropriately secondary
- Programme Studio Stage 1 is visually approved

The first Stage 1 shell mixed coaching inspection with engineering
evidence. The presentation was corrected to a coaching workstation
without changing Apollo or Spartan sources, schema, or the
authoritative projection.

## Coaching-workstation redesign

Four destinations: **Coach Review** (default), **Quality Gate**,
**Athlete Preview**, **Technical Integrity**. Desktop shell: compact
header, existing vs planned programme sidebar, selected-programme
summary (no hash/lineage/path/SQL), week **X of Y** selector, weekly
schedule, session-detail panel. Developer fixtures sit in a compact
menu. Production `lib/main.dart` cannot reach Studio or
`lib/main_programme_studio_preview.dart`.

## Corrected Apollo SQL replay

Commit `515cf16` projects the ordered warmup, prescription-encoding,
continuous-conditioning, and Week 5 capture correction chain from
committed SQL. Unsupported relevant SQL fails closed. That projection
was not changed by the workstation redesign.

## Final capabilities

- Deterministic read-only review from committed Plan Package YAML,
  Spartan founder YAML, Apollo executable-protocol SQL plus the
  correction chain, and M9 publication JSON
- Honest inventory classification
- Coach Review week/day/session inspection in coaching language
- Quality Gate checklist (Passed / Needs attention / Not assessed /
  Not implemented) with evidence behind Technical Integrity
- Athlete Preview of production-facing fields only
- Technical Integrity for hashes, sources, parser/compiler stages,
  publication artifacts, hosted-default limitation, and the Apollo
  correction chain
- Dedicated Chrome preview entry on port 4195

## Honest inventory

| Item | Classification |
|------|----------------|
| Apollo Build v2 | Internal / personal (not a commercial launch SKU) |
| Spartan Physique v3 | Legacy / withheld (1 week; 6 sessions/week; not deleted) |
| HYROX / later families | Approved planned families only — no sessions or metrics |
| Fixtures / examples | Hidden unless “Show developer fixtures” is on |

## Known honest limitations

- Plan Package v1 has no intended-level or equipment fields; Studio
  shows “Not specified” rather than inventing them
- Hosted catalogue default cannot be established locally
- Version comparison is unavailable (one local version per lineage)
- Running/pace, metrics profile, and Garmin/device checks are not
  implemented
- Coaching review, athlete device execution, and launch approval
  remain Not assessed
- Compiler success is not launch approval
- Stage 1 is integrated at `82ddb17`. Sprint B is not authorised
  by this closeout

## Verification

Preview on port 4195 was **stopped** before the full suite. Port 4195
was **free**. Lee’s installed production iPhone app was not altered.

| Check | Result |
|-------|--------|
| Focused Stage 1 / compiler / publication / isolation | `+52` passed, `0` skipped, `0` failed |
| Isolated `packages/cohort_plan_package` compiler tests | `+12` passed (`dart test` in package) |
| Changed-file `flutter analyze` | No issues found |
| `git diff --check origin/main...HEAD` | Clean |
| Phase 2 consolidation safety gate | `PHASE2_CONSOLIDATION_SAFETY_GATE=PASS` (6/6 groups) |
| Full `flutter test` (one uncontended invocation) | `+3269` passed, `~6` skipped, `0` failed |

An earlier combined `flutter test` that included package-path files
failed to **load** `packages/cohort_plan_package` tests from the app
root (`package:test` vs `flutter_test`). Isolated package rerun
passed. Not a Stage 1 defect.

## Preview

Stopped. Port 4195 free. Do not treat a running preview as required
for integration.

```bash
flutter run -d chrome --web-port 4195 \
  -t lib/main_programme_studio_preview.dart
```

## Non-actions

Integrated to `origin/main` at `82ddb17`. No Sprint B–D. No HYROX
authoring. No programme-source edits. No metrics selection. No pace
formulas. No Garmin contact. No catalogue publication. Launch
programme library infrastructure remains **in progress**.
