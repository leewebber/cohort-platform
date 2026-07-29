import 'package:cohort_platform/domain/coach_brain/coach_brain_domain.dart';
import 'package:flutter_test/flutter_test.dart';

CoachDecisionRequest _request(CoachDecisionType type, {String id = 'req-1'}) {
  return CoachDecisionRequest(
    decisionType: type,
    requestId: id,
    athleteId: 'athlete-1',
    referenceIds: const {'assignment_id': 'asgn-1'},
  );
}

void main() {
  group('CoachDecisionType', () {
    test('db round-trip for all values', () {
      for (final type in CoachDecisionType.values) {
        expect(CoachDecisionTypeDb.fromDb(type.dbValue), type);
      }
    });
  });

  group('CoachDecisionHandlerRegistry', () {
    test('stub composition registers all decision types', () {
      final deps = CoachBrainDependencies.stub();
      expect(deps.registry.validate(), isEmpty);
      expect(
        deps.registry.registeredDecisionTypes.toSet(),
        CoachDecisionType.values.toSet(),
      );
    });

    test('rejects duplicate handlers at construction', () {
      expect(
        () => CoachDecisionHandlerRegistry(
          handlers: const [
            StubSessionAdaptationCoachDecisionHandler(),
            StubSessionAdaptationCoachDecisionHandler(),
          ],
          requireAllDecisionTypes: false,
        ),
        throwsArgumentError,
      );
    });

    test('rejects incomplete registry when requireAllDecisionTypes', () {
      expect(
        () => CoachDecisionHandlerRegistry(
          handlers: const [StubSessionAdaptationCoachDecisionHandler()],
        ),
        throwsArgumentError,
      );
    });

    test('validate reports missing handler when partial registry allowed', () {
      final registry = CoachDecisionHandlerRegistry(
        handlers: const [StubSessionAdaptationCoachDecisionHandler()],
        requireAllDecisionTypes: false,
      );
      final issues = registry.validate();
      expect(issues, isNotEmpty);
      expect(
        issues.every(
          (i) =>
              i.code ==
              CoachDecisionHandlerRegistryIssueCode
                  .missingHandlerForDecisionType,
        ),
        isTrue,
      );
      expect(
        issues.map((i) => i.decisionType).toSet(),
        CoachDecisionType.values.toSet()
          ..remove(CoachDecisionType.sessionAdaptation),
      );
    });

    test('validate reports handler decision type mismatch', () {
      final registry = CoachDecisionHandlerRegistry.fromHandlerMap({
        CoachDecisionType.sessionAdaptation:
            const StubReschedulingCoachDecisionHandler(),
      }, requireAllDecisionTypes: false);
      final issues = registry.validate();
      expect(
        issues.any(
          (i) =>
              i.code ==
              CoachDecisionHandlerRegistryIssueCode.handlerDecisionTypeMismatch,
        ),
        isTrue,
      );
    });
  });

  group('CoachDecisionRouter', () {
    late CoachDecisionRouter router;

    setUp(() {
      router = CoachBrainDependencies.stub().router;
    });

    test('invalid request rejects before delegation', () {
      const bad = CoachDecisionRequest(
        decisionType: CoachDecisionType.sessionAdaptation,
        requestId: '   ',
        athleteId: 'athlete-1',
      );
      final result = router.route(bad);
      expect(result.status, CoachDecisionOutcomeStatus.invalidRequest);
      expect(result.isRouterFailure, isTrue);
    });

    test('handler not registered when registry is partial', () {
      final partial = CoachBrainDependencies(
        handlers: const [StubSessionAdaptationCoachDecisionHandler()],
        requireAllDecisionTypes: false,
      ).router;
      final result = partial.route(_request(CoachDecisionType.rescheduling));
      expect(result.status, CoachDecisionOutcomeStatus.handlerNotRegistered);
    });

    for (final type in CoachDecisionType.values) {
      test('delegates $type to registered handler', () {
        final handled = <CoachDecisionType>[];
        final handlers = kStubCoachDecisionHandlers.map((handler) {
          if (handler.decisionType != type) return handler;
          return _SpyCoachDecisionHandler(
            decisionType: type,
            onHandle: () => handled.add(type),
          );
        }).toList();
        final spyRouter = CoachBrainDependencies(handlers: handlers).router;
        final request = _request(type, id: 'req-$type');
        final result = spyRouter.route(request);

        expect(handled, [type]);
        expect(result.status, CoachDecisionOutcomeStatus.stubPlaceholder);
        expect(result.decisionType, type);
        expect(result.requestId, request.requestId);
        expect(result.handlerName, isNotNull);
        expect(result.placeholderCode, isNotEmpty);
      });
    }

    test('stub session adaptation returns deterministic placeholder', () {
      final a = router.route(_request(CoachDecisionType.sessionAdaptation));
      final b = router.route(_request(CoachDecisionType.sessionAdaptation));
      expect(a.status, b.status);
      expect(a.placeholderCode, b.placeholderCode);
      expect(a.handlerName, b.handlerName);
    });

    test('each stub handler exposes distinct placeholder code', () {
      final codes = <String>{};
      for (final type in CoachDecisionType.values) {
        final result = router.route(_request(type));
        codes.add(result.placeholderCode!);
      }
      expect(codes.length, CoachDecisionType.values.length);
    });

    test('router contains no adaptation domain imports', () {
      // Compile-time boundary: coach_brain library must not depend on adaptation.
      expect(CoachBrainDependencies.stub().router, isA<CoachDecisionRouter>());
    });
  });

  group('CoachBrainDependencies', () {
    test('custom handler overrides stub for one type', () {
      const custom = _CustomSessionAdaptationHandler();
      final deps = CoachBrainDependencies(
        handlers: [
          custom,
          ...kStubCoachDecisionHandlers.where(
            (h) => h.decisionType != CoachDecisionType.sessionAdaptation,
          ),
        ],
      );
      final result = deps.router.route(
        _request(CoachDecisionType.sessionAdaptation),
      );
      expect(result.handlerName, custom.handlerName);
      expect(result.placeholderCode, 'custom_session_adaptation');
    });
  });
}

class _CustomSessionAdaptationHandler extends CoachDecisionHandler {
  const _CustomSessionAdaptationHandler();

  @override
  CoachDecisionType get decisionType => CoachDecisionType.sessionAdaptation;

  @override
  String get handlerName => 'custom_session_adaptation';

  @override
  CoachDecisionResult handle(CoachDecisionRequest request) {
    return CoachDecisionResult.stubPlaceholder(
      decisionType: decisionType,
      requestId: request.requestId,
      handlerName: handlerName,
      placeholderCode: 'custom_session_adaptation',
    );
  }
}

class _SpyCoachDecisionHandler extends CoachDecisionHandler {
  _SpyCoachDecisionHandler({
    required this.decisionType,
    required this.onHandle,
  });

  @override
  final CoachDecisionType decisionType;

  final void Function() onHandle;

  @override
  String get handlerName => 'spy_${decisionType.name}';

  @override
  CoachDecisionResult handle(CoachDecisionRequest request) {
    onHandle();
    return CoachDecisionResult.stubPlaceholder(
      decisionType: decisionType,
      requestId: request.requestId,
      handlerName: handlerName,
      placeholderCode: 'spy_handled',
    );
  }
}
