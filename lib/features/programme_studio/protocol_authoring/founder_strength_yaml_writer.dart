import 'dart:convert';

/// Emits the existing Founder tree completely; validation grants exportability.
class FounderStrengthYamlWriter {
  const FounderStrengthYamlWriter();
  String write(Map<String, dynamic> tree) => '${_node(tree, 0).join('\n')}\n';
  List<String> _node(Object? value, int indent) {
    final pad = ' ' * indent;
    if (value is Map) {
      if (value.isEmpty) return ['$pad{}'];
      final keys = value.keys.cast<String>().toList()..sort();
      return [for (final k in keys) ..._entry('$pad$k:', value[k], indent)];
    }
    if (value is List) {
      if (value.isEmpty) return ['$pad[]'];
      return [for (final v in value) ..._entry('$pad-', v, indent)];
    }
    return ['$pad${_scalar(value)}'];
  }

  List<String> _entry(String prefix, Object? value, int indent) {
    if (value is Map && value.isNotEmpty || value is List && value.isNotEmpty) {
      return [prefix, ..._node(value, indent + 2)];
    }
    return [
      '$prefix ${value is Map
          ? '{}'
          : value is List
          ? '[]'
          : _scalar(value)}',
    ];
  }

  String _scalar(Object? value) {
    if (value is num && !value.isFinite) {
      throw const FormatException('Non-finite source number.');
    }
    if (value == null || value is String || value is bool || value is num) {
      return jsonEncode(value);
    }
    throw FormatException('Unsupported source scalar ${value.runtimeType}.');
  }
}
