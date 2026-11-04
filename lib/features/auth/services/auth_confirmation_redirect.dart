import 'package:flutter/foundation.dart';

/// Native callback consumed by the existing supabase_flutter/app_links handler.
/// The provider must allowlist this exact URI before distributing the client.
const cohortNativeAuthCallback = 'cohortplatform://auth-callback';

String? authConfirmationRedirect({
  required bool isWeb,
  required TargetPlatform platform,
}) =>
    !isWeb &&
        const {
          TargetPlatform.iOS,
          TargetPlatform.android,
          TargetPlatform.macOS,
        }.contains(platform)
    ? cohortNativeAuthCallback
    : null;
