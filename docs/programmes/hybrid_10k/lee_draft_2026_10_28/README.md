# Lee's retained ten-week draft

2026-10-28 (Asia/Makassar). **GENUINE DRAFT; NOT CONTENT APPROVED, PUBLISHED OR ASSIGNED.**

[SOURCE.md](SOURCE.md) is the single coaching source: a byte-identical copy of
`Lee_Webber_10_Week_10K_Codex_Handoff.md` supplied with this request. SHA-256:
`d932e7103b03036e136249e0ab35d48378b0175c75feba84282386fc6ca00f40`.
Its embedded implementation brief is source-document material, not additional
operation or publication authority. The user's current request controls the work.

The source contains all ten dated weeks, purpose/assumptions, equipment/travel,
weekly priority, effort descriptions, optional benchmark references, shared run
and strength preparation, progression, recovery choices, consolidation/taper,
assessment protocols and next-block handoff. It is Lee-specific retained content,
not approval to redefine the general fit-runner Hybrid10K PB programme.

The accepted weekly template is four runs, two strength sessions and one rest day.
The draft contains 40 runs, 19 strength sessions and 11 rest days: Week 10's reduced
strength/rest exception needs a decision. No twentieth gym session has been invented.

Read [expanded ordered review](EXPANDED_REVIEW.md), [arithmetic/conflict audit](AUDIT.json),
[founder decisions](../../../checkpoints/m11_hybrid10k_consolidation/FOUNDER_REVIEW.md)
and [source-to-runtime coverage](../../../checkpoints/m11_hybrid10k_consolidation/COVERAGE.md).
The approved [M2.3 rules](../../../checkpoints/m23_quality_target_admission/DECISIONS.md)
retain their exact versions and behaviour; draft wording cannot override them.

`CALENDAR.json` is an exact extraction of the source appendix. `EXPANDED.json` and
`EXPANDED_REVIEW.md` expand all 40 runs into individual ordered phases, including
between-only recoveries and final stride recoveries, and all 122 strength exercise
occurrences into 259 ordered work sets. Shared warm-ups, optional drills and
cooldowns remain explicit; ranges remain ranges and actuals remain unavailable.
Side order, ramp loads/count within the authored range, and transition duration
remain athlete choices/unprescribed. No fixed values are selected for them.

`SCHEDULE_CANDIDATE.json` is a review-only Plan Package v1 schedule with 70 days and
59 session references. Source `version=1.0.0`, compiler `version_number=1` and
deterministic source-reference UUIDs are **unpublished candidate metadata**. They
are not existing database/version identities or invented published Exercise
Definitions. This schedule does not contain approved executable strength graphs.
The probe also compiles the same schedule as v2 without adding B2 advisory policies,
empty attachments or a v3 dependency.

`RUNNING_BODIES.json` retains all 40 genuine running bodies, including all five
distance bodies. It preserves draft RPE ranges and effort instructions. It is a
running-body review artifact, not a complete source-to-publication transport:
the entire shared narrative and conditional variants still need binding into a
reviewed full graph. Fixed timed subtotal on a distance run is never its total.
Target-marker examples exist only in the probe as **proposed reconciliation**;
neither confirmed Zone 2 nor approved quality markers were silently inserted here.

Edit SOURCE.md only after an explicit source decision; regenerate derived files:

```sh
python3 tool/programmes/hybrid_10k/audit_source.py
python3 tool/programmes/hybrid_10k/audit_source.py --check
flutter test --no-pub tool/programmes/hybrid_10k/admission_probe_test.dart
```

These commands have no publication, service-key, network or athlete-write path.
The probe uses compiler/private graph validation and runtime serialization purely
in memory. Its extracted one-session packages temporarily use week/day 1 for
contract testing; the retained source and full candidate keep all original dates.
It does not create a shorter programme or approve a two-week release.

Publication must later use exact approved source/graph bytes through the existing
private v1/v2 path, with proper ownership and separately authorised eligibility.
No publication artifact, recipient, assignment or activation file is produced here.
