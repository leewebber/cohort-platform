import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/interval_pace_format.dart';

class IntervalPaceField extends StatefulWidget {
  const IntervalPaceField({
    super.key,
    required this.secondsPerKm,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Pace (MM:SS /km)',
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.errorText,
    this.onSubmitted,
    this.onDraftChanged,
  });

  final double? secondsPerKm;
  final ValueChanged<double?> onChanged;
  final bool enabled;
  final String label;
  final bool autofocus;
  final TextInputAction textInputAction;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onDraftChanged;

  @override
  State<IntervalPaceField> createState() => IntervalPaceFieldState();
}

class IntervalPaceFieldState extends State<IntervalPaceField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String get draftText => _controller.text;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: IntervalPaceFormat.formatSecondsPerKm(widget.secondsPerKm),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant IntervalPaceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) return;
    if (oldWidget.secondsPerKm == widget.secondsPerKm) return;
    final formatted = IntervalPaceFormat.formatSecondsPerKm(
      widget.secondsPerKm,
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
    _commitIfCompleteOrEmpty();
  }

  void _handleDraft(String value) {
    widget.onDraftChanged?.call(value);
    if (IntervalPaceFormat.isComplete(value)) {
      widget.onChanged(IntervalPaceFormat.parse(value));
    }
  }

  void _commitIfCompleteOrEmpty() {
    final draft = _controller.text;
    if (draft.trim().isEmpty) {
      widget.onChanged(null);
      return;
    }
    if (IntervalPaceFormat.isComplete(draft)) {
      widget.onChanged(IntervalPaceFormat.parse(draft));
    }
  }

  void _handleSubmitted(String value) {
    _commitIfCompleteOrEmpty();
    widget.onSubmitted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '4:10',
        suffixText: '/km',
        errorText: widget.errorText,
      ),
      onChanged: _handleDraft,
      onSubmitted: _handleSubmitted,
    );
  }
}
