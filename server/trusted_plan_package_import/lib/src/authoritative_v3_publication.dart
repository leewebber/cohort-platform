import 'dart:convert';
import 'contracts.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';

/// Configured on the trusted publication host, never constructed from an HTTP
/// request document. SQL resolves published versions and physical source itself.
abstract interface class V3PublicationAuthority {
  Future<Map<String, Object?>> resolveCanonicalSource(String canonicalText);
  Future<Map<String, Object?>> publishPrivateVersion(
    Map<String, Object?> payload,
  );
}

/// Extension of the existing compiler/private publication boundary. Generic
/// draft import stays v1/v2-only; this explicit path requires authority resolution.
class AuthoritativeV3Publication {
  const AuthoritativeV3Publication(this.authority);
  final V3PublicationAuthority authority;

  Future<Map<String, Object?>> publish({
    required String source,
    required String programmeVersionId,
    required String ownerId,
    required String importedBy,
    String? approvedContentHash,
  }) async {
    if (utf8.encode(source).length > 1024 * 1024) {
      throw const FormatException('V3 source exceeds the trusted input bound.');
    }
    // Provisional canonicalisation is internal only. It grants no admission,
    // publication credentials, consent or returnable successful compile receipt.
    final provisional = const PlanPackageCompiler(
      validator: PlanPackageValidator(personalisationResolver: _Pending()),
    ).compile(source);
    if (!provisional.isValid ||
        provisional.manifest?.packageSchemaVersion != 3) {
      throw const FormatException('Invalid v3 source.');
    }
    final resolved = await authority.resolveCanonicalSource(
      provisional.canonicalJson!,
    );
    final compile = PlanPackageCompiler(
      validator: PlanPackageValidator(
        personalisationResolver: RetainedV3Resolver(resolved),
      ),
    ).verifyCanonicalArtifact(provisional.canonicalJson!);
    if (!compile.isValid ||
        (approvedContentHash != null &&
            compile.contentHashSha256 != approvedContentHash)) {
      throw const FormatException('Unresolved authoritative v3 source.');
    }
    final canonical =
        jsonDecode(compile.canonicalJson!) as Map<String, dynamic>;
    final programme = Map<String, Object?>.from(canonical['programme'] as Map);
    final scope = programme.remove('library_scope');
    programme.remove('owner_type');
    final graphs = <Object?>[];
    for (final raw in resolved['sessions']! as List) {
      final session = raw as Map;
      graphs.add({
        'protocol_id': session['protocol_id'],
        'blocks': [
          for (final rawBlock in session['blocks'] as List)
            _graphBlock(rawBlock as Map),
        ],
      });
    }
    return authority.publishPrivateVersion({
      for (final entry in canonical.entries)
        if (!{'programme', 'personalisation_binding'}.contains(entry.key))
          entry.key: entry.value,
      'package_canonical_json': compile.canonicalJson!,
      'package_content_hash': compile.contentHashSha256!,
      'programme': programme,
      'publication_kind': 'private_exact_version',
      'programme_version_id': programmeVersionId,
      'library_scope': scope,
      'owner_id': ownerId,
      'imported_by': importedBy,
      'protocol_graphs': graphs,
    });
  }

  static Map<String, Object?> _graphBlock(Map block) => {
    for (final key in [
      'position',
      'block_type',
      'title',
      'content',
      'workout_format',
      'timer_config',
      'coach_notes',
      'performance_capture_mode',
    ])
      key: block[key],
    'exercises': [
      for (final raw in block['exercises'] as List)
        {
          for (final entry in (raw as Map).entries)
            if (!{'id', 'block_id'}.contains(entry.key))
              entry.key as String: entry.value,
        },
    ],
  };
}

class _Pending implements PersonalisationDependencyResolver {
  const _Pending();
  @override
  String? validateTarget(PlanPackagePersonalisationTarget target) => null;
}

/// Recompiles only against a resolved bundle returned by the configured trusted
/// boundary. Supplying a lookalike bundle cannot register SQL publication authority.
class RetainedV3Resolver implements PersonalisationDependencyResolver {
  const RetainedV3Resolver(this.bundle);
  final Map<String, Object?> bundle;
  @override
  String? validateTarget(PlanPackagePersonalisationTarget t) {
    try {
      final dependency = (bundle['dependencies']! as List)
          .cast<Map>()
          .singleWhere((x) => x['target_id'] == t.id);
      final exercise = dependency['exercise'] as Map;
      final rule = dependency['rule'] as Map;
      final benchmark = dependency['benchmark'] as Map;
      if (t.identityNamespace != 'canonical_exercise' ||
          exercise['exercise_id'] != t.exercise.id ||
          exercise['definition_version'] != t.exercise.version.toString() ||
          exercise['content_digest'] != t.exercise.digest ||
          personalisationDigest(
                jsonDecode(exercise['canonical_text'] as String),
              ) !=
              t.exercise.digest ||
          !((exercise['publication'] as Map)['approved_binding_kinds'] as List)
              .contains(t.kind.name) ||
          rule['id'] != t.rule.id ||
          rule['version'] != t.rule.version ||
          personalisationDigest(rule) != t.rule.digest ||
          benchmark['id'] != t.benchmark.id ||
          benchmark['version'] != t.benchmark.version ||
          personalisationDigest(benchmark) != t.benchmark.digest ||
          rule['input_unit'] != t.inputUnit.name ||
          rule['output_unit'] != t.outputUnit.name) {
        return 'unresolved_dependency';
      }
      final week = Map<String, Object?>.from(
        (rule['weeks'] as List)[t.weekNumber - 1] as Map,
      )..remove('week');
      if (personalisationCanonicalJson(week) !=
          personalisationCanonicalJson(t.parameters)) {
        return 'unapproved_parameters';
      }
      final session = (bundle['sessions']! as List).cast<Map>().singleWhere(
        (x) => x['session_key'] == t.sessionKey,
      );
      if (session['protocol_id'] != t.protocolId ||
          session['revision_number'] != t.protocolRevision ||
          personalisationDigest(session) != t.sessionBodyDigest) {
        return 'unresolved_source';
      }
      final block = (session['blocks'] as List).cast<Map>().singleWhere(
        (x) => x['block_id'] == t.blockId,
      );
      final exercises = (block['exercises'] as List).cast<Map>();
      if (exercises.length != 1 ||
          exercises.single['exercise_id'] != t.exercise.id) {
        return 'wrong_block';
      }
      return null;
    } catch (_) {
      return 'unresolved_authoritative_source';
    }
  }
}

/// Founder-authenticated facade reused by the explicit, configured HTTP path.
/// The legacy global-draft endpoint remains v1/v2-only.
class TrustedV3FounderPublication {
  const TrustedV3FounderPublication({
    required this.auth,
    required this.founder,
    required this.publication,
  });
  final AuthTokenVerifier auth;
  final FounderAuthorityVerifier founder;
  final AuthoritativeV3Publication publication;
  Future<AuthenticatedPrincipal> requireFounder(String bearerToken) async {
    final principal = await auth.verifyBearerToken(bearerToken);
    if (principal == null) throw const InvalidFounderCredentials();
    if (!await founder.isAuthorisedFounder(principal)) {
      throw const FounderPermissionRequired();
    }
    return principal;
  }

  Future<Map<String, Object?>> publish({
    required String bearerToken,
    required String source,
    required String programmeVersionId,
    required String ownerId,
  }) async {
    final principal = await requireFounder(bearerToken);
    return publication.publish(
      source: source,
      programmeVersionId: programmeVersionId,
      ownerId: ownerId,
      importedBy: principal.userId,
    );
  }
}
