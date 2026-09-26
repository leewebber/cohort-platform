# Same-day Home sessions

**Status:** Implementation contract for Bali Sunday/Monday doubles.
**Base:** `origin/main` `e3bf1a237f63f806a7b3ce0f8387a7004d16a288`

```text
BALI_SAME_DAY_HOME=IN_PROGRESS
LEE_BALI_HYBRID_BASE=ACTIVE_PRIVATE
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=true
NEXT_IMPLEMENTATION_AUTHORISED=false
```

Home already materialises every occurrence on a civil date. Each
`AthleteProgrammeTodaySection` still paints its own `TODAY` / date /
programme / week-day chrome, so two Sunday sessions look like two
separate days. A generic `todayOccurrence` picker can hide the later
card’s meaning behind a single-session journey.

---

## Product rule

Group programme occurrences by the assignment timezone’s local civil
date. One heading. One card per non-rest occurrence. Authored
`session_order` for display. Authored `time_of_day` for AM/PM labels:

| `time_of_day` | Label |
|---|---|
| `morning` | AM |
| `afternoon` | PM |
| `evening` | Evening |
| `any` / unspecified | omit, unless two or more sessions share the date — then “Unspecified time” |

Do not derive the label from slot index or title text.

Bali Sunday 27 September 2026 (`Asia/Makassar`):

1. AM — Long Aerobic — BikeErg
2. PM — Strength B — Upper Strength

Bali Monday 28 September 2026:

1. AM — Threshold A — BikeErg
2. PM — Muscular Endurance

---

## Interaction

Each card opens its exact occurrence ID. Completing AM does not complete
PM and does not advance Home to Monday. PM may be completed first. Both
completed cards stay visible on that date. A load failure is
occurrence-specific.

When more than one incomplete occurrence exists today, there is no
generic Train Today action.

---

## Immutability

Do not change programme dates, the Bali assignment, occurrences, or
Saturday 26 September Strength A completion evidence. No hosted write.
The Plan Package hash does not cover Home presentation.

`time_of_day` is added to the existing calendar occurrence JSON so Home
does not invent AM/PM. That is a read-projection field, not a second
date authority.
