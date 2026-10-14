import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/strength_prescription_formatter.dart';
import '../presentation/programme_studio_app.dart';
import 'founder_strength_source_guard.dart';
import 'protocol_authoring_controller.dart';
import 'synthetic_strength_lineage.dart';
import '../../session_revision/models/session_revision_usage_models.dart';

class ProtocolAuthoringScreen extends StatefulWidget {
  const ProtocolAuthoringScreen({
    super.key,
    this.controller,
    this.embedded = false,
  });
  final bool embedded;
  final ProtocolAuthoringController? controller;
  @override
  State<ProtocolAuthoringScreen> createState() =>
      _ProtocolAuthoringScreenState();
}

class _ProtocolAuthoringScreenState extends State<ProtocolAuthoringScreen> {
  late final controller = widget.controller ?? ProtocolAuthoringController();
  int _epoch = 0;
  SessionRevisionIdentity? _pick;
  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  void _refresh(void Function() action) {
    if (!mounted) return;
    action();
    setState(() {
      _epoch++;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Synthetic strength authoring')),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: controller.initialized
                  ? _editor()
                  : Text(
                      controller.errors.isEmpty
                          ? 'Opening retained R1 source…'
                          : controller.errors.join('\n'),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _editor() {
    final current = controller.current;
    final tree = controller.tree;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${controller.lineage.label} · local synthetic · unpublished · transient',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'One straight-sets block. Fixture values are mechanical tests, not programme content. Reloading this preview discards local additions.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!widget.embedded)
              Text(
                'Selected programme: R${controller.selectedRevision}',
                key: const Key('selected-programme'),
              ),
            Text(
              controller.isEditing
                  ? 'Working candidate: R${controller.activeIdentity.revisionNumber}'
                  : 'Opened frozen source: R${controller.openedRevision}',
            ),
            if (!controller.isEditing)
              SizedBox(
                width: 180,
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: revisionKey(controller.activeIdentity),
                  items: [
                    for (final r in controller.revisions)
                      DropdownMenuItem(
                        value: revisionKey(r.identity),
                        child: Text(
                          'Open frozen R${r.identity.revisionNumber}',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _refresh(
                        () => controller.openIdentity(
                          controller.revisions
                              .singleWhere(
                                (r) => revisionKey(r.identity) == value,
                              )
                              .identity,
                        ),
                      );
                    }
                  },
                ),
              ),
            if (!controller.isEditing)
              FilledButton(
                onPressed: () => _refresh(controller.createDraft),
                child: const Text('Create local draft revision'),
              ),
            if (controller.isEditing)
              OutlinedButton(
                onPressed: () => _refresh(controller.resetDraft),
                child: Text(
                  controller.isCreatingRoot
                      ? 'Clear new source fields'
                      : 'Reset to source revision',
                ),
              ),
            if (controller.isEditing)
              OutlinedButton(
                onPressed: () => _refresh(controller.cancelDraft),
                child: const Text('Cancel draft'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          controller.status,
          key: const Key('validation-status'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final error in controller.errors)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (controller.isEditing &&
            current != null &&
            !controller.semanticChange)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No semantic change. Edit or cancel; formatting alone cannot freeze a new revision.',
            ),
          ),
        const SizedBox(height: 16),
        if (controller.isEditing && tree != null) ..._form(tree),
        if (!controller.isEditing)
          const Text(
            'Frozen source is read-only. Create a separate draft to edit; freezing never changes the programme selection.',
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: controller.busy
                  ? null
                  : () async {
                      await controller.validate();
                      if (mounted) setState(() {});
                    },
              child: const Text('Validate and refresh review'),
            ),
            if (!widget.embedded)
              OutlinedButton(
                onPressed: current == null ? null : _review,
                child: const Text('Open Studio review'),
              ),
            OutlinedButton(
              onPressed: current == null ? null : () => _export(false),
              child: const Text('Export Founder YAML'),
            ),
            if (!widget.embedded)
              OutlinedButton(
                onPressed: current == null ? null : () => _export(true),
                child: const Text('Export review package YAML'),
              ),
            if (controller.isEditing)
              OutlinedButton(
                onPressed: _reopen,
                child: const Text('Reopen Founder YAML'),
              ),
            if (controller.isEditing)
              FilledButton(
                onPressed:
                    current != null &&
                        controller.semanticChange &&
                        !controller.busy
                    ? _freeze
                    : null,
                child: const Text('Freeze local revision'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (!controller.isEditing && !widget.embedded)
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Programme revision selection:'),
              SizedBox(
                width: 170,
                child: DropdownButton<String>(
                  key: const Key('programme-revision-picker'),
                  isExpanded: true,
                  value: revisionKey(_pick ?? controller.activeIdentity),
                  items: [
                    for (final r in controller.revisions)
                      DropdownMenuItem(
                        value: revisionKey(r.identity),
                        child: Text('Frozen R${r.identity.revisionNumber}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _pick = controller.revisions
                            .singleWhere(
                              (r) => revisionKey(r.identity) == value,
                            )
                            .identity;
                      });
                    }
                  },
                ),
              ),
              FilledButton(
                onPressed: _select,
                child: const Text('Select for programme'),
              ),
              OutlinedButton(
                onPressed: () async {
                  controller.openRevision(controller.selectedRevision);
                  await controller.validate();
                  if (mounted) {
                    setState(() {
                      _epoch++;
                    });
                  }
                },
                child: const Text('Review selected programme'),
              ),
            ],
          ),
        if (current != null) ...[
          const SizedBox(height: 18),
          if (!widget.embedded)
            Text(
              current.session.identity.revisionNumber ==
                          controller.selectedRevision &&
                      !controller.isEditing
                  ? 'Current review uses the selected programme reference.'
                  : 'Candidate review uses a proposed reference. Selected programme remains R${controller.selectedRevision}.',
            ),
          for (final link
              in current.session.protocol.blocks.single.linkedExercises)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  '${link.displayLabelOverride ?? link.exerciseId} (${link.exerciseId})',
                  StrengthPrescriptionFormatter.formatSetsReps(
                    link.prescription!,
                  ),
                  StrengthPrescriptionFormatter.formatLoad(
                        link.prescription!.load,
                      ) ??
                      'Load unspecified',
                  StrengthPrescriptionFormatter.formatRest(
                        link.prescription!.restSeconds,
                      ) ??
                      'Rest unspecified',
                  ?StrengthPrescriptionFormatter.formatTempo(
                    link.prescription!.tempo,
                  ),
                  ?link.prescription!.coachCue,
                ].join(' · '),
              ),
            ),
          ExpansionTile(
            title: const Text('Source binding and package identity'),
            children: [
              _evidence(
                'Exact revision tuple',
                '${current.session.identity.protocolId} / ${current.session.identity.sessionLineageId} / R${current.session.identity.revisionNumber}',
              ),
              _evidence(
                'Founder source-byte SHA-256',
                current.session.sourceDigest,
              ),
              if (!widget.embedded)
                _evidence(
                  'Review package hash — excludes session bodies',
                  current.packageHash,
                ),
              if (!widget.embedded)
                _evidence(
                  'Selected programme baseline hash — references only',
                  controller.selectedProgrammeHash,
                ),
              _evidence(
                'Exact exercise versions',
                current.session.bindings.toString(),
              ),
              const Text(
                'The source receipt binds the body locally. The package hash retains its existing meaning and does not prove session-body identity.',
              ),
            ],
          ),
        ],
        ExpansionTile(
          title: const Text('Exact source and textual diff'),
          children: [
            const Text(
              'Diff baseline: exact retained source revision bytes, including comments. Writer normalization is explicit; formatting preservation is not promised.',
            ),
            _evidence('Current source', controller.source),
            _evidence(
              'Source diff',
              controller.sourceDiff.isEmpty
                  ? 'No textual change.'
                  : controller.sourceDiff.join('\n'),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('Immutable local catalogue'),
          children: [
            for (final r in controller.revisions)
              _evidence(
                'Frozen R${r.identity.revisionNumber} · draft/unpublished',
                '${r.identity.protocolId}\nExact source receipt: ${r.digest}',
              ),
            const Text(
              'Founder YAML does not encode this tuple. Reopen only in the identified local draft. This preview has no cross-restart revision archive or publication path.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _evidence(String label, String value) => Padding(
    padding: const EdgeInsets.all(10),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          SelectableText(value),
        ],
      ),
    ),
  );
  List<Widget> _form(Map<String, dynamic> tree) {
    final session = FounderStrengthSourceGuard.session(tree);
    final block = FounderStrengthSourceGuard.block(tree);
    final rows = FounderStrengthSourceGuard.exerciseRows(tree);
    return [
      Text('Session and block', style: Theme.of(context).textTheme.titleLarge),
      _field(
        'session-title',
        'Session title',
        session['title'],
        (v) => controller.editSession('title', v),
      ),
      _field(
        'session-notes',
        'Session notes (optional)',
        session['coach_notes'],
        (v) => controller.editSession('coach_notes', v),
        multiline: true,
      ),
      _field(
        'session-duration',
        'Estimated minutes (optional)',
        session['estimated_duration_minutes'],
        (v) => controller.editSession('estimated_duration_minutes', v),
      ),
      _field(
        'block-title',
        'Block title',
        block['title'],
        (v) => controller.editBlock('title', v),
      ),
      _field(
        'block-notes',
        'Block notes (optional)',
        block['coach_notes'],
        (v) => controller.editBlock('coach_notes', v),
        multiline: true,
      ),
      for (var i = 0; i < rows.length; i++) _exercise(i, rows[i], rows.length),
      if (rows.length < 2)
        OutlinedButton(
          onPressed: () => _refresh(controller.addExercise),
          child: const Text('Add exercise — empty dosage'),
        ),
    ];
  }

  Widget _field(
    String id,
    String label,
    Object? value,
    ValueChanged<String> edit, {
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      key: ValueKey('${revisionKey(controller.activeIdentity)}-$_epoch-$id'),
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      onChanged: edit,
    ),
  );
  Widget _exercise(int i, Map<String, dynamic> row, int count) {
    final dose = row['prescription'] as Map;
    final mode = (dose['load'] as Map?)?['unit']?.toString() ?? 'unspecified';
    final id = row['transitional_exercise_id'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercise ${i + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            DropdownButton<String>(
              key: ValueKey(
                '${revisionKey(controller.activeIdentity)}-exercise-$i-picker',
              ),
              isExpanded: true,
              value:
                  {
                    'cohort.exercise.d2_fixture_a',
                    'cohort.exercise.d2_fixture_b',
                  }.contains(id)
                  ? id
                  : null,
              hint: const Text('Choose an exact fixture identity'),
              items: const [
                DropdownMenuItem(
                  value: 'cohort.exercise.d2_fixture_a',
                  child: Text('EX-9001 · Synthetic fixture A'),
                ),
                DropdownMenuItem(
                  value: 'cohort.exercise.d2_fixture_b',
                  child: Text('EX-9002 · Synthetic fixture B'),
                ),
              ],
              onChanged: (value) async {
                if (value != null &&
                    value != id &&
                    await _confirm(
                      'Replace exercise identity?',
                      'Keep authored dosage and clear the display label. Names do not resolve identity.',
                    )) {
                  _refresh(() => controller.replaceExercise(i, value));
                }
              },
            ),
            _field(
              'exercise-$i-label',
              'Display label (optional; not identity)',
              row['exercise_name'],
              (v) => controller.editExercise(i, 'exercise_name', v),
            ),
            _field(
              'exercise-$i-sets',
              'Sets',
              dose['sets'],
              (v) => controller.editExercise(i, 'sets', v),
            ),
            _field(
              'exercise-$i-reps',
              'Exact reps',
              dose['reps'],
              (v) => controller.editExercise(i, 'reps', v),
            ),
            _field(
              'exercise-$i-rest',
              'Rest seconds (optional)',
              dose['rest_seconds'],
              (v) => controller.editExercise(i, 'rest_seconds', v),
            ),
            _field(
              'exercise-$i-tempo',
              'Tempo (optional)',
              dose['tempo'],
              (v) => controller.editExercise(i, 'tempo', v),
            ),
            _field(
              'exercise-$i-cue',
              'Cue (optional)',
              dose['notes'],
              (v) => controller.editExercise(i, 'notes', v),
              multiline: true,
            ),
            const Text('Load'),
            DropdownButton<String>(
              key: ValueKey(
                '${revisionKey(controller.activeIdentity)}-exercise-$i-load-mode',
              ),
              isExpanded: true,
              value: mode,
              items: const [
                DropdownMenuItem(
                  value: 'unspecified',
                  child: Text('Unspecified'),
                ),
                DropdownMenuItem(
                  value: 'bodyweight',
                  child: Text('Bodyweight'),
                ),
                DropdownMenuItem(value: 'kg', child: Text('Fixed kilograms')),
                DropdownMenuItem(
                  value: 'rpe',
                  child: Text('RPE (1–10; D2 only)'),
                ),
              ],
              onChanged: (value) async {
                if (value != null &&
                    value != mode &&
                    await _confirm(
                      'Change load mode?',
                      'Clear incompatible authored load input explicitly; the source diff records the change.',
                    )) {
                  _refresh(() => controller.setLoadMode(i, value));
                }
              },
            ),
            if (mode == 'kg' || mode == 'rpe')
              _field(
                'exercise-$i-load',
                mode == 'kg' ? 'Kilograms' : 'RPE (1–10)',
                (dose['load'] as Map)['value'],
                (v) => controller.editLoadValue(i, v),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (i > 0)
                  OutlinedButton(
                    onPressed: () =>
                        _refresh(() => controller.moveExercise(i, i - 1)),
                    child: const Text('Move up'),
                  ),
                if (i < count - 1)
                  OutlinedButton(
                    onPressed: () =>
                        _refresh(() => controller.moveExercise(i, i + 1)),
                    child: const Text('Move down'),
                  ),
                OutlinedButton(
                  onPressed: () async {
                    if (await _confirm(
                      'Remove exercise?',
                      'Remove this authored row. An empty block must be corrected before validation.',
                    )) {
                      _refresh(() => controller.removeExercise(i));
                    }
                  },
                  child: const Text('Remove exercise'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String detail) async =>
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
  Future<void> _freeze() async {
    if (await controller.freeze() && mounted) {
      setState(() {
        _epoch++;
        _pick = controller.activeIdentity;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.embedded
                ? '${controller.lineage.label} R${controller.openedRevision} frozen; admission and selection remain separate.'
                : 'R${controller.openedRevision} frozen. Programme remains R${controller.selectedRevision}.',
          ),
        ),
      );
    }
  }

  Future<void> _select() async {
    if (await _confirm(
      'Select exact revision for the synthetic programme?',
      '${revisionKey(_pick ?? controller.activeIdentity)}\nChange the exact reference explicitly. Earlier frozen revisions remain unchanged.',
    )) {
      await controller.selectProgrammeIdentity(
        _pick ?? controller.activeIdentity,
      );
      if (mounted) {
        setState(() {
          _epoch++;
        });
      }
    }
  }

  Future<void> _reopen() async {
    final input = TextEditingController(text: controller.source);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen in this identified draft'),
        content: SizedBox(
          width: 720,
          height: 380,
          child: TextField(
            controller: input,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Reopen source'),
          ),
        ],
      ),
    );
    input.dispose();
    if (text != null && mounted) _refresh(() => controller.reopen(text));
  }

  Future<void> _export(bool package) async {
    final bytes = package
        ? await controller.exportPackage()
        : await controller.exportFounder();
    if (bytes == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final receipt = controller.current;
          final isCurrent =
              receipt != null &&
              (package ? receipt.packageSource : receipt.session.source) ==
                  bytes;
          return AlertDialog(
            title: Text(
              !isCurrent
                  ? 'Export invalidated'
                  : package
                  ? 'Review package YAML — references only'
                  : 'Founder YAML — exact validated bytes',
            ),
            content: SizedBox(
              width: 720,
              height: 380,
              child: SingleChildScrollView(
                child: SelectableText(
                  isCurrent
                      ? bytes
                      : 'Source changed. Close and validate again; previous export is unavailable.',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: !isCurrent
                    ? null
                    : () async {
                        final fresh = package
                            ? await controller.exportPackage()
                            : await controller.exportFounder();
                        if (fresh == bytes) {
                          await Clipboard.setData(ClipboardData(text: fresh!));
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        }
                      },
                child: const Text('Copy validated bytes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _review() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final current = controller.current;
            return current == null
                ? Scaffold(
                    appBar: AppBar(title: const Text('Review invalidated')),
                    body: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Source changed. Return to authoring and validate again.',
                      ),
                    ),
                  )
                : Scaffold(
                    appBar: AppBar(title: const Text('D2 Studio review')),
                    body: ProgrammeStudioScreen(
                      key: ValueKey(controller.generation),
                      catalog: current.catalog,
                      showDeveloperFixtures: true,
                      previewStateLabel:
                          'D2 synthetic · exact R${current.session.identity.revisionNumber} · unpublished',
                    ),
                  );
          },
        ),
      ),
    );
  }
}
