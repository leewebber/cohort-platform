import 'workspace/workspace_files.dart';
import 'source_export/canonical_source_bundle.dart';
import 'source_export/source_bundle_download.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/strength_prescription_formatter.dart';
import '../authoring/programme_authoring_screen.dart';
import '../presentation/programme_studio_app.dart';
import '../protocol_authoring/protocol_authoring_controller.dart';
import '../protocol_authoring/protocol_authoring_screen.dart';
import '../protocol_authoring/synthetic_session_revision_catalogue.dart';
import '../protocol_authoring/synthetic_strength_lineage.dart';
import '../protocol_authoring/synthetic_strength_session_compiler.dart';
import 'synthetic_composition_controller.dart';
import 'synthetic_composition_fixtures.dart';

const temporaryWorkspaceNotice =
    'Local workspace · synthetic example. Browser edits are not autosaved. Save an editable workspace file and keep it to continue later. Review exports open read-only; canonical sources are for compiler/tools or new bounded source ownership through Open canonical sources (complete Studio TAR, no editor history). No cloud backup.';
String sessionVersionLabel(D2CompiledSession s) =>
    '${s.protocol.name} · Session ${s.identity.sessionLineageId == SyntheticStrengthLineage.a.id ? 'A' : 'B'} · Version ${s.identity.revisionNumber}';
String sessionPrescription(D2CompiledSession s) => s.protocol.blocks
    .expand((b) => b.linkedExercises)
    .map(
      (e) => [
        e.displayLabelOverride ?? e.exerciseId,
        StrengthPrescriptionFormatter.summaryLine(e.prescription!),
        StrengthPrescriptionFormatter.detailLine(e.prescription!),
        if (e.prescription!.coachCue != null) e.prescription!.coachCue!,
      ].where((v) => v.isNotEmpty).join(' · '),
    )
    .join('\n');

class ProgrammeFirstScreen extends StatefulWidget {
  const ProgrammeFirstScreen({
    super.key,
    required this.controller,
    required this.advanced,
    this.downloadSources = downloadSourceBundle,
    this.downloadWorkspace = downloadEditableWorkspace,
    this.chooseWorkspace = chooseEditableWorkspace,
    this.chooseSources = chooseCanonicalSources,
  });
  final SyntheticCompositionController controller;
  final void Function(String) downloadWorkspace;
  final Future<String?> Function() chooseWorkspace;
  final Future<Uint8List?> Function() chooseSources;
  final Widget Function() advanced;
  final void Function(CanonicalSourceBundle) downloadSources;
  @override
  State<ProgrammeFirstScreen> createState() => _ProgrammeFirstScreenState();
}

class _ProgrammeFirstScreenState extends State<ProgrammeFirstScreen> {
  SyntheticCompositionController get c => widget.controller;
  bool sessions = false, everReviewed = false, openedExport = false;
  String? message;
  bool transferringWorkspace = false;
  String? workspaceError;
  List<({String key, String name, String sessionKey})> get workouts {
    if (!c.initialized) return [];
    final result = <({String key, String name, String sessionKey})>[];
    for (final w in c.programme.tree?['weeks'] as List? ?? []) {
      for (final d in w['days'] as List) {
        for (final s in d['slots'] as List) {
          result.add((
            key: s['slot_key'] as String,
            name:
                'Week ${w['week_number']} · Day ${d['day_order']} · Workout ${s['session_order']}',
            sessionKey: s['session_key'] as String,
          ));
        }
      }
    }
    return result;
  }

  D2CompiledSession? selected(String key) {
    final matches = c.admitted.where(
      (s) => compositionReference(s)['session_key'] == key,
    );
    return matches.length == 1 ? matches.single : null;
  }

