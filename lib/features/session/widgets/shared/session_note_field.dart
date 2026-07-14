import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

/// Shared optional session note field. Caller owns persisted value/state.
class SessionNoteField extends StatefulWidget {
  const SessionNoteField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'SESSION NOTE',
    this.hintText = 'Optional reflection for this session',
    this.helperText,
    this.useFilledBackground = false,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String label;
  final String hintText;
  final String? helperText;
  final bool useFilledBackground;

  @override
  State<SessionNoteField> createState() => _SessionNoteFieldState();
}

class _SessionNoteFieldState extends State<SessionNoteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant SessionNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        TextField(
          controller: _controller,
          style: CohortTextStyles.body,
          maxLines: 3,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: widget.useFilledBackground
                ? CohortTextStyles.small.copyWith(color: CohortColors.textMuted)
                : CohortTextStyles.small,
            filled: widget.useFilledBackground,
            fillColor: widget.useFilledBackground ? CohortColors.surface : null,
            isDense: !widget.useFilledBackground,
            contentPadding: EdgeInsets.symmetric(
              horizontal: CohortSpacing.md,
              vertical: widget.useFilledBackground
                  ? CohortSpacing.md
                  : CohortSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: CohortRadius.smallRadius,
              borderSide: const BorderSide(color: CohortColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: CohortRadius.smallRadius,
              borderSide: const BorderSide(color: CohortColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: CohortRadius.smallRadius,
              borderSide: BorderSide(
                color: widget.useFilledBackground
                    ? CohortColors.olive
                    : CohortColors.borderStrong,
              ),
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            widget.helperText!,
            style: CohortTextStyles.small,
          ),
        ],
      ],
    );
  }
}
