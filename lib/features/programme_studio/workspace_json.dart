import 'dart:convert';

const workspaceMaxBytes = 2 * 1024 * 1024;

Never workspaceInvalid(String message) =>
    throw FormatException('workspace: $message');
Map<String, dynamic> workspaceObject(Object? v, Set<String> keys, String path) {
  if (v is! Map<String, dynamic> ||
      v.length != keys.length ||
      !v.keys.every(keys.contains)) {
    workspaceInvalid('$path has missing/unsupported fields.');
  }
  return v;
}

int workspaceInt(Object? v, String path, {int min = 0, int max = 1000000}) {
  if (v is! int || v < min || v > max) {
    workspaceInvalid('$path is out of bounds.');
  }
  return v;
}

String workspaceString(Object? v, String path) {
  if (v is! String || v.length > 262144) {
    workspaceInvalid('$path must be bounded text.');
  }
  return v;
}

List<dynamic> workspaceList(Object? v, String path, {int max = 128}) {
  if (v is! List || v.length > max) {
    workspaceInvalid('$path must be a bounded list.');
  }
  return v;
}

/// Bound nesting before jsonDecode, then reject even escaped duplicate keys.
Map<String, dynamic> readWorkspaceJson(String text) {
  if (text.length > workspaceMaxBytes ||
      utf8.encode(text).length > workspaceMaxBytes) {
    workspaceInvalid('File exceeds 2 MiB.');
  }
  var depth = 0, quoted = false, escaped = false;
  for (final c in text.split('')) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == '"') {
        quoted = false;
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == '[' || c == '{') {
      if (++depth > 32) workspaceInvalid('Nesting exceeds 32 levels.');
    } else if (c == ']' || c == '}') {
      depth--;
    }
  }
  final decoded = jsonDecode(text);
  var nodes = 0;
  void bound(Object? value) {
    if (++nodes > 30000) workspaceInvalid('Too many input values.');
    if (value is String && value.length > 262144) {
      workspaceInvalid('Text field too large.');
    }
    if (value is num && !value.isFinite) workspaceInvalid('Non-finite number.');
    if (value is Map) {
      for (final e in value.entries) {
        bound(e.key);
        bound(e.value);
      }
    }
    if (value is List) {
      for (final v in value) {
        bound(v);
      }
    }
  }

  bound(decoded);
  var at = 0;
  void space() {
    while (at < text.length && text[at].trim().isEmpty) {
      at++;
    }
  }

  String string() {
    final start = at++;
    while (at < text.length) {
      if (text[at] == '\\') {
        at += 2;
        continue;
      }
      if (text[at++] == '"') break;
    }
    return jsonDecode(text.substring(start, at)) as String;
  }

  late void Function() value;
  value = () {
    space();
    if (text[at] == '"') {
      string();
      return;
    }
    if (text[at] == '{') {
      at++;
      space();
      final keys = <String>{};
      if (text[at] == '}') {
        at++;
        return;
      }
      while (true) {
        space();
        final key = string();
        if (!keys.add(key)) workspaceInvalid('Duplicate field $key.');
        space();
        at++;
        value();
        space();
        if (text[at++] == '}') return;
      }
    }
    if (text[at] == '[') {
      at++;
      space();
      if (text[at] == ']') {
        at++;
        return;
      }
      while (true) {
        value();
        space();
        if (text[at++] == ']') return;
      }
    }
    while (at < text.length && !RegExp(r'[\s,}\]]').hasMatch(text[at])) {
      at++;
    }
  };
  value();
  if (decoded is! Map<String, dynamic>) {
    workspaceInvalid('Expected a workspace object.');
  }
  return decoded;
}

Map<String, dynamic> workspaceFields(
  Object? v,
  Set<String> allowed,
  Set<String> required,
  String path,
) {
  if (v is! Map<String, dynamic> ||
      !v.keys.every(allowed.contains) ||
      !required.every(v.containsKey)) {
    workspaceInvalid('$path has missing/unsupported fields.');
  }
  return v;
}

String encodeWorkspaceJson(Object? value) {
  Object? sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: sorted(v[k])};
    }
    if (v is List) return v.map(sorted).toList();
    return v;
  }

  return '${const JsonEncoder.withIndent('  ').convert(sorted(value))}\n';
}

/// Resource guard for canonical YAML strings before invoking existing parsers.
/// Quoted text/comments are inert; aliases/tags/block scalars are not emitted by
/// the existing form writers and are refused in editable workspace source lanes.
void guardWorkspaceYaml(String source) {
  workspaceString(source, 'YAML source');
  String? quote;
  var flowDepth = 0, lines = 0;
  for (final line in source.split('\n')) {
    if (++lines > 16384 || line.length - line.trimLeft().length > 64) {
      workspaceInvalid('YAML nesting/line limit exceeded.');
    }
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quote != null) {
        if (quote == '"' && c == '\\') {
          i++;
          continue;
        }
        if (c == quote) {
          if (quote == "'" && i + 1 < line.length && line[i + 1] == "'") {
            i++;
            continue;
          }
          quote = null;
        }
        continue;
      }
      if (c == '#') break;
      if (c == '"' || c == "'") {
        quote = c;
        continue;
      }
      if ('&*!|>'.contains(c)) {
        workspaceInvalid('Unsupported YAML syntax in workspace sources.');
      }
      if (c == '[' || c == '{') {
        if (++flowDepth > 32) {
          workspaceInvalid('YAML flow nesting limit exceeded.');
        }
      } else if (c == ']' || c == '}') {
        flowDepth--;
      }
    }
  }
}