  String versionStatus(D2CompiledSession s) {
    final origin =
        c.ownerFor(s.identity).isImportedSnapshot(s.identity.revisionNumber)
        ? 'Validated imported snapshot · historical parent/freeze unknown. '
        : '';
    final uses = workouts
        .where((w) => w.sessionKey == compositionReference(s)['session_key'])
        .map((w) => w.name)
        .toList();
    if (uses.isNotEmpty) return '${origin}Used in ${uses.join('; ')}';
    if (c.admitted.any((a) => sameRevision(a.identity, s.identity))) {
      return '${origin}Available in programme, not currently used · included in export';
    }
    return '${origin}Saved here, not added to programme · excluded from complete review export';
  }

  void showMessage(String text) {
    if (mounted) setState(() => message = text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Programme Studio · local workspace')),
    body: !c.initialized
        ? const Center(child: Text('Opening example programme…'))
        : Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .34,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(temporaryWorkspaceNotice),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: c.busy || transferringWorkspace
                                ? null
                                : _saveWorkspace,
                            child: const Text('Save editable workspace'),
                          ),
                          OutlinedButton(
                            onPressed: c.busy || transferringWorkspace
                                ? null
                                : _openWorkspace,
                            child: const Text('Open editable workspace'),
                          ),
                          OutlinedButton(
                            onPressed: c.busy || transferringWorkspace
                                ? null
                                : _openSources,
                            child: const Text('Open canonical sources'),
                          ),
                          FilledButton(
                            onPressed: c.busy ? null : _review,
                            child: const Text('Review programme'),
                          ),
                          OutlinedButton(
                            onPressed: c.busy ? null : _export,
                            child: const Text('Export complete review'),
                          ),
                          OutlinedButton(
                            onPressed: c.busy ? null : _openExport,
                            child: const Text('Open exported review'),
                          ),
                        ],
                      ),
                      if (c.hasImportedSnapshots)
                        const Text(
                          'Source-import basis retained. Original canonical intake supplied snapshots only; omitted private versions and earlier history remain unknown. Editable workspace files retain subsequent local history, reservations and drafts. Missing earlier version numbers stay unavailable.',
                        ),
                      Text(
                        !c.workspaceSaveRequested
                            ? 'Workspace file not saved yet.'
                            : c.workspaceHasChanges
                            ? 'Unsaved workspace changes since the last file download/open.'
                            : 'Workspace matches the last file download/open. Keep the file; there is no autosave.',
                      ),
                      if (workspaceError != null)
                        ExpansionTile(
                          title: const Text('Advanced: workspace file error'),
                          children: [SelectableText(workspaceError!)],
                        ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          c.anyDraft
                              ? 'Save or discard your session changes before reviewing the programme.'
                              : c.busy
                              ? 'Checking current programme…'
                              : c.current != null
                              ? 'Programme checked — current selected versions'
                              : openedExport
                              ? 'Review the workspace again before exporting it.'
                              : everReviewed
                              ? 'Programme changed since review.'
                              : 'Programme has not been checked yet.',
                        ),
                      ),
                      if (message != null)
                        Semantics(liveRegion: true, child: Text(message!)),
                      if (c.errors.isNotEmpty) Text(c.errors.join('\n')),
                    ],
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => setState(() => sessions = false),
                    child: const Text('Programme'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => sessions = true),
                    child: const Text('Sessions'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => widget.advanced(),
                      ),
                    ),
                    child: const Text('Advanced'),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: sessions ? _sessions() : _programme(),
                ),
              ),
            ],
          ),
  );
  List<Widget> _programme() => [
    Text(
      c.programme.tree?['programme']['name'] as String? ?? 'Programme',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const Text(
      'Fixed synthetic exercise profile · two independent strength sessions · straight sets only.',
    ),
    Text(
      '${(c.programme.tree?['weeks'] as List?)?.length ?? 0} weeks · ${workouts.length} scheduled workouts',
    ),
    if ((c.programme.tree?['weeks'] as List?)?.length == 1)
      OutlinedButton(
        key: const Key('setup-four-weeks'),
        onPressed: c.busy || c.anyDraft ? null : _setupFourWeeks,
        child: const Text('Set up four weeks · two sessions per week'),
      ),
    for (final w in workouts)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.name, style: Theme.of(context).textTheme.titleMedium),
              if (selected(w.sessionKey) case final s?) ...[
                Text(sessionVersionLabel(s)),
                Text('Using Version ${s.identity.revisionNumber} here'),
                Text(sessionPrescription(s)),
                Wrap(
                  spacing: 10,
                  children: [
                    FilledButton(
                      key: Key('edit-workout-${w.key}'),
                      onPressed: c.busy
                          ? null
                          : () => _edit(c.ownerFor(s.identity), w.key, s),
                      child: const Text('Edit session'),
                    ),
                    OutlinedButton(
                      key: Key('choose-workout-${w.key}'),
                      onPressed: c.busy || c.anyDraft
                          ? null
                          : () => _choose(w.key),
                      child: const Text('Choose version'),
                    ),
                  ],
                ),
              ] else
                const Text(
                  'Session unavailable. Review the programme details.',
                ),
            ],
          ),
        ),
      ),
    OutlinedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Programme details and schedule')),
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(temporaryWorkspaceNotice),
                ),
                Expanded(
                  child: ProgrammeAuthoringScreen(
                    controller: c.programme,
                    embedded: true,
                    authorFacing: true,
                    workspaceGeneration: () => c.generation,
                    sessionChoiceLabel: (r) => sessionVersionLabel(
                      c.admitted.singleWhere(
                        (s) =>
                            compositionReference(s)['session_key'] ==
                            r['session_key'],
                      ),
                    ),
                    onSelectSlot: (week, day, slot, key) async {
                      final tree = c.programme.tree!;
                      final target =
                          tree['weeks'][week]['days'][day]['slots'][slot]['slot_key']
                              as String;
                      final s = c.admitted.singleWhere(
                        (s) => compositionReference(s)['session_key'] == key,
                      );
                      await _use(
                        target,
                        c
                            .ownerFor(s.identity)
                            .revisions
                            .singleWhere(
                              (r) => sameRevision(r.identity, s.identity),
                            ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: const Text('Programme details and schedule'),
    ),
    TextButton(onPressed: _reset, child: const Text('Reset example')),
  ];
  List<Widget> _sessions() => [
    for (final owner in c.owners) ...[
      Text(
        owner.lineage == SyntheticStrengthLineage.a ? 'Session A' : 'Session B',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (owner.canCreateRoot)
        FilledButton(
          onPressed: c.busy || c.anyDraft
              ? null
              : () async {
                  c.createSecondSession();
                  await _edit(owner, null, null);
                },
          child: const Text('Create second session'),
        ),
      if (owner.isEditing)
        FilledButton(
          onPressed: () => _edit(owner, null, null),
          child: const Text('Continue session changes'),
        ),
      for (final r in owner.revisions)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sessionVersionLabel(r.compiled)),
                Text(versionStatus(r.compiled)),
                Text(sessionPrescription(r.compiled)),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () => _edit(owner, null, r.compiled),
                      child: const Text('Edit session'),
                    ),
                    if (!c.admitted.any(
                      (s) => sameRevision(s.identity, r.identity),
                    ))
                      TextButton(
                        onPressed: c.busy || c.anyDraft
                            ? null
                            : () => _addOnly(r),
                        child: const Text(
                          'Add to programme without changing workouts',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  ];
  Future<void> _setupFourWeeks() async {
    if (c.secondSession.revisions.isEmpty) {
      setState(() => sessions = true);
      showMessage(
        'First create and save synthetic Session B. Then return to Programme to set up four weeks.',
      );
      return;
    }
    final generation = c.generation;
    final firstKey = workouts.first.sessionKey;
    final a = c.session.revisions
        .where(
          (r) => compositionReference(r.compiled)['session_key'] == firstKey,
        )
        .toList();
    if (a.length != 1) {
      showMessage(
        'The original workout must keep its exact A version and locked references.',
      );
      return;
    }
    var b = c.secondSession.revisions.first;
    var dayA = 1, dayB = 4;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Set up four synthetic weeks'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Four weeks, two workouts each week. No progression is generated. The original workout and all locked declarations are retained once. Later choices affect only the workout you confirm.',
                  ),
                  Text('Session A: ${sessionVersionLabel(a.single.compiled)}'),
                  DropdownButtonFormField<int>(
                    initialValue: dayA,
                    decoration: const InputDecoration(
                      labelText: 'Session A day each week',
                    ),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(value: d, child: Text('Day $d')),
                    ],
                    onChanged: (v) => update(() => dayA = v!),
                  ),
                  DropdownButtonFormField<D2LocalRevision>(
                    initialValue: b,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Session B exact version',
                    ),
                    items: [
                      for (final r in c.secondSession.revisions)
                        DropdownMenuItem(
                          value: r,
                          child: Text(
                            sessionVersionLabel(r.compiled),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() => b = v!),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: dayB,
                    decoration: const InputDecoration(
                      labelText: 'Session B day each week',
                    ),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(value: d, child: Text('Day $d')),
                    ],
                    onChanged: (v) => update(() => dayB = v!),
                  ),
                  if (dayA == dayB) const Text('Choose two different days.'),
                  const Text(
                    'Confirm creates seven new occurrences and makes the selected versions available. Existing prescriptions stay immutable. This is synthetic software content, not a training prescription.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: dayA == dayB
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Create eight-workout schedule'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirm != true || c.generation != generation) return;
    final prepared = await c.prepareFourWeekSchedule(a.single, b, dayA, dayB);
    if (!mounted || prepared == null) return;
    if (await c.usePreparedVersion(prepared)) {
      showMessage(
        'Four-week schedule created. Review all eight workouts below. Choose version changes one occurrence only.',
      );
    }
  }

  Future<void> _edit(
    ProtocolAuthoringController owner,
    String? slotKey,
    D2CompiledSession? source,
  ) async {
    if (c.anyDraft && !owner.isEditing) {
      showMessage('Save or discard the existing session changes first.');
      return;
    }
    if (!owner.isEditing) {
      if (source == null) return;
      owner.openIdentity(source.identity);
      owner.createDraft();
    }
    final workspace = c.generation;
    final used = source == null
        ? 'No programme workout is changed by saving.'
        : versionStatus(source);
    final saved = await Navigator.push<D2LocalRevision>(
      context,
      MaterialPageRoute(
        builder: (context) => ProtocolAuthoringScreen(
          controller: owner,
          embedded: true,
          authorFacing: true,
          workspaceGeneration: () => c.generation,
          selectionSummary:
              '$used. Unsaved changes do not change the programme.',
          onSaveWorkspace: _saveWorkspace,
          onSaved: () => Navigator.pop(
            context,
            owner.revisions.singleWhere(
              (r) => sameRevision(r.identity, owner.activeIdentity),
            ),
          ),
          onDiscard: () => Navigator.pop(context),
        ),
      ),
    );
    if (!mounted || !c.owners.contains(owner)) return;
    if (saved != null) {
      showMessage(
        'Version ${saved.identity.revisionNumber} saved in this workspace. Programme selection has not changed. Save editable workspace to keep it for later.',
      );
      if (slotKey != null) await _choose(slotKey, saved: saved);
    } else if (workspace != c.generation) {
      setState(() {});
    }
  }

  Future<void> _choose(String slotKey, {D2LocalRevision? saved}) async {
    final chosen = await showDialog<D2LocalRevision>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose version'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (saved != null)
                  Text(
                    'Version ${saved.identity.revisionNumber} saved. Programme still uses its previous version.',
                  ),
                for (final r in [
                  ?saved,
                  for (final o in c.owners)
                    for (final r in o.revisions)
                      if (!identical(r, saved)) r,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sessionVersionLabel(r.compiled)),
                        Text(versionStatus(r.compiled)),
                        Text(sessionPrescription(r.compiled)),
                        FilledButton(
                          key: Key('use-version-${revisionKey(r.identity)}'),
                          onPressed: () => Navigator.pop(context, r),
                          child: const Text('Use this version…'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep current version'),
          ),
        ],
      ),
    );
    if (chosen != null && mounted) await _use(slotKey, chosen);
  }

  Future<void> _use(String slotKey, D2LocalRevision revision) async {
    final targets = workouts.where((w) => w.key == slotKey).toList();
    if (targets.length != 1) {
      showMessage(
        'This workout changed. Choose the current workout and try again.',
      );
      return;
    }
    final target = targets.single,
        previous = selected(targets.single.sessionKey);
    final availableBefore = c.admitted
        .map((s) => revisionKey(s.identity))
        .toSet();
    final prepared = await c.prepareUseVersion(slotKey, revision);
    if (!mounted) return;
    if (prepared == null) {
      showMessage(
        "We couldn't use this version. Your programme and available versions were not changed. The saved version is still here; try again.",
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final valid = c.isCurrentVersionUse(prepared);
          return AlertDialog(
            title: Text(
              'Use Version ${revision.identity.revisionNumber} here?',
            ),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(target.name),
                    Text(sessionVersionLabel(revision.compiled)),
                    if (previous != null) ...[
                      const Text('Currently used'),
                      Text(sessionPrescription(previous)),
                    ],
                    const Text('Use instead'),
                    Text(sessionPrescription(revision.compiled)),
                    for (final s in prepared.includedVersions.where(
                      (s) => !availableBefore.contains(revisionKey(s.identity)),
                    ))
                      Text(
                        'Also makes available in this programme: ${sessionVersionLabel(s)}',
                      ),
                    const Text(
                      'Only this workout changes. Saving a version alone never changes selection.',
                    ),
                    if (!valid)
                      const Text(
                        'The workspace changed. Close this confirmation and choose again.',
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep current version'),
              ),
              FilledButton(
                onPressed: valid ? () => Navigator.pop(context, true) : null,
                child: const Text('Use version here'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || confirmed != true) return;
    if (await c.usePreparedVersion(prepared)) {
      showMessage(
        '${target.name} now uses Version ${revision.identity.revisionNumber}.',
      );
    } else {
      showMessage(
        'The workspace changed while we checked this. Review the current workout and try again.',
      );
    }
  }

  Future<void> _addOnly(D2LocalRevision revision) async {
    final generation = c.generation;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to programme without changing workouts?'),
        content: Text(
          '${sessionVersionLabel(revision.compiled)} will be included in the complete review export. Current workout selections stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add to programme'),
          ),
        ],
      ),
    );
    if (confirm == true && generation == c.generation) await c.admit(revision);
  }

  Future<void> _review() async {
    if (c.anyDraft) {
      showMessage(
        'Save or discard your session changes before reviewing the programme.',
      );
      return;
    }
    if (await c.validate() && mounted && c.current != null) {
      setState(() {
        everReviewed = true;
        openedExport = false;
      });
      await _reviewView(false);
    }
  }

  Future<void> _reviewView(bool reopened) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final r = reopened ? c.reconstructed : c.current;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                reopened ? 'Read-only exported review' : 'Review programme',
              ),
            ),
            body: r == null
                ? const Center(
                    child: Text(
                      'Review needs refreshing. Return to the workspace and review again.',
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          reopened
                              ? 'Read-only exported review. Your temporary workspace has not been replaced. You cannot continue editing from this copy.'
                              : temporaryWorkspaceNotice,
                        ),
                      ),
                      ExpansionTile(
                        title: Text('Included versions (${r.sessions.length})'),
                        children: [
                          for (final s in r.sessions)
                            ListTile(
                              title: Text(sessionVersionLabel(s)),
                              subtitle: Text(
                                r.slotBindings.any(
                                      (b) =>
                                          b['session_key'] ==
                                          compositionReference(
                                            s,
                                          )['session_key'],
                                    )
                                    ? 'Used in programme'
                                    : 'Available in programme, not currently used',
                              ),
                            ),
                        ],
                      ),
                      if (reopened)
                        TextButton(
                          onPressed: () => _export(reopened: true),
                          child: const Text('Copy review export'),
                        ),
                      Expanded(
                        child: ProgrammeStudioScreen(
                          key: ValueKey(r),
                          catalog: r.catalog,
                          showDeveloperFixtures: true,
                          previewStateLabel: reopened
                              ? 'Read-only exported review'
                              : 'Current selected programme versions',
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    ),
  );
  Future<void> _export({bool reopened = false}) async {
    final bytes = reopened ? c.reconstructedExport() : await c.exportHandoff();
    if (!mounted ||
        bytes == null ||
        !c.canConsumeExport(bytes, reconstructed: reopened)) {
      showMessage(
        'Save or discard session changes, then review the programme before exporting.',
      );
      return;
    }
    final r = reopened ? c.reconstructed! : c.current!;
    await showDialog<void>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final valid = c.canConsumeExport(bytes, reconstructed: reopened);
          return AlertDialog(
            title: Text(
              valid ? 'Export complete review' : 'Review export changed',
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Includes this programme, its selected session versions and every version added to the programme, including unused versions.',
                    ),
                    const Text(
                      'Keep the complete copy somewhere safe. It opens read-only and cannot resume editing.',
                    ),
                    for (final s in r.sessions)
                      Text('Included: ${sessionVersionLabel(s)}'),
                    if (!reopened)
                      for (final owner in c.owners)
                        for (final local in owner.revisions)
                          if (!r.sessions.any(
                            (s) => sameRevision(s.identity, local.identity),
                          ))
                            Text(
                              'Not included: ${sessionVersionLabel(local.compiled)} — saved here, not added to programme',
                            ),
                    if (!valid)
                      const Text(
                        'Sources or review changed. Close and export the current programme again.',
                      ),
                    const Text(
                      'Download canonical sources also provides the programme YAML, every included session version as exact Founder YAML, a file index, instructions and this read-only review in one archive. It does not save an editable project or publish content.',
                    ),
                    ExpansionTile(
                      title: const Text('Advanced: complete export text'),
                      children: [SelectableText(bytes)],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              OutlinedButton(
                onPressed: valid
                    ? () async {
                        final fresh = reopened
                            ? c.reconstructedExport()
                            : await c.exportHandoff();
                        if (fresh == null ||
                            fresh != bytes ||
                            !c.canConsumeExport(
                              fresh,
                              reconstructed: reopened,
                            )) {
                          return;
                        }
                        try {
                          final current = reopened
                              ? c.reconstructed!
                              : c.current!;
                          final bundle = CanonicalSourceBundle.fromReview(
                            current,
                          );
                          if (!mounted ||
                              !context.mounted ||
                              !c.canConsumeExport(
                                fresh,
                                reconstructed: reopened,
                              )) {
                            return;
                          }
                          widget.downloadSources(bundle);
                          if (!mounted ||
                              !context.mounted ||
                              !c.canConsumeExport(
                                fresh,
                                reconstructed: reopened,
                              )) {
                            return;
                          }
                          Navigator.pop(context);
                          showMessage(
                            'Source download requested. Keep the archive somewhere safe. Its review opens read-only; this is not an editable project.',
                          );
                        } catch (_) {
                          showMessage(
                            'Source download could not start. Use the local Chrome preview, or copy the complete review instead. Your workspace is unchanged.',
                          );
                        }
                      }
                    : null,
                child: const Text('Download canonical sources'),
              ),
              FilledButton(
                onPressed: valid
                    ? () async {
                        final fresh = reopened
                            ? c.reconstructedExport()
                            : await c.exportHandoff();
                        if (fresh != null &&
                            fresh == bytes &&
                            c.canConsumeExport(
                              fresh,
                              reconstructed: reopened,
                            )) {
                          await Clipboard.setData(ClipboardData(text: fresh));
                          // The platform write may finish after reset or an edit.
                          // It cannot be recalled, but must not report stale success.
                          if (!mounted ||
                              !context.mounted ||
                              !c.canConsumeExport(
                                fresh,
                                reconstructed: reopened,
                              )) {
                            return;
                          }
                          Navigator.pop(context);
                          showMessage(
                            'Review export copied. Keep the complete copy somewhere safe. It opens read-only.',
                          );
                        }
                      }
                    : null,
                child: const Text('Copy review export'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openExport() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewExportInput(initial: c.rejectedHandoff),
    );
    if (!mounted || text == null) return;
    if (await c.reopen(text) && mounted) {
      setState(() => openedExport = true);
      await _reviewView(true);
    } else {
      showMessage(
        'This review export is incomplete or unsupported. Paste the complete review export. Your temporary workspace has not been replaced.',
      );
    }
  }

  void _workspaceMessage(String text) {
    showMessage(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _saveWorkspace() async {
    if (transferringWorkspace) return;
    setState(() => transferringWorkspace = true);
    try {
      final text = await c.saveEditableWorkspace();
      if (!mounted) return;
      if (text == null || !c.canConsumeWorkspace(text)) {
        _workspaceMessage(
          'Workspace changed while preparing the file. Try saving again.',
        );
        return;
      }
      widget.downloadWorkspace(text);
      if (!mounted || !c.canConsumeWorkspace(text)) return;
      c.markWorkspaceDownloadRequested(text);
      if (!mounted || !c.canConsumeWorkspace(text)) return;
      _workspaceMessage(
        'Editable workspace download requested. Keep the JSON file to continue later. It includes private versions and unvalidated drafts. No autosave or cloud backup.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => workspaceError = '$e');
        _workspaceMessage(
          'Workspace file could not be saved. Your edits are unchanged. See Advanced for the reason.',
        );
      }
    } finally {
      if (mounted) setState(() => transferringWorkspace = false);
    }
  }

  Future<void> _openSources() async {
    if (transferringWorkspace) return;
    final generation = c.generation;
    PreparedEditableWorkspace? candidate;
    setState(() => transferringWorkspace = true);
    try {
      final bytes = await widget.chooseSources();
      if (!mounted || bytes == null) return;
      if (generation != c.generation) {
        showMessage(
          'Workspace changed while choosing canonical sources. Open the archive again.',
        );
        return;
      }
      candidate = await c.prepareCanonicalSources(bytes);
      if (!mounted) return;
      if (candidate == null) {
        showMessage(
          'Workspace changed while checking canonical sources. Nothing was replaced. Open the archive again.',
        );
        return;
      }
      final pending = candidate;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AnimatedBuilder(
          animation: c,
          builder: (context, _) => AlertDialog(
            title: const Text('Replace with canonical sources?'),
            content: SingleChildScrollView(
              child: Text(
                c.isCurrentEditableWorkspace(pending)
                    ? '${pending.programmeName}\n${pending.savedVersions} validated imported snapshots.\nA new editable workspace will own these exact sources. No private versions, abandoned reservations, draft history or historical approval are restored. Imported versions have no inferred parent. Missing earlier numbers remain unavailable with unknown history; new revisions start above each supplied lineage maximum.\nCurrent work will be replaced, not merged. Save editable workspace afterward to retain subsequent edits/history. Reviews must be recomputed.'
                    : 'Current workspace changed. Close and open canonical sources again.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep current workspace'),
              ),
              FilledButton(
                onPressed: c.isCurrentEditableWorkspace(pending)
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('Replace with source workspace'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || confirmed != true) return;
      if (await c.replaceEditableWorkspace(pending)) {
        if (!mounted) return;
        setState(() {
          sessions = false;
          everReviewed = false;
          openedExport = false;
          workspaceError = null;
        });
        showMessage(
          'Canonical sources opened as a new editable workspace. Imported versions are validated snapshots, not historical freezes. Review again and save editable workspace to keep new edits.',
        );
      } else {
        showMessage(
          'Workspace changed; canonical sources were not installed. Open the archive again.',
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          'Canonical sources refused: ${e is FormatException ? e.message : e}. Current work was not replaced. Choose the complete supported uncompressed Studio TAR; saved editable JSON and review JSON use their separate Open actions.',
        );
      }
    } finally {
      candidate?.dispose();
      if (mounted) setState(() => transferringWorkspace = false);
    }
  }

  Future<void> _openWorkspace() async {
    if (transferringWorkspace) return;
    final generation = c.generation;
    PreparedEditableWorkspace? candidate;
    setState(() => transferringWorkspace = true);
    try {
      final text = await widget.chooseWorkspace();
      if (!mounted || text == null) return;
      if (generation != c.generation) {
        showMessage(
          'Workspace changed while choosing a file. Open it again to review replacement.',
        );
        return;
      }
      candidate = await c.prepareEditableWorkspace(text);
      if (!mounted) return;
      if (candidate == null) {
        showMessage('Workspace changed while opening. Try again.');
        return;
      }
      final pending = candidate;
      final summary =
          '${pending.programmeName}\n${pending.savedVersions} immutable versions (${pending.importedVersions} validated imported snapshots; ${pending.privateVersions} private) · ${pending.drafts} unvalidated session drafts.\nThis file was reconstructed separately. Replace the current workspace only if you want to continue from this file. Current work is not merged. Validation/reviews must be refreshed. This does not prove external approval or history.';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AnimatedBuilder(
          animation: c,
          builder: (context, _) => AlertDialog(
            title: const Text('Replace current workspace?'),
            content: SingleChildScrollView(
              child: Text(
                c.isCurrentEditableWorkspace(pending)
                    ? summary
                    : 'Current workspace changed. Close and open the file again.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep current workspace'),
              ),
              FilledButton(
                onPressed: c.isCurrentEditableWorkspace(pending)
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('Replace current workspace'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || confirmed != true) return;
      if (await c.replaceEditableWorkspace(pending)) {
        if (!mounted) return;
        setState(() {
          sessions = c.anyDraft;
          everReviewed = false;
          openedExport = false;
          workspaceError = null;
        });
        showMessage(
          'Editable workspace opened. Continue editing saved versions or draft inputs. Review the programme again before exporting.',
        );
      } else {
        showMessage(
          'Workspace changed; the file was not installed. Open it again.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => workspaceError = '$e');
        showMessage(
          'This editable workspace file is unsupported, incomplete or inconsistent. Current work was not replaced. Read-only review exports use Open exported review.',
        );
      }
    } finally {
      candidate?.dispose();
      if (mounted) setState(() => transferringWorkspace = false);
    }
  }

  Future<void> _reset() async {
    final generation = c.generation;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Discard this temporary workspace and return to the example?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard workspace'),
          ),
        ],
      ),
    );
    if (confirm == true && generation == c.generation) {
      await c.reset();
      if (mounted) {
        setState(() {
          message = null;
          workspaceError = null;
          sessions = false;
          everReviewed = false;
          openedExport = false;
        });
      }
    }
  }
}

class _ReviewExportInput extends StatefulWidget {
  const _ReviewExportInput({this.initial});
  final String? initial;
  @override
  State<_ReviewExportInput> createState() => _ReviewExportInputState();
}

class _ReviewExportInputState extends State<_ReviewExportInput> {
  late final input = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Open exported review'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              'Paste the complete review export. It opens separately, read-only. Your temporary workspace is not replaced and editing cannot be resumed from this copy.',
            ),
            TextField(
              controller: input,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Paste review export',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, input.text),
        child: const Text('Open read-only review'),
      ),
    ],
  );
}
