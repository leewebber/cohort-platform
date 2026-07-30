# Cohort MVP Design Review v1

**Phase:** 6 — Product Hardening  
**Sprint:** 1 — Cohort MVP Design Review  
**Date:** 2026-07-29  
**Status:** Recommendations baseline + Sprint 2 Critical/High addressed + Sprint 3 persistence  
**Scope:** Athlete-facing MVP (closed-beta readiness)  
**Out of scope (Sprint 1):** New features, engine changes, persistence, coach surfaces as product work  
**Sprint 2:** Athlete/Founder separation, Home/Progress/Profile polish, contextual previous performance  
**Sprint 3:** Local athlete memory, product constitution, legacy test debt closure, welcome/assessment backlog docs

This document is the baseline for closed-beta preparation and defines the intended shape of **MVP v1.1** polish before external testing.

---

## Executive summary

Phase 5 delivered a coherent athlete loop:

**Start → Plan → Briefing → Execute → Adapt → Progress**

The product already feels more like a coach than a settings app on the critical path (Daily Briefing → Execute → Complete → tomorrow). The theme language (dark olive, phosphor CTAs, strong typography) is distinctive and mostly consistent.

What blocks closed beta is not missing engines — it is **friction, inconsistency, and unfinished edges**:

1. Navigation labels that do not match destinations  
2. Home still behaving partly like a dashboard under the briefing  
3. Duplicate / orphan “today” UI paths  
4. Thin Profile and Progress empty states  
5. Inconsistent CTA language and incomplete loading/error coverage  

**Verdict:** Ready for internal dogfood. Not yet ready for external closed beta without a focused **MVP v1.1 polish pass** (no new features).

---

## Review philosophy (applied)

| Principle | Test |
|-----------|------|
| One question per screen | Can the athlete state it in one sentence? |
| Obvious next action | Is the primary CTA unambiguous? |
| Premium feel | Does spacing, type, and motion feel intentional? |
| Coached, not configured | Does copy avoid software/admin language? |
| Reduce load | Can anything be removed without losing clarity? |

---

## Screen-by-screen review

### 1. Login / Start Training

**Surfaces:** `login_screen.dart`, `auth_gate.dart`, AuthScaffold

| Question | Finding |
|----------|---------|
| **Working well** | Clear AuthScaffold hierarchy; guest **START TRAINING** enables zero-friction entry; loading gate exists |
| **Confusing** | Two equal-looking paths (Sign in vs Start Training) compete for attention |
| **Unfinished** | Guest vs account identity story is unclear after entry |
| **Simplify** | One primary: Start Training; Sign in as quieter secondary |
| **Premium** | Dark scaffold and typography |
| **Breaks philosophy** | Auth can feel like “account software” before coaching begins |

**One question the screen should answer:** *How do I begin training?*

---

### 2. Onboarding

**Surfaces:** `athlete_onboarding_flow.dart`

| Question | Finding |
|----------|---------|
| **Working well** | Linear steps, sticky CONTINUE, generating state with progress |
| **Confusing** | Copy still says “programme” while product language is **Plan** |
| **Unfinished** | Errors can surface raw `toString()`; no calm cancel on generating |
| **Simplify** | Fewer steps or clearer “why we ask” microcopy |
| **Premium** | Choice chips and step rhythm |
| **Breaks philosophy** | “GENERATE MY PROGRAMME” sounds like software generation, not a coach assigning a plan |

**One question:** *Who am I as an athlete?*

---

### 3. Plan Library

**Surfaces:** `plan_library_screen.dart`, `plan_widgets.dart`

| Question | Finding |
|----------|---------|
| **Working well** | Clear browse intent; filter chips; premium card composition |
| **Confusing** | Hardcoded filter set may not match catalog reality |
| **Unfinished** | Terrain icon placeholders instead of plan imagery |
| **Simplify** | Fewer filters until catalog grows |
| **Premium** | Gradients, chips, typography on cards |
| **Breaks philosophy** | None major — stays product-facing |

