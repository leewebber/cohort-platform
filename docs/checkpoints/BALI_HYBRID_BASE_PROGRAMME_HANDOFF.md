# Bali Hybrid Base — local authoring handoff

**Recorded:** 2026-09-26
**Status:** Local programme authored. Stopped for founder visual review.
**Branch:** `feat/lee-bali-hybrid-base-v1` (local only)
**Do not:** push, contact hosted systems, apply migrations, change Lee’s
assignment, integrate, publish hosted, start B2, Garmin, or commercial
HYROX authoring.

```text
PRIVATE_PROGRAMME_INFRASTRUCTURE=APPROVED
LEE_BALI_HYBRID_BASE=IMPLEMENTED_AWAITING_FOUNDER_VISUAL_APPROVAL
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
BALI_PROGRAMME_CONTENT_AUTHORISED=true
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

Source authority remains the founder DOCX
`Cohort_Bali_8_Week_Hybrid_Base_Programme.docx`. It is not copied into
the repository.

---

## Identity

| Field | Value |
|-------|--------|
| Title | Bali Hybrid Base |
| Classification | Internal / Lee-specific |
| Library scope | `coach_private` |
| Public catalogue | no |
| Commercial HYROX Base | no |
| Duration label | 8 weeks |
| Calendar span | 58 days including Week 8 spillover |
| Sessions | 71 (9/9/9/8/9/9/9/9) |
| Lineage | `BALI-HYBRID-BASE` v1 |
| Package SHA-256 | `f5da4085c0ea8b4c6eec93859451db624aaa52cd4af79ca702278518ea227b5b` |
| Local publication id | `b1a1b001-0000-4000-8000-ba11b0010001` |
| Publication kind | `private_exact_version` |
| Running required | no |

Start date when later assigned: Saturday 26 September 2026,
`Asia/Makassar`. That assignment is **not** applied.

---

## Canonical files

- `tool/programmes/bali/emit_bali_hybrid_base.py`
- `tool/programmes/bali_hybrid_base_v1.plan-package.yaml`
- `tool/programmes/bali_hybrid_base_v1.founder.yaml`
- `content/programmes/bali_hybrid_base/v1/source_manifest.json`
- `content/programmes/bali_hybrid_base/v1/package.sha256`
- `content/programmes/bali_hybrid_base/v1/bali_hybrid_base.publication.json`

Programme Studio review uses the existing Plan Package compiler plus
founder YAML session bodies. There is no second programme representation
and no SQL protocol migration.

---

## Runtime honesty

**Supported as authored duration / notes**

- Time-based BikeErg and RowErg steady-state and work/recovery intervals
- Target `none` — no invented watts, HR zones, or pace
- P20 percentages remain textual guidance
- Mixed muscular-endurance, sleds, and carries as existing block/manual capture

**Manual / not automated**

- 2 km Row distance termination
- BikeErg 20-minute profile extras (W/kg, split 10-minute power, peak HR)
- Fixed-power HR checkpoints and drift
- Front squat 3RM / bodyweight ratio
- Weighted pull-up external and system load
- Programme-level performance-metrics profile

Adaptive rules remain coaching guidance. They do not delete, reschedule,
or change load automatically.

---

## Visual review

Isolated preview (not imported by `lib/main.dart`):

```bash
flutter run -d chrome --web-port 4195 -t lib/main_programme_studio_preview.dart
```

Default: Bali Hybrid Base · Coach Review · Week 1 · Saturday Strength A.

Use the preview-state menu for overview, same-day AM/PM, Week 4/8 tests,
Week 5 muscular endurance, Week 7 2×20, spillover, manual-capture,
narrow width, and large text.

Quality Gate: compiler success is not coaching approval.

---

## Hosted / assignment

None. Lee’s current assignment is unchanged. Migrations were not
applied. The two infrastructure migrations remain unchanged from the
approved infrastructure slice.
