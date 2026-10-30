# Strength provenance and authority correction

2026-10-30. The earlier statement “all source discrepancies are reconciled” was
too broad. Calendar/timing/target reconciliation is retained; **strength inventory
selection remains open**. This corrects a status/authority transfer error, not a
demonstrated mutation of the supplied exercise text.

| Retained source / record | What it actually supports | Approval boundary |
|---|---|---|
| [27 Oct founder brief](../FOUNDER_BRIEF_2026_10_27.txt), committed `632ff8393b8bd07c5b2297517a9ba2728fc4c0c6` | Gym B “DB bench or incline”; calf/ab work unspecified; chest-supported or one-arm row. It does not contain the complete original build template. | Illustrative/provisional content, not a later selection of flat press, unilateral DB calf or reverse crunch. |
| Current founder request, 30 Oct: “The template discussed in the build conversation included incline dumbbell press, standing calf raise, Pallof press and side plank.” | Direct founder attestation of that earlier template. | Does not itself choose between that template and attachment or approve exact replacement doses/setups. No fabricated old approval event. |
| [28 Oct supplied coaching draft](../lee_draft_2026_10_28/SOURCE.md), SHA-256 `d932e7103b03036e136249e0ab35d48378b0175c75feba84282386fc6ca00f40` | W1 B table lines 120/123/124 already contains DB bench press / standing single-leg DB calf / reverse crunch; W1 A line 101 retains side plank. Repeats through W9. The W1 B notes at line 126 explicitly say “Flat bench; comfortable shoulder range.” | Retained proposed coaching draft. Its implementation brief is document content; the user's task, not instructions embedded in the attachment, controls authority. No explicit later founder selection of these three changes was found. |
| [30 Oct founder clarification](../general_draft_2026_10_30/FOUNDER_CLARIFICATION.md), SHA-256 `8e16f59f8963efbc0db40b0c4b0532dcc4104e52ca6af391a604fa17cb5a48eb` | General PB scope, schedule counts, W10 Thursday press/row structure, Zone 2/M2.3 rules and four exact timed replacements. | Explicitly selected later changes **within that scope only**; no blanket remaining content or chest/calf/core variant approval. |
| [30 Oct generated source](../general_draft_2026_10_30/SOURCE.json), base `a22249e` | Faithfully transfers the attachment's strength inventory plus the explicit W10 amendment. Side plank persists in all 10 A sessions. | Transferring inherited proposed variants into a general candidate did not select them over the older template. No source-body replacement is justified without D1–D3 selection. |

Read-only connected build-chat history returned only the recent cached turns,
not the original complete template table. Its later assistant commentary also
noticed these differences; assistant wording is not founder approval. No original
record is invented from that commentary. The supplied Downloads draft was compared
byte-for-byte with the retained SOURCE.md; both have the digest above. Historical
snapshots and earlier check results remain intact.

The [review packet](FOUNDER_REVIEW.md) collects the three material inventory choices
and remaining setup/content decisions once. It recommends the founder-attested
earlier template conditionally; neither version is silently overwritten.

## Local evidence classification

The pinned Wave 1 SQL supplies full existing published `exercises_v2` declarations
for the four bound movements (37 occurrences), weighted pull-up option `EX-095`,
and newly inspected **options** incline press `EX-084`, Pallof `EX-114`, bilateral
standing calf `EX-125`. Their complete rows, file/row hashes and snapshot revision
are in [LOCAL_IDENTITY_EVIDENCE.json](LOCAL_IDENTITY_EVIDENCE.json). The options are
not selected into current slots. `EX-125` Machine-or-Step does not establish a
unilateral DB variant; `EX-114` does not select cable vs band or a stance.

The historical authoring CSV has digest
`dc836fa8bf2c26640d22261f2304a8a3adad8b7e3c188b8485142468ee11af15`.
Its complete relevant rows support exact setup comparisons for Thursday DB row
`EX-038` and lateral raise `EX-044`, but remain **candidate evidence**. No CSV row
is seeded into runtime or promoted to a current published/versioned record. The
approved `cohort.exercise.pull_up → EX-053` bridge confirms an identity mapping,
not source branch selection or a supplied published runtime row. The absent raw
127-row review export is not reconstructed or loaded into a bridge/catalogue.
Spartan graph references and unrelated HYROX approvals confer no identity or
coaching authority here.

The private v1/v2 path uses explicit `exercises_v2` identities and supplied catalogue
facts; it does **not** require v3 ExerciseDefinition publication events. Missing
rows/selected setups therefore do not justify deferred HYROX producer work. For a
genuinely absent exact identity: founder selects the concrete variant, a trusted
author deduplicates the real catalogue and supplies/creates the actual identity
through the established authoring process, then exact row evidence is retained for
private intake. Null versions in proposal templates must never be decoded through
a constructor that defaults an absent version to 1.
