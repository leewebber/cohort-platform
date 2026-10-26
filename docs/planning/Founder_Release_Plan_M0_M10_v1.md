# Founder release plan M0–M10

Recorded 2026-10-26 (Asia/Makassar). Binding founder product direction from the
M0 request, audited against published main `7736d60cc4ea87de548860b8a701918cf367bf03`.
This plan controls delivery priorities. It preserves technical authority contracts;
it does not grant implementation, content, hosted, account or release authority.
[M0 findings and critical path](../checkpoints/m0_alpha_baseline/HANDOFF.md).

## Gate A — tiny friends-and-family alpha

Approximately three athletes, including the founder:

- Founder uses Cohort for all gym/running training on a genuine ten-week
  **Hybrid10K**, four runs and two strength sessions weekly.
- His father tests a genuine programme tailored primarily to his gym-training needs.
- A possible third tester's identity and training needs remain unconfirmed.

Every tester installs, creates an account, completes standard onboarding, discovers
the intended programme through the marketplace and obtains private free alpha
access through the ordinary entitlement path. No purchase is required. No tester-only
shortcut may bypass that journey. Do not assume any account, grant or programme exists.
Programmes are small, genuine and tailored. Commercial HYROX Base publication is
not an alpha prerequisite unless a specific unavoidable architecture dependency is proved.

| Milestone | Required outcome |
|---|---|
| M0 Establish release baseline | 0.1 Inspect implementation against this plan. 0.2 Classify every requirement as verified, partial, missing or blocked, with evidence type. 0.3 Establish the shortest dependency order through M1–M4. |
| M1 Deliver real alpha programmes | 1.1 Supported source/publication/access path for tester programmes. 1.2 Account/onboarding, marketplace discovery, free private access, schedule and relevant benchmarks/personalisation. 1.3 Selection and progress survive restart. |
| M2 Execute and track | 2.1 Strength prescription, previous performance and efficient logging. 2.2 WOD whiteboard, appropriate timers and result logging. 2.3 Structured running work/recovery and personalised targets. 2.4 Save/resume/complete/correct/History without loss or duplication. 2.5 Garmin: connect → deliver structured running workout → execute on founder's watch → return completed activity into Cohort. **Both delivery and activity return are alpha requirements.** |
| M3 Adapt | 3.1 Equipment-based changes. 3.2 Time-based changes. 3.3 Recovery-based suggestions. 3.4 Individual exercise swaps. Preserve intent, require athlete acceptance, and explain unavailable alternatives. No automatic progression or silent adaptation. |
| M4 Release private alpha | 4.1 Installable distribution and sign-in. 4.2 Authenticated real-device end-to-end checks. 4.3 Adequate movement instructions. 4.4 Feedback route and tester tasks. 4.5 No known blocking security, data-loss or execution defects. |

## Gate B — ready for sale

| Milestone | Required outcome |
|---|---|
| M5 Alpha fixes and experience polish | Strength/WOD whiteboard/timers/logging; running; progression/trends; standalone training logging. |
| M6 Programme library | Eight-programme commercial library; instructions/video coverage; separate HYROX Test Week. |
| M7 Garmin and hardening | Broader Garmin reliability and release hardening, building on M2.5; do not defer the first round trip here. |
| M8 Commercial readiness | Pricing/payments/entitlements; privacy/terms/account controls; support/monitoring; purchase-to-training validation. |

### Locked commercial catalogue — M6.1

| # | Programme | Approved purpose/shape only |
|---|---|---|
| 1 | Hybrid10K | Ten weeks; four runs and two strength sessions weekly. |
| 2 | HYROX Base | Catalogue purpose approved; retain separately approved existing content decisions. |
| 3 | HYROX Open | Catalogue purpose only; no new prescription approval. |
| 4 | HYROX Pro | Catalogue purpose only; no new prescription approval. |
| 5 | Tactical Performance | Catalogue purpose only; no new prescription approval. |
| 6 | Strength for Endurance | Two-day core; optional third session subject to authoring. |
| 7 | Lifelong Strength | Catalogue purpose only; no new prescription approval. |
| 8 | Hybrid Physique | Catalogue purpose only; no new prescription approval. |

Test Week is a supporting assessment programme, not a ninth commercial programme.
Do not invent unauthored prescriptions. The earlier separate HYROX Build/Race
launch-product proposal and older family/build-order lists are superseded by
Base/Open/Pro and this exact catalogue. Preserve historical records. Do not
silently relabel Apollo, Spartan, Bali or fixtures as one of these products.

## Gate C — public launch

| Milestone | Required outcome |
|---|---|
| M9 Paid beta | Validate with real usage, billing/support and resolution of blocking findings. |
| M10 Wider release | Distribution/store requirements; accurate product information; operations/recovery; wider-release approval. |

The former M9 content graph and M10 athlete/coach-management milestones retain
their historical names and accepted scope. Their closure does not close these
new M9/M10 release outcomes. Use the plan name/date when referring to either set.

## Reconciliation and preserved contracts

| Older direction | Resolution under this founder reset |
|---|---|
| `Athlete_Product_Completion_Plan_v1.md` and `Delivery_Roadmap_v1.md`: founder dogfood → 5–10 → 25–50 → 100–250; library first, wearables/onboarding later; HealthKit-first research | Replaced for prioritisation by Gate A (~three athletes), B and C above. Standard onboarding and both Garmin directions are Gate A work. Old percentages, cohort sizes and dates are not completion estimates for this plan. |
| `Launch_Programme_Library_v1.md`: HYROX Base-first and older six-family catalogue / A–D infrastructure prerequisites | This plan's eight catalogue purposes and M1 alpha programmes control. Broader Studio/Sprint C and commercial Base producer work are not automatic prerequisites for alpha. Existing artifact validation still applies to the path actually selected. |
| `Running_Workout_and_Device_Interop_v1.md`: provider work deferred / Cohort works without wearables | Provider-neutral model and Cohort prescription authority remain. Garmin round-trip becomes an alpha release gate; the app still works without a wearable, including for the father. No Garmin API or provider access is invented. |
| `hyrox_approval_producer/HANDOFF.md`: recommend one-file schema as next authority | Prepared S1–S4 work is retained, but deferred off the selected v1/v2 alpha path. No migration, provisioning, activation or publication is authorised by M0. Reuse exact prepared work if a later genuinely v3-dependent programme needs it. |
| Historical Complete Athlete Experience / Phase 1/2 closure and Stage 2/C local acceptance | Retain bounded completed work. None establishes Gate A acceptance, complete content, current installed builds or broader phase closure. |

Unchanged: canonical authored prescription, immutable versions/hashes and assignment
pins, Programme Athlete runtime, explicit adaptation acceptance affecting only the
current prepared session, separate scheduling authority, exact evidence identity,
actuals/corrections/history ownership, and no automatic prescription progression.
Do not change Plan Package v1 to manufacture an exercise-ID dependency. Phase
3.2E/F/G remain unallocated; new UI/content/schema work needs its own bounded task.

## M0 authority and stop boundary

M0 authorises local inspection/documentation, focused commits and normal main-only
publication of reviewed sanitised planning evidence. Existing read-only hosted
inspection may be used where needed; this audit reuses committed hosted receipts.
No implementation beyond M0. No next build starts automatically.

Preserve all older checkouts, outstanding paths, indices, HEADs and `.temp`. Do not
invoke managed worktree lifecycle/cleanup or change global settings. Computer and
browser control remains revoked: no app control, browser automation, AppleScript or
permission bypass. No Garmin application/account action, external message, hosted
migration/provisioning, publication/assignment, athlete write or device distribution.
