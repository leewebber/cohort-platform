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
    this.onSubmitted,
  });

  final double? secondsPerKm;
  final ValueChanged<double?> onChanged;
  final bool enabled;
  final String label;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<IntervalPaceField> createState() => _IntervalPaceFieldState();
}

class _IntervalPaceFieldState extends State<IntervalPaceField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: IntervalPaceFormat.formatSecondsPerKm(widget.secondsPerKm),
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant IntervalPaceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final formatted = IntervalPaceFormat.formatSecondsPerKm(
      widget.secondsPerKm,
    );
    if (!_focusNode.hasFocus && oldWidget.secondsPerKm != widget.secondsPerKm) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
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
      ),
      onChanged: (value) => widget.onChanged(IntervalPaceFormat.parse(value)),
      onSubmitted: widget.onSubmitted,
    );
  }
}
