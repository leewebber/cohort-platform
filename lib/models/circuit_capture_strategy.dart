/// Explicit athlete capture strategy for authored circuit / rounds blocks.
///
/// Resolved only from authored timer metadata. Never inferred from titles.
enum CircuitCaptureStrategy {
  /// Station output is unknown and must be recorded per occurrence.
  variableOutput,

  /// Station work is prescribed and invariant. Completing a round confirms
  /// that prescribed work; the athlete records shared setup and round time.
  fixedWork,
}

extension CircuitCaptureStrategyDb on CircuitCaptureStrategy {
  String get dbValue {
    return switch (this) {
      CircuitCaptureStrategy.variableOutput => 'variable_output',
      CircuitCaptureStrategy.fixedWork => 'fixed_work',
    };
  }

  static CircuitCaptureStrategy? tryParse(String? value) {
    return switch (value?.trim()) {
      'variable_output' => CircuitCaptureStrategy.variableOutput,
      'fixed_work' => CircuitCaptureStrategy.fixedWork,
      _ => null,
    };
  }

  static CircuitCaptureStrategy parseOrVariable(String? value) {
    return tryParse(value) ?? CircuitCaptureStrategy.variableOutput;
  }
}
