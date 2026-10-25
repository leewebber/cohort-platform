// Run only with flutter test and COHORT_PUBLICATION_REHEARSAL_DIR pointing to
// a task-owned temporary directory. Generates local fixtures, never real events.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/application/exercise_knowledge/published_version_retention.dart';
import 'package:cohort_platform/application/hyrox_base/session_source_compiler.dart';
import 'package:cohort_platform/domain/exercise_knowledge/in_memory/in_memory_exercise_knowledge_repository.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_definition.dart';

// Same seed convention as public.cohort_stable_uuid; not historical identity.
String localUuid(String seed) {
  final h = md5.convert(utf8.encode(seed)).toString();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-4${h.substring(12, 15)}-8${h.substring(16, 19)}-${h.substring(20, 32)}';
}

class _LocalFixtureAuthority implements ExerciseVersionPublicationAuthority {
  _LocalFixtureAuthority(this.events);
  final Map<String, Map<String, Object?>> events;
  @override
  Future<Map<String, Object?>?> verifiedPublicationFor(
    ExerciseDefinition d,
  ) async => events[d.id.value]?['publication'] as Map<String, Object?>?;
}

void main() {
  test(
    'prepare 48 complete local rehearsal sources without real authority',
    () async {
      final path = Platform.environment['COHORT_PUBLICATION_REHEARSAL_DIR'];
      if (path == null) {
        throw StateError('Task-owned temporary output required.');
      }
      final dir = Directory(path)..createSync(recursive: true);
      final resolved = dir.resolveSymbolicLinksSync();
      if (!resolved.startsWith('/private/tmp/') &&
          !resolved.startsWith('/private/var/folders/')) {
        throw StateError('Rehearsal output must remain temporary.');
      }
      final review =
          jsonDecode(
                File(
                  'docs/programmes/hyrox_base/PRODUCER_REVIEW_BUNDLE.json',
                ).readAsStringSync(),
              )
              as Map;
      final authored =
          jsonDecode(
                File(
                  'docs/programmes/hyrox_base/SESSIONS.json',
                ).readAsStringSync(),
              )
              as Map;
      final repo = InMemoryExerciseKnowledgeRepository();
      final definitions = <Map<String, Object?>>[];
      final byKey = <String, Map<String, Object?>>{};
      final events = <String, Map<String, Object?>>{};
      var n = 0;
      for (final raw in review['definitions'] as List) {
        final row = raw as Map;
        final content = Map<String, Object?>.from(
          row['definition_content'] as Map,
        );
        final id = 'EX-${901000 + n++}';
        final published = {
          ...content,
          'id': id,
          'version': '1',
          'lifecycle_status': 'published',
          'published_at': '2026-10-25T00:00:00Z',
          'canonical_name': 'LOCAL REHEARSAL: ${content['canonical_name']}',
        };
        final d = ExerciseDefinition.fromJson(published);
        final publication = <String, Object?>{
          'issuer': 'founder_exercise_publication_v1',
          'event_id': localUuid(
            'local-only:hyrox:exercise:${row['definition_key']}',
          ),
          'source_reference':
              'LOCAL-REHEARSAL-NOT-REAL-APPROVAL:${row['definition_key']}',
          'published_at': '2026-10-25T00:00:00Z',
          'approved_binding_kinds': row['required_binding_kinds'],
        };
        final entry = <String, Object?>{
          'definition_key': row['definition_key'],
          'exercise_id': id,
          'canonical_text': personalisationCanonicalJson(d.toJson()),
          'publication': publication,
          'content_digest': personalisationDigest(d.toJson()),
          'definition_version': '1',
        };
        definitions.add(entry);
        byKey[row['definition_key'] as String] = entry;
        events[id] = entry;
        repo.upsertDefinition(d);
      }
      final pins = <String, SessionExerciseVersionPin>{};
      for (final raw in review['bindings'] as List) {
        final r = raw as Map;
        final d = byKey[r['definition_key']]!;
        pins[r['authored_label'] as String] = SessionExerciseVersionPin(
          d['exercise_id'] as String,
          '1',
          d['content_digest'] as String,
        );
      }
      final compiler = CanonicalSessionSourceCompiler(
        lookup: repo,
        publicationAuthority: _LocalFixtureAuthority(events),
        pins: pins,
      );
      final sources = <Map<String, Object?>>[];
      for (final raw in authored['sessions'] as List) {
        final input = Map<String, dynamic>.from(raw as Map);
        final compiled = await compiler.compile(
          personalisationCanonicalJson(input),
        );
        expect(
          (await compiler.reopen(compiled.exportSource())).exportSource(),
          compiled.exportSource(),
        );
        final key = input['source_id'] as String;
        final protocol = 'LOCAL-HYROX-${key.substring(5)}-R1';
        final blocks = <Map<String, Object?>>[];
        for (final rawBlock in compiled.graph['blocks'] as List) {
          final b = Map<String, Object?>.from(rawBlock as Map);
          b.remove('local_source_block');
          b['block_id'] = localUuid('$protocol:block:${b['position']}');
          b['session_id'] = protocol;
          final links = <Map<String, Object?>>[];
          for (final rawLink in b['exercises'] as List) {
            final e = Map<String, Object?>.from(rawLink as Map);
            e['id'] = localUuid(
              '$protocol:ex:${b['position']}:${e['position']}',
            );
            e['block_id'] = b['block_id'];
            e.putIfAbsent('prescription', () => null);
            links.add(e);
          }
          b['exercises'] = links;
          blocks.add(b);
        }
        sources.add({
          'source_id': key,
          'input_sha256': compiled.sourceDigest,
          'week': input['week'],
          'day': input['day'],
          'mode': input['mode'],
          'title': 'LOCAL REHEARSAL: ${compiled.execution.sessionTitle}',
          'source': {
            'session_key': key.toLowerCase().replaceAll('_', '-'),
            'protocol_id': protocol,
            'session_lineage_id': localUuid('local-only:lineage:$key'),
            'revision_number': 1,
            'blocks': blocks,
          },
          'binding_intents': input['binding_intents'],
          'logical_steps': [
            for (final b in input['blocks'] as List)
              if (b['steps'] is List) ...b['steps'] as List,
          ],
          'authored_source': input,
        });
      }
      expect(definitions.length, 27);
      expect(sources.length, 48);
      final output = {
        'classification': 'LOCAL_REHEARSAL_ONLY_NOT_AUTHORITATIVE',
        'definitions': definitions,
        'label_bindings': {
          for (final r in review['bindings'] as List)
            r['authored_label']: byKey[r['definition_key']]!['exercise_id'],
        },
        'sources': sources,
        'schedule': authored['schedule'],
        'policies': authored['policies'],
      };
      File(
        '${dir.path}/prepared.json',
      ).writeAsStringSync(personalisationCanonicalJson(output));
    },
  );
}
