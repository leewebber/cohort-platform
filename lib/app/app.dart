import 'package:flutter/material.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/screens/auth_gate.dart';
import 'theme.dart';

class CohortPlatformApp extends StatefulWidget {
  const CohortPlatformApp({super.key});

  @override
  State<CohortPlatformApp> createState() => _CohortPlatformAppState();
}

class _CohortPlatformAppState extends State<CohortPlatformApp> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cohort Platform',
      debugShowCheckedModeBanner: false,
      theme: cohortTheme,
      home: AuthGate(controller: _authController),
    );
  }
}
