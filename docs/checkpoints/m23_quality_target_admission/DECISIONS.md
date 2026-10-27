# Approved initial alpha quality-target rules

Recorded 2026-10-27 (Asia/Makassar). Authority: founder's current M2.3 request,
plus explicit reply **“Approve the proposed ±2% window”** to the manual-threshold
proposal. These are versioned alpha product/coaching estimates, not content approval
for Hybrid 10K, measured physiological thresholds or guaranteed race predictions.

| Source/rule | Exact admitted behaviour |
|---|---|
| `five_k` / `alpha_5k_8w_riegel_1_06_v1` | Athlete-entered representative sustained 5K, date and explicit sustained-effort confirmation. P5=T5/5; estimatedT10=T5×2^1.06; P10=estimatedT10/10. Threshold: P10×1.02..1.06; 10K-specific: P10×0.99..1.02; short-5K: P5×1.00..1.03. |
| `manual_threshold` / `alpha_manual_threshold_pm2_v1` | Explicit athlete selection only for threshold-labelled work. Entered pace in seconds/km ×0.98..1.02. Origin is manual entry or manually read from Garmin; neither means a Garmin connection. Founder approved this exact window in the reply above. |
| `authored_rpe` / `authored_rpe_v1` | Explicit alternative only if every marked work step contains a valid authored `fallback_rpe` (integer CR10 1..10). No estimated pace, automatic fallback or invented RPE. |

Pace bounds use **seconds per kilometre**, rounded independently to nearest whole
second with **exact halves upward**: floor(x+0.5) for positive values. Calculate
from unrounded intermediate values. Lower is the faster bound, upper the slower;
require positive integers and lower < upper after rounding. SQL uses numeric power
and arithmetic; Dart uses equivalent calculations, with exact integer-ratio rounding
for manual/short-5K boundaries. SQL is the authoritative frozen calculation; client
checks the approved bounds. Full intermediate decimal values are retained as strings
so JSON round-trip does not weaken exact snapshot equality.

The preceding eight weeks means **0 through 56 local civil days inclusive**, in the
confirmed training/assignment IANA timezone. Today and exactly 56 days ago qualify;
57 days and future dates do not. It is a versioned alpha rule, not a physiological
guarantee. No rolling UTC-hour/DST cutoff. Server transaction time determines today;
clients cannot backdate it. A timezone change/mismatch requires reconfirmation in the
matching training timezone. Review hashes include the evaluation date/timezone; a
new start across midnight may need renewed review. Frozen starts do not expire.

Inputs accept whole seconds in 1..86400 as a structural one-day bound, not an entry
standard or suitability decision; reject windows that collapse after rounding. No
age-based Zone 2 formula, manual-threshold elapsed-time expiry, automatic completed
activity ingestion or general benchmark evidence reclassification is introduced.
The athlete must confirm inputs, review the selected source/targets/limitations and
explicitly accept the exact review before a new start. Later replacement/withdrawal
changes only future starts after review. Started/completed prescriptions stay frozen.

No target-rule decision remains for this representative slice. Exact genuine ten-week
workouts/durations, entry standard/progression, Lee's separate adjustment and content
approval remain the founder's work. These rules do not approve the synthetic fixture.
