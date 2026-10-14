Recommend **one bounded extension: author a second independent synthetic strength-session lineage, then compose exact frozen revisions from both lineages using the accepted straight-sets editor and Studio workflow.** No sprint number is assigned.

Inspection used the clean composition worktree at `c75d38358a8a8bc37f6d0444f206b1bffcb81c29`. Cached `origin/main` matches; no remote freshness claim is made. The original checkout still has exactly 95 outstanding paths. Its saved file inventory, HEAD, index and `.temp`, plus both older D1/D2 checkout inventories, match exactly. No files were changed, and no tests, builds, fetches or hosted operations were run.

This follows [Studio’s canonical-source rule](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/docs/architecture/Programme_Studio_v1.md:81) and the [accepted next-task recommendation](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/docs/checkpoints/programme_studio_composition/NEXT_STAGE2_HANDOFF.md:1).

**Bounded scope.** Preserve the original lineage and seed byte-for-byte. Add one explicit **Create second synthetic session** action within composition, reusing the existing editor. Allow the same one-block, one-or-two-exercise straight-sets grammar: exact sets/reps, existing optional rest/tempo/cue, and unspecified/bodyweight/kg/RPE load modes. Keep the existing programme duration, available days, editable fields and locked contracts.

Creation, freeze, admission and slot selection remain separate actions. A new session must require explicit author input; do not silently clone or invent a prescription.

**Identity and ownership.** Use the existing `SessionRevisionIdentity` tuple: `(protocolId, sessionLineageId, revisionNumber)`. Keep the original identifiers unchanged. A concrete second-family convention is:

| Identity element | Existing lineage A | Proposed lineage B |
|---|---|---|
| Lineage | `SYN-D2-STRENGTH-LINEAGE` | `SYN-D2-STRENGTH-B-LINEAGE` |
| Root protocol | `syn-d2-strength-r1-w1-d1-s1` | `syn-d2-strength-b-r1-w1-d1-s1` |
| Later protocol | Existing root + `-rev-N` | B root + `-rev-N` |
| Wrapper import key | `syn-d2-strength-rN` | `syn-d2-strength-b-rN` |
| Programme session key | `SYN-D2-STRENGTH-RN` | `SYN-D2-STRENGTH-B-RN` |

These are fixed synthetic identities, not user-editable names. Reuse the unchanged [revision-ID helper](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/lib/features/session_revision/services/session_revision_clone.dart:20).

Each lineage should use its own instance of the **existing** authoring controller and revision catalogue. Composition owns both instances and retains one admitted programme catalogue. This adds neither a parallel catalogue implementation nor another editor.

Live admission must:

- Identify the owning lineage controller.
- Require the identical frozen-entry object retained by that owner.
- Recompile its exact source under that lineage’s fixed policy.
- Compare tuple, source bytes/digest, compiled meaning and exercise-version bindings.
- Reject foreign-workspace entries, even when their bytes and tuple match.

Require globally unique protocol IDs and session keys, and unique `(lineage, revision)` pairs. An identical live repeat is idempotent; a conflicting replacement is refused. Duplicate packet entries remain invalid.

Titles are display data. Both lineages may have the same title and R1/R2 numbers. Every cross-lineage lookup, picker value, widget key, confirmation and admission-status check must use the validated full identity or its exact session-key mapping.

**Initial root and revision evolution.** A currently starts from the exact retained fixture source. B needs a new-root authoring mode because the existing catalogue requires a retained R1 and only allocates descendants.

For B, create a transient draft from the fixed wrapper with empty required author fields. Validate through the existing guard/writer/compiler. Assign and pin B’s R1 only at successful, current first freeze; failed or cancelled creation allocates no frozen revision. That first source has no frozen-parent comparison.

Afterward, reuse existing max-plus-one reservations, abandoned-number protection, parent-source diffs and semantic no-op refusal independently within each lineage. A change to A must leave every B frozen byte, binding and reference unchanged, and vice versa. Frozen entries remain synthetic, unpublished local snapshots.

**Profile boundary.** Both lineages should share the exact existing exercise fixture profile:

- `cohort.exercise.d2_fixture_a` → `EX-9001@1`
- `cohort.exercise.d2_fixture_b` → `EX-9002@1`

Preserve the complete definition/mapping snapshots and existing profile ID, version and fingerprint. This is an exercise-resolution fixture profile; it grants no tracking or comparison authority.

