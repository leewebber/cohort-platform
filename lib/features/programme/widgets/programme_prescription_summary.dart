import 'package:flutter/material.dart';
import '../../../domain/hyrox_base/programme_prescription.dart';

class ProgrammePrescriptionSummary extends StatelessWidget {
  const ProgrammePrescriptionSummary({super.key, required this.prescription});
  final ProgrammePrescription prescription;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Prescribed targets · fixed at session start'),
      for (final t in prescription.targets)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t.label} · Week ${t.binding['week_number']}'),
              Text(t.dose),
              Text(t.targetLabel),
              Text(t.benchmarkLabel),
            ],
          ),
        ),
      const Text(
        'Record actual results separately below. Later benchmark or consent changes do not change these targets.',
      ),
    ],
  );
}
