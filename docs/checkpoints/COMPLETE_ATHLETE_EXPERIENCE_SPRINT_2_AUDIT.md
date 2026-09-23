# Complete Athlete Experience Sprint 2 — audit

**Recorded:** 2026-09-23
**Live pointer:** Founder decisions bound 2026-09-23.
Sprint 2 is **approved, not started, not implemented.**
Binding:
[`../architecture/Complete_Athlete_Experience_Sprint_2_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_2_v1.md)
§3. Historical §§1–7 remain the audit evidence. The §8 list below is
preserved as the pre-decision question set; live answers are in §8.1.
**Base:** `origin/main` `a3cd3512093f4dc96843e01ab0efe311671e4db9`

```text
COMPLETE_ATHLETE_EXPERIENCE=ARCHITECTURE_APPROVED
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE
COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=APPROVED_NOT_STARTED
NEXT_IMPLEMENTATION_AUTHORISED=false
REPLACEMENT_TRANSACTION_AUTHORISED=false
HOSTED_REPAIR_AUTHORISED=false
HOSTED_WRITES=false
PUSHED=false
```

Sprint 1 **Programme Discovery and Decision** is integrated at `a3cd351`.
This audit does not reopen it.

---

## 1. Purpose

Determine the truthful production design for:

1. Enrolment start-date and timezone integrity
2. Exact pinned programme-version continuity
3. Catalogue-default movement
4. Athlete-visible “your programme is unchanged”
5. Future replacement as architecture only

---

## 2. Production path (evidence)

### 2.1 Version and enrol

| Step | File | Fact |
|------|------|------|
| Catalogue id | `lib/data/repositories/programme_version_supabase_store.dart` | `programme_versions.id` → `ProgrammeCatalogEntry.versionId` |
| Eligible list | `lib/features/programme/services/athlete_programme_switch_catalog_service.dart` | Published, cohort_global, approved, not archived |
| Confirm | `athlete_programme_enrolment_review_screen.dart` | `confirmEnrol(startedAt: DateTime.now(), timezone: DateTime.now().timeZoneName)` |
| Controller | `athlete_programme_controllers.dart` | `replaceActive` forced false; active assignment → `sprint1_switch_unavailable` without RPC |
| Store | `athlete_catalogue_enrolment_supabase_store.dart` | RPC `enrol_athlete_in_catalogue_programme_version` |
| RPC | `supabase/migrations/20260817170000_enrol_replace_active_materialised_assignment_guc_correction.sql` | `v_athlete_id := auth.uid()`; pin `p_programme_version_id`; `started_at = CURRENT_DATE`; timezone trimmed, **not IANA-validated** |

Review `startedAt` is **not** forwarded to the service or RPC.

### 2.2 Pin and default

| Mechanism | Evidence |
|-----------|----------|
| Pin column | `programme_assignments.programme_version_id` |
| No in-place repin | `content_graph_prevent_assignment_repin` in `20260918120000_content_graph_core.sql` |
| Catalogue replacement | `replace_approved_cohort_global_programme_version` archives the old eligible version |
| Execution | `today_session_service_impl.dart`, `athlete_programme_authored_slot_resolver.dart`, `cohort_resolve_fixed_programme_calendar_at` load **pin + hash** |
| Restore | `production_restore_resolver.dart` rejects version mismatch |
| M9 `catalogueDefault` | Local `ContentGraphService` only — not the athlete shell |

No production athlete path silently follows the latest default.

### 2.3 Start, occurrences, today

| Step | Evidence |
|------|----------|
| Start Programme | `athlete_programme_screen.dart` → `start_fixed_programme_from_enrolment` |
| Start timezone | Reuses stored assignment timezone; validates `pg_timezone_names` |
| Start date picker | Device-local `DateTime.now()`, not assignment-zone today |
| Occurrences | `ensure_programme_schedule_projection`: `started_at + day_offset` |
| Home/Calendar today | `(p_now AT TIME ZONE assignment.timezone)::date` via `resolve_active_fixed_programme_calendar` |
| Client greeting clock | `AthleteIanaClock` — small hardcoded map; unknown zone → **UTC** |
| Daily Journey | `create_or_resume_fixed_programme_occurrence_session` on pinned occurrence |

Timezone disagreement (abbreviation stored, picker in device zone, client
UTC fallback) **can** label the wrong athlete-local day.

### 2.4 Reconstruction vs fresh enrol

Fresh enrol: insert assignment, inert `CURRENT_DATE`, unvalidated
timezone, `legacy_cursor` until Start.

Start: overwrite `started_at` / timezone, `fixed_schedule`, ensure
projection.

Reload: `ensure_programme_schedule_projection` is idempotent; it does not
recalculate dates if the projection exists.

Backfill (`20260913120000_...`) writes historical `performed_on`; it does
not rewrite occurrence `scheduled_date`.

---

## 3. Timezone options (audit)

| Option | iOS / Android / web | DST | Travel | Offline | Persist | Authority |
|--------|---------------------|-----|--------|---------|---------|-----------|
| Device IANA | Needs a plugin; **not in repo** | Correct if real IANA | Changes with device | Last known device | Can persist after validate | **Hint** |
| Profile timezone | **Missing** | — | — | — | — | — |
| Explicit picker | All platforms | Correct if list is IANA | Stable until athlete changes it | Cached choice | Yes | **Authoritative confirmation** |
| Abbreviation | `timeZoneName` today | Unsafe | Ambiguous | Yes | Currently stored | **Not authoritative** |
| Offset only | Easy | Unsafe | Misleading | Yes | Must not | **Not authoritative** |

**Persist:** Bali `Asia/Makassar`. UK `Europe/London`.

**Travel:** keep assignment zone; do not move days.

**Invalid device IANA:** fail closed + picker.

**Schema:** validate existing TEXT; enrol RPC currently accepts anything.

---

## 4. Pin / default honesty (current vs required)

Already distinguished in code: Current programme (exact version match),
Available, Not available.

**Not distinguished:** current catalogue default, newer version
available, superseded-but-valid, withdrawn, completed.

Misleading today:

- After atomic catalogue replacement, catalogue hides the pin; overview
  can still show the old title; Calendar/Home fail closed.
- No version number on cards.
- Enrolled-only Home looks like no programme until Start.
- Progress `planName` is `lineageCode` (Sprint 3).

---

## 5. Replacement models

Existing RPC already implements **end + create** when
`p_replace_active` is true. Sprint 1 never sends that flag.

| Model | Recommendation |
|-------|----------------|
| Mutate pin | Rejected (trigger) |
| End + create | **Recommend** if founder later approves the transaction |
| Epochs | Not present; unnecessary |

Draft / adaptation / occurrence aftermath on replace is **unbound**.
History rows stay on the old assignment (Gate S).

---

## 6. Readiness scoreboard

| Area | Score | Evidence | Launch implication |
|------|-------|----------|--------------------|
| IANA timezone capture | **Prototype-only** | `timeZoneName`; no plugin | Enrol start can be wrong or unblockable |
| Timezone persistence | **Functional but incomplete** | TEXT column; no enrol validation | Start/calendar reject abbreviations |
| DST correctness | **Strong foundation** (server IANA) / **Prototype-only** (client clock) | `AT TIME ZONE`; `AthleteIanaClock` map | Greeting/date helpers can disagree |
| Travel handling | **Missing** | No policy in product code | Device TZ change can confuse picker/today |
| Enrolment start-date integrity | **Functional but incomplete** | Inert `CURRENT_DATE`; Start picker is device-local | Wrong first day |
| Assignment pin integrity | **Production-complete** | Exact UUID + trigger + tests | Do not reopen |
| Default-change honesty | **Missing** | Silent pin; no copy | Athlete thinks the programme changed or vanished |
| Superseded-version messaging | **Missing** | Current/Available/Unavailable only | Trust gap |
| Withdrawn-version handling | **Fail-closed** (exec) / **Functional but incomplete** (UI) | Calendar/prepare fail; overview may still name pin | Contradictory surfaces |
| Programme completion transition | **Functional but incomplete** | Plan Complete card; no next CTA | Sprint 3 |
| Replacement design | **Strong foundation** (this audit) | End+create exists | Not a product |
| Replacement transaction | **Missing** (product) | Sprint 1 blocks RPC | Do not implement in Sprint 2 |
| Home/Calendar agreement | **Strong foundation** | Same hosted today RPC | Breaks together if timezone wrong |
| Daily Journey pin continuity | **Production-complete** | Pin + hash restore | Must stay |
| Historical truth | **Strong foundation** (server) | Completions stay on assignment | Narration weak |
| Offline behaviour | **Functional but incomplete** | No catalogue cache; pin on server | Retry |
| Recovery/error | **Strong foundation** | Typed calendar/prepare errors | Need unified copy |
| Status-language a11y | **Missing** | No superseded vocabulary | Sprint 2 copy must not be colour-only |

---

## 7. Sprint recommendation (historical 2026-09-23 audit)

**Smallest vertical slice:** IANA enrol + start-date honesty +
pinned-versus-default status + unified unavailable-pin copy.
Replacement remains architecture only.

The founder-approved boundary and the start-date override
(`CURRENT_DATE` is **not** retained as inert authority) live in
[`../architecture/Complete_Athlete_Experience_Sprint_2_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_2_v1.md)
§§3 and 9–10.

