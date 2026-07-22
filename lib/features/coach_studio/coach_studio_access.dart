import 'package:flutter/material.dart';

import '../../core/errors/user_facing_error_messages.dart';
import '../../core/services/authenticated_identity.dart';
import 'programmes/controllers/programme_catalogue_controller.dart';
import 'programmes/programme_catalogue_screen.dart';
import 'programmes/services/programme_catalogue_services.dart';
import 'coach_studio_home_screen.dart';
import 'models/coach_studio_navigation_state.dart';

/// Coach Studio entry with authenticated identity checks.
class CoachStudioAccess {
  CoachStudioAccess._();

  static ProgrammeCatalogueController createCatalogueController() {
    return ProgrammeCatalogueServices.createController();
  }

  static void open(BuildContext context) {
    try {
      final navigationState = CoachStudioNavigationState.instance;

      if (navigationState.shouldOpenProgrammesDirectly) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProgrammeCatalogueScreen(
              controller: createCatalogueController(),
            ),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CoachStudioHomeScreen(
            openProgrammesDirectly: navigationState.shouldOpenProgrammesDirectly,
          ),
        ),
      );
    } on AuthenticatedIdentityException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            UserFacingErrorMessages.from(error),
          ),
        ),
      );
    }
  }
}
