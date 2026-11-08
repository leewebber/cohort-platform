# M3.2 approved strength time option

Local slice based on `5ec4a46`. M3.1 installed equipment acceptance remains recorded. M1.3 stays open for Lee’s live Hybrid 10K training.

The later local-only preparation is recorded in the [pinned private trial candidate](../programmes/m32_time_trial/README.md).

## Exact local fixture

The fixture is synthetic. It represents one versioned strength slot, `fixture-time-strength`, and uses a 30-minute athlete budget. The full session estimate is 45 minutes. The coach’s only shorter option is 30 minutes.

| Block | Full session | Approved 30-minute option |
| --- | --- | --- |
| Preparation | 5 minutes of easy walking | Keep all 5 minutes |
| Bench press | 25-minute allocation, 4 × 8, 120 seconds’ rest | Keep the same sets, reps and rests |
| Optional upper-body accessories | 15-minute allocation, accessory raise 3 × 12, 60 seconds’ rest | Omit the whole block |

[Fixture source](../../test/support/adaptation_planning_test_support.dart) · [Home-to-History widget proof](../../test/application/adaptation/equipment_adaptation_b4d19_test.dart)

## Approval and proof boundary

Programme Athlete continues to use **Adapt Session → Time → 30** and the shared SessionAdaptationPipeline. The athlete sees the estimated duration change, the omitted block by name and the unchanged retained work before accepting. The published-version permission must be exactly one `remove_optional_accessories` row for the exact slot and require athlete agreement. The authored block must be explicitly optional and removable. The planner must produce exactly that one omission with known time savings, the exact approved shorter duration and a fit within the athlete’s budget. Generic set reductions and uncertain or partial results refuse. The executable plan reuses the original retained blocks. Acceptance re-reads the permission, checks the current programme identity and compares the full executable plan with the review.

The local widget test drives the production Home, review, session and History widgets using a mock permission response and disposable in-memory start and completion stores. It checks missing approval and decline against the original persisted bytes. It explicitly accepts the reviewed plan, logs a set, saves and rebuilds from serialized state with the in-memory session cache cleared. It verifies the same session and record, the saved set and the shortened blocks, then completes once and opens the single History entry. Focused negatives also cover a wrong slot, a budget below 30 minutes, withdrawn approval at acceptance and a planner-generated set cut.

## Installed trial decision

Approve preparation of a separate one-session private trial with the exact keep/omit contract above. Before review, resolve the fixture exercise identities to exact approved catalogue entries, pin the private version and authored graph, and prove the narrow permission read for the signed-in athlete’s own active assignment, published version, occurrence and slot. The existing direct permission table read covers approved global versions and eligible coaches. It does not expose the private row to an ordinary assigned athlete. Review the resulting read boundary, publication and recipient package, and the compatible signed build separately before an installed test. This local slice did not change build 11 or contact a hosted project.
