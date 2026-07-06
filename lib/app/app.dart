import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import 'theme.dart';

class CohortPlatformApp extends StatelessWidget {
  const CohortPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cohort Platform',
      debugShowCheckedModeBanner: false,
      theme: cohortTheme,
      home: const HomeScreen(),
    );
  }
}