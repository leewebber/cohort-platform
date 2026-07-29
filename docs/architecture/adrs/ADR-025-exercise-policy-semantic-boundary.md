# ADR-025: Exercise Policy owns movement selection; never changes intent

**Status:** Accepted (Phase 3.5 architecture)  
**Date:** 2026-07-29  
**Related:** ADR-027 (Session Blueprint input)

## Context

Exercise selection, substitution, and equipment constraints historically touch many layers (M7 rendering, knowledge substitutions, adaptation swaps). Phase 4 needs a **final semantic translation layer** that preserves programme and session **intent**.

## Decision

Establish an **Exercise Policy Engine** as the **sole owner** of:

- Exercise/movement **selection** for a session
- Equipment and environment **compatibility**
- Injury and fatigue **movement constraints**
- Athlete **preference** handling within intent-preserving sets
- **Substitution** ranking (knowledge graph + platform Exercise catalogue)
- Movement **diversity** and **variation** within blueprint bounds

**Invariant:** Exercise Policy **must not** change:

- Programme phase, training block, or week type
- Training intent emphasis or session archetype
- Capability gap ranking or intent recommendations

If constraints make a `SessionBlueprint` infeasible, the engine returns **failure with explainability** — not a silent retarget of intent.

Adaptation Pipeline **swap** actions delegate movement choice to the same policy rules where applicable; adaptation **decides whether** to swap, not macro intent.

## Consequences

- `SessionBlueprint` is the policy input contract (ADR-027).
- Output adapts to existing **`SessionExecutionPlan`** / M7 projection via compatibility adapter (Phase 2 pattern).
- Knowledge Layer provides data; policy provides algorithms.

## Alternatives considered

- **Session Generator picks exercises** — rejected; blurs blueprint vs movement boundary.
- **Coach Brain picks exercises** — rejected; violates minimal-knowledge Brain rule.

## Migration implications

- Phase 4c implements policy behind feature flag; legacy DB plan rendering remains until parity tests pass.
