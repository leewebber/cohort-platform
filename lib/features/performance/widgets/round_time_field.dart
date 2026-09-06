import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/interval_pace_format.dart';

class RoundTimeInputFormatter extends TextInputFormatter {
  const RoundTimeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(RegExp(r'[^0-9:]'), '');
    final next = IntervalPaceFormat.applySmartDraft(filtered);
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

/// Compact MM:SS round-time entry using the same digit rules as pace fields.
class RoundTimeField extends StatefulWidget {
  const RoundTimeField({
    super.key,
    required this.durationSeconds,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  final int? durationSeconds;
  final ValueChanged<int?> onChanged;
  final String label;
  final bool enabled;

  @override
  State<RoundTimeField> createState() => _RoundTimeFieldState();
}

class _RoundTimeFieldState extends State<RoundTimeField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _draftError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: IntervalPaceFormat.formatSecondsPerKm(
        widget.durationSeconds?.toDouble(),
      ),
    );
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant RoundTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) return;
    if (oldWidget.durationSeconds == widget.durationSeconds) return;
    final formatted = IntervalPaceFormat.formatSecondsPerKm(
      widget.durationSeconds?.toDouble(),
    );
    if (_controller.text == formatted) return;
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    final draft = _controller.text;
    if (draft.trim().isEmpty) return;
    if (!IntervalPaceFormat.isComplete(draft)) {
      setState(() {
        _draftError = IntervalPaceFormat.hasInvalidSeconds(draft)
            ? 'Enter seconds as 00–59'
            : 'Enter time as MM:SS';
      });
    }
  }

  void _syncDraft(String value) {
    final invalid = IntervalPaceFormat.hasInvalidSeconds(value);
    setState(() {
      _draftError = invalid ? 'Enter seconds as 00–59' : null;
    });
    if (value.trim().isEmpty) {
      widget.onChanged(null);
      return;
    }
    if (!IntervalPaceFormat.isComplete(value)) return;
    final parsed = IntervalPaceFormat.parse(value);
    widget.onChanged(parsed?.round());
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey('round-time-${widget.label}'),
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [RoundTimeInputFormatter()],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'MM:SS',
        errorText: _draftError,
      ),
      onChanged: _syncDraft,
    );
  }
}
