import 'production_session_draft.dart';
import 'production_session_ui_cursor.dart';

/// Identity + UI cursor companion to [ActivePerformanceDraft] actuals.
class ProductionRestoreEnvelope {
  const ProductionRestoreEnvelope({
    required this.identity,
    this.cursor,
  });

  final ProductionSessionDraft identity;
  final ProductionSessionUiCursor? cursor;

  Map<String, dynamic> toJson() {
    return {
      'identity': identity.toJson(),
      if (cursor != null) 'cursor': cursor!.toJson(),
    };
  }

  factory ProductionRestoreEnvelope.fromJson(Map<String, dynamic> json) {
    final identityRaw = json['identity'];
    if (identityRaw is! Map) {
      throw const FormatException('restore envelope missing identity');
    }
    final cursorRaw = json['cursor'];
    return ProductionRestoreEnvelope(
      identity: ProductionSessionDraft.fromJson(
        Map<String, dynamic>.from(identityRaw),
      ),
      cursor: cursorRaw is Map
          ? ProductionSessionUiCursor.fromJson(
              Map<String, dynamic>.from(cursorRaw),
            )
          : null,
    );
  }
}
