# Structured Running — founder approval and Sprint B1 authorisation

**Recorded:** 2026-09-25
**Status:** Architecture **approved**. Sprint **B1 approved, not
started**. B2–B4 **not authorised**.
**Branch:** `docs/running-pace-foundation-audit`
**Base / `origin/main`:** `82ddb176d4df9f493d577001091ee9c1d6c404ad`
**Audit (historical):**
[`RUNNING_PACE_FOUNDATION_AUDIT.md`](./RUNNING_PACE_FOUNDATION_AUDIT.md)
**Binding architecture:**
[`../architecture/Running_Workout_and_Device_Interop_v1.md`](../architecture/Running_Workout_and_Device_Interop_v1.md)

```text
LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED
LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS
PROGRAMME_STUDIO_STAGE_1=COMPLETE
RUNNING_PACE_FOUNDATION=APPROVED_B1_NOT_STARTED
RUNNING_WORKOUT_B1=APPROVED_NOT_STARTED
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
STRUCTURED_AUTHORING_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

This record authorises **documentation of B1 scope only**. It does
**not** start or implement B1.

---

## Founder resolutions

### Architecture

The vendor-neutral structured-running architecture is **approved**.

Preserve five separate authorities:

1. Authored workout intent
2. Programme-version calculation policy
3. Athlete benchmark evidence
4. Frozen calculated target
5. Completed result

Cohort remains programme, assignment, and occurrence authority.
Wearables remain optional execution/evidence providers.
Programme content remains **unauthorised**.

### Terminology

Do **not** describe the initial calculation family as “percentage of
threshold pace derived from a 5 km test.”

A 5 km result is **benchmark evidence**, not automatically threshold
pace.

The initial **candidate** method family (B2, not B1) is:

**transparent, versioned percentage of benchmark speed.**

Exact percentages, ranges, and physiological labels remain
**unresolved until B2**. Do not use “threshold”, “easy”, “interval”,
or other physiological zone labels **numerically** unless the selected
B2 method explicitly and validly defines them.

Authored session intent labels may remain descriptive. Labels alone
are not numeric calculation authority.

The audit’s earlier “percentage of threshold pace” wording is
**historical**. This record supersedes it.

### Benchmark direction (B2 later)

- Initial recommended benchmark: Cohort 5 km time trial, **or** a
  recent trusted 5 km performance with result date and evidence
  source
- Evidence must include: type, result, date, source, canonical unit,
  athlete identity
- Initial freshness window: **90 days**
- Stale or missing benchmark must **not** silently generate a pace
- Without a valid benchmark: retain authored intent; allow authored
  RPE/HR guidance; show numeric pace unavailable; **never invent a
  pace**

### Target freezing (B2/B3 later)

Freeze the complete calculation snapshot at the **earliest execution
commitment**:

- successful device export; **or**
- first in-app workout start

Until device export exists, that means **first in-app start**.

The frozen snapshot must preserve: benchmark identity/result/date;
calculation method/version; programme policy/version; calculated
target; presentation conversion; override if any.

Recalculating after a new benchmark must **not** rewrite already
frozen or completed occurrences.

### Overrides (B2/B3 later)

Athlete override is permitted only when the authored programme
policy allows it. Preserve original calculated target, override
value/range, reason or source where required, and time of override.
Override must not mutate authored intent or the athlete’s benchmark.

### Units

Canonical storage remains metric and numerical (millimetres/metres
and milliseconds/seconds as the model defines; unambiguous pace).
Athlete presentation may use kilometres or miles. Preference must
not change canonical values or historical results. Conversion and
rounding occur at the presentation boundary using a **versioned**
policy.

### Treadmill / manual

Cohort must support treadmill/manual execution without GPS or a
wearable. Distance steps without trusted automatic distance require
deliberate manual advance/lap/evidence. Manual completion must be
labelled as **manual evidence**. No wearable is required to execute a
programme.

### Heart rate and RPE

HR and RPE may be authored guidance or fallback. They are **not**
converted into pace unless a future approved method explicitly
defines that calculation. Absence of HR/device data must not block
an otherwise executable workout.

### Repeats

Structured Workout v1 supports **one** explicit repeat-group level.
Unsupported nested repeats **fail validation** rather than flatten
silently. Revisit nesting only when genuine programme requirements
prove it necessary.

### Storage

B1 uses a versioned structured-running JSON representation in
**existing JSONB** authority. **No migration is approved for B1.**
Existing `timer_config` and production execution must remain
backward-compatible. If implementation proves JSONB cannot preserve
the required authority safely, **stop** for a new schema decision.

---

## Approved B1 scope

B1 **may** implement:

- immutable RunningWorkout v1 domain model
- stable workout and step IDs
- ordered typed steps
- warm-up / work / recovery / rest / cooldown / open roles
- time, distance, and manual-lap/open durations
- one-level repeat groups
- typed target **representations** without calculating athlete
  targets
- canonical units
- deterministic JSON encode/decode
- validation and explicit failure codes
- backward-compatible projection from currently supported
  steady-state and time-based interval timer configurations
- preservation of existing runtime behaviour
- Programme Studio **technical** preview only where needed to prove
  the model

B1 **must not** implement:

- benchmark capture UI
- any numeric pace formula
- zone percentages
- target calculation
- athlete overrides
- target freezing runtime
- new execution UI/timer behaviour
- distance/GPS execution
- metrics profiles
- Garmin/device provider integration
- programme content
- database migration
- hosted writes

B1 is **approved, not started**.

---

## B1 acceptance gates (when implementation is later authorised)

- Deterministic encoding
- Stable workout/step identity
- Round-trip equality
- Explicit schema version
- Canonical unit validation
- Invalid duration/target/repeat combinations fail closed
- Existing steady-state timer projects without behavioural change
- Existing simple work/recovery intervals project without
  behavioural change
- Ambiguous prose is not numeric-ised
- Unsupported nested repeats are rejected
- Existing Apollo execution remains unchanged
- Existing Plan Package / version pin authority remains unchanged
- No production entry-point leakage from internal previews
- Full regression suite and Phase 2 safety gate during
  implementation

---

## Deferred

| Item | Status |
|------|--------|
| B2 exact pace method/ranges | `PACE_CALCULATION_B2=NOT_AUTHORISED` |
| Benchmark capture and staleness UX | Deferred |
| Runtime freezing and overrides | Deferred |
| B3 execution changes | Deferred |
| B4 full Studio preview | Deferred |
| Programme metrics profiles | Not authorised |
| Garmin / provider work | Not authorised |
| HYROX programme authoring | Not authorised |

---

## Historical audit flags (preserved)

The audit commit `1853f51` recorded:

```text
RUNNING_PACE_FOUNDATION=AUDITED_AWAITING_APPROVAL
RUNNING_PACE_FOUNDATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

Those flags remain dated evidence in
[`RUNNING_PACE_FOUNDATION_AUDIT.md`](./RUNNING_PACE_FOUNDATION_AUDIT.md).
This record is the live approval pointer.
