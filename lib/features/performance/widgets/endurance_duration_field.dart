import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/endurance_metrics_calculator.dart';

/// Athlete-friendly duration entry in MM:SS or H:MM:SS format.
class EnduranceDurationField extends StatefulWidget {
  const EnduranceDurationField({
    super.key,
    required this.durationSeconds,
    required this.onDurationSecondsChanged,
    this.label = 'Duration',
  });

  final int? durationSeconds;
  final ValueChanged<int?> onDurationSecondsChanged;
  final String label;

  @override
  State<EnduranceDurationField> createState() => _EnduranceDurationFieldState();
}

class _EnduranceDurationFieldState extends State<EnduranceDurationField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: EnduranceMetricsCalculator.formatAthleteDuration(
        widget.durationSeconds,
      ),
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant EnduranceDurationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        oldWidget.durationSeconds != widget.durationSeconds) {
      final external = EnduranceMetricsCalculator.formatAthleteDuration(
        widget.durationSeconds,
      );
      _controller.value = TextEditingValue(
        text: external,
        selection: TextSelection.collapsed(offset: external.length),
      );
      _validationError = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^0-9:]'), '');
    if (sanitized != value) {
      _controller.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }

    final parsed = EnduranceMetricsCalculator.parseAthleteDuration(sanitized);
    setState(() {
      _validationError = parsed.isInvalid
          ? 'Enter time as MM:SS or H:MM:SS'
          : null;
    });

    if (parsed.isValid) {
      widget.onDurationSecondsChanged(parsed.seconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: 'MM:SS or H:MM:SS',
        errorText: _validationError,
      ),
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
      ],
      onChanged: _handleChanged,
    );
  }
}
