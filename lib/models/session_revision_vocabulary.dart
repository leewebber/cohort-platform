/// Lifecycle vocabulary for immutable Session Revisions (M9.1).
///
/// Each `performance_protocols.protocol_id` row is one Session Revision.
/// Revisions are grouped by [SessionLineage].
library;

enum SessionRevisionLifecycleStatus {
  /// Mutable; not assignable to published programme slots by policy.
  draft,

  /// Immutable revision snapshot.
  published,

  /// Retired; hidden from default pickers but still resolvable historically.
  archived,
}

extension SessionRevisionLifecycleStatusDb on SessionRevisionLifecycleStatus {
  String get dbValue {
    return switch (this) {
      SessionRevisionLifecycleStatus.draft => 'draft',
      SessionRevisionLifecycleStatus.published => 'published',
      SessionRevisionLifecycleStatus.archived => 'archived',
    };
  }

  static SessionRevisionLifecycleStatus fromDb(String? value) {
    return switch (value?.trim()) {
      'draft' => SessionRevisionLifecycleStatus.draft,
      'archived' => SessionRevisionLifecycleStatus.archived,
      'published' => SessionRevisionLifecycleStatus.published,
      _ => SessionRevisionLifecycleStatus.published,
    };
  }

  static SessionRevisionLifecycleStatus fromPublishedBoolean(bool published) {
    return published
        ? SessionRevisionLifecycleStatus.published
        : SessionRevisionLifecycleStatus.draft;
  }
}
