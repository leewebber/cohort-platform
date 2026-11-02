import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/utils/database_uuid.dart';
import '../composition/workspace/workspace_files.dart';
import '../composition/source_export/source_bundle_download.dart';
import '../presentation/programme_studio_app.dart';
import 'genuine_workspace.dart';
import 'native_form_fields.dart';
import 'native_session_source.dart';
import 'native_source_bundle.dart';
import 'reload_warning.dart';
import 'builder_theme.dart';
import 'structured_prescription_preview.dart';
import '../../../domain/running_workout/running_workout_codec.dart';
import 'prescription_presentation.dart';

/// Native source-policy presentation inside the existing programme-first entry.
/// Controls write existing package/graph fields, never a second programme tree.
class GenuineWorkspaceScreen extends StatefulWidget {
  const GenuineWorkspaceScreen({
    super.key,
    required this.controller,
    required this.replace,
    this.downloadWorkspace = downloadEditableWorkspace,
    this.chooseWorkspace = chooseEditableWorkspace,
  });
  final GenuineWorkspace controller;
  final void Function(GenuineWorkspace) replace;
  final void Function(String) downloadWorkspace;
  final Future<String?> Function() chooseWorkspace;
  @override
  State<GenuineWorkspaceScreen> createState() => _GenuineWorkspaceScreenState();
}

class _GenuineWorkspaceScreenState extends State<GenuineWorkspaceScreen> {
  GenuineWorkspace get c => widget.controller;
  int page = 0, week = 0;
  String? activeSlot, newSessionSlot;
  NativeRevision? viewed, editOriginal;
  Map<String, dynamic>? beforeEdit;
  String? beforeTitle;
  bool editing = false;
  final restRangeFields = <String>{};
  static const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  NativeRevision get selectedSession => viewed ?? active.latest;
  String displayTitle(NativeRevision r) {
    final owner = c.ownerOf(r);
    return owner.parent == r.identity.revisionNumber && owner.draft != null
        ? owner.draftTitle!
        : r.title;
  }

  String coachError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^(Bad state: |FormatException: )'), '')
      .replaceAll('Sources changed', 'The programme changed')
      .replaceAll(
        'Unresolved exercise setup — cannot prepare for publication.',
        'Library approval is needed before this exercise can be published.',
      )
      .replaceAll('local revision', 'saved session');

  void openSession(NativeRevision r, String? slot) {
    setState(() {
      activeLineage = r.identity.sessionLineageId;
      viewed = r;
      activeSlot = slot;
      editing = false;
      newSessionSlot = null;
      page = 1;
      message = null;
    });
  }

  void editSession() => attempt(() {
    var r = selectedSession;
    editOriginal = null;
    // A shared selection is split before editing, so pending intent cannot
    // leak into another day. Cancel restores the original selection.
    if (activeSlot != null &&
        (c.occurrences.where((s) => s['session_key'] == r.key).length > 1 ||
            c.ownerOf(r).draft != null &&
                c.ownerOf(r).parent != r.identity.revisionNumber)) {
      editOriginal = r;
      r = c.copyForCoach(r);
      c.useRevision(r, [activeSlot!], c.generation);
      activeLineage = r.identity.sessionLineageId;
      viewed = r;
    }
    final owner = c.ownerOf(r);
    beforeEdit = owner.draft == null ? null : nativeCopy(owner.draft!);
    beforeTitle = owner.draftTitle;
    if (owner.draft == null) c.begin(r);
    editing = true;
  });

  void cancelEdit() => attempt(() {
    final owner = active;
    if (beforeEdit == null || editOriginal != null) {
      c.cancel(owner);
    } else {
      owner.draftTitle = beforeTitle;
      c.edit(
        owner,
        (g) => g
          ..clear()
          ..addAll(nativeCopy(beforeEdit!)),
      );
    }
    if (editOriginal != null && activeSlot != null) {
      c.useRevision(editOriginal!, [activeSlot!], c.generation);
      viewed = editOriginal;
      activeLineage = editOriginal!.identity.sessionLineageId;
    }
    if (newSessionSlot != null) {
      c.removeOccurrence(newSessionSlot!);
      activeSlot = null;
      newSessionSlot = null;
      page = 0;
    }
    editing = false;
    message = 'Editing cancelled.';
  });

  void saveChanges() => attempt(() {
    final owner = active;
    final receipt = c.inspect(owner);
    final corrections = receipt.issues
        .where((e) => !e.contains('Unresolved exercise setup'))
        .toList();
    if (corrections.isNotEmpty) {
      message = 'Please correct: ${corrections.map(coachError).join('\n')}';
      return;
    }
    if (!receipt.admitted) {
      // Keep the exact pending source; never freeze an unresolved identity.
      c.save();
      newSessionSlot = null;
      editing = false;
      message =
          'Changes kept in this workspace. Library approval is still needed. Download a backup to keep them after reload.';
      return;
    }
    if (!c.freeze(owner)) {
      if (c.errors.any((e) => e.startsWith('No prescription change.'))) {
        cancelEdit();
        message = 'Session unchanged.';
      } else {
        message = c.errors.map(coachError).join('\n');
      }
      return;
    }
    viewed = owner.latest;
    if (activeSlot != null) {
      c.useRevision(owner.latest, [activeSlot!], c.generation);
    }
    newSessionSlot = null;
    editing = false;
    message =
        'Changes saved in this workspace. Download a backup to keep them after reload.';
  });
  String? activeLineage, message;
  bool transferring = false;
  late final void Function() stopReloadWarning;
  @override
  void initState() {
    super.initState();
    stopReloadWarning = watchUnsavedReload(() => c.unsaved);
  }

  @override
  void dispose() {
    stopReloadWarning();
    super.dispose();
  }

  NativeSessionOwner get active =>
      activeLineage == null ? c.owners.values.first : c.owners[activeLineage!];
  List<Map<String, dynamic>> get palette {
    final variants = <String, Map<String, dynamic>>{};
    for (final owner in c.owners.values) {
      for (final block in readWorkspaceJsonForUi(
        owner.revisions.first.source,
      )['blocks']) {
        for (final e in block['exercises']) {
          variants.putIfAbsent(
            e['variant_key'] as String,
            () => nativeCopy(e as Map),
          );
        }
      }
    }
    return variants.values.toList();
  }