The [current composition check](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/lib/features/programme_studio/composition/synthetic_composition_fixtures.dart:57) checks resolved bindings against these versions. Its profile fingerprint is generated from the default fixture definitions/mappings, while the compiler permits injected snapshots. For this extension, bind the **actual immutable compiler snapshot fingerprint** into its receipt and verify it against the fixed composition profile. Matching IDs/version strings alone must not admit altered definitions, mappings or provenance.

The source policy should allow exactly the two fixed lineage descriptors. Preserve the existing locked synthetic wrapper; vary only the descriptor-bound import key and allowed session subtree. Founder YAML still does not encode revision identity, and this workflow does not establish an apply/import path.

**Actual gaps versus accepted behaviour.**

| Actual extension gap | Expected component change |
|---|---|
| Compiler hard-codes A’s root, lineage and import-key family | Add a narrowly scoped synthetic lineage policy to the existing local compiler; preserve standalone defaults. |
| Authoring/catalogue assumes an exact retained initial R1 | Add B’s initial-root mode and per-lineage policy to the existing controller/catalogue. |
| Composition owns one session controller | Own both controllers; observe both generations and draft states. |
| Selection accepts only a revision number; UI keys/status use numbers | Select an exact admitted tuple/key and scope all UI identities across lineages. |
| Reference generation and root checks assume one lineage | Extend the existing composition source/catalogue policy with per-lineage roots and collision rules. |
| Handoff rejects duplicate revision numbers globally and sorts only by number | Validate full identities and sort deterministically by lineage, numeric revision, then protocol ID. |
| Receipts do not carry the actual compiler-profile fingerprint | Add and verify that local binding without changing shared identity authority. |

Evidence: [compiler restriction](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/lib/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart:89), [initial catalogue rule](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/lib/features/programme_studio/protocol_authoring/synthetic_session_revision_catalogue.dart:15), [revision-number selection](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/lib/features/programme_studio/composition/synthetic_composition_controller.dart:186), and [transport assumptions](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/lib/features/programme_studio/composition/synthetic_composition_handoff.dart:69).

Already supported—and to be preserved—are genuine-entry admission, separate confirmed selection, immutable snapshots, D1 catalogue refresh without losing edits, every-slot prescription verification, pending-operation invalidation, callback/reset/disposal protection, copy-consumption checks and complete selected/unselected-source transport. The [accepted composition review](/Users/leewebber/.codex/worktrees/programme-studio-composition/cohort_platform/docs/checkpoints/programme_studio_composition/FINAL_REVIEW_AND_ACCEPTANCE.md:18) records these guarantees. They need cross-lineage coverage, not replacement implementations.

Reuse D1’s slot controls, YAML writers, source-provider seam, derived reader transport, actual projector and Studio presentation. The reader-text bridge already accepts multiple protocol IDs. Its standalone package helpers need only lineage-policy support for B’s individual preview.

**Selection, freshness and reopen.** Keep the original assessed slot on A for the walkthrough. Add B through an existing required-slot action; preserve locked comparison/evidence declarations unchanged. Sharing exercise fixtures does not make A and B comparable.

Joint review must capture exact programme bytes, admitted catalogue state, both owner identities/generations and the operation token. A draft or source change in either lineage invalidates joint success immediately. Verify freshness after awaits, notification completion and at export/copy consumption.

The handoff must contain exactly every declared programme revision, including unselected revisions and both declared roots. Unadmitted frozen entries and working drafts remain outside that declared inventory.

I recommend preserving existing single-lineage transport-v1 output and reopening unchanged, while using **local handoff transport version 2** for packets declaring B. Keep the same canonical YAML payload lanes; this is unrelated to Plan Package v2 or running editing.

Reopen must recompute profile, source, tuple, catalogue, package-hash and every-slot claims. Require exact known A R1 bytes; validate B R1 under its fixed source policy, then enforce each lineage’s wrapper boundary on later revisions. Re-export must be byte-idempotent.

Reopen remains a separate read-only review. It cannot admit entries into live catalogues, restore reservations or resume editable history. Consistent supplied bytes establish a validated read-only source binding; hashes do not prove an earlier freeze or founder approval.

**Concrete founder walkthrough.**

