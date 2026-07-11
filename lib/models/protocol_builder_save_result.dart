/// Outcome of persisting a [ProtocolDraft] via [ProtocolBuilderService].
class ProtocolBuilderSaveResult {
  const ProtocolBuilderSaveResult({
    required this.protocolId,
    required this.created,
    required this.stepCount,
    required this.message,
    required this.published,
  });

  final String protocolId;
  final bool created;
  final int stepCount;
  final String message;
  final bool published;

  factory ProtocolBuilderSaveResult.draft({
    required String protocolId,
    required bool created,
    required int stepCount,
  }) {
    final verb = created ? 'Saved new draft' : 'Updated draft';

    return ProtocolBuilderSaveResult(
      protocolId: protocolId,
      created: created,
      stepCount: stepCount,
      published: false,
      message: '$verb $protocolId with $stepCount steps.',
    );
  }

  factory ProtocolBuilderSaveResult.published({
    required String protocolId,
    required bool created,
    required int stepCount,
  }) {
    return ProtocolBuilderSaveResult(
      protocolId: protocolId,
      created: created,
      stepCount: stepCount,
      published: true,
      message: 'Published protocol $protocolId with $stepCount steps.',
    );
  }
}
