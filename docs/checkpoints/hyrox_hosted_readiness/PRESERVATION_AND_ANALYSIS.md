# Preservation exception and analysis reconciliation

## Automatic cleanup: identified, restoration verified without further churn

The installed desktop log records managed `create_worktree` at 2026-10-23T12:51:23.631Z,
creation ready at 12:51:25.186Z, owner assignment at 12:51:25.222Z, then
`[worktree-service] [worktree-cleanup] plan-summary` at **12:51:25.290Z**:
`candidatesCount=4 deletesPlanned=4 keepCount=15 totalWorktrees=20`.
Four subsequent delete candidates had `reason=owned`, `isProtected=false`,
`ownerThreadInProgress=false`; no pinned/workspace-root protection was recorded.
This identifies automatic desktop retention after managed-worktree creation. It was not
an authorised destructive cleanup requested by the founder. The four snapshot refs still
point to the original branch commits:

| Original checkout under ~/.codex/worktrees | Original HEAD / retained snapshot ref suffix |
| --- | --- |
| programme-studio-stage2/cohort_platform | `6318f319db15ff7a42283c7719dc22a6dc28daa5` / `5ac84e149fb87ad0a7a32178cd299bbbc46e5ca6` |
| programme-studio-d2/cohort_platform | `6f83f7324fe0ea585f6c7f3a4ba34151ee588ec6` / `1f8d49f326aa2cfd49a952877648d0b2ef70bcdb` |
| studio-canonical-source-export/cohort_platform | `2d97daf71e31c4691eba9cf85e731b4a1b3c2e33` / `75e15ac4ded4fff0f600a2f332b62e2415dffe0b` |
| studio-editable-workspace/cohort_platform | `3ec4866c5d4583fdb5f7c581b5e6099ee3616ef6` / `f1a4038c9ed8e2f51ad743818eaadbd428ac54c4` |

Refs use prefix `refs/codex/snapshots/`. The previous task restored original paths from
these exact clean branch commits with `git worktree add --lock`. The original recorded
tracked/outstanding bytes, branch, HEAD, .git pointer and .temp state match the prior
pre-cleanup inventory. All four were clean with no staged changes. Their original index
byte streams were lost: restoration generated new clean indexes. This is content/ref
restoration and logical clean-index equivalence, **not original index-byte preservation**.
Ignored generated artifacts were outside that inventory and are not claimed restored.

This task used `GIT_OPTIONAL_LOCKS=0` inventory reads, not checkout restoration/index
recreation. Before and after the documentation edits, all 20 older checkouts exactly match
`/private/tmp/cohort-hyrox-athlete/POST_PUSH.json`; all four regenerated index hashes remain
unchanged. Original `/Users/leewebber/Developer/cohort_platform` remains main at
`a331f52967e1887c4435cccc8f1ecfa192028cd6` with its original **95 outstanding paths**,
index and .temp exact. Raw comparison/hash evidence is summarised in [INSPECTION](INSPECTION.json).
The pre-cleanup reference is `/private/tmp/cohort-hyrox-authoritative/POST_PUSH.json`;
previous published [preservation evidence](../hyrox_athlete_runner/PRESERVATION.json) is retained.

The log is a local primary source:
`~/Library/Logs/com.openai.codex/2026/10/23/codex-desktop-22e9d424-94db-4c67-9730-8bbb2f9266cf-38613-t0-i1-103749-0.log`.
Only cleanup timestamps/counts and mapped refs are retained here; unrelated log contents
are not published. Read-only installed bundle inspection confirms automatic cleanup uses
host worktree settings and the `worktree_auto_cleanup` operation after retention planning.
No app opening/control was used.

[Official worktree documentation](https://learn.chatgpt.com/docs/environments/git-worktrees)
describes the default most-recent-15 retention, settings to change the limit or disable
automatic deletion, and pinned/in-progress/permanent worktree protections. No explicit
desktop worktree override was present in the inspected local desktop configuration.
**Recurrence action requiring separate authority:** in Codex Settings → Worktrees, turn off
automatic worktree deletion (or explicitly select an agreed retention/permanent-worktree
policy). No global setting/pin was changed. Git worktree locks protect Git pruning but are
not claimed to disable the app's cleanup planner. This task reused the existing clean
`hyrox-athlete-runner` checkout and did not invoke managed create/archive/attach/handoff.

## Exactly why analysis decreased

Hash-verified logs retained under `/private/tmp/cohort-hyrox-athlete` show:

| Evidence | Findings | Errors | Warnings | Info | SHA-256 |
| --- | ---: | ---: | ---: | ---: | --- |
| analysis-baseline.log | 365 | 0 | 110 | 255 | `14e1c95b50b456ef2891650fd413cca8b7ce0d30a871bbca78571b405e48e3a6` |
| analysis-final.log | 364 | 0 | 110 | 254 | `97352dc0f58b048c6dd96dd4d811464bac9355dda6f11cefd85bf4d7f138706d` |

A multiset comparison by severity, repository path, code and **full message**, excluding
line/column movement, yields **zero added identities and exactly one removed identity**:

- Severity `info`, code `prefer_initializing_formals`.
- File `lib/features/programme/services/athlete_programme_authored_slot_resolver.dart`,
  former location **37:8**.
- Message: `Use an initializing formal to assign a parameter to a field. Try using an initialing formal ('this._versionStore') to initialize the field`.

Implementation commit **70f7c72d0828b4043208dbea41ec4ab6fe6b85f3** changed the constructor:

```dart
// Before at 6fff850807a18d025004f5f16b74d5b58a4f2182
const AthleteProgrammeAuthoredSlotResolver({
  required ProgrammeVersionStore versionStore,
}) : _versionStore = versionStore;
// After, also present at published 55c38bbee7015bc16b25dd6d4fef4eb01900195f
const AthleteProgrammeAuthoredSlotResolver({
  required this._versionStore,
});
```

The source change directly removes that lint; no suppression or unexplained baseline drift
is involved. Source blob SHA-256s and log hashes are in INSPECTION.json. Analysis remains
non-green at 364 inherited findings. This documentation task changes no Dart/SQL runtime
source, introduces no new analysis baseline, and reuses the exact prior verified evidence
rather than presenting an unrun analysis as fresh.
