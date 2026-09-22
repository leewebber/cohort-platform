# Complete Athlete Experience Sprint 1 — handoff

**Recorded:** 2026-09-22
**Status:** Local implementation plus founder visual-review correction.
Awaiting founder visual approval. Not pushed. Not Sprint 1 approved.

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=AWAITING_FOUNDER_APPROVAL
FOUNDER_VISUAL_REVIEW=CORRECTION_APPLIED
NEXT_IMPLEMENTATION_AUTHORISED=false
PHONE_UNTOUCHED=true
HOSTED_WRITES=false
PUSHED=false
REPO_ENV_UNTOUCHED=true
```

Binding:
[`../architecture/Athlete_Programme_Discovery_and_Decision_v1.md`](../architecture/Athlete_Programme_Discovery_and_Decision_v1.md),
[`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md).

**Base:** `origin/main` `3d2213940ae2d6f066fafc30dbd48f71fed2bf14`  
**Prior approved local HEAD:** `a3e59ae0`  
**Correction branch tip:** local `feat/programme-discovery-decision-v1`

---

## Founder verdict

Discovery/list composition is directionally approved.

Programme detail was rejected as a long database-style label/value list.

Programme comparison was rejected as unclear: identity was lost while
scrolling, and repeated “Not provided” rows were unhelpful.

Black/green theme remains approved. Correction is presentation and
decision clarity only.

---

## Commits (local, linear)

Original Sprint 1:

1. `dffa779` `docs(programmes): define athlete decision contract`
2. `7ec3e90` `feat(programmes): add athlete programme details`
3. `43a51ab` `feat(programmes): add authored programme comparison`
4. `8caafe5` `fix(programmes): enforce enrolment decision boundaries`
5. `7441e55` `test(programmes): prove discovery and enrolment integrity`
6. `9c8ea56` `feat(preview): expose programme decision states`
7. `81f996b` `docs(programmes): record sprint one handoff`
8. `a3e59ae` `docs(programmes): mark sprint one awaiting founder approval`

Visual correction commits follow this handoff update and do not rewrite
the eight approved commits.

---

## Production surfaces

Programmes tab → `AthleteProgrammeSelectionScreen` (discovery cards,
composition preserved) → editorial `AthleteProgrammeDetailScreen` →
identity-persistent `AthleteProgrammeComparisonScreen` → enrolment
review with a concise authored summary.

---

## Authorities reused

Unchanged from Sprint 1:

- Catalogue list: `AthleteProgrammeSwitchCatalogService`
- Enrolment: `enrol_athlete_in_catalogue_programme_version` only
- Pin: assignment `programmeVersionId`
- `replaceActive` ignored; active assignment blocks enrol without RPC

---

## Corrected behaviour

**Detail.** App bar is generic (`Programme`). One hero title below the
bar. Status, authored goal, and summary sit in the hero. Glance tiles
cover duration, sessions/week, level, and equipment. Optional
emphasis/formats/progression/recovery appear only when authored. The
whole supporting section is omitted when all are absent.

**Comparison.** Programme names stay in a persistent identity bar.
Glance differentiators first. A row is hidden when both values are
absent. One-sided absence uses **Not specified**. Values always carry
programme names. No winner or score.

**Enrolment review.** Shows title, goal, duration, sessions/week, and
level, then explains current-programme + exact-version pin. Confirm and
Cancel remain distinct. Preview still cannot enrol.

---

## Preview

Internal only. Not imported by `lib/main.dart`.

```bash
flutter run -d chrome --web-port 4192 \
  -t lib/main_programme_discovery_decision_preview.dart
```

URL: `http://127.0.0.1:4192/`

Review states: discovery, Apollo/Spartan detail, comparison, comparison
narrow, comparison large text, missing optional facts, enrol
review/pending/success/rejected, current programme, assigned inspecting
another, empty, unavailable, large-text 320px.

---

## Limitations

- IANA timezone still uses device `timeZoneName` (Sprint 2)
- Replacement is not implemented (not approved)
- Training emphasis/formats/progression/recovery have no authored
  catalogue fields, so that section remains omitted in production data
- Coach-only shell routing unchanged
- Progress/History blockers unchanged

---

## Explicit non-actions

No push, Field Manual, phone install, migration, Sprint 2/3,
replacement, matching, adaptation, payments, WOD Timer, Performance
Portfolio, wearables, Android, blue brand, or Sprint 1 approval claim.
