import 'package:flutter/material.dart';

import '../../session/services/block_timer_controller.dart';
import '../models/performance_result_data.dart';
import '../widgets/emom_result_capture.dart';

class EmomResultScreen extends StatefulWidget {
  const EmomResultScreen({
    super.key,
    required this.result,
    this.timer,
    this.secondaryLabel = 'Return to timer/review',
  });

  final CircuitResultData result;
  final BlockTimerState? timer;
  final String secondaryLabel;

  @override
  State<EmomResultScreen> createState() => _EmomResultScreenState();
}

class _EmomResultScreenState extends State<EmomResultScreen> {
  late CircuitResultData _result = widget.result;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: EmomResultCapture(
            result: _result,
            timer: widget.timer,
            secondaryLabel: widget.secondaryLabel,
            saving: _saving,
            onChanged: (next) => setState(() => _result = next),
            onSave: (saved) {
              if (_saving) return;
              setState(() => _saving = true);
              Navigator.of(context).pop(saved);
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

Future<CircuitResultData?> openEmomResultCapture(
  BuildContext context, {
  required CircuitResultData result,
  BlockTimerState? timer,
  String secondaryLabel = 'Return to timer/review',
}) {
  return Navigator.of(context).push<CircuitResultData>(
    MaterialPageRoute(
      builder: (_) => EmomResultScreen(
        result: result,
        timer: timer,
        secondaryLabel: secondaryLabel,
      ),
    ),
  );
}
