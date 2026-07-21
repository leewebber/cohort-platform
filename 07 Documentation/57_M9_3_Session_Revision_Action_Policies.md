# M9.3 — Session Revision Action Policies

**Status:** Implemented  
**Depends on:** M9.1 Session Lineages, M9.2 Usage Relationships

---

## Purpose

Convert relationship **facts** into typed **decisions** about what actions are safe for one exact Session Revision (`protocol_id`).

Supported actions:

| Action | Question |
|--------|----------|
| `edit` | Can this revision be edited in place? |
| `createNewRevision` | Can a new draft revision be forked? |
| `publish` | Can this revision be published? |
| `archive` | Can this revision be archived? |
| `delete` | Can this revision be hard-deleted? |

This milestone is policy + lightweight enforcement. It does **not** add Coach Studio UI.

---

## Relationship facts vs policy decisions

| Layer | Responsibility |
|-------|----------------|
| `SessionRevisionRelationshipService` (M9.2) | Read-only usage: programme slots, active assignments, historical records |
| `SessionRevisionActionPolicyService` (M9.3) | Interpret usage + lifecycle + content protection → allowed/blocked + messages |

Policy services **must not** duplicate relationship queries.

---

## Action vocabulary

### `SessionRevisionAction`

`edit`, `createNewRevision`, `publish`, `archive`, `delete`

### `SessionRevisionActionReasonCode`

Structured machine-readable reasons — e.g. `publishedRevisionImmutable`, `usedByActiveAssignments`, `canonicalContentProtected`.

### `SessionRevisionActionSeverity`

| Value | Meaning |
|-------|---------|
| `info` | Allowed; informational context |
| `warning` | Allowed but impactful (e.g. archive with live dependencies) |
| `blocking` | Not allowed |

### `SessionRevisionActionDecision`

Contains:

- `allowed`, `severity`, `primaryReasonCode`, full `reasons` list
- `userMessage` (Coach Studio-ready, no raw UUIDs)
- optional `recommendedAlternative`
- optional `usageSummary` attachment

---

## Lifecycle rules (summary)

### Edit

- **Draft:** allowed (subject to existing builder/canonical guards)
- **Published / archived:** blocked — recommend `createNewRevision`

Usage does **not** make published content editable.

### Create new revision

- **Published / archived:** allowed (unless canonical protected)
- **Draft:** blocked — continue editing in place
- **Official Cohort Protocol:** blocked — recommend Copy & Customise

### Publish

- **Draft:** allowed subject to existing M6 builder validation
- **Published:** blocked (already published)
- **Archived:** blocked — create new revision instead

### Archive

- **Published:** allowed — warnings when referenced, actively assigned, or historical
- **Draft:** blocked — delete if unused, or publish first
- **Archived:** blocked (already archived)

Archiving hides from new selection but **does not break** pinned programmes, assignments, execution, or history.

### Delete

Hard delete allowed **only** when ALL are true:

1. lifecycle is `draft`
2. no programme version slot references (any lifecycle)
3. no active assignment dependencies
4. no terminal training records
5. not canonical/founder protected content
6. relationship lookup succeeded

Otherwise blocked with structured reasons.

---

## Blocker priority (delete)

Deterministic primary blocker selection:

1. revision not found / lookup failure (fail closed)
2. canonical protection
3. lifecycle incompatibility (published / archived)
4. active assignment dependency
5. direct programme references
6. historical usage

All applicable blockers are included in `reasons` even when one is sufficient to reject delete.

---

## Fail-closed delete behaviour

| Situation | Delete decision |
|-----------|-----------------|
| Revision not found | Blocked |
| Relationship lookup failed | Blocked — do not assume empty usage |
| Successful lookup with zero usage | May allow (draft + other checks) |

`SessionRevisionRelationshipService.tryGetUsageForRevision()` distinguishes:

- `success`
- `revisionNotFound`
- `lookupFailed`

---

## Canonical content protection

Protected when:

- Official Cohort Protocol (`TrainingContentClassification.isCohortProtocol`)
- Founder Acceptance canonical session (`FounderAcceptanceContent.protocolId`)

Effects:

- **Delete:** blocked
- **Create new revision:** blocked — recommend Copy & Customise
- **Edit:** follows normal lifecycle immutability (published still immutable)

Ownership and copy rules from M5 are preserved.

---

## Service enforcement points

| Location | Enforcement |
|----------|-------------|
| `SessionRevisionActionPolicyService.evaluate()` | Primary policy API |
| `SessionRevisionService.deleteRevision()` | Requires allowed delete decision before `SessionRevisionDeleteStore` |
| `SessionRevisionService.createNewSessionRevision()` | Policy check before fork |
| `SessionRevisionService.publishRevision()` | Policy check before publish |
| `SessionRevisionService.archiveRevision()` | Policy check before lifecycle update |
| `ProtocolBuilderService.saveDraft()` | Existing M9.1 immutability guard for published/archived rows |

No destructive database cascades added.

---

## User message rules

- Concise, action-specific, count-aware pluralisation
- No raw UUIDs in `userMessage`
- Include `recommendedAlternative` when a clear next step exists
- Multiple blockers surfaced in `reasons`; highest-priority blocker drives primary message

Examples:

- “Cannot delete this draft because it is used in 2 programme versions across 4 slots.”
- “Published revisions cannot be edited. Create draft revision 3 instead.”
- “You can archive this revision. Existing programmes and athlete history will continue to use it.”

---

## API

```dart
final decision = await policyService.evaluate(protocolId, SessionRevisionAction.delete);

final summary = await policyService.evaluateAll(protocolId);
```

Execution:

```dart
await sessionRevisionService.deleteRevision(protocolId); // throws SessionRevisionPolicyException when blocked
```

---

## Known limitations (M9.3)

| Limitation | Notes |
|------------|-------|
| Session-revision-specific | No universal content policy engine |
| No Coach Studio UI | Decisions only |
| Slot substitution edges excluded | Same as M9.2 |
| Publish validation deferred | Policy says “subject to builder validation” |
| No lineage roll-up | Exact revision only |

---

## How M9.4 Coach Studio will consume decisions

M9.4 should:

- Call `evaluate()` / `evaluateAll()` before showing action buttons
- Map `severity` to info / warning / disabled states
- Surface `userMessage` and `recommendedAlternative` in confirmation flows
- Wire “Used by” panel to M9.2 `getUsageForRevision()` alongside policy decisions

Policy remains read-only at evaluation time; UI performs actions through existing services after checking `allowed`.

---

## Related documentation

- `55_M9_1_Session_Lineages_and_Revisions.md`
- `56_M9_2_Session_Revision_Usage_Relationships.md`
