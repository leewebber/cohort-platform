# Programme Studio Stage 1 — implementation handoff

**Recorded:** 2026-09-25
**Status:** Implemented locally. Awaiting founder visual review.
**Branch:** `feat/programme-studio-review-v1`
**Base / start SHA:** `origin/main` `3df1442ce035df5d45370cd0a528cc18f14bdfe3`
**Contract:**
[`../architecture/Programme_Studio_Stage_1_Implementation_v1.md`](../architecture/Programme_Studio_Stage_1_Implementation_v1.md)

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
RUNNING_PACE_FOUNDATION_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
COMPLETE_ATHLETE_EXPERIENCE=COMPLETE
PUSHED=false
```

## What shipped

Internal, read-only Programme Studio. Deterministic review projection from
committed Plan Package YAML, Spartan founder YAML, Apollo executable-protocol
SQL `INSERT` artifacts plus the ordered warmup/capture/format correction
chain, and M9 publication JSON. Dedicated preview
`lib/main_programme_studio_preview.dart` on port **4195**. Not imported by
`lib/main.dart`.

## Honest inventory

| Item | Classification |
|------|----------------|
| Apollo Build v2 | Internal / personal (not a commercial launch SKU) |
| Spartan Physique v3 | Legacy / withheld (1 week; not deleted) |
| HYROX / later families | Approved planned families only — no sessions or metrics |
| Fixtures / examples | Hidden unless “Show developer fixtures” is on |

## Limitations shown honestly

- Plan Package v1 has no intended-level or equipment fields.
- Apollo warmup, prescription-encoding, continuous-conditioning, and W5
  capture corrections are replayed in migration order from committed SQL.
  Unsupported relevant SQL fails closed.
- Hosted catalogue default cannot be established locally.
- Version comparison is unavailable (one local version per lineage).
- Running/pace, metrics profile, and Garmin/device checks are not implemented.
- Compiler success is not launch approval.

## Founder review

```bash
flutter run -d chrome --web-port 4195 \
  -t lib/main_programme_studio_preview.dart
```

Inspect inventory, overview, week/day/session, validation, athlete preview,
and readiness. Do not treat this as Sprint A complete until visual approval.

## Non-actions

No push, no Sprint B–D, no HYROX authoring, no programme-source edits, no
metrics selection, no pace formulas, no Garmin contact, no catalogue
publication.