**One question:** *Which coaching product is right for me?*

---

### 4. Plan Detail

**Surfaces:** `plan_detail_screen.dart`

| Question | Finding |
|----------|---------|
| **Working well** | Overview / who / improve / requirements / week / FAQs; sticky **START PLAN** |
| **Confusing** | No “already your active plan” state |
| **Unfinished** | Hero is colour placeholder; start errors may be technical |
| **Simplify** | Shorter longDescription on mobile |
| **Premium** | Sticky CTA, large hero, section rhythm |
| **Breaks philosophy** | Low risk |

**One question:** *Should I commit to this plan?*

---

### 5. Home + Daily Briefing

**Surfaces:** `home_screen.dart`, `daily_briefing_section.dart`, `choose_plan` empty card

| Question | Finding |
|----------|---------|
| **Working well** | Briefing answers “what should I know before I train?”; Execute is dominant when active; rest day handled |
| **Confusing** | Empty state stacks greeting + “Start with a plan…” + “Choose Your First Plan” |
| **Unfinished** | Home still appends Training History / Adapt / Knowledge — dashboard chrome under a briefing |
| **Simplify** | Briefing-only first viewport; defer History/Adapt/Knowledge |
| **Premium** | Greeting, standards checklist, motivation line |
| **Breaks philosophy** | Duplicate “Training focus” (meta row + TODAY'S FOCUS); Adapt path may no-op (section key without mounted widget); orphan `TodaySessionCard` / `AthleteGeneratedTodaySection` / `HomeTodaySessionSection` |

**One question:** *What should I know before I train today?*

---

### 6. Workout Overview

**Surfaces:** `workout_overview_screen.dart`

| Question | Finding |
|----------|---------|
| **Working well** | Brief from engine; loading + retry error; **START SESSION** |
| **Confusing** | CTA wording differs from Home (“EXECUTE…” vs “START SESSION”) |
| **Unfinished** | Limited coach narrative presentation |
| **Simplify** | Align CTA language with Home |
| **Premium** | Calm overview before effort |
| **Breaks philosophy** | Low |

**One question:** *Am I ready to begin this session?*

---

### 7. Workout Player

**Surfaces:** `workout_player_screen.dart`

| Question | Finding |
|----------|---------|
| **Working well** | Clear set progression; COMPLETE SET primary |
| **Confusing** | No obvious mid-session exit / end-early |
| **Unfinished** | Video placeholder; sparse empty “no exercises” |
| **Simplify** | One focus: current set only |
| **Premium** | Progress framing |
| **Breaks philosophy** | Placeholder media breaks premium promise |

**One question:** *What do I do right now?*

---

### 8. Workout Completion

**Surfaces:** `workout_complete_screen.dart`

| Question | Finding |
|----------|---------|
| **Working well** | Duration / exercises / RPE / notes; adaptive transition copy is calm |
| **Confusing** | RPE optional with no scale guidance |
| **Unfinished** | Bookkeeping failures silent; adapt errors somewhat technical |
| **Simplify** | Shorter transition if generation is fast |
| **Premium** | “Analysing… / Updating… / Tomorrow is ready.” |
| **Breaks philosophy** | Low — this is the coaching loop moment |

**One question:** *How did today feel — and what’s next?*

---

### 9. Progress

**Surfaces:** `progress_screen.dart`

| Question | Finding |
|----------|---------|
| **Working well** | “Am I getting better?”; plain-language improvements; no chart spam |
| **Confusing** | Metric card grid can feel denser than the calm brief |
| **Unfinished** | Empty state has no path to Plans |
| **Simplify** | Lead with improvements + plan; demote secondary metrics |
| **Premium** | Timeline and history language |
| **Breaks philosophy** | Slight dashboard drift if all sections equally weighted |

**One question:** *Am I getting better?*

---

### 10. Profile / Account

**Surfaces:** `account_screen.dart`, bottom nav Profile

| Question | Finding |
|----------|---------|
| **Working well** | Sign out; role display |
| **Confusing** | Called Profile in nav, Account in screen |
| **Unfinished** | No plan, goals, equipment, or preferences — too thin for “Profile” |
| **Simplify** | Either rename to Account or add minimal athlete identity |
| **Premium** | Weak — sparse |
| **Breaks philosophy** | Feels like auth admin, not coaching relationship |

**One question:** *Who am I in Cohort?* (currently unanswered)

---

## Navigation review

**Current athlete bottom nav:** Home · Plans · Sessions · Progress · Profile

| Question | Status |
|----------|--------|
| Where am I? | Weak — stack pushes don’t keep true tab selection; Sessions label ≠ destination |
| What do I do next? | Strong on Home when plan is active (Execute) |
| Where do I find things? | Mixed — Plans/Progress clear; Sessions misleading; Profile empty |

**Critical navigation issues**

1. **Sessions → Protocol Library** — label/destination mismatch  
2. **Push-based “tabs”** — returning leaves wrong selected index  
3. **Home secondary links** duplicate bottom destinations (Protocol, Exercise Library)

**Suggested model for v1.1 (recommendation only)**

- Home · Plans · Progress · Profile  
- Retire or rename Sessions until a true Sessions product exists  
- Keep Protocol Library behind Progress or a quiet overflow — not a primary tab mislabeled

---

## Design language review

| Token | Assessment |
|-------|------------|
| Spacing | Generally consistent (`CohortSpacing`) |
| Typography | Strong hierarchy; occasional over-use of hero/all-caps on CTAs |
| Radius | Mostly 12–16; chips use pills — acceptable |
| Buttons | Primary `CohortButton` used well; hierarchy muddied by ALL CAPS everywhere |
| Icons | Terrain placeholders overused for plans |
| Cards | Surface raised + border consistent; Home still over-carded below briefing |
| Colour | Phosphor/olive dark theme coherent |

**Polish opportunities (no new features)**

- Standardise primary CTA casing and verbs  
- Replace plan placeholders with a small curated image set (or stronger abstract art system)  
- Reduce duplicate focus text on briefing  
- Align AppBar / back affordances (Account vs Plans)

---

## Coaching review

| Moment | Feels coached? |
|--------|----------------|
| Daily Briefing | Yes |
| Plan browse / start | Yes |
| Execute → Complete → adapt | Yes |
| Progress improvements | Yes |
| Onboarding “Generate programme” | Partially — software tone |
| Login dual path | No — account software |
| Profile | No — empty admin |
| Home History/Adapt/Knowledge stack | Partially — tool shelf under coach |

**Rule for v1.1:** First viewport of every primary tab must answer a coaching question, not expose tools.

---

## Performance review (observation only)

| Area | Note |
|------|------|
| Home | Large `SingleChildScrollView` with many conditional sections — rebuilds whole column on `setState` after session return |
| Progress | Sync summary build is fine for memory data; long history lists should stay lazy later |
| Workout Overview | Coach Brain resolve can be heavy — loading state exists (good) |
| Orphan widgets | `HomeTodaySessionSection` / programme loaders unused on Home but still in codebase — cognitive + potential future misuse debt |
| Briefing | Sync; no unnecessary async (good) |

No implementation required this sprint.

---

## Architecture review (confirmation)

| Check | Status |
|-------|--------|
| Coach Brain remains orchestration | Confirmed — athlete path uses `CoachBrainWorkoutPlanService` |
| Planning deterministic | Confirmed — no LLM in MVP loops |
| UI does not invent sessions | Confirmed — execution from engine plan |
| Plan → PlanningInput tags | Confirmed — preference tags, no engine fork |
| Adaptive loop after complete | Confirmed — evidence → progress → regenerate |
| Duplicated “today” UI | **Debt** — parallel widgets unused on Home |
| Adapt sheet vs missing section | **Debt** — Home adapt may no-op |
| Persistence | Intentionally absent (OK for beta if communicated) |

---

## Prioritised findings

Effort scale: **S** ≤ 0.5 day · **M** 1–2 days · **L** 3–5 days

### Critical

| ID | Problem | Impact | Suggested improvement | Effort | Sprint 2 |
|----|---------|--------|----------------------|--------|----------|
| C1 | Bottom nav **Sessions** opens Protocol Library | Athletes cannot trust navigation; “where do I find things?” fails | Rename to **Library** or **Protocols**, or remove tab until Sessions product exists | S | **Addressed** — Sessions removed; athlete nav is Home / Plans / Progress / Profile |
| C2 | Home Adapt / today-session key references unmounted section | “Need to Adapt?” may silently no-op | Wire Adapt to active briefing session or hide Adapt until fixed | M | **Addressed** — `HomeAdaptFlow` loads today independently; athlete-safe empty states |
| C3 | Home empty-plan copy redundancy + “First Plan” wording | Confusion and unfinished feel | Single empty composition: one headline, one body, one **Browse Plans** CTA | S | **Addressed** — single Choose a Plan / Browse Plans composition |

### High

| ID | Problem | Impact | Suggested improvement | Effort | Sprint 2 |
|----|---------|--------|----------------------|--------|----------|
| H1 | Home still stacks History / Adapt / Knowledge under briefing | Breaks “briefing not dashboard” | Defer secondary tools below fold or into Profile/overflow for beta | M | **Addressed** — Home today-only; History → Profile; founder tools → Founder Workspace |
| H2 | CTA language inconsistent (EXECUTE / START SESSION / START PLAN / START TRAINING / GENERATE PROGRAMME) | Cognitive load; less premium | Unified verb set: **Start training** · **Start plan** · **Start session** · **Finish** | S | **Partially addressed** — athlete CTAs use Plan / Today's Training / Adapt vocabulary |
| H3 | Onboarding / generation still says “programme” | Product vocabulary drift | Align all athlete copy to **Plan** | S | **Partially addressed** — athlete-facing surfaces prefer Plan; internal code may retain Programme |
| H4 | Profile is Account-only | Athletes have nowhere to see identity/plan | Minimal Profile: name, active plan, goal, sign out / continue as guest | M | **Addressed** — `AthleteProfileScreen` with Account, Goals, Equipment, History, Support, Sign Out |
| H5 | Progress empty state has no CTA | Dead end | Add **Browse Plans** | S | **Addressed** — honest placeholders + Choose a Plan / Start Today's Training |
| H6 | Duplicate today UI (`TodaySessionCard`, `AthleteGeneratedTodaySection`, legacy home today) | Maintenance risk; accidental UI forks | Mark legacy unused or delete in polish sprint; single briefing path | M | **Partially addressed** — Home uses Daily Briefing + Adapt only; legacy widgets not mounted on athlete Home |

### Medium

| ID | Problem | Impact | Suggested improvement | Effort |
|----|---------|--------|----------------------|--------|
| M1 | Plan cover placeholders | Unfinished premium | Curated placeholder art system per category | M |
| M2 | Briefing repeats training focus | Visual noise | Keep focus once (headline or TODAY'S FOCUS, not both) | S |
| M3 | RPE without scale guidance | Lower quality evidence | One-line RPE legend (easy → hard) | S |
| M4 | No mid-session exit affordance | Anxiety / trapped feeling | Quiet “End session” with confirm | S |
| M5 | Bottom nav selection not true tabs | “Where am I?” weak after pushes | IndexedStack or reset selection on return | M |
| M6 | Filter chips sparse / hardcoded | Weak browse | Derive filters from catalog facets | S |
| M7 | Technical error strings on onboarding / plan start | Breaks coaching tone | Athlete-safe error copy + retry | S |
| M8 | Video placeholder in player | Breaks premium | Hide media until real assets; show movement name only | S |

### Low

| ID | Problem | Impact | Suggested improvement | Effort |
|----|---------|--------|----------------------|--------|
| L1 | Account back control inconsistent with AppBars | Polish | Standard AppBar leading | S |
| L2 | ALL-CAPS CTAs everywhere | Shouty | Sentence case for secondary; reserve caps for one primary | S |
| L3 | Motivation / standards always same structure | Predictable (can be good) | Optional light motion on briefing entrance | S |
| L4 | Accessibility: contrast/tap targets mostly OK; labels sparse | A11y debt | Semantic labels on filter chips and RPE | M |
| L5 | Accessibility: no reduce-motion consideration on adapt transition | Edge case | Honour reduced motion | S |

---

## Animation & micro-interaction opportunities (polish only)

| Opportunity | Intent |
|-------------|--------|
| Briefing entrance fade/slide (subtle) | “Coach arrives” |
| Plan card press scale | Premium tactile |
| COMPLETE SET success tick | Confidence without celebration spam |
| Adapt phase cross-fade (already AnimatedSwitcher) | Keep understated |
| Progress improvement lines stagger | Quiet pride |

Avoid confetti, badge spam, and long loaders.

---

## Accessibility checklist (beta bar)

- [ ] Primary CTAs ≥ 44pt height (CohortButton ~54 — OK)  
- [ ] RPE chips labelled for VoiceOver  
- [ ] Filter chips announce selected state  
- [ ] Error text not colour-only  
- [ ] Rest day and empty states readable without icons alone  
- [ ] Dark theme contrast verified on phosphor-on-black body text  

---

## MVP v1.1 definition (before external closed beta)

**v1.1 is polish-only.** No new product pillars. No engine feature work.

### Must ship

1. Fix Sessions nav label/destination (**C1**)  
2. Fix or hide broken Adapt path (**C2**)  
3. Unify empty-plan Home (**C3**)  
4. Align Plan vocabulary + CTA verbs (**H2**, **H3**)  
5. Progress empty CTA (**H5**)  
6. Athlete-safe errors on onboarding / plan start (**M7**)  
7. Hide player media placeholder or replace (**M8**)  

### Should ship

8. Slim Home to briefing-first (**H1**)  
9. Minimal Profile content (**H4**)  
10. Retire/orphan cleanup of duplicate today UIs (**H6**)  
11. Briefing focus de-dupe (**M2**)  
12. RPE legend (**M3**)  
13. Quiet end-session (**M4**)  

### Nice for beta

14. Plan imagery system (**M1**)  
15. True tab selection (**M5**)  
16. Motion / a11y polish (**L3–L5**)  

### Explicitly out of v1.1

- Persistence / cloud sync  
- Wearables  
- AI chat / Coach tab  
- Marketplace / payments  
- Graphs / analytics dashboards  
- Multi active plans  

---

## Closed-beta messaging (product)

Communicate clearly:

> Cohort remembers your plan and adapts in-session **on this device for now**. Progress resets if you clear the app. That is intentional for this beta.

---

## Success criteria for this review sprint

| Criterion | Met? |
|-----------|------|
| Prioritised UX backlog (Critical → Low) | Yes |
| Polish opportunity list | Yes |
| Clear MVP v1.1 definition | Yes |
| No new features implemented | Yes — recommendations only |

---

## Recommended next sprint

**Phase 6 Sprint 4 — Visual Polish + Welcome Transition**

Candidate work (see `docs/product/Welcome_Briefing_Transition.md`): calm COHORT → greeting → Home fade (&lt;1s when data ready), reduced-motion honour, no theatrical spinner. Continue deleting quarantined `HomeTodaySessionSection` once founder programme Adapt path is retired. Assessment frameworks remain vision-only (`Plan_Assessments_Vision.md`).

---

## Appendix — Screen → one question map

| Screen | One question |
|--------|--------------|
| Login | How do I begin training? |
| Onboarding | Who am I as an athlete? |
| Plan Library | Which plan is right for me? |
| Plan Detail | Should I commit? |
| Home / Briefing | What should I know before I train today? |
| Overview | Am I ready to begin? |
| Player | What do I do right now? |
| Complete | How did it feel — what’s next? |
| Progress | Am I getting better? |
| Profile | Who am I in Cohort? |
