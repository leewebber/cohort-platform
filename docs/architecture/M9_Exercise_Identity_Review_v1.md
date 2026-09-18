# Exercise identity review (M9, repository scan)

No hosted mutation. Counts from committed Apollo SQL only.

| Finding | Detail |
|---------|--------|
| Canonical ID | `exercises_v2.exercise_id` = `EX-*` |
| Hosted freeze | EX-001–EX-132 on Field Manual (132 rows) |
| Local Apollo extras | EX-133–EX-169 in dogfood migrations — not the 132-row freeze |
| Apollo SQL unique IDs | 58 `EX-*` tokens across Apollo week files |
| Highest usage | EX-147, EX-129 (Running), EX-138/139/145/146 (~27–28 refs) |
| Duplicate names in INSERT scan | 0 exact-name duplicates in scanned `('EX-nnn','Name'` rows |
| Distinct variants to keep | Weighted Pull-Up EX-095 vs Neutral-Grip EX-137 vs Strict EX-149; generic Running EX-129 vs intensity-specific rows |
| Aliases | Knowledge YAML only; not identity |
| Unresolved | Some TMP steps have no `exercise_id`; HYROX TMP-006 prose; Plan Package v1 has zero exercise IDs |
| Merge policy | **Do not** auto-merge similar names |

Potential human-review pairs (not merged): pull-up family; running family; display_label_override vs catalogue name.

Production consumers key by `EX-*`. Evidence uses `source_exercise_id`.
