# Coaching Constitution v1

**Phase:** 6 Sprint 4  
**Status:** Binding  
**Companion:** [Session_Authority_Model_v1.md](./Session_Authority_Model_v1.md), [Adaptation_Policy_v1.md](./Adaptation_Policy_v1.md), [Connected_Data_Privacy_v1.md](./Connected_Data_Privacy_v1.md)

---

## Authority model

**The coach owns the programme.**  
**Cohort prepares and supports execution.**  
**The athlete retains final control.**

---

## Coach Authority

1. The coach-authored Plan version is the source of truth for phase structure, week structure, session order, session content, exercise selection, sets, reps, programmed effort metrics, progression structure, and assessment placement.
2. The execution layer must not independently rewrite those fields.
3. A coach should always recognise their own programme after any accepted adaptation (**Coaching Recognition Test**).

---

## Programme Integrity

- Same Plan version + week + day ⇒ same programmed session structure for every athlete on that version.
- Athlete history, previous load, or capability evidence must not alter the programmed prescription.
- Reconstruction after restart means restore prepared execution or resolve the same programmed session — never invent materially different training.

---

## Athlete Agency

- The athlete selects and records load.
- The athlete may accept or dismiss adaptations and recommendations.
- The athlete can always retain the original programmed session before execution.

---

## Explicit Adaptation

- No adaptation may be applied automatically.
- Valid paths: athlete-initiated Adapt, or recommendation that remains unchanged until explicit accept.
- Recommendations must not mutate durable session state before acceptance.
- See [Adaptation_Policy_v1.md](./Adaptation_Policy_v1.md).

---

## Previous Performance Is Descriptive

- Previous performance comes from actual typed execution results.
- It is shown separately from the programmed prescription.
- It never overwrites the coach-authored prescription or becomes today’s prescribed load.

---

## No Forced Progression

Cohort must not show or calculate suggested next load, required load increase, forced progression, automatic percentage increase, or “you should lift X”.

---

## Recommendation Transparency

Every proposed adaptation must expose:

- original programmed session reference  
- adaptation reason  
- exact changes  
- preserved training intent  
- option to keep the original session  
- accept / dismiss actions  

---

## Coaching Recognition Test

After any accepted adaptation, a coach reviewing the Plan version and programmed session identity must still recognise the original programme. Adaptations are derived execution decisions, not programme rewrites.

---

## Privacy by Design

Cohort consumes only explicitly connected performance and recovery metrics.  
Cohort must not track, persist, expose, or infer athlete location or travel behaviour.  
See [Connected_Data_Privacy_v1.md](./Connected_Data_Privacy_v1.md).

---

## Connected Data Boundaries

Allowed (when explicitly connected in a future sprint): heart rate, HRV, recovery/readiness, sleep, pace, cadence, power, training load, completed activity metrics (distance/elevation without route coordinates).

Prohibited: live location, GPS route history, background location, home/work inference, geofencing, travel detection, behavioural movement tracking.
