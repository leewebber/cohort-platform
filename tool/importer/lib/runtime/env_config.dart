import 'dart:io';

import 'package:dotenv/dotenv.dart';

class EnvConfig {
  EnvConfig._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.importEmail,
    this.importPassword,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? importEmail;
  final String? importPassword;

  static EnvConfig load({String fileName = '.env'}) {
    final env = DotEnv(includePlatformEnvironment: true)..load([fileName]);

    final url = env['SUPABASE_URL']?.trim();
    final anonKey = env['SUPABASE_ANON_KEY']?.trim();

    if (url == null ||
        url.isEmpty ||
        anonKey == null ||
        anonKey.isEmpty ||
        url.contains('your-project') ||
        anonKey.contains('your-anon-key')) {
      throw EnvConfigException(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be set in $fileName.',
      );
    }

    return EnvConfig._(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      importEmail: env['SUPABASE_IMPORT_EMAIL']?.trim(),
      importPassword: env['SUPABASE_IMPORT_PASSWORD']?.trim(),
    );
  }

  static EnvConfig loadFromWorkspace({String? workspaceRoot}) {
    final root = workspaceRoot ?? _findWorkspaceRoot();
    if (root != null) {
      final envFile = File('$root/.env');
      if (envFile.existsSync()) {
        return load(fileName: envFile.path);
      }
    }
    return load();
  }

  static String? _findWorkspaceRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 8; i++) {
      if (File('${dir.path}/pubspec.yaml').existsSync() &&
          File('${dir.path}/.env').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}

class EnvConfigException implements Exception {
  EnvConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}
