import 'dart:convert';
import 'dart:typed_data';

import '../synthetic_composition_fixtures.dart';
import '../synthetic_composition_handoff.dart';
import '../synthetic_composition_review_bridge.dart';
import '../../protocol_authoring/synthetic_strength_lineage.dart';
import '../../protocol_authoring/synthetic_strength_session_compiler.dart';

/// Derived files only. Receipt ownership/freshness is checked by the live caller;
/// neither this archive nor its index grants publication or historical restore.
class CanonicalSourceBundle {
  CanonicalSourceBundle.fromReview(CompositionReviewReceipt receipt) {
    final checked = reviewComposition(
      receipt.programmeSource,
      receipt.sessions,
    );
    const transport = SyntheticCompositionHandoff();
    final review = transport.write(checked);
    if (review != transport.write(receipt) ||
        checked.canonicalJson != receipt.canonicalJson) {
      throw const FormatException('Source review claims differ.');
    }
    final sources = <String, String>{
      'programme.plan-package.yaml': checked.programmeSource,
    };
    final rows = <Map<String, Object>>[];
    for (final s
        in (checked.sessions.toList()
          ..sort((a, b) => compareRevisions(a.identity, b.identity)))) {
      final lineage = SyntheticStrengthLineage.resolve(s.identity);
      final name =
          'sessions/session-${lineage == SyntheticStrengthLineage.a ? 'a' : 'b'}-v${s.identity.revisionNumber}.founder.yaml';
      sources[name] = s.source;
      rows.add({
        'path': name,
        'identity': compositionTuple(s.identity),
        'session_key': lineage.sessionKey(s.identity.revisionNumber),
        'source_digest': s.sourceDigest,
        'profile_fingerprint': s.profileFingerprint,
        'exercise_bindings': s.bindings,
      });
    }
    sources['review.json'] = review;
    sources['source-index.json'] =
        '${const JsonEncoder.withIndent('  ').convert(compositionSorted({
          'kind': 'derived_canonical_source_file_index',
          'version': 1,
          'programme': {'path': 'programme.plan-package.yaml', 'source_digest': checked.programmeSourceDigest, 'package_hash': checked.packageHash},
          'sessions': rows,
          'files_sha256': {for (final e in sources.entries) e.key: d2SourceDigest(e.value)},
        }))}\n';
    sources['README.md'] = _instructions;
    files = Map.unmodifiable(
      Map.fromEntries(
        sources.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
    );
    _archive = _tar(files);
  }

  late final Map<String, String> files;
  late final Uint8List _archive;
  Uint8List get archiveBytes => _archive.asUnmodifiableView();
  String get filename => 'cohort-canonical-sources.tar';

  static const _instructions =
      '''# Canonical authoring sources — synthetic example

These files are outputs of the temporary Programme Studio workspace.
They are not published, founder-approved coaching content or an editable project.
Open canonical sources in Studio accepts this complete uncompressed .tar file as
new editable ownership after validation and explicit replacement. Imported revisions
are snapshots, not proof of historical freeze/approval. No private versions, omitted
history, reservations or drafts are restored. New numbers start above the supplied
inventory, whose missing earlier numbers remain unavailable with unknown history.
Save editable workspace separately to retain subsequent local history and drafts.
No upload or database operation was performed.

- programme.plan-package.yaml: exact current Plan Package v1 source.
- sessions/: exact Founder protocol YAML for EVERY declared version, including
  unused versions and each declared lineage root. Private saved versions/drafts
  not added to the programme are excluded. Names use Session A/B and version,
  not user titles. Original Session A Version 1 bytes are preserved.
- source-index.json: derived file/identity/profile/digest index, not authority.
  The package hash excludes session bodies; source digests cover exact UTF-8 bytes.
  Consistent digests do not prove historical freeze provenance or approval.
- review.json: the existing complete review transport. Open exported review in
  Studio and paste this complete file to open a SEPARATE READ-ONLY review.
  It never restores editable owners, drafts or revision reservations.

Extract the standard TAR archive with your computer's archive tool. For a local
operator in this repository, compile the extracted programme with the unchanged
compiler (replace the example path with the extracted file's absolute path):

    cd packages/cohort_plan_package
    dart run tool/compile_package.dart /absolute/path/programme.plan-package.yaml

Session YAML uses the already supported Founder grammar and EXACT fixed synthetic
exercise/profile identities. It is not real programme intake or general profile
support. The existing review validator recompiles every session and all slot
bindings when opening review.json. Do not run hosted import/publication commands
with these fixture files. Real content, general authoring coverage and Stage 2/launch
readiness require further work and separate applicable authority.
''';
}

/// Standard uncompressed USTAR container, stable order/metadata and UTF-8 bodies.
/// Paths are fixed/generated above. Intake accepts this bounded file set only.
Uint8List _tar(Map<String, String> files) {
  final output = BytesBuilder(copy: false);
  for (final e in files.entries) {
    final body = utf8.encode(e.value), header = Uint8List(512);
    void field(int offset, int width, String value) {
      final bytes = ascii.encode(value);
      if (bytes.length > width) throw StateError('Archive field too long.');
      header.setRange(offset, offset + bytes.length, bytes);
    }

    void octal(int offset, int width, int value) => field(
      offset,
      width,
      '${value.toRadixString(8).padLeft(width - 1, '0')}\x00',
    );
    field(0, 100, e.key);
    octal(100, 8, 420); // 0644, ordinary source file.
    octal(108, 8, 0);
    octal(116, 8, 0);
    octal(124, 12, body.length);
    octal(136, 12, 0);
    field(148, 8, '        ');
    field(156, 1, '0');
    field(257, 6, 'ustar\x00');
    field(263, 2, '00');
    final checksum = header.fold<int>(0, (sum, byte) => sum + byte);
    field(148, 8, '${checksum.toRadixString(8).padLeft(6, '0')}\x00 ');
    output.add(header);
    output.add(body);
    output.add(Uint8List((512 - body.length % 512) % 512));
  }
  output.add(Uint8List(1024));
  return output.takeBytes();
}
