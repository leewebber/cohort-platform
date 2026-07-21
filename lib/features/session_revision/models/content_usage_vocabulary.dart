/// Typed vocabulary for content usage relationship queries (M9.2).
enum ContentEntityType {
  sessionRevision,
  programmeVersion,
  programmeAssignment,
  trainingSessionRecord,
}

/// How a Session Revision is referenced in the platform.
enum ContentUsageClassification {
  /// Referenced directly by a programme version slot (`protocol_id`).
  directAuthored,

  /// Referenced transitively by an active programme assignment.
  activeOperational,

  /// Referenced by terminal training history records.
  historicalPerformance,
}

extension ContentUsageClassificationLabels on ContentUsageClassification {
  String get displayLabel {
    switch (this) {
      case ContentUsageClassification.directAuthored:
        return 'Direct authored';
      case ContentUsageClassification.activeOperational:
        return 'Active operational';
      case ContentUsageClassification.historicalPerformance:
        return 'Historical performance';
    }
  }
}