---

## 8. Founder decisions

### 8.1 Resolved (2026-09-23)

| # | Historical question | Binding |
|---|---------------------|---------|
| 1 | Approve Sprint 2 boundary (no replacement transaction)? | **Approved, not started.** Included: IANA enrol, athlete-local start date, server validation/persistence, pin-versus-default status, truthful current/default/superseded/unavailable copy, unified unavailable-pin handling. Excluded: replacement transaction, repin, automatic upgrade, completion, Progress/History, travel rescheduling, settings redesign, matching, adaptation, payments, wearables, offline completion queue. |
| 2 | Persist `Asia/Makassar` / `Europe/London`; fail-closed invalid capture? | **Yes.** Validated IANA only. Device IANA is a suggested default. Review shows the zone and the athlete may change it. Server validates `pg_timezone_names`. Never persist or infer `BST`, `GMT`, `WITA`, `KST`, or offsets. |
| 3 | Travel does not move scheduled days? | **Yes.** Active programme stays on the enrolment timezone. Device change does not rewrite the assignment. Travel rescheduling is a later product. |
| 4 | End+create as the future replacement model? | **Approved as architecture only.** End current assignment, preserve history, create a new pin, link via `superseded_by_assignment_id`. Never mutate the old pin. Transaction, UI, mid-programme eligibility, draft/adaptation aftermath, occurrence cancellation, return-to-old, RPC/schema, and entitlement remain **unapproved**. |
| 5 | Abbreviation rows need explicit IANA repair, not guessed mapping? | **Yes.** Repair-required fail-closed state may be built in Sprint 2. Hosted repair apply requires separate inventory and founder approval. Do not assume occurrence regeneration vs timezone-only repair. |

