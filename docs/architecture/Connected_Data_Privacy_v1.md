# Connected Data & Privacy Policy v1

**Phase:** 6 Sprint 4  
**Status:** Binding  
**Integrations:** Not implemented in this sprint — policy and safe contracts only.

---

## Principle

Cohort may consume **explicitly connected** performance and recovery metrics.  
Cohort must **not** consume, persist, expose, or infer athlete location or travel behaviour.

---

## Allowed categories (future connections)

- Heart rate  
- HRV  
- Recovery / readiness score  
- Sleep metrics  
- Pace  
- Cadence  
- Power  
- Training load  
- Completed activity metrics (distance, duration, elevation **without** route coordinates)

---

## Prohibited categories

- Live location  
- GPS route history / coordinates  
- Background location  
- Home or work location inference  
- Geofencing  
- Travel detection  
- Regular-location inference  
- Behavioural movement tracking  

`PlanningTravelContext.isTraveling` remains an **athlete-declared** preference only — never sensor-inferred.

---

## Safe contract surface

See `lib/core/privacy/connected_data_contracts.dart`:

- `ConnectedPerformanceMetric` — allowed metric kinds only  
- No location / GPS / geofence / travel-detection fields on these contracts  

Wearable integrations must not be added until a dedicated sprint.
