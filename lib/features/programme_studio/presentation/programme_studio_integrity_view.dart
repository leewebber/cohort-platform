import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../domain/programme_review_models.dart';
import 'programme_studio_copy.dart';

class ProgrammeStudioIntegrityView extends StatelessWidget {
  const ProgrammeStudioIntegrityView({
    super.key,
    required this.programme,
    required this.sourceInputs,
    required this.authority,
  });

  final ProgrammeReviewProgramme programme;
  final List<String> sourceInputs;
  final String authority;

  @override
  Widget build(BuildContext context) {
    final compile = programme.compile;
    final corrections = programme.findings
        .where((item) => item.code.startsWith('sql_correction'))
        .toList(growable: false);
    final unsupported = programme.findings
        .where((item) => item.code == 'unsupported_sql_correction')
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ProgrammeStudioCopy.technicalIntegrity,
          style: CohortTextStyles.h2,
        ),
        const SizedBox(height: CohortSpacing.md),
        _Section(
          title: 'Source files',
          child: _MonoBlock(programme.sourcePaths.join('\n')),
        ),
        _Section(
          title: 'Source ordering',
          child: _MonoBlock(sourceInputs.join('\n')),
        ),
        _Section(
          title: 'Identity',
          child: _MonoBlock(
            [
              'lineage ${programme.lineageCode}',
              'version ${programme.versionNumber}',
              'programme_version_id ${programme.programmeVersionId ?? 'none'}',
              'catalog_id ${programme.catalogId}',
            ].join('\n'),
          ),
        ),
        _Section(
          title: 'Canonical hash',
          child: _MonoBlock(compile.contentHashSha256 ?? 'none'),
        ),
        _Section(
          title: 'Compiler stages',
          child: Text(
            'Parse ${compile.parseOk ? 'passed' : 'failed'} · '
            'Validation ${compile.validationOk ? 'passed' : 'failed'} · '
            'Canonicalisation ${compile.canonicalisationOk ? 'passed' : 'failed'}',
            style: CohortTextStyles.body,
          ),
        ),
        _Section(
          title: 'Validation output',
          child: _Findings(
            findings: [...compile.issues, ...programme.findings],
          ),
        ),
        _Section(
          title: 'Publication evidence',
          child: Text(
            [
              programme.publication.detail ?? 'Not established locally',
              if (programme.publication.artifactPath != null)
                programme.publication.artifactPath!,
              if (programme.publication.sourcePackageHash != null)
                programme.publication.sourcePackageHash!,
              ProgrammeStudioCopy.comparisonUnavailable,
            ].join('\n'),
            style: CohortTextStyles.small,
          ),
        ),
        _Section(
          title: 'Applied Apollo correction chain',
          child: corrections.isEmpty
              ? const Text(
                  'No correction findings.',
                  style: CohortTextStyles.small,
                )
              : _Findings(findings: corrections),
        ),
        if (unsupported.isNotEmpty)
          _Section(
            title: 'Unsupported SQL or source findings',
            child: _Findings(findings: unsupported),
          ),
        _Section(
          title: 'Deterministic projection identity',
          child: _MonoBlock(authority),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title, style: CohortTextStyles.cardTitle),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _MonoBlock extends StatelessWidget {
  const _MonoBlock(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      value,
      style: CohortTextStyles.small.copyWith(fontFamily: 'monospace'),
    );
  }
}

class _Findings extends StatelessWidget {
  const _Findings({required this.findings});

  final List<ProgrammeReviewFinding> findings;

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) {
      return const Text('None', style: CohortTextStyles.small);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final finding in findings)
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
            child: SelectableText(
              '${finding.code}: ${finding.message}'
              '${finding.sourceContext == null ? '' : '\n${finding.sourceContext}'}',
              style: CohortTextStyles.small.copyWith(fontFamily: 'monospace'),
            ),
          ),
      ],
    );
  }
}
