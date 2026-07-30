# Adaptation Policy v1

**Phase:** 6 Sprint 4  
**Status:** Binding  
**Related:** ADR-020 (day-of adaptation authority)

---

## Flows

### A. Athlete-initiated

1. Athlete taps Adapt Session  
2. Chooses a constraint  
3. Reviews proposed adaptation (reason, exact changes, preserved intent)  
4. Accept → prepared execution updates; programmed session unchanged  
5. Dismiss / Keep Planned Session → no durable mutation  

### B. Recommendation-initiated

1. Cohort may display a recommendation  
2. Original prepared execution remains unchanged  
3. Athlete explicitly accepts or dismisses  
4. Only accept mutates prepared execution  

---

## Acceptance requirement

- Recommendations must not mutate durable session state before acceptance.
- Every proposal must provide: original programmed session reference, reason, exact changes, preserved training intent, keep-original option, accept, dismiss.
- Post-completion future-slot mutation (load progression / protocol substitution) is **not** applied automatically. It requires both explicit athlete acceptance and coach-authored permission for future sessions; otherwise the coordinator skips.

---

## Allowed scope (examples)

When permitted by policy flags:

- reduce volume  
- remove optional accessories  
- compress for time  
- substitute approved equipment / exercises  
- convert to an approved modality equivalent  

---

## Prohibited changes

- rewrite the Plan or later sessions  
- change periodisation / force a deload week  
- move the athlete to another week  
- change assessments  
- invent unrelated training  
- mutate the immutable programmed session  

Unsupported changes are rejected by `AdaptationPolicyGate`.

---

## Auditability & persistence

Accepted adaptations persist on the prepared execution record (`AcceptedAdaptationDecision`) with programmed session key, reason codes, and timestamp.

Before completion, the athlete may revert to the original programmed session (clear accepted adaptation and reconstruct prepared from programmed key).

---

## Future wearable recommendations

Wearable-informed recommendations may only use explicitly connected performance/recovery metrics ([Connected_Data_Privacy_v1.md](./Connected_Data_Privacy_v1.md)).  
They follow flow B: recommend → never auto-apply → athlete accepts.
