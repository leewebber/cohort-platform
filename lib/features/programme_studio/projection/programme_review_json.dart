import 'dart:convert';

import '../domain/programme_review_models.dart';

const programmeReviewJsonEncoder = JsonEncoder.withIndent('  ');

String encodeProgrammeReviewCatalog(ProgrammeReviewCatalog catalog) {
  return '${programmeReviewJsonEncoder.convert(_sortJson(catalog.toJson()))}\n';
}

Object? _sortJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _sortJson(value[key])};
  }
  if (value is List) {
    return value.map(_sortJson).toList(growable: false);
  }
  return value;
}
