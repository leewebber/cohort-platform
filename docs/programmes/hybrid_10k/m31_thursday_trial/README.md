# M3.1 reusable equipment substitution

This is a local-only candidate derived from Hybrid 10K version `b0290b33-2764-4e5b-ad78-3d4beafbb375`, Week 1 Thursday, slot `LW10K-W01-D04`, occurrence `W01-B-barbell_rdl`. The private trial retains the original three blocks and the Thursday position. The original programme and Lee's assignment are separate.

| Pin | Value |
| --- | --- |
| Trial version | `5d095027-a4fb-4529-9ade-7a96a75e743f` |
| Trial protocol | `protocol-514e5f5a-c825-49cd-911a-a2bdf4f6c6d3`, revision 1 |
| Canonical package SHA-256 | `f6fdc8bbe341f56d1dc819a3878a7df2ede766bc4b3b295e40efd8709f50352b` |
| Protocol graph SHA-256 | `7dd9eff7c49a00d92a003163935d71749a43247fd7a82fb271f83d326bd65a64` |
| Equipment approval file SHA-256 | `7a616169be278b98d43234a14ac2e6b6f2565f6061fa5a692f2222ff19da7cfd` |

[Plan Package](programme.plan-package.yaml) · [Protocol graph](protocol-graphs.json) · [Approved replacement](equipment-approval.json) · [Deployment proposal](DEPLOYMENT_PROPOSAL.md)

## Approval and execution

The publisher calls `publish_private_equipment_substitution_v1(p_payload, p_approval)` with the retained private-v2 publication payload and the separately reviewed approval JSON. This route is executable by the existing service role. The payload must contain exactly one canonical equipment permission that requires agreement and targets the approval slot. The approval must match the exact source occurrence in the reviewed graph, name two distinct published catalogue identities and provide a complete bilateral, athlete-selected kg strength prescription. The database holds the approval and permission in the same transaction as the retained publication. The immutable approval row references the retained publication artifact through a deferred foreign key. The publisher shares the retained version lock. A narrow guard on the legacy writer refuses an equipment package without staged approval. An exact retry returns the same publication result and a changed approval conflicts.

The athlete reader derives identity from `auth.uid()` and requires the requested assignment, published private-v2 version, exact materialised occurrence and slot, package hash, retained seal and canonical permission. Proposal and acceptance independently read the exact approval and use the existing adaptation pipeline. The client verifies the source placement again before applying. Decline leaves the prepared session unchanged.

For Thursday, absence of a barbell and explicit confirmation of two matching dumbbells enable the approved `EX-078 → EX-040` replacement. Two sets of 5–6 bilateral reps, 2–3 reps in reserve, 120–180 seconds’ rest and about two seconds of controlled lowering are unchanged from the approval. Both load fields start blank. Capture uses kg per dumbbell with the replacement cue retained in completion and History.

The bounded contract supports one explicit placement per private v2 version and a bilateral external-load range prescription. It leaves authoring UI, time and recovery changes, and athlete-selected replacement choices outside this work. The separate [Goblet Squat fixture](../../../../test/fixtures/m31_goblet_approval/equipment-approval.json) supplies `EX-073 → EX-030`, a one-dumbbell approval and its own prescription as data, with no client or schema branch for it.

## Local proof

[Evidence](REVIEW_RESULTS.txt) · [SQL proof](../../../../supabase/tests/sql/gate_m31_approved_equipment_substitutions.sql) · [Ordinary-athlete proof](../../../../test/application/adaptation/m31_thursday_trial_local_test.dart)

The disposable SQL test uses compiled packages, exact retained catalogue rows and synthetic fixtures. It tests the service-role publication, rollback after both rows have staged, exact retry and changed approval, while preserving normal private-v2 publication. The app test uses ordinary local GoTrue users and real acquisition, read, start, completion and History APIs. It tests both programmes, including refusal for a different athlete, assignment, version, occurrence and slot, and withdrawal after End programme. Each fixture starts with blank load fields, keeps the original on decline, and restores the accepted version and sets before completing into one History entry.

The candidate check can emit the two disposable envelopes using `M31_LOCAL_PAYLOAD`. Supply those envelopes and the exact retained catalogue dependencies as the temporary inputs described in the SQL test. The opt-in app test uses a temporary `M31_LOCAL_CONFIG` file with the disposable loopback API URL, anon key and exact container name.

The [candidate-specific migration and review](superseded/) are retained as historical evidence from `51824f8`. That migration is outside the deployable migration directory. Its old proposal has been superseded.
