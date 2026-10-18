import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../presentation/programme_studio_app.dart';
import '../presentation/programme_studio_controller.dart';
import 'programme_authoring_controller.dart';
import 'programme_authoring_fixtures.dart';

class ProgrammeAuthoringScreen extends StatefulWidget {
  const ProgrammeAuthoringScreen({
    super.key,
    this.controller,
    this.embedded = false,
    this.authorFacing = false,
    this.workspaceGeneration,
    this.onSelectSlot,
    this.sessionChoiceLabel,
  });
  final bool embedded, authorFacing;
  final int Function()? workspaceGeneration;
  final String Function(Map<String, dynamic> reference)? sessionChoiceLabel;
  final Future<void> Function(int week, int day, int slot, String sessionKey)?
  onSelectSlot;
  final ProgrammeAuthoringController? controller;
  @override
  State<ProgrammeAuthoringScreen> createState() =>
      _ProgrammeAuthoringScreenState();
}

class _ProgrammeAuthoringScreenState extends State<ProgrammeAuthoringScreen> {
  late ProgrammeAuthoringController controller =
      widget.controller ??
      ProgrammeAuthoringController(fixture: programmeAuthoringFixtures.first);
  int week = 0;
  int day = 0;
  int sourceEpoch = 0;
  bool showReview = false;

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => widget.embedded
        ? _editor()
        : LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180;
              return Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: wide ? 260 : constraints.maxHeight * .38,
                        ),
                        child: SingleChildScrollView(child: _header(wide)),
                      ),
                      Expanded(
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(width: 460, child: _editor()),
                                  const VerticalDivider(width: 1),
                                  Expanded(child: _review()),
                                ],
                              )
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment(
                                          value: false,
                                          label: Text('Author'),
                                        ),
                                        ButtonSegment(
                                          value: true,
                                          label: Text('Review'),
                                        ),
                                      ],
                                      selected: {showReview},
                                      onSelectionChanged: (value) => setState(
                                        () => showReview = value.single,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: showReview ? _review() : _editor(),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );

  Widget _header(bool wide) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.edit_note, size: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Programme authoring',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Text('D1 · Local synthetic source · Plan Package v1'),
              ],
            ),
            FilledButton.icon(
              key: const Key('validate-review'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                final valid = controller.validateAndReview();
                if (valid && !wide) setState(() => showReview = true);
              },
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Validate & refresh review'),
            ),
            OutlinedButton.icon(
              key: const Key('export-yaml'),
              onPressed: controller.isCurrent ? _export : null,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export YAML'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            controller.status,
            key: const Key('source-status'),
            style: TextStyle(
              color: controller.isCurrent
                  ? Colors.greenAccent
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Edits clear validation, review and export. No publication or athlete changes.',
        ),
      ],
    ),
  );

  Widget _editor() {
    final tree = controller.tree;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.embedded) Text(controller.sourceLabel),
        if (!widget.embedded)
          DropdownButtonFormField<String>(
            key: ValueKey('fixture-${controller.fixture.id}'),
            initialValue: controller.fixture.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Synthetic source'),
            items: [
              for (final fixture in programmeAuthoringFixtures)
                DropdownMenuItem(
                  value: fixture.id,
                  child: Text(
                    fixture.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.controller != null
                ? null
                : (value) {
                    if (value == null) return;
                    final previous = controller;
                    setState(() {
                      controller = ProgrammeAuthoringController(
                        fixture: programmeAuthoringFixtures.firstWhere(
                          (f) => f.id == value,
                        ),
                      );
                      week = 0;
                      day = 0;
                      sourceEpoch++;
                      showReview = false;
                    });
                    previous.dispose();
                  },
          ),
        const SizedBox(height: 12),
        if (!widget.embedded)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                key: const Key('reopen-source'),
                onPressed: _reopen,
                child: const Text('Reopen YAML'),
              ),
              TextButton(
                key: const Key('reset-source'),
                onPressed: () {
                  controller.reset();
                  setState(() {
                    sourceEpoch++;
                    week = 0;
                    day = 0;
                    showReview = false;
                  });
                },
                child: const Text('Reset to imported source'),
              ),
            ],
          ),
        if (controller.issues.isNotEmpty)
          _card('Resolve before review or export', [
            for (final issue in controller.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(
                  '${issue.path} · ${issue.code ?? 'validation'}\n${issue.message}',
                  key: ValueKey('issue-${issue.path}-${issue.code}'),
                ),
              ),
          ]),
        if (tree != null) ...[
          _card('Programme metadata', [
            for (final field in [
              'name',
              'description',
              'coaching_intent',
              'primary_goal',
              'sessions_per_week',
            ])
              _field(
                'programme-$field',
                _label(field),
                (tree['programme'] as Map)[field]?.toString() ?? '',
                (value) => controller.editProgramme(field, value),
              ),
            Text(
              controller.supportsScheduleEditing
                  ? 'Identity, owner and version are locked. Use Programme to set up the supported four-week schedule.'
                  : 'Identity, owner, version and duration are locked to this synthetic source.',
            ),
          ]),
          _schedule(tree),
        ],
        _card('Source comparison', [
          const Text(
            'Baseline: original imported YAML bytes, including comments. Export normalizes formatting; formatting preservation is not promised.',
          ),
          const SizedBox(height: 8),
          Text(
            controller.isCurrent
                ? (controller.meaningChanged
                      ? 'Compiled meaning differs from the imported source.'
                      : 'Compiled meaning and hash match the imported source.')
                : 'Semantic comparison awaits current validation.',
          ),
          ExpansionTile(
            title: Text(
              'Original → candidate source diff (${controller.sourceDiff.length} changed lines)',
            ),
            children: [
              SelectableText(
                controller.sourceDiff.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ]),
        _card('Locked authored contracts', [
          Text(
            controller.supportsScheduleEditing
                ? 'Progression, phases, adaptation, invariants, assessments, evidence and comparison declarations remain authored source. Actions that would invalidate a locked reference are refused.'
                : 'Progression, phases, adaptation, invariants, assessments, evidence and comparison declarations remain authored source. Removing a referenced slot fails validation.',
          ),
          if (tree != null)
            ExpansionTile(
              title: const Text('Inspect preserved contract declarations'),
              children: [
                for (final key in [
                  'adaptation_permissions',
                  'protected_invariants',
                  'assessments',
                  'performance_evidence_requirements',
                  'comparison_identities',
                ])
                  ListTile(
                    title: Text(key.replaceAll('_', ' ')),
                    subtitle: SelectableText(tree[key].toString()),
                  ),
              ],
            ),
        ]),
      ],
    );
  }

  Widget _schedule(Map<String, dynamic> tree) {
    final weeks = tree['weeks'] as List;
    final selectedWeek = weeks[week] as Map;
    final days = selectedWeek['days'] as List;
    final selectedDay = days[day] as Map;
    final slots = selectedDay['slots'] as List;
    return _card('Authored schedule', [
      DropdownButtonFormField<int>(
        key: ValueKey('week-$sourceEpoch-$week'),
        initialValue: week,
        decoration: const InputDecoration(labelText: 'Week'),
        items: [
          for (var i = 0; i < weeks.length; i++)
            DropdownMenuItem(
              value: i,
              child: Text('Week ${weeks[i]['week_number']}'),
            ),
        ],
        onChanged: (value) => setState(() {
          week = value!;
          day = 0;
        }),
      ),
      for (final field in ['title', 'coach_note'])
        _field(
          'week-$week-$field',
          'Week ${_label(field).toLowerCase()}',
          selectedWeek[field]?.toString() ?? '',
          (value) => controller.editWeek(week, field, value),
        ),
      DropdownButtonFormField<int>(
        key: ValueKey('day-$sourceEpoch-$week-$day'),
        initialValue: day,
        decoration: const InputDecoration(labelText: 'Day'),
        items: [
          for (var i = 0; i < days.length; i++)
            DropdownMenuItem(
              value: i,
              child: Text('Day ${days[i]['day_order']}'),
            ),
        ],
        onChanged: (value) => setState(() => day = value!),
      ),
      for (final field in ['title', 'coach_note'])
        _field(
          'day-$week-$day-$field',
          'Day ${_label(field).toLowerCase()}',
          selectedDay[field]?.toString() ?? '',
          (value) => controller.editDay(week, day, field, value),
        ),
      DropdownButtonFormField<String>(
        key: ValueKey(
          'day-type-$sourceEpoch-$week-$day-${selectedDay['day_type']}',
        ),
        initialValue: selectedDay['day_type'] as String,
        decoration: const InputDecoration(labelText: 'Day placement'),
        items: [
          for (final type in [
            'training',
            'rest',
            if (selectedDay['day_type'] == 'optional') 'optional',
          ])
            DropdownMenuItem(value: type, child: Text(type)),
        ],
        onChanged: selectedDay['day_type'] == 'optional'
            ? null
            : (value) => controller.setDayType(week, day, value!),
      ),
      const SizedBox(height: 16),
      if (slots.isEmpty) const Text('No session slots on this day.'),
      for (var i = 0; i < slots.length; i++) _slot(tree, slots[i] as Map, i),
      OutlinedButton.icon(
        key: const Key('add-slot'),
        onPressed: selectedDay['day_type'] == 'training' ? _addSlot : null,
        icon: const Icon(Icons.add),
        label: Text(
          widget.authorFacing ? 'Add workout' : 'Add required fixture slot',
        ),
      ),
    ]);
  }

  Widget _slot(Map<String, dynamic> tree, Map slot, int index) {
    final required =
        slot['is_optional'] == false &&
        slot['completion_expectation'] == 'required';
    final canMove =
        required &&
        (tree['weeks'] as List).any(
          (w) => (w['days'] as List).any((d) => d['day_type'] == 'training'),
        );
    final sessions = tree['sessions'] as List;
    final key = slot['slot_key'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.authorFacing
                ? 'Workout ${slot['session_order']}'
                : 'Slot ${slot['session_order']} · $key',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('session-$sourceEpoch-$key-${slot['session_key']}'),
            initialValue: slot['session_key'] as String,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.authorFacing
                  ? 'Choose version'
                  : 'Exact fixture session revision',
            ),
            items: [
              for (final session in sessions)
                DropdownMenuItem(
                  value: session['session_key'] as String,
                  child: Text(
                    widget.sessionChoiceLabel?.call(
                          Map<String, dynamic>.from(session),
                        ) ??
                        '${session['title']} · revision ${session['revision_number']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: required
                ? widget.onSelectSlot != null
                      ? (value) async {
                          if (value == null || value == slot['session_key']) {
                            return;
                          }
                          await widget.onSelectSlot!(week, day, index, value);
                          if (mounted) setState(() => sourceEpoch++);
                        }
                      : (value) async {
                          if (value == null || value == slot['session_key']) {
                            return;
                          }
                          final active = controller;
                          final revision = active.revision;
                          final confirmed = await _confirm(
                            'Change exact session revision?',
                            'Slot $key will reference $value. Its locked progression and completion contracts remain unchanged.',
                          );
                          if (!mounted) return;
                          if (confirmed &&
                              identical(active, controller) &&
                              revision == controller.revision) {
                            controller.editSlot(
                              week,
                              day,
                              index,
                              'session_key',
                              value,
                            );
                          }
                          setState(() => sourceEpoch++);
                        }
                : null,
          ),
          for (final field in ['display_title', 'coach_note'])
            _field(
              'slot-$key-$field',
              _label(field),
              slot[field]?.toString() ?? '',
              (value) => controller.editSlot(week, day, index, field, value),
              enabled: required,
            ),
          DropdownButtonFormField<String>(
            key: ValueKey('time-$sourceEpoch-$key-${slot['time_of_day']}'),
            initialValue: slot['time_of_day'] as String,
            decoration: const InputDecoration(labelText: 'Time of day'),
            items: [
              for (final time in ['any', 'morning', 'afternoon', 'evening'])
                DropdownMenuItem(value: time, child: Text(time)),
            ],
            onChanged: required
                ? (value) => controller.editSlot(
                    week,
                    day,
                    index,
                    'time_of_day',
                    value!,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Locked progression: ${(slot['progression'] as Map)['prescription_summary']}',
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: canMove ? () => _move(index, tree) : null,
                icon: const Icon(Icons.swap_vert),
                label: const Text('Move / reorder'),
              ),
              TextButton.icon(
                onPressed: required
                    ? () async {
                        final confirmed = await _confirm(
                          widget.authorFacing
                              ? 'Remove this workout?'
                              : 'Remove $key?',
                          widget.authorFacing
                              ? 'Remove this workout from the day. Programme rules remain protected; review the programme afterward.'
                              : 'Authored references are preserved. Removing a referenced slot will fail validation.',
                        );
                        if (!mounted) return;
                        if (confirmed) {
                          controller.removeSlot(week, day, index);
                          setState(() => sourceEpoch++);
                        }
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Remove'),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _review() {
    final catalog = controller.currentReview;
    if (catalog == null) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.preview_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'Review awaits the current source',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Validate and refresh review to inspect the exact candidate export. Previous successful reviews are cleared on every edit.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SizedBox(
          height:
              constraints.maxHeight >
                  900 * MediaQuery.textScalerOf(context).scale(1)
              ? constraints.maxHeight
              : 900 * MediaQuery.textScalerOf(context).scale(1),
          child: ProgrammeStudioScreen(
            key: ValueKey('review-${controller.revision}'),
            catalog: catalog,
            showDeveloperFixtures: true,
            previewStateLabel:
                'D1 synthetic · current source revision ${controller.revision}',
            initialSelection: ProgrammeStudioSelection(
              catalogId: 'd1-${controller.fixture.id}',
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String id,
    String label,
    String value,
    ValueChanged<String> changed, {
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      key: ValueKey('$id-$sourceEpoch'),
      initialValue: value,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      minLines: 1,
      maxLines:
          id.contains('note') ||
              id.contains('description') ||
              id.contains('intent')
          ? 3
          : 1,
      onChanged: changed,
    ),
  );

  Widget _card(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  String _label(String field) => switch (field) {
    'name' => 'Programme name',
    'coaching_intent' => 'Coaching intent',
    'primary_goal' => 'Primary goal',
    'sessions_per_week' => 'Declared sessions per week',
    'coach_note' => 'Coach note',
    'display_title' => 'Display title',
    _ => '${field[0].toUpperCase()}${field.substring(1)}',
  };

  Future<bool> _confirm(String title, String detail) async {
    final revision = controller.revision;
    final workspace = widget.workspaceGeneration?.call();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(detail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
    return confirmed &&
        revision == controller.revision &&
        workspace == widget.workspaceGeneration?.call();
  }

  Future<void> _reopen() async {
    final source = await showDialog<String>(
      context: context,
      builder: (context) => const _ReopenSourceDialog(),
    );
    if (!mounted) return;
    if (source != null) {
      controller.loadSource(source);
      setState(() {
        sourceEpoch++;
        week = 0;
        day = 0;
        showReview = false;
      });
    }
  }

  Future<void> _export() async {
    final yaml = controller.verifiedExport();
    if (yaml == null) return;
    final revision = controller.revision;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export current synthetic YAML'),
        content: SizedBox(
          width: 800,
          child: SingleChildScrollView(
            child: SelectableText(
              yaml,
              key: const Key('export-text'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            key: const Key('copy-yaml'),
            onPressed: () async {
              final exact = controller.verifiedExport();
              if (controller.revision != revision || exact != yaml) {
                Navigator.pop(context);
                return;
              }
              await Clipboard.setData(ClipboardData(text: exact!));
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy YAML'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSlot() async {
    final usedKeys = {
      for (final w in controller.tree!['weeks'] as List)
        for (final d in w['days'] as List)
          for (final s in d['slots'] as List) s['slot_key'],
    };
    var n = 1;
    while (usedKeys.contains('W${week + 1}D${day + 1}S$n')) {
      n++;
    }
    var newKey = widget.authorFacing ? 'W${week + 1}D${day + 1}S$n' : '';
    final capturedRevision = controller.revision;
    final capturedWorkspace = widget.workspaceGeneration?.call();
    var session = widget.embedded
        ? (controller.tree!['sessions'] as List).first['session_key'] as String
        : 'SYN-SESSION-R1';
    final key = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            widget.authorFacing
                ? 'Add workout to this day'
                : 'Add required fixture slot',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.authorFacing)
                TextField(
                  key: const Key('new-slot-key'),
                  onChanged: (value) => newKey = value,
                  decoration: const InputDecoration(
                    labelText: 'Explicit unique slot key',
                  ),
                ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: session,
                decoration: InputDecoration(
                  labelText: widget.authorFacing
                      ? 'Session version'
                      : 'Fixture revision',
                ),
                items: [
                  if (widget.embedded)
                    for (final entry in controller.tree!['sessions'] as List)
                      DropdownMenuItem(
                        value: entry['session_key'] as String,
                        child: Text(
                          widget.sessionChoiceLabel?.call(
                                Map<String, dynamic>.from(entry),
                              ) ??
                              '${entry['title']} · revision ${entry['revision_number']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  if (!widget.embedded)
                    for (final rev in [1, 2])
                      DropdownMenuItem(
                        value: 'SYN-SESSION-R$rev',
                        child: Text('Synthetic revision $rev'),
                      ),
                ],
                onChanged: (value) => update(() => session = value!),
              ),
              const Text(
                'The existing required completion and progression template is reused exactly.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, newKey),
              child: Text(widget.authorFacing ? 'Add workout' : 'Add slot'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (key != null &&
        capturedRevision == controller.revision &&
        capturedWorkspace == widget.workspaceGeneration?.call()) {
      controller.addSlot(week, day, key, session);
      setState(() => sourceEpoch++);
    }
  }

  Future<void> _move(int index, Map<String, dynamic> tree) async {
    final revision = controller.revision;
    final workspace = widget.workspaceGeneration?.call();
    final targets = <(int, int)>[
      for (var w = 0; w < (tree['weeks'] as List).length; w++)
        for (var d = 0; d < (tree['weeks'][w]['days'] as List).length; d++)
          if (tree['weeks'][w]['days'][d]['day_type'] == 'training') (w, d),
    ];
    if (targets.isEmpty) return;
    final currentDestination = targets.indexOf((week, day));
    // A rest-day draft keeps its slots until the author explicitly moves them.
    var destination = currentDestination < 0 ? 0 : currentDestination;
    var position = 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final target = targets[destination];
          final count =
              (tree['weeks'][target.$1]['days'][target.$2]['slots'] as List)
                  .length -
              (target == (week, day) ? 1 : 0);
          return AlertDialog(
            title: Text(
              widget.authorFacing
                  ? 'Move workout'
                  : 'Move / reorder required slot',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: destination,
                  decoration: const InputDecoration(labelText: 'Training day'),
                  items: [
                    for (var i = 0; i < targets.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          'Week ${targets[i].$1 + 1} · Day ${targets[i].$2 + 1}',
                        ),
                      ),
                  ],
                  onChanged: (value) => update(() {
                    destination = value!;
                    position = 0;
                  }),
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('position-$destination'),
                  initialValue: position,
                  decoration: const InputDecoration(labelText: 'Position'),
                  items: [
                    for (var i = 0; i <= count; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          widget.authorFacing
                              ? 'Workout ${i + 1}'
                              : 'Slot ${i + 1}',
                        ),
                      ),
                  ],
                  onChanged: (value) => update(() => position = value!),
                ),
                Text(
                  widget.authorFacing
                      ? 'Only placement and order change. Review the programme afterward.'
                      : 'Slot key and progression remain unchanged. Validate the resulting authored references.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm move'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted) return;
    if (confirmed == true &&
        revision == controller.revision &&
        workspace == widget.workspaceGeneration?.call()) {
      final target = targets[destination];
      controller.moveSlot(week, day, index, target.$1, target.$2, position);
      setState(() => sourceEpoch++);
    }
  }
}

class _ReopenSourceDialog extends StatefulWidget {
  const _ReopenSourceDialog();
  @override
  State<_ReopenSourceDialog> createState() => _ReopenSourceDialogState();
}

class _ReopenSourceDialogState extends State<_ReopenSourceDialog> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reopen synthetic YAML'),
    content: SizedBox(
      width: 700,
      child: TextField(
        key: const Key('reopen-input'),
        controller: input,
        minLines: 8,
        maxLines: 16,
        decoration: const InputDecoration(
          labelText: 'Paste exported YAML for this synthetic fixture',
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
        child: const Text('Open source'),
      ),
    ],
  );
}
