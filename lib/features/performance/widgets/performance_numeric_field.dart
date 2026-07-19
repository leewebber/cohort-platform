import 'package:flutter/material.dart';

/// Numeric input that keeps a stable [TextEditingController] across rebuilds.
///
/// Prevents digit reversal/cursor jumps when parent state updates on each keystroke.
class PerformanceNumericField extends StatefulWidget {
  const PerformanceNumericField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.allowDecimal = false,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String? label;
  final bool allowDecimal;

  @override
  State<PerformanceNumericField> createState() =>
      _PerformanceNumericFieldState();
}

class _PerformanceNumericFieldState extends State<PerformanceNumericField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant PerformanceNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = widget.value ?? '';
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.value = TextEditingValue(
        text: external,
        selection: TextSelection.collapsed(offset: external.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: InputDecoration(labelText: widget.label),
      keyboardType: widget.allowDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      onChanged: widget.onChanged,
    );
  }
}