1. Validate the original A-only seed and inspect its full prescription.
2. Create B using the reused form. Choose the existing fixture exercises and explicitly enter a different synthetic prescription. Use the **same session title as A**. Freeze B R1; demonstrate A R1 and its selected slot remain unchanged.
3. Admit B R1. Show admission leaves selection unchanged. Add a required slot using D1’s existing controls and explicitly select B R1 after reviewing its full tuple/digest. Inspect both slots in Studio.
4. Create and freeze A R2. Show B R1 bytes/references unchanged. Admit A R2 and explicitly select it for A’s slot.
5. Create and freeze B R2 with the same title and revision number as A R2. Admit it but leave B R1 selected. Verify all-slot bodies and export an inventory containing A R1/R2 and B R1/R2.
6. Reopen that complete handoff read-only. Inspect both selected bodies and all four declared sources; re-export identical bytes. Show live owners, frozen history and selections were not replaced.

Include invalid input, cancelled confirmation and stale-review clearing during the walkthrough.

**Acceptance criteria.**

- Same-title/same-number A/B cases remain distinct through authoring, admission, selection, widgets, Studio and transport.
- Exact tuple/import-key/source/profile/version bindings pass; conflicting tuple/key/protocol reuse, foreign owners, altered profiles and unsupported sources fail closed.
- Initial-root failures commit nothing; later no-op and abandoned-reservation protections remain.
- Editing either lineage preserves the other’s frozen bytes and all unrelated references.
- Every slot resolves its exact complete body after selection, addition, ordering and movement.
- Races cover changes in either lineage during compile/admission/selection/export/reopen, competing requests, late failures, notification edits, queued microtasks, reset, disposal and stale panels/copy.
- Deterministic export→reopen→export includes unselected declared sources. Missing/extra/duplicate/tampered inputs fail without partial live mutation.
- Existing D1/D2/composition behaviour and old handoff round trips remain compatible.
- Shared compiler/schema/hash, canonical resolver/revision allocator, published artifacts and v1/v2 goldens remain byte-identical.

Implementation must freshly measure full analysis before editing and afterward. Retain the inherited qualification: **367 diagnostics—110 warnings, 257 info, zero errors; full analysis is non-green.** Require zero new diagnostics, zero diagnostics in every new/changed Dart file, zero repository errors and comparison of diagnostic identities. Unexpected baseline drift must be explained rather than silently adopted.

Run affected Studio/Founder/authored-package/session/identity regressions, the canonical-package suite, all six unchanged safety groups, `git diff --check`, documentation-link checks and protected-byte/preservation checks. No database gate is required for this transient source-only extension. Historical composition results are recorded evidence, not checks rerun here.

**Safe implementation strategy.** After explicit implementation approval, create a separate managed worktree from the exact published SHA, with branch `codex/studio-strength-lineages`. Preserve the accepted composition checkout as well as every older checkout. Do not move original local main. Create neither branch nor worktree during this allocation turn.

The ready-to-run handoff is:

> Implement the bounded two-lineage synthetic strength-session allocation above from `c75d38358a8a8bc37f6d0444f206b1bffcb81c29`, after founder implementation approval. Use a separate clean managed worktree on `codex/studio-strength-lineages`. Read AGENTS.md, CURRENT_CHECKPOINT.md, binding Studio/roadmap contracts and D1/D2/composition acceptance records.
>
> Preserve all older contents, HEADs, indices, the original 95 outstanding paths and `.temp`; capture and compare preservation inventories. Reuse existing editor/catalogue/compiler adapters and composition. Add only fixed lineage B, initial-root authoring, full-identity operations, exact actual-profile bindings, both-owner freshness and complete deterministic read-only transport. Preserve standalone defaults and old transport compatibility.
>
> Complete the acceptance checks and local founder Chrome walkthrough. Protect shared compiler/schema/hash and published/golden bytes. Do not fetch, commit, publish, contact hosted systems, build/install on devices or expand scope without separate authority. Stop for founder review with implementation evidence.

**Remaining Stage 2 coverage.** The roadmap requires a controlled structured-authoring workflow generating the existing Plan Package and protocol sources. It does not enumerate a universal closure suite. This extension improves independent session creation within one accepted representation; it does not close Stage 2.

Broader programme creation/source intake, other representations, additional schedule structures, locked-contract editing and editable archive restoration remain unallocated coverage choices. Arbitrary lineage counts and broader fixture profiles are optional future extensions, not established closure requirements. Real content approval, hosted publication and Stage 3 operator controls remain separate.

Broader Sprint C and Stage 2 stay open. The four genuine-record-dependent phone checks remain pending. No production wiring, athlete writes, persistence services, tracking work or v2 running editing is included. **Implementation has not begun.**
