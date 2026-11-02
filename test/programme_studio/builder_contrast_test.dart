import 'package:cohort_platform/core/theme/colors.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/builder_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WCAG relative-luminance ratio of the actual opaque/composited component pairs.
double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
}

void main() {
  test(
    'builder text, interactive states, warnings and control boundaries meet contrast targets',
    () {
      final t = founderBuilderTheme, s = t.colorScheme;
      final textPairs = <String, (Color, Color)>{
        'page text': (s.onSurface, s.surfaceContainerLow),
        'card/field/dialog text': (s.onSurface, s.surface),
        'labels/hints': (builderMuted, s.surface),
        'supporting text': (builderMuted, s.surfaceContainerLow),
        'button': (s.onPrimary, s.primary),
        'button hover': (
          s.onPrimary,
          Color.alphaBlend(Colors.white.withValues(alpha: .08), s.primary),
        ),
        'button pressed': (
          s.onPrimary,
          Color.alphaBlend(Colors.white.withValues(alpha: .12), s.primary),
        ),
        'text/outlined button': (s.primary, s.surface),
        'selected chip': (s.onPrimaryContainer, s.primaryContainer),
        'menu': (s.onSurface, s.surfaceContainerHigh),
        'disabled control': (builderMuted, s.surfaceContainerHigh),
        'warning': (builderWarning, builderWarningSurface),
        'warning supporting text': (builderMuted, builderWarningSurface),
        'error': (s.error, s.surface),
        'dark toolbar': (
          t.appBarTheme.foregroundColor!,
          t.appBarTheme.backgroundColor!,
        ),
        'toolbar disabled': (
          CohortColors.textSecondary,
          t.appBarTheme.backgroundColor!,
        ),
      };
      for (final pair in textPairs.entries) {
        final ratio = contrast(pair.value.$1, pair.value.$2);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '${pair.key}: $ratio');
      }
      for (final bg in [s.surface, s.surfaceContainerLow, s.primaryContainer]) {
        expect(contrast(builderOutline, bg), greaterThanOrEqualTo(3));
      }
      expect(contrast(s.primary, s.surface), greaterThanOrEqualTo(3));
      expect(
        contrast(builderWarning, builderWarningSurface),
        greaterThanOrEqualTo(3),
      );
      expect(t.brightness, Brightness.light);
      expect(t.appBarTheme.backgroundColor, CohortColors.surfaceRaised);
    },
  );
  testWidgets(
    'actual entered field and label roles belong to the light field surface',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: founderBuilderTheme,
          home: const Scaffold(
            body: TextField(
              decoration: InputDecoration(labelText: 'Sets'),
              controller: null,
            ),
          ),
        ),
      );
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.style.color, builderInk);
      final theme = Theme.of(tester.element(find.byType(TextField)));
      expect(
        contrast(editable.style.color!, theme.inputDecorationTheme.fillColor!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(
          theme.inputDecorationTheme.labelStyle!.color!,
          theme.inputDecorationTheme.fillColor!,
        ),
        greaterThanOrEqualTo(4.5),
      );
    },
  );
}
