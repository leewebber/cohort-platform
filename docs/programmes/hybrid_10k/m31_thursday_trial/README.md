# M3.1 private Thursday equipment trial

This is a local-only candidate. Source version `b0290b33-2764-4e5b-ad78-3d4beafbb375`, Week 1 Thursday `LW10K-W01-D04`, protocol `protocol-2bf58279-08c7-4498-a4ad-c8256ac589fb` revision 6. The approved source occurrence is `W01-B-barbell_rdl` in block 2, exercise 1. The trial carries those exact blocks under a separate private lineage and one-session version. Six rest placeholders preserve its Thursday position. The source programme and its active assignment remain separate.

| Pin | Value |
| --- | --- |
| Trial version | `5d095027-a4fb-4529-9ade-7a96a75e743f` |
| Trial protocol | `protocol-514e5f5a-c825-49cd-911a-a2bdf4f6c6d3`, revision 1 |
| Canonical package SHA-256 | `f6fdc8bbe341f56d1dc819a3878a7df2ede766bc4b3b295e40efd8709f50352b` |
| Graph artifact SHA-256 | `7dd9eff7c49a00d92a003163935d71749a43247fd7a82fb271f83d326bd65a64` |
| Migration SHA-256 | `2b9c0a916da6e21046d0300192db0264b8f905923d2f2e4df1ddaa96b8448c49` |

[Plan Package](programme.plan-package.yaml) · [Exact protocol graph](protocol-graphs.json) · [Migration](../../../../supabase/migrations/20261107130000_m31_thursday_trial_permission_read.sql)

## Approved change

Offer `EX-040` Dumbbell Romanian Deadlift in place of `EX-078` Barbell Romanian Deadlift only when the athlete reports no barbell and explicitly confirms two matching dumbbells. One dumbbell per hand. Do 2 working sets of 5–6 bilateral reps at 2–3 reps in reserve. Rest 120–180 seconds and lower under control for about two seconds. Start the athlete-selected load blank. Capture actual reps and kg per dumbbell. The review shows the replacement and logging convention before **Accept Adaptation**. **Keep Original Session** leaves the original prepared session in place.

The authored permission is `m31-w01-d04-rdl`, `substitute_approved_equipment`, target `LW10K-W01-D04`, with athlete agreement required. Both proposal and acceptance read it again through `read_m31_thursday_trial_permission(p_assignment_id, p_version_id, p_slot_key)` using the signed-in athlete connection. The RPC returns only the exact four permission fields for the caller's own active, materialised assignment and pinned occurrence. Its anonymous execute privilege is absent. The trigger materialises exactly that permission while this version is still a draft so the existing retained publication RPC can seal and verify it. A deferred guard requires the matching retained seal at commit. The reader also requires that seal and checks the actual persisted package slot. Existing table grants and publication RPCs remain unchanged.

## Local evidence

- The [candidate check](../../../../test/application/adaptation/m31_trial_candidate_test.dart) recompiles the Plan Package, verifies the package and graph hashes, and compares the entire three-block graph to the genuine Thursday source.
- The [loopback integration test](../../../../test/application/adaptation/m31_thursday_trial_local_test.dart) uses ordinary athlete profiles and the real GoTrue, acquisition, permission, start and completion APIs in a disposable Supabase stack. One matching row is returned to the owner. Wrong athlete, assignment, version, slot and eligibility without an assignment return zero. The app also refuses absent dumbbell-pair confirmation or a reported barbell.
- **Keep Original Session** preserves the saved bytes. **Accept Adaptation** replaces only the approved placement and starts with both load fields blank. After reloading serialized local state and server actuals, the session and record IDs match and the replacement prescription remains exact. The completion RPC saves one result. Rendered History shows the dumbbell cue and 5 and 6 reps at 16 kg per dumbbell. The numeric load stays in kg, with the per-dumbbell meaning retained in the exercise snapshot.
- To reconstruct the local publication payload, run the candidate check with `M31_LOCAL_PAYLOAD` set to a task-owned file. Bind only the trial version and a synthetic local coach owner, and use the retained private publication RPC in a positively identified disposable stack. Seed the graph's exact exercise IDs and `EX-040` from the retained catalogue snapshot into that stack only. Point `M31_LOCAL_CONFIG` at a temporary JSON containing its loopback `API_URL`, local `ANON_KEY`, and exact `CONTAINER` name. The integration test creates its own ordinary local athlete accounts and eligibility fixture. Remove local credentials and tear down the stack after the run.

## Review

The original hook allowed the legacy private-v2 endpoint to publish the trial and seed its permission without a retained artifact. The reviewed migration adds an exact-candidate, deferred seal guard and requires the retained artifact in the athlete read. [Focused SQL proof](../../../../supabase/tests/sql/gate_m31_thursday_trial_review.sql) shows that legacy publication and a forced failure after permission seeding both roll back all trial state. A retained publication through the service role commits exactly one immutable permission and one seal. An exact retry returns `already_published` with both rows unchanged. A recompiled conflicting permission returns `immutable_version_conflict`. The normal End programme RPC drops an authenticated owner's read from one row to zero after commit and preserves the sealed permission row.

The migration and app rule are deliberately coupled to this trial's version, package hash, protocol, slot, permission key and exact source/replacement. They cannot onboard another substitution without code and SQL changes. A reusable implementation would need one separately reviewed change to materialise approved permission data in the retained publisher before sealing, plus an owner-scoped reader and a runtime contract for the exact approved replacement prescription. Future approvals could then live in versioned publication data.

## Later hosted trial, subject to separate approval

1. Freshly verify the Field Manual ledger, protected state, exact source and catalogue rows, and absence of the proposed trial data and database objects. See [exact deployment proposal](DEPLOYMENT_PROPOSAL.md). From the retained ledger-136 baseline, apply only the pinned migration and verify ledger 137, the RPC's authenticated-only execute access, the exact draft trigger and unchanged protected state. Use a deployment copy that excludes other held migrations.
2. Bind the approved actual owner to the pinned private-v2 payload and use `publish_private_exact_programme_version_retained_v1` once under separate publication authority. Verify the new immutable version, package and graph pins, and its one sealed permission. Preserve the existing Hybrid 10K version and assignment.
3. Under separate recipient-access approval, bind one exact eligibility row to an existing, approved trial athlete with no active programme. That athlete acquires the private trial through the normal app flow. Verify the wrong-account and wrong-pin responses with ordinary athlete auth.
4. Sign and manually verify a compatible candidate build for the trial. Exercise the same confirmation, decline, acceptance, restart and History path on the installed device.

Hosted deployment, publication, recipient access and installed acceptance remain pending.
