/// Parses PostgreSQL `VALUES (...), (...)` tuples used by committed protocol
/// SQL artifacts. This is an artifact reader, not a programme authoring format.
class SqlValuesParser {
  const SqlValuesParser();

  List<List<Object?>> parseTupleList(String valuesClause) {
    final tuples = <List<Object?>>[];
    var i = 0;
    while (i < valuesClause.length) {
      while (i < valuesClause.length && _isSpace(valuesClause.codeUnitAt(i))) {
        i++;
      }
      if (i >= valuesClause.length) {
        break;
      }
      if (valuesClause[i] == ',') {
        i++;
        continue;
      }
      if (valuesClause[i] != '(') {
        i++;
        continue;
      }
      final parsed = _parseTuple(valuesClause, i);
      tuples.add(parsed.$1);
      i = parsed.$2;
    }
    return tuples;
  }

  (List<Object?>, int) _parseTuple(String source, int start) {
    final values = <Object?>[];
    var i = start + 1;
    while (i < source.length) {
      while (i < source.length && _isSpace(source.codeUnitAt(i))) {
        i++;
      }
      if (i < source.length && source[i] == ')') {
        return (values, i + 1);
      }
      final value = _parseValue(source, i);
      values.add(value.$1);
      i = value.$2;
      while (i < source.length && _isSpace(source.codeUnitAt(i))) {
        i++;
      }
      if (i < source.length && source[i] == ',') {
        i++;
      }
    }
    throw FormatException('Unclosed SQL VALUES tuple.');
  }

  (Object?, int) _parseValue(String source, int start) {
    var i = start;
    while (i < source.length && _isSpace(source.codeUnitAt(i))) {
      i++;
    }
    if (i >= source.length) {
      throw const FormatException('Unexpected end of SQL value.');
    }
    if (source.startsWith('NULL', i) || source.startsWith('null', i)) {
      return (null, i + 4);
    }
    if (source[i] == "'") {
      return _parseQuoted(source, i);
    }
    final token = StringBuffer();
    while (i < source.length) {
      final ch = source[i];
      if (ch == ',' || ch == ')' || _isSpace(source.codeUnitAt(i))) {
        break;
      }
      token.write(ch);
      i++;
    }
    final raw = token.toString();
    final cast = raw.split('::').first;
    if (cast == 'NULL' || cast == 'null') {
      return (null, i);
    }
    final asInt = int.tryParse(cast);
    if (asInt != null) {
      return (asInt, i);
    }
    return (cast, i);
  }

  (String, int) _parseQuoted(String source, int start) {
    final buffer = StringBuffer();
    var i = start + 1;
    while (i < source.length) {
      final ch = source[i];
      if (ch == "'") {
        if (i + 1 < source.length && source[i + 1] == "'") {
          buffer.write("'");
          i += 2;
          continue;
        }
        i++;
        while (i < source.length && source.startsWith('::', i)) {
          i += 2;
          while (i < source.length &&
              !{',', ')'}.contains(source[i]) &&
              !_isSpace(source.codeUnitAt(i))) {
            i++;
          }
        }
        return (buffer.toString(), i);
      }
      buffer.write(ch);
      i++;
    }
    throw const FormatException('Unclosed SQL string literal.');
  }

  bool _isSpace(int code) =>
      code == 32 || code == 9 || code == 10 || code == 13;
}

class SqlInsertExtractor {
  const SqlInsertExtractor();

  String? valuesClause({
    required String sql,
    required String table,
    bool publicQualified = true,
  }) {
    final clauses = valuesClauses(
      sql: sql,
      table: table,
      publicQualified: publicQualified,
    );
    return clauses.isEmpty ? null : clauses.first;
  }

  List<String> valuesClauses({
    required String sql,
    required String table,
    bool publicQualified = true,
  }) {
    final qualified = publicQualified ? 'public\\.$table' : table;
    final marker = RegExp(
      'INSERT\\s+INTO\\s+$qualified\\b',
      caseSensitive: false,
    );
    final clauses = <String>[];
    for (final match in marker.allMatches(sql)) {
      final valuesAt = RegExp(
        '\\bVALUES\\b',
        caseSensitive: false,
      ).firstMatch(sql.substring(match.end));
      if (valuesAt == null) {
        continue;
      }
      final from = match.end + valuesAt.end;
      final end = _statementEnd(sql, from);
      clauses.add(sql.substring(from, end));
    }
    return clauses;
  }

  int _statementEnd(String sql, int from) {
    var depth = 0;
    var inString = false;
    for (var i = from; i < sql.length; i++) {
      final ch = sql[i];
      if (inString) {
        if (ch == "'" && i + 1 < sql.length && sql[i + 1] == "'") {
          i++;
          continue;
        }
        if (ch == "'") {
          inString = false;
        }
        continue;
      }
      if (ch == "'") {
        inString = true;
        continue;
      }
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
      } else if (ch == ';' && depth <= 0) {
        return i;
      }
    }
    return sql.length;
  }
}
