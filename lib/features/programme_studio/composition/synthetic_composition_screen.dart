import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../authoring/programme_authoring_screen.dart';
import '../presentation/programme_studio_app.dart';
import '../protocol_authoring/protocol_authoring_screen.dart';
import 'synthetic_composition_controller.dart';
import 'synthetic_composition_handoff.dart';
import 'synthetic_composition_review_bridge.dart';

class SyntheticCompositionScreen extends StatefulWidget {
  const SyntheticCompositionScreen({super.key, this.controller});
  final SyntheticCompositionController? controller;
  @override
  State<SyntheticCompositionScreen> createState() =>
      _SyntheticCompositionScreenState();
}

class _SyntheticCompositionScreenState
    extends State<SyntheticCompositionScreen> {
  late final controller = widget.controller ?? SyntheticCompositionController();
  int tab = 0;
  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Synthetic programme composition')),
      body: Column(
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
                  const Text(
                    'Local synthetic sources · unpublished · transient',
                  ),
                  const Text(
                    'Freeze → admit → explicitly select. Programme YAML contains references, not session bodies.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        key: const Key('joint-validate'),
                        onPressed: !controller.initialized || controller.busy
                            ? null
                            : () async {
                                FocusManager.instance.primaryFocus?.unfocus();
                                await controller.validate();
                              },
                        child: const Text('Validate & refresh joint review'),
                      ),
                      OutlinedButton(
                        key: const Key('complete-export'),
                        onPressed: controller.current == null ? null : _export,
                        child: const Text('Export complete handoff'),
                      ),
                      OutlinedButton(
                        key: const Key('complete-reopen'),
                        onPressed: controller.busy ? null : _reopen,
                        child: const Text('Reopen read-only review'),
                      ),
                      TextButton(
                        key: const Key('workspace-reset'),
                        onPressed: () async {
                          if (await _confirm(
                            'Reset entire synthetic workspace?',
                            'Discard transient drafts, additions and selections; restore original R1 and programme seed.',
                          )) {
                            await controller.reset();
                            if (mounted) setState(() => tab = 0);
                          }
                        },
                        child: const Text('Reset to original seed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      controller.status,
                      key: const Key('joint-status'),
                    ),
                  ),
                  for (final error in controller.errors)
                    SelectableText(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < 4; i++)
                TextButton(
                  key: Key('composition-tab-$i'),
                  onPressed: () => setState(() => tab = i),
                  child: Text(
                    ['Session', 'Programme', 'Catalogue', 'Review'][i],
                    style: TextStyle(
                      fontWeight: tab == i
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: !controller.initialized
                ? const Center(child: Text('Opening exact R1…'))
                : IndexedStack(
                    index: tab,
                    children: [
                      ProtocolAuthoringScreen(
                        key: ValueKey(controller.session),
                        controller: controller.session,
                        embedded: true,
                      ),
                      ProgrammeAuthoringScreen(
                        key: ValueKey(controller.programme),
                        controller: controller.programme,
                        embedded: true,
                        onSelectSlot: _select,
                      ),
                      _catalogue(),
                      _reviews(),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _catalogue() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('Frozen session catalogue', style: TextStyle(fontSize: 20)),
      const Text(
        'Admission adds a reference/source, never selects a programme slot. Choose its exact revision in Programme afterwards.',
      ),
      for (final r in controller.session.revisions)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'R${r.identity.revisionNumber} · ${r.compiled.protocol.name}',
                ),
                SelectableText(
                  '${r.identity.protocolId}\n${r.identity.sessionLineageId}\nSource SHA-256: ${r.digest}',
                ),
                Text(
                  controller.admitted.any(
                        (s) =>
                            s.identity.revisionNumber ==
                            r.identity.revisionNumber,
                      )
                      ? 'Admitted — programme selection is separate'
                      : 'Frozen — not admitted',
                  key: Key('admission-status-${r.identity.revisionNumber}'),
                ),
                OutlinedButton(
                  key: Key('admit-${r.identity.revisionNumber}'),
                  onPressed: controller.busy || controller.session.isEditing
                      ? null
                      : () async {
                          final generation = controller.generation;
                          if (await _confirm(
                            'Admit frozen R${r.identity.revisionNumber}?',
                            '${r.identity.protocolId}\n${r.identity.sessionLineageId}\nExact source: ${r.digest}\nProgramme slots remain unchanged.',
                          )) {
                            if (generation == controller.generation) {
                              await controller.admit(r);
                            }
                          }
                        },
                  child: const Text('Admit frozen revision'),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      const Text('Current programme references'),
      for (final w in controller.programme.tree?['weeks'] as List? ?? [])
        for (final d in w['days'] as List)
          for (final slot in d['slots'] as List)
            Text(
              '${slot['slot_key']} → ${slot['session_key']}',
              key: Key('reference-${slot['slot_key']}'),
            ),
    ],
  );

  Future<void> _select(int week, int day, int slot, String key) async {
    final candidates = controller.admitted
        .where((s) => 'SYN-D2-STRENGTH-R${s.identity.revisionNumber}' == key)
        .toList();
    if (candidates.length != 1) {
      controller.reportFailure('selection: revision is not admitted.');
      return;
    }
    final next = candidates.single;
    final tree = controller.programme.tree!;
    final previous =
        (((tree['weeks'] as List)[week]['days'] as List)[day]['slots']
            as List)[slot]['session_key'];
    final generation = controller.generation;
    if (await _confirm(
      'Select exact revision for this required slot?',
      '$previous → $key\n${next.identity.protocolId}\n${next.identity.sessionLineageId}\nR${next.identity.revisionNumber}\nSource SHA-256: ${next.sourceDigest}\nOther slots and locked contracts stay unchanged.',
    )) {
      if (generation == controller.generation) {
        await controller.select(week, day, slot, next.identity.revisionNumber);
      }
    }
  }

  Widget _reviews() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (controller.current != null)
        ..._receipt(controller.current!, false)
      else
        const Text('No current live joint review. Refresh after changes.'),
      if (controller.reconstructed != null) ...[
        const Divider(),
        ..._receipt(controller.reconstructed!, true),
      ],
      ExpansionTile(
        title: const Text('Programme source and original-byte diff'),
        children: [
          SelectableText(controller.programme.draftSource),
          const Divider(),
          SelectableText(
            controller.programme.sourceDiff.isEmpty
                ? 'No textual change.'
                : controller.programme.sourceDiff.join('\n'),
          ),
        ],
      ),
    ],
  );
  List<Widget> _receipt(CompositionReviewReceipt r, bool reconstructed) => [
    Text(
      reconstructed
          ? 'Reconstructed review — read-only, separate sources'
          : 'Current live joint review',
      style: const TextStyle(fontSize: 20),
    ),
    if (reconstructed)
      const Text(
        'This view does not restore the live catalogue, drafts or revision history.',
      ),
    OutlinedButton(
      key: Key(reconstructed ? 'reconstructed-studio' : 'joint-studio'),
      onPressed: () => _studio(reconstructed),
      child: const Text('Open Studio review'),
    ),
    if (reconstructed)
      OutlinedButton(
        key: const Key('reconstructed-export'),
        onPressed: () => _showReconstructed(r),
        child: const Text('Re-export reconstructed handoff'),
      ),
    SelectableText(
      'Programme package hash — excludes session bodies\n${r.packageHash}',
    ),
    SelectableText('Exact programme YAML digest\n${r.programmeSourceDigest}'),
    for (final s in r.sessions)
      ExpansionTile(
        title: Text('R${s.identity.revisionNumber} · ${s.protocol.name}'),
        children: [
          SelectableText(
            '${s.identity.protocolId}\n${s.identity.sessionLineageId}\nSource SHA-256: ${s.sourceDigest}\nExercise versions: ${s.bindings}',
          ),
          SelectableText(s.source),
        ],
      ),
    const Text('Every reviewed slot is bound to exact source bytes:'),
    for (final binding in r.slotBindings)
      SelectableText(
        '${binding['slot_key']} → ${binding['session_key']} / R${binding['revision_number']}\n${binding['source_digest']}',
      ),
  ];
  void _studio(bool reconstructed) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final receipt = reconstructed
                ? controller.reconstructed
                : controller.current;
            return receipt == null
                ? Scaffold(
                    appBar: AppBar(title: const Text('Review invalidated')),
                    body: const Center(
                      child: Text(
                        'Sources changed. Close and refresh joint review.',
                      ),
                    ),
                  )
                : Scaffold(
                    appBar: AppBar(
                      title: Text(
                        reconstructed
                            ? 'Read-only reconstructed Studio'
                            : 'Current joint Studio',
                      ),
                    ),
                    body: ProgrammeStudioScreen(
                      key: ValueKey(controller.generation),
                      catalog: receipt.catalog,
                      showDeveloperFixtures: true,
                      previewStateLabel: reconstructed
                          ? 'Read-only reconstructed source review'
                          : 'Current exact-source joint review',
                    ),
                  );
          },
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(detail)),
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

  Future<void> _export() async {
    final bytes = await controller.exportHandoff(), r = controller.current;
    if (!mounted || bytes == null || r == null) return;
    await _exportDialog(bytes, r, false);
  }

  Future<void> _showReconstructed(CompositionReviewReceipt r) =>
      _exportDialog(const SyntheticCompositionHandoff().write(r), r, true);
  Future<void> _exportDialog(
    String bytes,
    CompositionReviewReceipt r,
    bool reconstructed,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final valid = reconstructed
              ? identical(r, controller.reconstructed)
              : controller.isCurrentReceipt(r);
          return AlertDialog(
            scrollable: true,
            title: Text(
              valid
                  ? 'Complete local handoff — canonical sources'
                  : 'Export invalidated',
            ),
            content: SizedBox(
              width: 850,
              height: MediaQuery.sizeOf(context).height * .45,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: 'Complete handoff'),
                        Tab(text: 'Programme YAML'),
                        Tab(text: 'Session sources'),
                      ],
                    ),
                    Expanded(
                      child: valid
                          ? TabBarView(
                              children: [
                                _source(bytes),
                                _source(
                                  'Programme YAML contains references, not session bodies.\n\n${r.programmeSource}',
                                ),
                                _source(
                                  r.sessions
                                      .map(
                                        (s) =>
                                            'R${s.identity.revisionNumber} · ${s.identity.protocolId}\n${s.source}',
                                      )
                                      .join('\n'),
                                ),
                              ],
                            )
                          : const Text(
                              'Sources changed. Previous successful export is unavailable.',
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              FilledButton(
                key: const Key('copy-handoff'),
                onPressed: !valid
                    ? null
                    : () async {
                        final fresh = reconstructed
                            ? controller.reconstructedExport()
                            : await controller.exportHandoff();
                        if (fresh == bytes) {
                          await Clipboard.setData(ClipboardData(text: fresh!));
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        }
                      },
                child: const Text('Copy complete validated handoff'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _source(String s) => SingleChildScrollView(
    child: SelectableText(
      s,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    ),
  );
  Future<void> _reopen() async {
    final source = await showDialog<String>(
      context: context,
      builder: (context) =>
          _HandoffInputDialog(initial: controller.rejectedHandoff),
    );
    if (!mounted || source == null) return;
    await controller.reopen(source);
    if (mounted) setState(() => tab = 3);
  }
}

class _HandoffInputDialog extends StatefulWidget {
  const _HandoffInputDialog({this.initial});
  final String? initial;
  @override
  State<_HandoffInputDialog> createState() => _HandoffInputDialogState();
}

class _HandoffInputDialogState extends State<_HandoffInputDialog> {
  late final text = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reconstruct a separate read-only review'),
    content: SizedBox(
      width: 760,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              'Paste the complete JSON handoff. Programme YAML alone does not include session sources. Live authoring is not overwritten.',
            ),
            TextField(
              key: const Key('handoff-input'),
              controller: text,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Complete local handoff',
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
        onPressed: () => Navigator.pop(context, text.text),
        child: const Text('Reconstruct review'),
      ),
    ],
  );
}