  void downloadBackup() => attempt(() {
    final text = c.save();
    widget.downloadWorkspace(text);
    c.markSaved(text);
    message =
        'Backup download requested. Check your Downloads folder and keep the file.';
  });

  void attempt(VoidCallback action) {
    try {
      message = null;
      action();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => message = coachError(e));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => LayoutBuilder(
      builder: (context, viewport) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AppBar(
          title: const Text('Programme builder'),
          actions: [
            if (viewport.maxWidth < 650) ...[
              IconButton(
                tooltip: 'Download backup',
                disabledColor: const Color(0xff939c94),
                onPressed: transferring ? null : downloadBackup,
                icon: const Icon(Icons.download_outlined),
              ),
              IconButton(
                tooltip: 'Open backup',
                disabledColor: const Color(0xff939c94),
                onPressed: transferring ? null : open,
                icon: const Icon(Icons.folder_open_outlined),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: transferring ? null : downloadBackup,
                icon: const Icon(Icons.download_outlined),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).appBarTheme.foregroundColor,
                  disabledForegroundColor: const Color(0xff939c94),
                ),
                label: const Text('Download backup'),
              ),
              TextButton(
                onPressed: transferring ? null : open,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).appBarTheme.foregroundColor,
                  disabledForegroundColor: const Color(0xff939c94),
                ),
                child: const Text('Open backup'),
              ),
            ],
            PopupMenuButton<String>(
              tooltip: 'Advanced tools',
              onSelected: (v) {
                if (v == 'sources') {
                  openSources();
                }
                if (v == 'advanced') {
                  setState(() => page = 2);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'advanced',
                  child: Text('Advanced inspection & export'),
                ),
                PopupMenuItem(
                  value: 'sources',
                  child: Text('Import canonical sources'),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: page == 1 && editing
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      FilledButton(
                        onPressed: saveChanges,
                        child: const Text('Save changes'),
                      ),
                      OutlinedButton(
                        onPressed: cancelEdit,
                        child: const Text('Cancel'),
                      ),
                      OutlinedButton(
                        onPressed: previewSession,
                        child: const Text('Preview as athlete'),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.unsaved
                        ? 'Workspace changed · Download backup to keep your work'
                        : 'Backup matches workspace · keep the downloaded file',
                  ),
                  const Text(
                    'No autosave. Reloading loses changes since your last backup. Saving does not publish.',
                  ),
                  if (message != null)
                    Text(
                      message!,
                      key: const ValueKey('coach-message'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey('coach-page-$page'),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: page == 0
                        ? arrangement()
                        : page == 1
                        ? sessions()
                        : review(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget compact(List<Widget> fields) => LayoutBuilder(
    builder: (_, size) {
      final width = size.maxWidth < 420
          ? size.maxWidth
          : size.maxWidth < 760
          ? (size.maxWidth - 12) / 2
          : (size.maxWidth - 36) / 4;
      return Wrap(
        spacing: 12,
        runSpacing: 0,
        children: [for (final f in fields) SizedBox(width: width, child: f)],
      );
    },
  );

  String prescriptionSummary(Map p) {
    final reps = p['reps'] as Map;
    final dose = reps['type'] == 'range'
        ? '${reps['min_reps']}–${reps['max_reps']}'
        : reps['type'] == 'exact'
        ? '${reps['exact_reps']}'
        : '${reps['text']}';
    final rest =
        p['rest_seconds'] ??
        (p['rest_seconds_range'] as List?)?.join('–') ??
        'as coached';
    final rir = p['authored_details']?['source_rir'];
    return '${p['sets']} × $dose${p['per_side'] == true ? ' each side' : ''} · rest $rest sec${rir == null || rir == 'N/A' ? '' : ' · $rir RIR'}';
  }

  String targetChoice(Map target) => switch (target['kind']) {
    'alpha_quality_pace_v1' =>
      target['category'] == 'threshold'
          ? 'Personalised threshold pace'
          : 'Personalised current 10K pace',
    'heart_rate_zone_ref' => 'Personalised Zone 2 heart rate',
    'rpe_range' => 'Authored effort range',
    _ => 'Follow the coached effort',
  };

  String runningSummary(Map workout) {
    try {
      final typed = const RunningWorkoutCodec().decodeMap(
        Map<String, dynamic>.from(workout),
      );
      final groups = groupRunningSteps(typed.steps);
      final total = runningTotals(workout);
      return '${formatRunSeconds(total.seconds)}${total.metres == 0 ? '' : ' + ${total.metres} m'} · ${groups.length} training section${groups.length == 1 ? '' : 's'}';
    } catch (_) {
      return 'Check the workout durations';
    }
  }

  Widget readiness(NativeRevision revision) {
    final owner = c.ownerOf(revision);
    final graph =
        owner.parent == revision.identity.revisionNumber && owner.draft != null
        ? owner.draft!
        : readWorkspaceJsonForUi(revision.source);
    final pending = [
      for (final b in graph['blocks'])
        for (final e in b['exercises'])
          if (c.catalogue.idFor(e['variant_key'] as String) == null ||
              e['exercise_id'] != c.catalogue.idFor(e['variant_key'] as String))
            e,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        pending.isEmpty
            ? 'Draft programme · content approval and publication are separate.'
            : '${pending.length} exercise setup${pending.length == 1 ? '' : 's'} awaiting library approval. You can edit and keep a backup; athlete delivery is blocked.',
        style: TextStyle(
          color: pending.isEmpty ? builderMuted : builderWarning,
        ),
      ),
    );
  }

  Widget sessionPreview(NativeRevision revision, {bool modal = false}) {
    final owner = c.ownerOf(revision);
    final pending =
        owner.draft != null && owner.parent == revision.identity.revisionNumber;
    final graph = pending
        ? owner.draft!
        : readWorkspaceJsonForUi(revision.source);
    final receipt = pending ? c.inspect(owner) : c.inspectRevision(revision);
    final corrections = receipt.issues
        .where((e) => !e.contains('Unresolved exercise setup'))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: builderWarningSurface,
                border: Border.all(color: builderWarning),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: builderWarning),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Coach readiness · not athlete instructions'),
                    Text(
                      pending
                          ? 'Unpublished changes · not yet ready for athlete delivery'
                          : 'Selected session · unpublished',
                    ),
                    readiness(revision),
                    if ((graph['blocks'] as List).any(
                      (b) => b['timer_config'] != null,
                    ))
                      const Text(
                        'Personalised targets require separately confirmed athlete inputs and review. No automatic fallback.',
                      ),
                    const Text(
                      'Full source commentary and library evidence: Advanced session tools.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (corrections.isNotEmpty)
              Text(
                'Correct the prescription before previewing: ${corrections.map(coachError).join('\n')}',
              )
            else
              StructuredPrescriptionPreview(
                source: graph,
                title: pending ? owner.draftTitle! : revision.title,
                showTitle: modal,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> previewSession() async {
    final token = c.generation;
    final r = selectedSession;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 820,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedBuilder(
                    animation: c,
                    builder: (_, _) => token == c.generation
                        ? sessionPreview(r, modal: true)
                        : const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'The session changed. Close and reopen the preview.',
                            ),
                          ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close preview'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget field(
    String label,
    Object? value,
    ValueChanged<String> change, {
    String? identity,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: TextFormField(
      key: ValueKey(
        '${activeLineage ?? 'programme'}:${identity ?? label}:${active.reserved ?? 0}',
      ),
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: lines,
      onChanged: change,
    ),
  );
  Widget choice<T>(
    String label,
    T value,
    List<(T, String)> values,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      isExpanded: true,
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v.$1,
            child: Text(v.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) change(v);
      },
    ),
  );
  Widget arrangement() {
    final tree = c.programme.tree!;
    final weeks = tree['weeks'] as List;
    week = week.clamp(0, weeks.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field(
          'Programme name',
          tree['programme']['name'],
          (v) => c.programme.editProgramme('name', v),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (var w = 0; w < weeks.length; w++)
              ChoiceChip(
                label: Text('Week ${w + 1}'),
                selected: week == w,
                onSelected: (_) => setState(() => week = w),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Week ${week + 1}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TextButton.icon(
              onPressed: duplicateWeek,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate week'),
            ),
          ],
        ),
        if (weeks[week]['coach_note'] != null)
          Text('${weeks[week]['coach_note']}'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (_, box) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var d = 0; d < 7; d++)
                SizedBox(
                  width: box.maxWidth < 650
                      ? box.maxWidth
                      : (box.maxWidth - 24) / 3,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            days[d],
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if ((weeks[week]['days'][d]['slots'] as List).isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text('Rest day'),
                            ),
                          for (final slot in weeks[week]['days'][d]['slots'])
                            Builder(
                              builder: (_) {
                                final r = c.selected(
                                  slot['slot_key'] as String,
                                );
                                final graph = readWorkspaceJsonForUi(r.source);
                                final running = (graph['blocks'] as List).where(
                                  (b) => b['timer_config'] != null,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () => openSession(
                                          r,
                                          slot['slot_key'] as String,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayTitle(r),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                              Text(
                                                running.isNotEmpty
                                                    ? runningSummary(
                                                        running.first['timer_config']['running_workout']
                                                            as Map,
                                                      )
                                                    : '${(graph['blocks'] as List).expand((b) => b['exercises'] as List).length} exercises',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Wrap(
                                        children: [
                                          TextButton(
                                            onPressed: () => openSession(
                                              r,
                                              slot['slot_key'] as String,
                                            ),
                                            child: const Text('Open session'),
                                          ),
                                          TextButton(
                                            onPressed: () => transferSession(
                                              r,
                                              slot['slot_key'] as String,
                                              move: false,
                                            ),
                                            child: const Text('Copy to day'),
                                          ),
                                          TextButton(
                                            onPressed: () => transferSession(
                                              r,
                                              slot['slot_key'] as String,
                                              move: true,
                                            ),
                                            child: const Text('Move'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          if (weeks[week]['days'][d]['coach_note'] != null)
                            Text('${weeks[week]['days'][d]['coach_note']}'),
                          TextButton.icon(
                            onPressed: () => addSession(d),
                            icon: const Icon(Icons.add),
                            label: const Text('Add session'),
                          ),
                          if ((weeks[week]['days'][d]['slots'] as List)
                              .isNotEmpty)
                            TextButton(
                              onPressed: () => confirm(
                                'Remove all sessions from Week ${week + 1} ${days[d]} and make it a rest day?',
                                () => c.rest(week, d),
                              ),
                              child: const Text('Make rest day'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ExpansionTile(
          title: const Text('Programme details'),
          children: [
            field(
              'Programme description',
              tree['programme']['description'],
              (v) => c.programme.editProgramme('description', v),
              lines: 3,
            ),
            field(
              'Sessions per week',
              tree['programme']['sessions_per_week'],
              (v) => c.programme.editProgramme('sessions_per_week', v),
            ),
            choice(
              'Number of weeks',
              weeks.length,
              [for (var i = 1; i <= 10; i++) (i, '$i')],
              (v) => confirm(
                'Change to $v weeks? Removed weeks will be lost from this workspace. Keep a backup first.',
                () => c.setWeeks(v),
              ),
            ),
            field(
              'Week notes',
              weeks[week]['coach_note'] ?? weeks[week]['title'],
              (v) => c.programme.editWeek(week, 'coach_note', v),
              identity: 'week-$week',
              lines: 3,
            ),
            for (var d = 0; d < 7; d++)
              field(
                '${days[d]} notes',
                weeks[week]['days'][d]['coach_note'],
                (v) => c.programme.editDay(week, d, 'coach_note', v),
                identity: 'day-$week-$d',
                lines: 2,
              ),
          ],
        ),
      ],
    );
  }

  Widget sessions() {
    final owner = active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: editing ? null : () => setState(() => page = 0),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to programme'),
        ),
        Text(
          displayTitle(selectedSession),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (activeSlot != null)
          Text(
            c.occurrences
                .where((s) => s['slot_key'] == activeSlot)
                .map(
                  (s) => 'Week ${s['week']} · ${days[(s['day'] as int) - 1]}',
                )
                .join(),
          ),
        if (editing) readiness(selectedSession),
        Wrap(
          spacing: 12,
          children: [
            if (!editing)
              FilledButton(
                onPressed: editSession,
                child: const Text('Edit session'),
              ),
            if (!editing)
              OutlinedButton.icon(
                onPressed: previewSession,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview as athlete'),
              ),
            if (!editing && activeSlot != null)
              TextButton(
                onPressed: () =>
                    transferSession(selectedSession, activeSlot!, move: false),
                child: const Text('Copy to day'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!editing)
          sessionPreview(selectedSession)
        else ...[
          field('Session title', owner.draftTitle, (v) {
            owner.draftTitle = v;
            c.edit(owner, (_) {});
          }),
          for (var b = 0; b < (owner.draft!['blocks'] as List).length; b++)
            blockEditor(owner, b),
          TextButton(
            onPressed: () => c.edit(
              owner,
              (_) => (owner.draft!['blocks'] as List).add({
                'position': (owner.draft!['blocks'] as List).length + 1,
                'block_id': DatabaseUuid.newV4(),
                'block_type': 'strength',
                'title': 'Strength',
                'content': '',
                'workout_format': 'none',
                'exercises': [],
              }),
            ),
            child: const Text('Add exercise group'),
          ),
        ],
        ExpansionTile(
          title: const Text('Advanced session tools'),
          children: [
            for (final r in owner.revisions)
              ListTile(
                title: Text(
                  '${r.title} · saved version ${r.identity.revisionNumber}',
                ),
                trailing: TextButton(
                  onPressed: editing ? null : () => chooseUses(r),
                  child: const Text('Update multiple sessions…'),
                ),
              ),
            ExpansionTile(
              title: const Text('Source & library evidence'),
              children: [
                SelectableText(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(owner.latest.origin),
                ),
                for (final b
                    in (owner.draft ??
                        readWorkspaceJsonForUi(owner.latest.source))['blocks'])
                  for (final e in b['exercises'])
                    SelectableText(
                      const JsonEncoder.withIndent('  ').convert(
                        c.catalogue.rowFor(e['variant_key'] as String) ??
                            {'status': 'Awaiting library approval'},
                      ),
                    ),
                SelectableText(
                  owner.draft == null
                      ? selectedSession.source
                      : const JsonEncoder.withIndent('  ').convert(owner.draft),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<(int, int)?> pickDay(String title) => showDialog<(int, int)>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        SizedBox(
          width: 500,
          height: 420,
          child: ListView(
            children: [
              for (
                var w = 0;
                w < (c.programme.tree!['weeks'] as List).length;
                w++
              )
                ExpansionTile(
                  title: Text('Week ${w + 1}'),
                  initiallyExpanded: w == week,
                  children: [
                    for (var d = 0; d < 7; d++)
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, (w, d)),
                        child: Text(days[d]),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> transferSession(
    NativeRevision r,
    String slot, {
    required bool move,
  }) async {
    final token = c.generation;
    final target = await pickDay(
      move ? 'Move session to…' : 'Copy session to…',
    );
    if (target == null || !mounted || token != c.generation) return;
    await confirm(
      '${move ? 'Move' : 'Copy independently'} ${displayTitle(r)} to Week ${target.$1 + 1} ${days[target.$2]}? Existing sessions there will be kept.',
      () {
        if (token != c.generation) {
          throw StateError('The programme changed. Choose the day again.');
        }
        if (move) {
          c.moveOccurrence(slot, target.$1, target.$2);
        } else {
          c.copyToDay(r, target.$1, target.$2);
        }
        message = move
            ? 'Session moved.'
            : 'Independent copy added. Editing it will not change the original.';
      },
    );
  }

  Future<void> addSession(int day) async {
    final token = c.generation;
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Add session · ${days[day]}'),
        children: [
          for (final item in [
            ('strength', 'Strength session'),
            ('run', 'Running session'),
            ('copy', 'Copy an existing session'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, item.$1),
              child: Text(item.$2),
            ),
        ],
      ),
    );
    if (kind == null || !mounted || token != c.generation) return;
    if (kind == 'copy') {
      final r = await pickRevision();
      if (r != null && mounted && token == c.generation) {
        attempt(() {
          c.copyToDay(r, week, day);
        });
      }
    } else {
      attempt(() {
        final r = c.createSession(running: kind == 'run');
        c.place(week, day, r);
        final slot =
            c.occurrences.lastWhere(
                  (s) => s['session_key'] == r.key,
                )['slot_key']
                as String;
        openSession(r, slot);
        editSession();
        newSessionSlot = slot;
      });
    }
  }

  Widget blockEditor(NativeSessionOwner owner, int bi) {
    final b = owner.draft!['blocks'][bi] as Map<String, dynamic>;
    void change(VoidCallback f) => c.edit(owner, (_) => f());
    final key = b['block_id'] ?? 'block-$bi';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field(
              'Group title',
              b['title'],
              (v) => change(() => b['title'] = v),
              identity: '$key-title',
            ),
            if (b['timer_config'] == null)
              choice(
                'Training section',
                b['block_type'] as String,
                [
                  ('warm_up', 'Preparation'),
                  ('strength', 'Main strength'),
                  ('cool_down', 'Walking finish / cooldown'),
                ],
                (v) => change(() => b['block_type'] = v),
              ),
            if (b['block_type'] == 'warm_up' || b['block_type'] == 'cool_down')
              field(
                b['block_type'] == 'warm_up'
                    ? 'Warm-up instructions'
                    : 'Finish instructions',
                b['content'],
                (v) => change(() => b['content'] = v),
                identity: '$key-content',
                lines: 3,
              ),
            ExpansionTile(
              title: const Text('Additional session guidance & source notes'),
              children: [
                if (b['block_type'] != 'warm_up' &&
                    b['block_type'] != 'cool_down')
                  field(
                    'Section guidance',
                    b['content'],
                    (v) => change(() => b['content'] = v),
                    identity: '$key-content',
                    lines: 3,
                  ),
                if (b['coach_notes'] != null)
                  field(
                    'Additional coaching notes',
                    b['coach_notes'],
                    (v) => change(() => b['coach_notes'] = v),
                    identity: '$key-coach-notes',
                    lines: 3,
                  ),
              ],
            ),
            ExpansionTile(
              title: const Text('Arrange training sections'),
              children: [
                Wrap(
                  children: [
                    TextButton(
                      onPressed: bi == 0
                          ? null
                          : () => change(
                              () => moveNativeRow(
                                owner.draft!['blocks'] as List,
                                bi,
                                bi - 1,
                              ),
                            ),
                      child: const Text('Move section up'),
                    ),
                    TextButton(
                      onPressed:
                          bi + 1 == (owner.draft!['blocks'] as List).length
                          ? null
                          : () => change(
                              () => moveNativeRow(
                                owner.draft!['blocks'] as List,
                                bi,
                                bi + 1,
                              ),
                            ),
                      child: const Text('Move section down'),
                    ),
                    TextButton(
                      onPressed: () => confirm(
                        'Remove this block and all of its rows?',
                        () => change(() {
                          (owner.draft!['blocks'] as List).removeAt(bi);
                          for (
                            var i = 0;
                            i < (owner.draft!['blocks'] as List).length;
                            i++
                          ) {
                            owner.draft!['blocks'][i]['position'] = i + 1;
                          }
                        }),
                      ),
                      child: const Text('Remove section…'),
                    ),
                  ],
                ),
              ],
            ),
            if (b['timer_config'] != null)
              runningEditor(owner, b, '$key')
            else ...[
              for (var ei = 0; ei < (b['exercises'] as List).length; ei++)
                strengthEditor(owner, b, ei, '$key'),
              if (b['block_type'] == 'strength')
                TextButton(
                  onPressed: () => selectExercise(owner, b),
                  child: const Text('Add exercise'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget strengthEditor(
    NativeSessionOwner owner,
    Map<String, dynamic> block,
    int index,
    String bk,
  ) {
    final e = block['exercises'][index] as Map<String, dynamic>;
    final p = e['prescription'] as Map<String, dynamic>;
    final reps = p['reps'] as Map;
    final details = p['authored_details'] as Map? ?? {};
    final rirText = details['source_rir']?.toString() ?? 'N/A';
    final rirMode = rirText.startsWith('at least ')
        ? 'at_least'
        : p['rir_range'] != null
        ? (p['rir_range'][0] == p['rir_range'][1] ? 'exact' : 'range')
        : 'absent';
    final rirLow =
        p['rir_range']?[0]?.toString() ??
        (rirMode == 'at_least' ? rirText.substring(9) : '');
    final rirHigh = p['rir_range']?[1]?.toString() ?? rirLow;
    final restLow =
        (p['rest_seconds'] ?? p['rest_seconds_range']?[0])?.toString() ?? '';
    final restHigh =
        (p['rest_seconds'] ?? p['rest_seconds_range']?[1])?.toString() ?? '';
    final both = details.containsKey('rest_location')
        ? details['rest_location'].toString().contains('after both sides')
        : (e['variant_key'] == 'reverse_lunge_db' ||
              e['variant_key'] == 'bench_supported_db_row');
    final capture = p['performance_capture'] as Map?;
    void change(VoidCallback f) => c.edit(owner, (_) => f());
    final k = '$bk-${e['source_occurrence_id'] ?? index}';
    return Card(
      key: ValueKey(k),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${e['display_label_override']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            if (e['exercise_id'] == null)
              const Text(
                'Awaiting library approval',
                style: TextStyle(color: builderWarning),
              ),
            if (e['exercise_id'] == null &&
                c.catalogue.idFor(e['variant_key'] as String) != null)
              TextButton(
                onPressed: () => change(
                  () => e['exercise_id'] = c.catalogue.idFor(
                    e['variant_key'] as String,
                  ),
                ),
                child: const Text('Use approved library setup'),
              ),
            const SizedBox(height: 8),
            compact([
              field(
                'Sets',
                p['sets'],
                (v) => change(() => p['sets'] = integerInput(v)),
                identity: '$k-sets',
              ),
              if (reps['type'] == 'exact')
                field(
                  'Reps',
                  reps['exact_reps'],
                  (v) => change(() => reps['exact_reps'] = integerInput(v)),
                  identity: '$k-reps',
                ),
              if (reps['type'] == 'range') ...[
                field(
                  'Reps from',
                  reps['min_reps'],
                  (v) => change(() => reps['min_reps'] = integerInput(v)),
                  identity: '$k-reps-min',
                ),
                field(
                  'Reps to',
                  reps['max_reps'],
                  (v) => change(() => reps['max_reps'] = integerInput(v)),
                  identity: '$k-reps-max',
                ),
              ],
              if (reps['type'] == 'duration')
                field(
                  'Hold duration',
                  reps['text'],
                  (v) => change(() => reps['text'] = v),
                  identity: '$k-hold',
                ),
              if (restLow == restHigh && !restRangeFields.contains(k))
                field(
                  'Rest (sec)',
                  restLow,
                  (v) => change(() => setRest(p, v, v, both)),
                  identity: '$k-rest-exact',
                )
              else ...[
                field(
                  'Rest from (sec)',
                  restLow,
                  (v) => change(() => setRest(p, v, restHigh, both)),
                  identity: '$k-rest-min',
                ),
                field(
                  'Rest to (sec)',
                  restHigh,
                  (v) => change(() => setRest(p, restLow, v, both)),
                  identity: '$k-rest-max',
                ),
              ],
              if (rirMode != 'absent')
                field(
                  rirMode == 'exact'
                      ? 'RIR'
                      : rirMode == 'at_least'
                      ? 'RIR at least'
                      : 'RIR from',
                  rirLow,
                  (v) => change(
                    () =>
                        setRir(p, rirMode, v, rirMode == 'exact' ? v : rirHigh),
                  ),
                  identity: '$k-rir-min',
                ),
              if (rirMode == 'range')
                field(
                  'RIR to',
                  rirHigh,
                  (v) => change(() => setRir(p, rirMode, rirLow, v)),
                  identity: '$k-rir-max',
                ),
            ]),
            if (capture != null)
              field(
                'Load guidance / logging',
                capture['load_label'],
                (v) => change(() => capture['load_label'] = v),
                identity: '$k-load-label',
              ),
            ExpansionTile(
              title: const Text('Prescription options'),
              children: [
                choice(
                  'Reps / timed hold',
                  reps['type'] as String,
                  [
                    ('exact', 'Reps'),
                    ('range', 'Rep range'),
                    ('duration', 'Timed hold'),
                  ],
                  (v) => change(
                    () => p['reps'] = v == 'exact'
                        ? {'type': v, 'exact_reps': 1}
                        : v == 'range'
                        ? {'type': v, 'min_reps': 1, 'max_reps': 1}
                        : {'type': v, 'text': ''},
                  ),
                ),
                choice(
                  'Reps in reserve (RIR)',
                  rirMode,
                  [
                    ('absent', 'No requirement'),
                    ('exact', 'Exact'),
                    ('range', 'Range'),
                    ('at_least', 'At least'),
                  ],
                  (v) => change(() => setRir(p, v, rirLow, rirHigh)),
                ),
                TextButton(
                  onPressed: () => setState(() => restRangeFields.add(k)),
                  child: const Text('Show rest range bounds'),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('Setup, coaching notes & tempo'),
              children: [
                field(
                  'Coaching and setup notes',
                  p['coach_cue'],
                  (v) => change(() => p['coach_cue'] = v),
                  identity: '$k-notes',
                  lines: 4,
                ),
                field(
                  'Tempo',
                  p['tempo'],
                  (v) => change(() => p['tempo'] = v),
                  identity: '$k-tempo',
                  lines: 2,
                ),
                SwitchListTile(
                  title: const Text('Each side; both sides form one set'),
                  value: p['per_side'] == true,
                  onChanged: (v) => change(() => p['per_side'] = v),
                ),
                SwitchListTile(
                  title: const Text('Rest after both sides'),
                  value: both,
                  onChanged: (v) =>
                      change(() => setRest(p, restLow, restHigh, v)),
                ),
                if (capture != null)
                  choice(
                    'Load unit',
                    capture['load_unit'] as String? ?? '',
                    [('', 'As displayed'), ('kg', 'kg'), ('lb', 'lb')],
                    (v) => change(() {
                      if (v.isEmpty) {
                        capture.remove('load_unit');
                      } else {
                        capture['load_unit'] = v;
                      }
                    }),
                  ),
              ],
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: index == 0
                      ? null
                      : () => change(
                          () => moveNativeRow(
                            block['exercises'] as List,
                            index,
                            index - 1,
                          ),
                        ),
                  child: const Text('Move up'),
                ),
                TextButton(
                  onPressed: index + 1 == (block['exercises'] as List).length
                      ? null
                      : () => change(
                          () => moveNativeRow(
                            block['exercises'] as List,
                            index,
                            index + 1,
                          ),
                        ),
                  child: const Text('Move down'),
                ),
                TextButton(
                  onPressed: () => confirm(
                    'Remove ${e['display_label_override']} from this session?',
                    () => change(() {
                      (block['exercises'] as List).removeAt(index);
                      for (
                        var i = 0;
                        i < (block['exercises'] as List).length;
                        i++
                      ) {
                        block['exercises'][i]['position'] = i + 1;
                      }
                    }),
                  ),
                  child: const Text('Remove exercise'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget runningEditor(
    NativeSessionOwner owner,
    Map<String, dynamic> block,
    String key,
  ) {
    final workout = block['timer_config']['running_workout'] as Map;
    final steps = workout['steps'] as List;
    void change(VoidCallback f) => c.edit(owner, (_) {
      f();
      syncTimer(block);
    });
    String total;
    try {
      final t = runningTotals(workout);
      total =
          '${formatRunSeconds(t.seconds)}${t.metres > 0 ? ' + ${t.metres} m' : ''}';
    } catch (_) {
      total = 'Correct invalid phase durations';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workout duration · $total'),
        Text(
          '${runningSummary(workout)}\nPersonalised pace and heart rate use the athlete’s separately confirmed training inputs. No athlete data is entered here.',
        ),
        ExpansionTile(
          title: const Text('Additional workout guidance'),
          children: [
            field(
              'Workout notes',
              workout['notes'],
              (v) => change(() => workout['notes'] = v),
              identity: '$key-workout-notes',
              lines: 4,
            ),
          ],
        ),
        for (var i = 0; i < steps.length; i++)
          Builder(
            builder: (_) {
              final s = steps[i] as Map,
                  d = s['duration'] as Map,
                  target = s['target'] as Map;
              final sk = s['step_id'];
              return ExpansionTile(
                key: ValueKey(sk),
                title: Text('${i + 1}. ${s['label']}'),
                subtitle: Text(
                  '${d['kind'] == 'time' && d['milliseconds'] is int
                      ? formatRunSeconds((d['milliseconds'] as int) ~/ 1000)
                      : d['kind'] == 'distance'
                      ? '10,000 m'
                      : 'Invalid time'} · ${targetChoice(target)}',
                ),
                children: [
                  field(
                    'Phase title',
                    s['label'],
                    (v) => change(() => s['label'] = v),
                    identity: '$sk-title',
                  ),
                  choice(
                    'Phase role',
                    s['role'] as String,
                    [
                      ('warm_up', 'Warm-up'),
                      ('work', 'Work'),
                      ('recovery', 'Recovery'),
                      ('cool_down', 'Cooldown'),
                    ],
                    (v) => change(() => s['role'] = v),
                  ),
                  if (d['kind'] == 'time')
                    field(
                      'Duration in seconds',
                      d['milliseconds'] is int
                          ? (d['milliseconds'] as int) ~/ 1000
                          : d['milliseconds'],
                      (v) => change(() {
                        final n = int.tryParse(v);
                        d['milliseconds'] = n == null ? v : n * 1000;
                      }),
                      identity: '$sk-seconds',
                    ),
                  if (d['kind'] == 'distance')
                    const Text(
                      'Selected final 10,000 m body. Athlete confirms external distance; no live distance measurement.',
                    ),
                  choice(
                    'Training target',
                    target['kind'] == 'alpha_quality_pace_v1'
                        ? target['category'] as String
                        : target['kind'] as String,
                    [
                      ('none', 'Coached effort; no fixed pace/HR'),
                      ('heart_rate_zone_ref', 'Personalised Zone 2 heart rate'),
                      ('threshold', 'Personalised threshold pace'),
                      ('current_10k', 'Personalised current 10K pace'),
                      if (target['kind'] == 'rpe_range')
                        ('rpe_range', 'Retained authored RPE range'),
                    ],
                    (v) => change(
                      () => s['target'] = v == 'heart_rate_zone_ref'
                          ? {'kind': v, 'zone_ref': 'athlete_confirmed_zone_2'}
                          : {'threshold', 'current_10k'}.contains(v)
                          ? {'kind': 'alpha_quality_pace_v1', 'category': v}
                          : v == 'rpe_range'
                          ? target
                          : {'kind': 'none'},
                    ),
                  ),
                  field(
                    'Phase cues / effort',
                    s['notes'],
                    (v) => change(() => s['notes'] = v),
                    identity: '$sk-notes',
                    lines: 3,
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: i == 0
                            ? null
                            : () => change(
                                () => moveNativeRow(
                                  steps,
                                  i,
                                  i - 1,
                                  positions: false,
                                ),
                              ),
                        child: const Text('Move phase up'),
                      ),
                      TextButton(
                        onPressed: i + 1 == steps.length
                            ? null
                            : () => change(
                                () => moveNativeRow(
                                  steps,
                                  i,
                                  i + 1,
                                  positions: false,
                                ),
                              ),
                        child: const Text('Move phase down'),
                      ),
                      TextButton(
                        onPressed: () => change(() => steps.removeAt(i)),
                        child: const Text('Remove phase'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        Wrap(
          children: [
            TextButton(
              onPressed: () => change(() => steps.add(nativePhase())),
              child: const Text('Add timed phase'),
            ),
            TextButton(
              onPressed: () => repeat(owner, block),
              child: const Text('Add intervals'),
            ),
          ],
        ),
      ],
    );
  }

  Widget review() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton(
        onPressed: () => setState(() => page = 0),
        child: const Text('Back to programme'),
      ),
      TextButton(
        onPressed: () => c.refreshReview(),
        child: const Text('Check export readiness'),
      ),
      TextButton(
        onPressed: () => confirm(
          'Keep unused sessions in the backup but remove them from the export inventory?',
          c.excludeUnusedSources,
        ),
        child: const Text('Exclude unused sources from programme export…'),
      ),
      const Text(
        'Advanced inspection & prepared export · content approval and publication remain separate.',
      ),
      if (c.errors.isNotEmpty) Text(c.errors.join('\n')),
      if (!c.reviewCurrent)
        const Text('Sources changed. Refresh the exact prescription review.'),
      TextButton(
        onPressed: c.reviewCurrent && c.errors.isEmpty
            ? () => attempt(
                () => downloadSourceBundle(
                  NativeSourceBundle.prepare(c).transport,
                ),
              )
            : null,
        child: const Text('Prepare canonical v2 / native graph export'),
      ),
      for (final slot in c.occurrences)
        ExpansionTile(
          title: Text(
            'Week ${slot['week']} · day ${slot['day']} · ${c.selected(slot['slot_key'] as String).title}',
          ),
          children: [
            SelectableText(
              c
                  .inspectRevision(c.selected(slot['slot_key'] as String))
                  .readable,
            ),
          ],
        ),
      if (c.programme.currentReview != null && c.errors.isEmpty)
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ProgrammeStudioApp(catalog: c.programme.currentReview!),
            ),
          ),
          child: const Text('Open existing athlete prescription review'),
        ),
    ],
  );

  Future<void> confirm(String title, VoidCallback action) async {
    final token = c.generation;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      attempt(() {
        if (token != c.generation) {
          throw StateError('Sources changed. Review this action again.');
        }
        action();
      });
    }
  }

  Future<void> open() async {
    final token = c.generation;
    setState(() => transferring = true);
    PreparedGenuineOpen? prepared;
    try {
      final text = await widget.chooseWorkspace();
      if (!mounted || text == null || token != c.generation) return;
      prepared = c.prepareOpen(text);
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Open this backup and replace the workspace?'),
          content: const Text(
            'Download a backup of your current work first. Opening this file replaces the workspace. Saving or opening does not approve or publish a programme.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open backup'),
            ),
          ],
        ),
      );
      if (yes == true && mounted && c.isCurrentOpen(prepared)) {
        final candidate = prepared.candidate;
        prepared = null;
        widget.replace(candidate);
      }
    } catch (e) {
      if (mounted) setState(() => message = coachError(e));
    } finally {
      prepared?.candidate.dispose();
      if (mounted) setState(() => transferring = false);
    }
  }

  Future<void> place(int day) async {
    final token = c.generation;
    final r = await pickRevision();
    if (r != null && mounted) {
      attempt(() {
        if (token != c.generation) {
          throw StateError('Programme changed. Choose the placement again.');
        }
        c.place(week, day, r);
      });
    }
  }

  Future<void> openSources() async {
    final token = c.generation;
    GenuineWorkspace? candidate;
    setState(() => transferring = true);
    try {
      final bytes = await chooseCanonicalSources();
      if (!mounted || bytes == null || token != c.generation) return;
      candidate = NativeSourceBundle.open(bytes, c.catalogue);
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Open as a new local draft?'),
          content: const Text(
            'This replaces the current workspace. Canonical sources have unknown historical revisions and no restored approval. Keep your current editable file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open backup'),
            ),
          ],
        ),
      );
      if (yes == true && mounted && token == c.generation) {
        final next = candidate;
        candidate = null;
        widget.replace(next);
      }
    } catch (e) {
      if (mounted) setState(() => message = coachError(e));
    } finally {
      candidate?.dispose();
      if (mounted) setState(() => transferring = false);
    }
  }

  Future<NativeRevision?> pickRevision() => showDialog<NativeRevision>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Copy an existing session'),
      children: [
        for (final o in c.owners.values)
          for (final r in [o.latest])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(
                c.sessionLabel(r).replaceAll(RegExp(r' · version \d+$'), ''),
              ),
            ),
      ],
    ),
  );
  Future<void> duplicateWeek() async {
    final token = c.generation;
    final from = week;
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Duplicate into which week?'),
        children: [
          for (var w = 0; w < (c.programme.tree!['weeks'] as List).length; w++)
            if (w != week)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, w),
                child: Text('Week ${w + 1}'),
              ),
        ],
      ),
    );
    if (target != null && mounted) {
      await confirm(
        'Replace all seven days in Week ${target + 1} with independent copies of Week ${from + 1}? Existing sessions in the target week will be replaced.',
        () {
          if (token != c.generation) {
            throw StateError('The programme changed. Choose the week again.');
          }
          c.copyWeekForCoach(from, target);
        },
      );
    }
  }

  Future<void> chooseUses(NativeRevision revision) async {
    final token = c.generation;
    final occurrences = c.occurrences;
    final chosen = <String>{};
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Update multiple sessions'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final s in occurrences)
                    CheckboxListTile(
                      title: Text(
                        'Week ${s['week']} · ${days[(s['day'] as int) - 1]} · ${c.selected(s['slot_key'] as String).title}',
                      ),
                      value: chosen.contains(s['slot_key']),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          chosen.add(s['slot_key'] as String);
                        } else {
                          chosen.remove(s['slot_key']);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text('Update ${chosen.length} selected sessions'),
            ),
          ],
        ),
      ),
    );
    if (yes == true && mounted) {
      await confirm(
        'Replace the selected sessions with ${revision.title}: ${chosen.map((k) {
          final s = occurrences.singleWhere((s) => s['slot_key'] == k);
          return 'Week ${s['week']} ${days[(s['day'] as int) - 1]}';
        }).join(', ')}?',
        () => c.useRevision(revision, chosen.toList(), token),
      );
    }
  }

  Future<void> selectExercise(
    NativeSessionOwner owner,
    Map<String, dynamic> block,
  ) async {
    final token = c.generation;
    var query = '', equipment = '', movement = '';
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Find exercise'),
          content: SizedBox(
            width: 650,
            height: 550,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Exercise name'),
                  onChanged: (v) => update(() => query = v.toLowerCase()),
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Equipment / setup filter',
                  ),
                  onChanged: (v) => update(() => equipment = v.toLowerCase()),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Movement'),
                  onChanged: (v) => update(() => movement = v.toLowerCase()),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final e in palette)
                        if ('${e['display_label_override']}'
                                .toLowerCase()
                                .contains(query) &&
                            '${e['prescription']['coach_cue']} ${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['equipment']}'
                                .toLowerCase()
                                .contains(equipment) &&
                            '${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['movement_pattern'] ?? 'unknown'}'
                                .toLowerCase()
                                .contains(movement))
                          Card(
                            child: ListTile(
                              title: Text(
                                e['display_label_override'] as String,
                              ),
                              subtitle: Text(
                                '${e['prescription']['coach_cue']}\nEquipment: ${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['equipment'] ?? 'unknown'}; setup: ${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['setup'] ?? 'unknown'}; execution: ${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['execution'] ?? 'unknown'}\n${c.catalogue.idFor(e['variant_key'] as String) == null ? 'Awaiting library approval' : 'Library setup available'}',
                              ),
                              onTap: () => Navigator.pop(ctx, e),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted && token == c.generation) {
      c.edit(owner, (_) {
        final e = nativeCopy(selected)
          ..['exercise_id'] = c.catalogue.idFor(
            selected['variant_key'] as String,
          )
          ..['position'] = (block['exercises'] as List).length + 1
          ..['source_occurrence_id'] = DatabaseUuid.newV4();
        (block['exercises'] as List).add(e);
      });
    }
  }

  Future<void> repeat(
    NativeSessionOwner owner,
    Map<String, dynamic> block,
  ) async {
    final token = c.generation;
    var count = '4', work = '300', recovery = '90', last = false;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Add running intervals'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  initialValue: count,
                  decoration: const InputDecoration(labelText: 'Repetitions'),
                  onChanged: (v) => count = v,
                ),
                TextFormField(
                  initialValue: work,
                  decoration: const InputDecoration(labelText: 'Work seconds'),
                  onChanged: (v) => work = v,
                ),
                TextFormField(
                  initialValue: recovery,
                  decoration: const InputDecoration(
                    labelText: 'Recovery seconds',
                  ),
                  onChanged: (v) => recovery = v,
                ),
                SwitchListTile(
                  title: const Text(
                    'Include recovery after the last repetition',
                  ),
                  value: last,
                  onChanged: (v) => update(() => last = v),
                ),
                const Text(
                  'Adds work and easy recovery in order. Choose whether recovery follows the final repetition, then adjust each step if needed.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add intervals'),
            ),
          ],
        ),
      ),
    );
    if (yes == true && mounted && token == c.generation) {
      attempt(() {
        final n = int.parse(count),
            w = int.parse(work),
            r = int.parse(recovery);
        if (w <= 0 || r <= 0) {
          throw const FormatException('Enter positive work/recovery seconds.');
        }
        c.edit(owner, (_) {
          (block['timer_config']['running_workout']['steps'] as List).addAll(
            expandRepeat(
              work: nativePhase(
                seconds: w,
                title: 'Threshold-labelled work',
                target: {
                  'kind': 'alpha_quality_pace_v1',
                  'category': 'threshold',
                },
              ),
              recovery: nativePhase(
                role: 'recovery',
                seconds: r,
                title: 'Very easy recovery',
              ),
              count: n,
              recoveryAfterLast: last,
            ),
          );
          syncTimer(block);
        });
      });
    }
  }
}

Map<String, dynamic> readWorkspaceJsonForUi(String source) =>
    jsonDecode(source) as Map<String, dynamic>;
