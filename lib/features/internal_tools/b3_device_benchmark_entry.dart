import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/config/internal_tools_policy.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_button.dart';

enum B3DeviceBenchmarkSurface { outdoor, treadmill }

class B3DeviceBenchmarkCommand {
  const B3DeviceBenchmarkCommand({
    required this.commandId,
    required this.localTestDate,
    required this.elapsedDurationMilliseconds,
    required this.surface,
    this.timezone = 'Asia/Makassar',
  });

  final String commandId;
  final DateTime localTestDate;
  final int elapsedDurationMilliseconds;
  final B3DeviceBenchmarkSurface surface;
  final String timezone;

  Map<String, Object> toRpcPayload() {
    if (elapsedDurationMilliseconds <= 0) {
      throw const FormatException('Elapsed duration must be positive.');
    }
    final y = localTestDate.year.toString().padLeft(4, '0');
    final m = localTestDate.month.toString().padLeft(2, '0');
    final d = localTestDate.day.toString().padLeft(2, '0');
    return {
      'command_id': commandId,
      'source_reference': 'b3-device-validation:$commandId',
      'source': 'manual',
      'declaration': 'completed_five_kilometre_test',
      'distance_metres': 5000,
      'elapsed_duration_milliseconds': elapsedDurationMilliseconds,
      'duration_basis': 'elapsed_including_pauses',
      'local_test_date': '$y-$m-$d',
      'iana_timezone': timezone,
      'surface_context': surface.name,
    };
  }
}

class B3DeviceBenchmarkWriteResult {
  const B3DeviceBenchmarkWriteResult({required this.isSuccess, this.message});

  final bool isSuccess;
  final String? message;
}

abstract interface class B3DeviceBenchmarkEvidenceStore {
  Future<B3DeviceBenchmarkWriteResult> record(B3DeviceBenchmarkCommand command);
}

class B3DeviceBenchmarkSupabaseStore implements B3DeviceBenchmarkEvidenceStore {
  const B3DeviceBenchmarkSupabaseStore();

  @override
  Future<B3DeviceBenchmarkWriteResult> record(
    B3DeviceBenchmarkCommand command,
  ) async {
    try {
      final response = await SupabaseService.client.rpc(
        'record_manual_completed_5k_benchmark',
        params: {'payload': command.toRpcPayload()},
      );
      final map = response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{};
      final status = map['status']?.toString();
      if (status == 'recorded' || status == 'already_recorded') {
        return const B3DeviceBenchmarkWriteResult(isSuccess: true);
      }
      return B3DeviceBenchmarkWriteResult(
        isSuccess: false,
        message: switch (map['code']?.toString()) {
          'ineligible_manual_evidence' =>
            'This result is not eligible. Confirm the date, elapsed time, and exact 5 km declaration.',
          'athlete_authentication_required' =>
            'Sign in as the athlete who completed the test.',
          _ => 'The benchmark could not be recorded.',
        },
      );
    } catch (_) {
      return const B3DeviceBenchmarkWriteResult(
        isSuccess: false,
        message:
            'The benchmark could not be recorded. Check the connection and retry.',
      );
    }
  }
}

class B3DeviceBenchmarkEntryScreen extends StatefulWidget {
  const B3DeviceBenchmarkEntryScreen({
    super.key,
    this.store = const B3DeviceBenchmarkSupabaseStore(),
    this.initialDate,
    this.commandIdFactory = _commandId,
  });

  final B3DeviceBenchmarkEvidenceStore store;
  final DateTime? initialDate;
  final String Function() commandIdFactory;

  @override
  State<B3DeviceBenchmarkEntryScreen> createState() =>
      _B3DeviceBenchmarkEntryScreenState();
}

class _B3DeviceBenchmarkEntryScreenState
    extends State<B3DeviceBenchmarkEntryScreen> {
  final _minutes = TextEditingController();
  final _seconds = TextEditingController();
  late DateTime _date;
  B3DeviceBenchmarkSurface _surface = B3DeviceBenchmarkSurface.outdoor;
  bool _confirmed = false;
  bool _submitting = false;
  String? _message;
  String? _commandId;

  @override
  void initState() {
    super.initState();
    final value = widget.initialDate ?? DateTime.now();
    _date = DateTime(value.year, value.month, value.day);
  }

  @override
  void dispose() {
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final minutes = int.tryParse(_minutes.text.trim());
    final seconds = int.tryParse(_seconds.text.trim());
    if (!_confirmed ||
        minutes == null ||
        minutes < 1 ||
        seconds == null ||
        seconds < 0 ||
        seconds > 59) {
      setState(() {
        _message =
            'Enter a valid elapsed time and confirm the exact completed 5 km declaration.';
      });
      return;
    }
    _commandId ??= widget.commandIdFactory();
    setState(() {
      _submitting = true;
      _message = null;
    });
    final result = await widget.store.record(
      B3DeviceBenchmarkCommand(
        commandId: _commandId!,
        localTestDate: _date,
        elapsedDurationMilliseconds: (minutes * 60 + seconds) * 1000,
        surface: _surface,
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _message = result.isSuccess
          ? 'Eligible completed 5 km evidence recorded for this athlete.'
          : result.message;
      if (result.isSuccess) _commandId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!InternalToolsPolicy.enabled) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(CohortSpacing.lg),
            child: Text('This developer validation tool is disabled.'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('B3 device validation benchmark')),
      body: ListView(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        children: [
          Text('TEST ONLY', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.sm),
          Text('Record a completed 5 km test', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Use only a test you actually completed. Enter elapsed time including pauses. '
            'Ordinary activities are not eligible and this tool does not create estimated evidence.',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('b3-benchmark-minutes'),
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                ),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: TextField(
                  key: const ValueKey('b3-benchmark-seconds'),
                  controller: _seconds,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Seconds'),
                ),
              ),
            ],
          ),
          const SizedBox(height: CohortSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Test date'),
            subtitle: Text(_iso(_date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          DropdownButtonFormField<B3DeviceBenchmarkSurface>(
            initialValue: _surface,
            decoration: const InputDecoration(labelText: 'Surface'),
            items: const [
              DropdownMenuItem(
                value: B3DeviceBenchmarkSurface.outdoor,
                child: Text('Outdoor'),
              ),
              DropdownMenuItem(
                value: B3DeviceBenchmarkSurface.treadmill,
                child: Text('Treadmill'),
              ),
            ],
            onChanged: _submitting
                ? null
                : (value) => setState(() => _surface = value ?? _surface),
          ),
          const SizedBox(height: CohortSpacing.md),
          CheckboxListTile(
            key: const ValueKey('b3-benchmark-confirmation'),
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            title: const Text(
              'I completed exactly 5 km and this is elapsed time including pauses.',
            ),
            onChanged: _submitting
                ? null
                : (value) => setState(() => _confirmed = value == true),
          ),
          if (_message != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(_message!, style: CohortTextStyles.body),
          ],
          const SizedBox(height: CohortSpacing.lg),
          CohortButton(
            label: _submitting ? 'Recording…' : 'Record completed 5 km test',
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  static String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _commandId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
