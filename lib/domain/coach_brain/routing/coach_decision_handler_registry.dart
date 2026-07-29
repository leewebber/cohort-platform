import '../handlers/coach_decision_handler.dart';
import '../vocabulary/coach_decision_type.dart';

enum CoachDecisionHandlerRegistryIssueCode {
  duplicateDecisionType,
  handlerDecisionTypeMismatch,
  missingHandlerForDecisionType,
}

class CoachDecisionHandlerRegistryIssue {
  const CoachDecisionHandlerRegistryIssue({
    required this.code,
    this.decisionType,
    this.detail,
  });

  final CoachDecisionHandlerRegistryIssueCode code;
  final CoachDecisionType? decisionType;
  final String? detail;
}

/// Dependency-injection boundary: maps decision types to handlers.
class CoachDecisionHandlerRegistry {
  CoachDecisionHandlerRegistry({
    required Iterable<CoachDecisionHandler> handlers,
    this.requireAllDecisionTypes = true,
  }) : _handlers = _buildMapFromHandlers(handlers, requireAllDecisionTypes);

  /// Explicit map for composition roots that bind by [CoachDecisionType] key.
  CoachDecisionHandlerRegistry.fromHandlerMap(
    Map<CoachDecisionType, CoachDecisionHandler> handlerByType, {
    this.requireAllDecisionTypes = true,
  }) : _handlers = _buildMapFromEntries(
         handlerByType.entries,
         requireAllDecisionTypes,
       );

  final Map<CoachDecisionType, CoachDecisionHandler> _handlers;
  final bool requireAllDecisionTypes;

  CoachDecisionHandler? handlerFor(CoachDecisionType type) => _handlers[type];

  Iterable<CoachDecisionType> get registeredDecisionTypes => _handlers.keys;

  List<CoachDecisionHandlerRegistryIssue> validate() {
    final issues = <CoachDecisionHandlerRegistryIssue>[];

    for (final type in CoachDecisionType.values) {
      if (!_handlers.containsKey(type)) {
        issues.add(
          CoachDecisionHandlerRegistryIssue(
            code: CoachDecisionHandlerRegistryIssueCode
                .missingHandlerForDecisionType,
            decisionType: type,
          ),
        );
      }
    }

    for (final entry in _handlers.entries) {
      if (entry.value.decisionType != entry.key) {
        issues.add(
          CoachDecisionHandlerRegistryIssue(
            code: CoachDecisionHandlerRegistryIssueCode
                .handlerDecisionTypeMismatch,
            decisionType: entry.key,
            detail: entry.value.handlerName,
          ),
        );
      }
    }

    return List.unmodifiable(issues);
  }

  static Map<CoachDecisionType, CoachDecisionHandler> _buildMapFromHandlers(
    Iterable<CoachDecisionHandler> handlers,
    bool requireAllDecisionTypes,
  ) {
    return _buildMapFromEntries(
      handlers.map((h) => MapEntry(h.decisionType, h)),
      requireAllDecisionTypes,
    );
  }

  static Map<CoachDecisionType, CoachDecisionHandler> _buildMapFromEntries(
    Iterable<MapEntry<CoachDecisionType, CoachDecisionHandler>> entries,
    bool requireAllDecisionTypes,
  ) {
    final map = <CoachDecisionType, CoachDecisionHandler>{};
    for (final entry in entries) {
      final type = entry.key;
      final handler = entry.value;
      if (map.containsKey(type)) {
        throw ArgumentError(
          'Duplicate handler for $type: '
          '${map[type]!.handlerName} vs ${handler.handlerName}',
        );
      }
      map[type] = handler;
    }
    if (requireAllDecisionTypes) {
      for (final type in CoachDecisionType.values) {
        if (!map.containsKey(type)) {
          throw ArgumentError('Missing handler for CoachDecisionType.$type');
        }
      }
    }
    return Map.unmodifiable(map);
  }
}
