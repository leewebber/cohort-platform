import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/persistence/athlete_persistence.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initResult = await SupabaseService.tryInitialize();
  await AthletePersistence.initialize();

  runApp(
    CohortPlatformApp(
      configurationError: initResult.isConfigured
          ? null
          : initResult.errorMessage,
    ),
  );
}
