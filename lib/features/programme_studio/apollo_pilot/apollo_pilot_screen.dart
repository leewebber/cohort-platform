import 'package:flutter/material.dart';

import '../local_files/studio_json_files.dart';
import '../projection/movement_prescription_review.dart';
import '../workspace_json.dart';
import 'apollo_pilot.dart';
import 'apollo_pilot_pin.dart';

void downloadApolloPilotFile(String text) {
  final kind = readWorkspaceJson(text)['kind'];
  if (kind != ApolloPilotSource.workspaceKind &&
      kind != ApolloPilotSource.sourceKind) {
    throw const FormatException('Unsupported Apollo pilot file.');
  }
  downloadEditableWorkspace(
    text,
    filename: kind == ApolloPilotSource.sourceKind
        ? 'cohort-apollo-local-source.json'
        : 'cohort-apollo-local-workspace.json',
  );
}

/// Separate internal entry. No production navigation or programme intake.
class ApolloPilotScreen extends StatefulWidget {
  const ApolloPilotScreen({
    super.key,
    required this.controller,
    this.saveFile = downloadApolloPilotFile,
    this.openFile = chooseEditableWorkspace,
  });
  final ApolloPilotController controller;
  final void Function(String) saveFile;
  final Future<String?> Function() openFile;
  @override
  State<ApolloPilotScreen> createState() => _ApolloPilotScreenState();
}

class _ApolloPilotScreenState extends State<ApolloPilotScreen> {
  late ApolloPilotController _controller = widget.controller;
  bool _ownsController = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _run(void Function() action) {
    try {
      action();
      if (mounted) setState(() => _message = null);
    } on FormatException catch (e) {
      setState(() => _message = e.message);
    } on UnsupportedError catch (e) {
      setState(() => _message = e.message);
    }
  }

