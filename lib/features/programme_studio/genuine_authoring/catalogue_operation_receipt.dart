import 'dart:convert';

import '../workspace_json.dart';
import 'native_session_source.dart';

/// Pins supplied by the separately authorised operator/audit handoff, never
/// read from the file being admitted or a founder-entered "published" flag.
class CatalogueOperationTrust {
  const CatalogueOperationTrust({
    required this.receiptSha256,
    required this.auditReference,
  });
  final String receiptSha256, auditReference;
}

/// Pure intake over the exact operator bundle. A deployment/audit owner must
/// establish the independent receipt pin first. No default trusted operation is
/// installed: the three genuine records remain unretained in this build.
class RetainedCatalogueOperation {
  RetainedCatalogueOperation._(this._receipt, this._rawReadback);
  final String _receipt, _rawReadback;
  Map<String, dynamic> get receipt => _readOperationJson(_receipt);
  Map<String, dynamic> get rawReadback => _readOperationJson(_rawReadback);

  static RetainedCatalogueOperation read(
    Map<String, String> files,
    CatalogueOperationTrust trust,
  ) {
    const requiredFiles = {
      'receipt.json',
      'manifest.json',
      'seed.sql',
      'apply.json',
      'preflight.raw.json',
      'readback.raw.json',
    };
    if (files.length != requiredFiles.length ||
        !requiredFiles.every(files.containsKey) ||
        nativeDigest(files['receipt.json']!) != trust.receiptSha256 ||
        trust.auditReference.isEmpty) {
      throw const FormatException(
        'Retain the complete operator bundle and its independently verified audit/digest first.',
      );
    }
    final receipt =
        workspaceObject(_readOperationJson(files['receipt.json']!), {
          'kind',
          'target_ref',
          'classification',
          'request_id',
          'audit_reference',
          'identity',
          'captured_at',
          'query_sha256',
          'source_sha256',
          'write_set_sha256',
          'files_sha256',
          'rows_sha256',
          'result_rows',
          'hosted_retention',
          'authority',
        }, 'catalogue operation receipt');
    if (receipt['kind'] != 'm11_catalogue_retention_receipt_v1' ||
        receipt['target_ref'] != 'otnhhdxstdnwccehacku' ||
        receipt['classification'] != 'AUTHENTICATED_OPERATOR_PREFLIGHT' ||
        receipt['hosted_retention'] != true ||
        receipt['query_sha256'] !=
            'cca4ad67b6e43a3ff87f34cff7607ff80585772e0c93398c685449f114bec75d' ||
        receipt['audit_reference'] != trust.auditReference ||
        receipt['source_sha256'] !=
            'f12b5df97f0a9dc813c9610021ee82233414d2e2b1e6187dd0ae09745e3ecdf5' ||
        receipt['write_set_sha256'] !=
            '7ebba83be9d35c26c73ad2202fd149f5909fa71619d3b1266e465b18b847a746') {
      throw const FormatException(
        'This is not the independently retained genuine three-setup operation. Synthetic rehearsal cannot bind exercises.',
      );
    }
    final hashes = workspaceObject(receipt['files_sha256'], {
      'manifest.json',
      'seed.sql',
      'apply.json',
      'preflight.raw.json',
      'readback.raw.json',
    }, 'receipt inventory');
    for (final e in hashes.entries) {
      if (nativeDigest(files[e.key]!) != e.value) {
        workspaceInvalid('Operator file digest differs.');
      }
    }
    final manifest = _readOperationJson(files['manifest.json']!);
    final readback = _readOperationJson(files['readback.raw.json']!);
    final applied = _readOperationJson(files['apply.json']!);
    final after = _readOperationJson(applied['after_raw'] as String);
    if (nativeDigest(_canonical(readback['rows'])) != receipt['rows_sha256']) {
      workspaceInvalid('Canonical catalogue row digest differs.');
    }
    if (manifest['request_id'] != receipt['request_id'] ||
        applied['request_id'] != receipt['request_id'] ||
        manifest['audit_reference'] != trust.auditReference ||
        !nativeEqual(readback['identity'], receipt['identity']) ||
        !nativeEqual(readback['identity'], manifest['preflight']['identity']) ||
        !nativeEqual(readback['rows'], after['rows']) ||
        !nativeEqual(
          readback['consumer_guard'],
          manifest['preflight']['consumer_guard'],
        )) {
      workspaceInvalid(
        'Operator authentication/readback/operation bindings differ.',
      );
    }
    final resultRows = workspaceObject(receipt['result_rows'], {
      'chest_supported_db_row',
      'seated_supported_db_press',
      'reverse_lunge_db',
    }, 'exact retained setups');
    final operations = workspaceList(
      manifest['operations'],
      'catalogue operations',
      max: 3,
    );
    if (operations.length != 3) {
      workspaceInvalid('Exactly three catalogue operations are required.');
    }
    final ids = <String>{};
    for (final op in operations) {
      final row = resultRows[op['source_variant']] as Map?;
      final fields = op['fields'] as Map;
      if (row == null ||
          row['published'] != true ||
          {'EX-026', 'EX-037', 'EX-090'}.contains(row['exercise_id']) ||
          !ids.add(row['exercise_id'] as String) ||
          !fields.entries.every((e) => nativeEqual(row[e.key], e.value)) ||
          !(readback['rows'] as List).any((r) => nativeEqual(r, row))) {
        workspaceInvalid(
          'Retained setup row differs from the exact operator payload.',
        );
      }
    }
    return RetainedCatalogueOperation._(
      files['receipt.json']!,
      files['readback.raw.json']!,
    );
  }

  LegacyCatalogueEvidence bind(LegacyCatalogueEvidence previous) {
    final intake = previous.source;
    final rows = intake['catalogue_rows'] as Map,
        bindings = intake['verified_bindings'] as Map;
    for (final entry in (receipt['result_rows'] as Map).entries) {
      final row = entry.value as Map, id = row['exercise_id'] as String;
      if (bindings.containsKey(entry.key) || rows.containsKey(id)) {
        workspaceInvalid('An existing exact binding cannot be overwritten.');
      }
      bindings[entry.key] = id;
      rows[id] = {
        'catalogue_row': row,
        'row_sha256': nativeDigest(_canonical(row)),
        'source_sha256': nativeDigest(_rawReadback),
        'source_path': 'readback.raw.json',
        'target_ref': receipt['target_ref'],
        'observed_at_utc': receipt['captured_at'],
        'operation_receipt_sha256': nativeDigest(_receipt),
        'audit_reference': receipt['audit_reference'],
        'canonical_definition_version': null,
        'publication_event': null,
      };
    }
    return LegacyCatalogueEvidence(intake);
  }
}

String _canonical(Object? value) =>
    jsonEncode(jsonDecode(encodeWorkspaceJson(value)));

// Full operator preflight rows are separate from the 2 MiB editable envelope.
Map<String, dynamic> _readOperationJson(String text) => readWorkspaceJson(
  text,
  maxBytes: 8 * 1024 * 1024,
  maxTextLength: 2 * 1024 * 1024,
  maxNodes: 300000,
);
