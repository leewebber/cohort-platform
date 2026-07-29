/// Semantic intensity band (no %1RM, pace, or HR targets).
enum SemanticIntensityLevel {
  restorative,
  low,
  moderate,
  moderatelyHigh,
  high,
  maximal,
  variable,
}

enum SemanticDomainEmphasis {
  aerobic,
  threshold,
  anaerobic,
  maximalStrength,
  hypertrophy,
  technique,
  mixed,
}

class SemanticIntensityTarget {
  const SemanticIntensityTarget({
    required this.level,
    this.domainEmphasis,
    this.rationale,
  });

  final SemanticIntensityLevel level;
  final SemanticDomainEmphasis? domainEmphasis;
  final String? rationale;

  @override
  bool operator ==(Object other) {
    return other is SemanticIntensityTarget &&
        other.level == level &&
        other.domainEmphasis == domainEmphasis &&
        other.rationale == rationale;
  }

  @override
  int get hashCode => Object.hash(level, domainEmphasis, rationale);
}

enum SemanticVolumeLevel { minimal, low, moderate, high, veryHigh }

enum SemanticVolumeDescriptor {
  shortDuration,
  standardDuration,
  extendedDuration,
  lowRepetitionExposure,
  repeatedExposure,
  highAccumulatedWork,
}

class SemanticVolumeTarget {
  const SemanticVolumeTarget({
    required this.level,
    this.descriptors = const [],
    this.rationale,
  });

  final SemanticVolumeLevel level;
  final List<SemanticVolumeDescriptor> descriptors;
  final String? rationale;

  @override
  bool operator ==(Object other) {
    return other is SemanticVolumeTarget &&
        other.level == level &&
        _listEq(other.descriptors, descriptors) &&
        other.rationale == rationale;
  }

  @override
  int get hashCode => Object.hash(level, Object.hashAll(descriptors), rationale);
}

enum SemanticDensityLevel {
  sparse,
  controlled,
  moderate,
  dense,
  continuous,
  variable,
}

class SemanticDensityTarget {
  const SemanticDensityTarget({
    required this.level,
    this.rationale,
  });

  final SemanticDensityLevel level;
  final String? rationale;

  @override
  bool operator ==(Object other) {
    return other is SemanticDensityTarget &&
        other.level == level &&
        other.rationale == rationale;
  }

  @override
  int get hashCode => Object.hash(level, rationale);
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

extension SemanticIntensityLevelOps on SemanticIntensityLevel {
  static const _order = SemanticIntensityLevel.values;

  SemanticIntensityLevel cap([int steps = 1]) {
    final index = _order.indexOf(this);
    return _order[(index - steps).clamp(0, _order.length - 1)];
  }

  SemanticIntensityLevel elevate([int steps = 1]) {
    final index = _order.indexOf(this);
    return _order[(index + steps).clamp(0, _order.length - 1)];
  }
}

extension SemanticVolumeLevelOps on SemanticVolumeLevel {
  static const _order = SemanticVolumeLevel.values;

  SemanticVolumeLevel reduce([int steps = 1]) {
    final index = _order.indexOf(this);
    return _order[(index - steps).clamp(0, _order.length - 1)];
  }

  SemanticVolumeLevel increase([int steps = 1]) {
    final index = _order.indexOf(this);
    return _order[(index + steps).clamp(0, _order.length - 1)];
  }
}

extension SemanticDensityLevelOps on SemanticDensityLevel {
  static const _order = SemanticDensityLevel.values;

  SemanticDensityLevel soften([int steps = 1]) {
    final index = _order.indexOf(this);
    return _order[(index - steps).clamp(0, _order.length - 1)];
  }
}
