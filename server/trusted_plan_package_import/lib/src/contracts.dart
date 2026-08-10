import 'package:cohort_plan_package/cohort_plan_package.dart';

class AuthenticatedPrincipal {
  const AuthenticatedPrincipal({required this.userId, required this.email});

  final String userId;
  final String email;
}

abstract interface class AuthTokenVerifier {
  Future<AuthenticatedPrincipal?> verifyBearerToken(String token);
}

abstract interface class FounderAuthorityVerifier {
  Future<bool> isAuthorisedFounder(AuthenticatedPrincipal principal);
}

abstract interface class PlanPackageImportRpc {
  Future<PlanPackageImportResult> importPackage(
    Map<String, Object?> compilerDerivedPayload,
  );
}

class TrustedAuthenticationException implements Exception {
  const TrustedAuthenticationException();
}

class FounderAuthorityLookupException implements Exception {
  const FounderAuthorityLookupException();
}

class PlanPackageRpcException implements Exception {
  const PlanPackageRpcException();
}
