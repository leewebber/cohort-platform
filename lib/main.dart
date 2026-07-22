import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initResult = await SupabaseService.tryInitialize();

  runApp(
    CohortPlatformApp(
      configurationError:
          initResult.isConfigured ? null : initResult.errorMessage,
    ),
  );
}