  Future<void> _edit(String key, String field) async {
    final owner = _controller;
    final stamp = owner.stamp();
    final raw = readWorkspaceJson(
      _controller.source.movement(key).rawPrescription!,
    );
    final value = _controller.draft[key]?[field] ?? raw[field];
    final input = TextEditingController(text: '$value');
    String? error;
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Edit ${_label(field)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Keep the authored form. Other fields and contextual guidance remain read-only.',
              ),
              TextField(
                controller: input,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _label(field),
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  if (!identical(owner, _controller)) {
                    throw const FormatException(
                      'Workspace changed. Reopen this edit.',
                    );
                  }
                  owner.requireFresh(stamp);
                  owner.edit(key, field, input.text);
                  Navigator.pop(context);
                } on FormatException catch (e) {
                  update(() => error = e.message);
                }
              },
              child: const Text('Apply edit'),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    input.dispose();
  }

  Future<void> _use(ApolloPilotRevision revision) async {
    final controller = _controller;
    final prepared = controller.prepareUse(revision);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this version…'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(ApolloPilotSource.target),
                Text(
                  'Current: ${prepared.current.protocolId} · Proposed: ${prepared.proposed.protocolId}',
                ),
                const Text(
                  'Only this local pilot occurrence changes. The original programme and all shared occurrences retain their selections.',
                ),
                const Text(
                  'Session and block guidance remains read-only; review it alongside changed doses.',
                ),
                if (prepared.changes.isEmpty)
                  const Text('No prescription change.'),
                for (final change in prepared.changes)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          change.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('Current: ${change.before.join(' · ')}'),
                        Text('Proposed: ${change.after.join(' · ')}'),
                      ],
                    ),
                  ),
                ExpansionTile(
                  title: const Text('Exact comparison identities'),
                  children: [
                    SelectableText(
                      'Source ${controller.source.digest}\n${prepared.current.digest}\n${prepared.proposed.digest}',
                    ),
                    for (final change in prepared.changes)
                      SelectableText(change.key),
                  ],
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm local selection'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    _run(() {
      if (!identical(controller, _controller)) {
        throw const FormatException('Workspace changed. Review again.');
      }
      controller.confirmUse(prepared);
    });
  }

  Future<void> _open() async {
    final previous = _controller;
    final stamp = previous.stamp();
    ApolloPilotController? candidate;
    try {
      final text = await widget.openFile();
      if (!mounted || text == null) return;
      candidate = ApolloPilotController.reopen(text);
      final summary =
          'Validated ${candidate.revisions.length} local revisions. Selected: ${candidate.selected.protocolId}. Unsaved local edits will be replaced.';
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace local pilot workspace?'),
          content: Text(summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace local workspace'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
      if (!identical(previous, _controller)) {
        throw const FormatException(
          'Workspace changed while opening. Try again.',
        );
      }
      previous.requireFresh(stamp);
      _controller.removeListener(_refresh);
      if (_ownsController) _controller.dispose();
      _controller = candidate;
      candidate = null;
      _ownsController = true;
      _controller.addListener(_refresh);
      setState(() => _message = null);
    } on FormatException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } on UnsupportedError catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      candidate?.dispose();
    }
  }

  Future<void> _checkSource() async {
    final controller = _controller;
    final stamp = controller.stamp();
    try {
      final text = await widget.openFile();
      if (!mounted || text == null) return;
      final (_, revision) = ApolloPilotSource.recompileCanonical(text);
      if (!identical(controller, _controller)) {
        throw const FormatException('Workspace changed. Try again.');
      }
      controller.requireFresh(stamp);
      setState(
        () => _message =
            'Source recompiled: ${revision.protocolId} · ${revision.digest}. No workspace or selection changed.',
      );
    } on FormatException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } on UnsupportedError catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _controller.source;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programme Studio · Apollo local pilot'),
      ),
      bottomNavigationBar: _message == null
          ? null
          : Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!, key: const ValueKey('pilot-error')),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Internal working copy · no publication or athlete assignment',
          ),
          Text(
            source.session.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(ApolloPilotSource.target),
          Text('Original: ${ApolloPilotSource.originalProtocol} · revision 1'),
          Text('Locally selected: ${_controller.selected.protocolId}'),
          if (source.protocol.purpose != null)
            Text('Purpose: ${source.protocol.purpose}'),
          if (source.protocol.primarySessionIntent != null)
            Text('Intent: ${source.protocol.primarySessionIntent}'),
          if (source.protocol.coachingNotes != null)
            Text('Session notes: ${source.protocol.coachingNotes}'),
          const Text(
            'Review and edit a separate draft below. Saving a revision does not select it. Existing load is unspecified; authored effort uses RIR. Session/block guidance stays read-only.',
          ),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: () => _run(() {
                  _controller.freeze();
                }),
                child: const Text('Save new local revision'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _run(() => widget.saveFile(_controller.saveWorkspace())),
                child: const Text('Save editable pilot'),
              ),
              OutlinedButton(
                onPressed: _open,
                child: const Text('Open editable pilot'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Immutable local revisions'),
          for (final revision in _controller.revisions)
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(revision.protocolId),
                TextButton(
                  onPressed: () => _run(() => _controller.startFrom(revision)),
                  child: Text('Edit from R${revision.number}'),
                ),
                TextButton(
                  onPressed: () => _use(revision),
                  child: Text('Use R${revision.number}…'),
                ),
                TextButton(
                  onPressed: () => _run(
                    () => widget.saveFile(source.exportCanonical(revision)),
                  ),
                  child: Text('Export R${revision.number} source'),
                ),
              ],
            ),
          TextButton(
            onPressed: _checkSource,
            child: const Text('Recompile pilot source'),
          ),
          const Text(
            'Source exports use the separate Apollo pilot source-envelope format. Recompile with ApolloPilotSource.recompileCanonical; they are not Founder YAML or publication inputs.',
          ),
          const Text('Retained author-approved default guidance (read-only)'),
          Text(source.retainedDefaultGuidance),
          for (final block in source.session.blocks) ...[
            const Divider(height: 32),
            Text(
              '${block.position}. ${block.title}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Type: ${block.blockType} · ${block.workoutFormat}'),
            if (block.trainingIntent != null)
              Text('Intent: ${block.trainingIntent}'),
            if (block.content?.isNotEmpty == true) Text(block.content!),
            if (block.coachNotes != null)
              Text('Block notes: ${block.coachNotes}'),
            for (final m in block.movements)
              Builder(
                builder: (context) {
                  final key = ApolloPilotSource.movementKey(block, m);
                  final reviewed = source.reviewedMovement(
                    key,
                    _controller.draft,
                  );
                  final review = MovementPrescriptionReview.fromMovement(
                    reviewed,
                  );
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m.position}. ${m.name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final line in review.lines) Text(line),
                          if (source.editableFields(key).isEmpty)
                            const Text('Read-only preparation'),
                          Wrap(
                            children: [
                              for (final field in source.editableFields(key))
                                TextButton(
                                  key: ValueKey('$key/$field'),
                                  onPressed: () => _edit(key, field),
                                  child: Text('Edit ${_label(field)}'),
                                ),
                            ],
                          ),
                          ExpansionTile(
                            title: const Text(
                              'Retained source and local identity',
                            ),
                            children: [
                              SelectableText(
                                'Exercise ${m.exerciseId}\n$key\nLocal snapshot at ${ApolloPilotPin.snapshotGitRevision}\nRow SHA-256 ${ApolloPilotPin.rows[m.exerciseId]!.$2}\n${source.profileRows[m.exerciseId]}\nOriginal prescription: ${m.rawPrescription}\nDraft prescription: ${reviewed.rawPrescription}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
          ExpansionTile(
            title: const Text('Advanced source provenance'),
            children: [
              SelectableText(
                'Original lineage ${ApolloPilotSource.originalLineage}\nLocal lineage ${ApolloPilotSource.localLineage}\nSource envelope SHA-256 ${source.digest}\nLocal row snapshots are not canonical ExerciseDefinition versions. No title matching or new global identity mappings.',
              ),
              for (final pin in ApolloPilotPin.files.entries)
                SelectableText('${pin.key}\n${pin.value}'),
            ],
          ),
        ],
      ),
    );
  }

  static String _label(String field) => switch (field) {
    'rest_seconds' => 'rest range (seconds)',
    'rir' => 'RIR',
    _ => field,
  };
}