**Start-date override:** the audit’s “keep enrol `CURRENT_DATE` inert”
recommendation is **not** adopted. The server derives `started_at` as
the athlete-local date in the validated IANA zone inside the enrol
transaction. Decorative client `DateTime.now()` is not authority. No
new future-date picker.

### 8.2 Historical unresolved list (pre-decision)

Preserved as the 2026-09-23 audit question set:

1. Approve the Sprint 2 implementation boundary (no replacement
   transaction).
2. Confirm `Asia/Makassar` / `Europe/London` and fail-closed invalid
   capture.
3. Confirm travel does not move scheduled days.
4. Confirm end+create as the only future replacement model, still
   unapproved as a transaction.
5. Confirm abbreviation rows need explicit IANA repair, not guessed
   mapping.

---

## 9. Acceptance gates (implementation, later task)

See
[`../architecture/Complete_Athlete_Experience_Sprint_2_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_2_v1.md)
§10. Summary: iOS/Android/web IANA capture; server IANA validation;
UTC-midnight local date; `Europe/London` DST; `Asia/Makassar` non-DST;
invalid/missing fail-closed; travel without silent movement; idempotent
enrol; no row on validation failure; no pin mutation; default change
without execution change; no cross-version composition; consistent
unavailable-pin copy; 320/390 and large-text review; accessible status
wording; local DB Gate AY if RPC/schema changes; no hosted apply or
data repair without separate approval.

---

## 10. Explicit non-actions

No Sprint 2 implementation, no replacement RPC/UI, no hosted timezone
repair, no schema inventing occurrence rewrites, no Field Manual, no
phone, no push, no Sprint 3.
