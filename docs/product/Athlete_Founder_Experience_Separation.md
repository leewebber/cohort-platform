# Athlete / Founder Experience Separation

**Phase:** 6 — Product Hardening  
**Sprint:** 2 — Athlete Experience Simplification & Founder Workspace Separation  
**Sprint 3:** Local athlete memory + product constitution (no founder tools on athlete)  
**Status:** Implemented (MVP v1.1)

---

## Role boundary

| Role | Meaning |
|------|---------|
| **Athlete** | Default application experience. Four destinations only. |
| **Founder** | Explicitly authorised workspace for authoring, ops, and diagnostics. |

`AppAccessRole` values: `athlete` | `founder`.

**Important:** Coach flags on `UserProfile` (`isCoach`) do **not** grant Founder Workspace. Founder access is email-allowlist (or explicit development override) only.

---

## Access policy

| Type | Responsibility |
|------|----------------|
| `FounderAccessConfig` | Allowlist emails + optional `developmentOverride` |
| `FounderAccessPolicy` | Single policy: `configure` / `isAuthorisedFounder` / `reset` |
| `AppExperienceResolver` | Resolves `AppAccessRole` from email + policy |

`AuthGate` routes:

- Founder → `FounderWorkspaceShell`
- Otherwise → `AthleteAppShell`

Guest / START TRAINING always enters the athlete shell.

---

## Athlete navigation

Exactly four bottom destinations:

1. **Home** — today only  
2. **Plans** — plan library  
3. **Progress** — capability / improvement  
4. **Profile** — identity + settings + Training History  

Absent from athlete nav and athlete Home widget tree:

- Sessions  
- Protocol Library / Exercise Library  
- My Athletes / Coach Studio  
- Knowledge administration  
- Diagnostics / feature flags / internal tools  

---

## Founder navigation

`FounderWorkspaceShell` destinations:

- Overview  
- Athletes  
- Studio  
- Knowledge  
- Settings  

Overview includes entries for My Athletes, Coach Studio, Plan authoring, Knowledge, Diagnostics, Help/feedback, and **Preview Athlete App** (explicit push to `AthleteAppShell`).

---

## Security limitations

- Access control is **client-side** for UX separation. It is not a server-enforced security boundary.
- Do not treat UI absence as authorisation for sensitive admin APIs.
- Development override must never ship enabled in production athlete builds.
- Coach role on a profile must not be used as a founder signal.

---

## Founder email configuration

Lee’s work email is **not** hardcoded.

**Where to add it:**

```dart
FounderAccessPolicy.configure(
  FounderAccessConfig(
    allowedEmails: {
      // Add Lee's work email here once supplied:
      // 'lee@your-domain.com',
    },
  ),
);
```

Call `FounderAccessPolicy.configure` from app bootstrap (e.g. after `main` / before `AuthGate`) or inject in tests.

**Local development fixture:**

```dart
FounderAccessPolicy.configure(
  const FounderAccessConfig(developmentOverride: true),
);
```

Reset with `FounderAccessPolicy.reset()`.

---

## Preview Athlete behaviour

Founders open the athlete experience via **Preview Athlete App** on Founder Overview. This pushes `AthleteAppShell` without mixing founder cards into athlete Home.

---

## Product constitution (Sprint 3)

Binding principles live in `docs/product/Cohort_Product_Constitution_v1.md`.

Athlete vocabulary: **Plan · Today's Training · Progress · Adapt · Profile**.

Athlete and founder experiences remain separate. Complexity belongs in the engine; simplicity belongs in the athlete interface.

---

## Legacy athlete Home path

`HomeTodaySessionSection` is **quarantined** — not used on athlete Home (replaced by `DailyBriefingSection`). Retained only for the programme-assignment Adapt / Supabase schedule path until that founder path is removed.
