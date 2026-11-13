# M3.3 private Recovery trial provisioning proposal

Local source review for Founder release plan M3.3. The generated-ID contract
was later implemented and verified in disposable Supabase. See the
[contract review](LOCAL_CONTRACT_REVIEW.md#generated-id-verification) for results.
The checkout remains based on `e7cadfc4eb4ef7e665770d91fadabb28d5a3ebc3`.

## Candidate identity

| Field | Proposed pin |
| --- | --- |
| Programme lineage | `M33-STRENGTH-RECOVERY-TRIAL` |
| Version UUID / version number | `7e1d15e7-20ee-46d4-b5e9-0d6449010330` / 1 |
| Session lineage UUID / revision | `7e1d15e7-20ee-46d4-b5e9-0d6449010333` / 1 |
| Protocol | `protocol-7e1d15e7-20ee-46d4-b5e9-0d6449010334` |
| Authored session key | `m33-upper-body-recovery-trial` |
| Authored slot key | `M33-W01-D01-STRENGTH` |
| Canonical v2 package SHA-256 | `f7a402a26fd4738cc6b1cc99add4c20a87ce1087b934ab197220a3c05379faed` |
| Source package file SHA-256 | `ef54913b4fafe1c9331079970100698aff0516ad854752c5afbcb3e52984cd6d` |
| Reviewed graph file SHA-256 | `7a127971ad36d301928ab2cc39ef4eca8b61df6da6ef44b218547af2cc51abdf` |

The draft [Plan Package](proposed_source/programme.plan-package.yaml) and
[reviewed graph copy](proposed_source/protocol-graphs.json) are available for
source review. The proposal keeps the requested Recovery version UUID and gives the programme
and session new lineages and the workout a new protocol identity. The draft
changes names and identity references. The three authored block objects match
M3.2 exactly, including exercise IDs, notes, prescriptions and timer settings.
The new protocol owns its own block and exercise-link rows, so M3.2 Time and its
History retain their existing references. The package is private v2 with one
required Week 1 Day 1 session and an empty generic adaptation list.

The original is a five-minute easy walk, barbell bench press **4 × 8 with
120 seconds’ rest**, and optional dumbbell lateral raises **3 × 12 with
60 seconds’ rest**. A fresh **Poor Sleep** answer in the open review may offer
**45 → 30 min estimated** even when the athlete has time for all three blocks.
**Keep Original** leaves the prepared workout intact. Explicit acceptance
rereads the approval and omits only the lateral raises.

## Provisioning sequence

1. **Review the source and exact publication request.** Compile the candidate
   and check the reviewed graph and the three published catalogue identities
   `EX-008`, `EX-083`, `EX-044`. Resolve the approved private owner and trusted
   publisher, confirm that the proposed identities are unused, and pin the full
   request hash after binding its environment-specific values. The draft hashes
   above identify source bytes. The publication request hash will also cover
   the approved owner and operator inputs.
2. **Publish the version through the existing retained v2 route.** The trusted
   publisher calls `publish_private_exact_programme_version_retained_v1`.
   It commits the private version, graph, one slot and retained artifact in
   the same transaction. The slot INSERT uses the database UUID default. After
   commit, an authorised readback resolves the single slot UUID by exact
   version, authored slot key and protocol. Verify it against the retained seal,
   record the seal hash and recompute the seal from the live graph. Verify the
   exact body and generated lateral-raise block ID. Publication creates no
   assignment or Recovery approval. On an ambiguous response, reconcile the
   exact version, owner, canonical bytes, graph and retained seal before an
   identical retry.
3. **Grant eligibility separately.** Confirm the intended test athlete by UID,
   completed training setup and timezone, and no active programme. Verify the
   grant binds only that UID and the new version and creates no assignment.
   Preserve prior completions and confirm the main-account Hybrid 10K is
   outside the operation. The existing eligibility path needs no change.
4. **Acquire through the signed-in athlete.** Use
   `acquire_my_private_programme` with the reviewed Week 1 Day 1 local start
   date. The wrapper uses the established no-replacement enrolment path.
   Acquisition returns the assignment ID after materialisation commits the
   fixed calendar. The occurrence INSERT generates its UUID. Resolve it from
   the athlete’s calendar and cross-check it through trusted readback using
   exact assignment, version and published slot UUID. Verify one occurrence,
   the reviewed civil date and programmed-session key, scheduled disposition,
   and absence of a start or terminal outcome. An active assignment for another
   programme stops acquisition. If the exact version is already active, confirm
   that the returned assignment and anchor match the reviewed request.
5. **Issue one Recovery approval on the due day before starting.** The
   service-role-only issuer receives the exact version, athlete, assignment,
   generated slot and occurrence, scheduled date and expected retained seal
   hash from the reviewed readback. Under the existing per-version publication
   lock, lock the exact assignment and re-read the occurrence and outcome in
   a fresh snapshot. Start, end and schedule changes serialize on the assignment
   row. The issuer can read the occurrence without locking it first, avoiding
   a lock inversion with start, which locks the occurrence before the assignment.
   Recheck the athlete, active materialised assignment, package hash, current
   civil day in the assignment timezone, unstarted disposition and seal. The
   candidate slot must be the sole slot in the exact version and in the seal.
   Recompute the live seal, compare it with the retained and expected seal,
   and match the entire reviewed workout. Derive the omitted block ID from
   the sealed third block. The issuer accepts no caller-supplied exercise,
   duration or omission. Insert only the immutable Recovery approval.
6. **Verify the issued scope.** Read back one approval with the reviewed
   identity tuple, exact seal and omission. The dedicated authenticated reader
   derives identity from `auth.uid()` and rechecks that the same occurrence
   is due and unstarted. Verify the option is available only with a fresh
   Poor Sleep answer and that accepting revalidates the approval. Installed
   acceptance remains a separate operation.

## Retries and refusal

Use the existing one-row-per-version primary key and serialize issuers for
that version. Compare a retry’s complete request pins with the immutable
stored request before considering a new insert. An identical retry after
success returns the original approval with an `already_approved` status.
That status records the previous write. It grants no current read access and
does not make the option usable after a start, an end or any other scope
change. A different request for an approved version returns a conflict and
leaves the existing row intact. If the first response is unclear, reconcile
the stored tuple before resending the same request.

If start or End programme commits first, the fresh issuance read refuses
and inserts zero rows. The same refusal applies when the occurrence is
missing, mismatched, not due, moved to a different day, or the live seal
differs. A start or end after issuance leaves the historical approval intact
and removes access through the reader. Reacquisition, rescheduling or
resealing cannot retarget the approval.

## Smallest contract change to review

- **SQL.** Retain the exact version constraint, one-row primary key, RLS,
  write protection and grants. Remove the fixture UUID equality checks on
  the slot and occurrence columns and replace those literal predicates with
  exact inputs resolved through the existing assignment, occurrence, slot
  and seal joins. Pin the new package hash, authored slot and protocol.
  Store and compare the full issuance tuple. Keep the reader’s existing
  signature and derive live scope from the IDs on the stored approval.
  Use the existing assignment row lock for issuance revalidation.
- **App.** Keep the Recovery version gate and require nonempty runtime slot
  and occurrence IDs from the execution context. Drop the two fixture UUID
  comparisons. Continue comparing the server-bound plan with the prepared
  workout and reread approval on acceptance.
- **Proof after approval.** Replace fixture UUID injection with IDs returned
  by normal publication and acquisition in disposable Supabase. Run the
  existing authenticated journey and prove identical and conflicting retries,
  concurrent issue attempts, start/end versus first issuance, and seal drift.
  Verify that M3.2’s existing approval and History retain their original
  references. No publisher or acquisition schema changes are proposed.

Source references include the [retained publisher](../../../supabase/migrations/20261005140000_tracking_publication_artifact_retention.sql),
[slot insert](../../../supabase/migrations/20260926160000_private_protocol_graph_publication.sql),
[private acquisition](../../../supabase/migrations/20261026110000_training_setup_private_alpha_acquisition.sql),
[occurrence materialisation](../../../supabase/migrations/20260926120000_authored_occurrence_calendar_dates.sql)
and [reviewed Recovery patch](../../../supabase/migrations/20261113120000_approved_strength_recovery_option.sql).
