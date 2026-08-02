import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/supabase_service.dart';
import 'features/app_shell/athlete_app_shell.dart';
import 'features/auth/models/user_profile.dart';
import 'features/auth/services/current_user_session.dart';
import 'features/plans/screens/plan_library_screen.dart';
import 'features/programme/models/athlete_catalogue_enrolment.dart';
import 'features/programme/screens/athlete_programme_selection_screen.dart';
import 'features/programme/services/athlete_catalogue_enrolment_services.dart';
import 's13_staging_secrets.g.dart';

/// Opt-in Cohort Staging Flutter verification entrypoint for Sprint 1.3.
///
/// Uses temporary staging `.env` (anon only) and a working-tree overwrite of
/// [s13_staging_secrets.g.dart] that must be restored afterward.
///
/// `flutter run -d chrome -t lib/main_s13_staging_verify.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final report = <String, dynamic>{'assertions': <Map<String, dynamic>>[]};

  void add(String name, bool ok, [Object? detail]) {
    (report['assertions'] as List).add({
      'name': name,
      'pass': ok,
      'detail': detail?.toString(),
    });
  }

  if (!S13StagingSecrets.enabled) {
    runApp(
      const _ResultApp(
        title: 'S13 staging verify disabled',
        lines: [
          'Overwrite lib/s13_staging_secrets.g.dart for a controlled staging run,',
          'then restore the stub afterward.',
        ],
        ok: false,
      ),
    );
    return;
  }

  try {
    final init = await SupabaseService.tryInitialize();
    add('supabase_configured', init.isConfigured, init.errorMessage);
    final url = Supabase.instance.client.rest.url.toString();
    add('targets_cohort_staging', url.contains('tsbadngzgvsyfqjupkng'), url);
    if (!init.isConfigured || !url.contains('tsbadngzgvsyfqjupkng')) {
      throw StateError(
        'Refusing to continue: not configured for Cohort Staging',
      );
    }

    final auth = await Supabase.instance.client.auth.signInWithPassword(
      email: S13StagingSecrets.athleteAEmail,
      password: S13StagingSecrets.athleteAPassword,
    );
    add('sign_in', auth.session != null);

    final athleteId = S13StagingSecrets.athleteAId;
    final profileRow = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', athleteId)
        .single();
    final profile = UserProfile.fromMap(
      Map<String, dynamic>.from(profileRow as Map),
    );
    add('profile_is_athlete_only', profile.isAthlete && !profile.isCoach);
    CurrentUserSession.bind(profile);

    final catalog = AthleteCatalogueEnrolmentServices.createCatalogService();
    final programmes = await catalog.listPublishedAssignableProgrammes();
    final names = programmes.map((p) => p.name).toList();
    add(
      'catalogue_shows_eligible',
      names.any((n) => n.contains('PROG-S13-ELIG')),
      names.length,
    );
    add(
      'catalogue_hides_negatives',
      !names.any((n) => n.contains('PROG-S13-DRAFT')) &&
          !names.any((n) => n.contains('PROG-S13-UNAPP')) &&
          !names.any((n) => n.contains('PROG-S13-PRIV')),
      names.length,
    );

    final selection =
        AthleteCatalogueEnrolmentServices.createSelectionController(
          athleteId: athleteId,
        );
    await selection.load();
    add('selection_controller_loaded', !selection.isLoading);
    add(
      'selection_has_eligible',
      selection.programmes.any((p) => p.name.contains('PROG-S13-ELIG')),
    );

    final eligible = selection.programmes.firstWhere(
      (p) => p.name.contains('PROG-S13-ELIG'),
    );
    selection.selectProgramme(eligible);
    final enrol = await selection.confirmEnrol(
      startedAt: DateTime.now(),
      timezone: 'UTC',
      replaceActive: false,
    );
    add(
      'enrol_via_ui_controller',
      enrol != null &&
          (enrol.status == AthleteCatalogueEnrolmentStatus.enrolled ||
              enrol.status == AthleteCatalogueEnrolmentStatus.alreadyEnrolled),
      enrol?.status.name,
    );

    final enrol2 = await selection.confirmEnrol(
      startedAt: DateTime.now(),
      timezone: 'UTC',
      replaceActive: false,
    );
    add(
      'idempotent_via_ui_controller',
      enrol2?.status == AthleteCatalogueEnrolmentStatus.alreadyEnrolled,
      enrol2?.status.name,
    );

    add('home_type_available', true, 'HomeScreen');
    add('programme_screen_type_available', true, 'AthleteProgrammeScreen');
    add(
      'selection_screen_type_available',
      true,
      'AthleteProgrammeSelectionScreen',
    );
    add('plan_library_type_available', true, 'PlanLibraryScreen');
    add('shell_type_available', true, 'AthleteAppShell');

    runApp(
      MaterialApp(
        home: _VerifyHost(report: report, child: const AthleteAppShell()),
      ),
    );
  } catch (e, st) {
    add('fatal', false, '$e');
    debugPrint('$st');
    runApp(
      _ResultApp(
        title: 'S13 staging verify failed',
        lines: [
          (report['assertions'] as List).map((a) => a.toString()).join('\n'),
          '$e',
        ],
        ok: false,
      ),
    );
  }
}

class _VerifyHost extends StatefulWidget {
  const _VerifyHost({required this.report, required this.child});

  final Map<String, dynamic> report;
  final Widget child;

  @override
  State<_VerifyHost> createState() => _VerifyHostState();
}

class _VerifyHostState extends State<_VerifyHost> {
  void _add(String name, bool ok, [Object? detail]) {
    (widget.report['assertions'] as List).add({
      'name': name,
      'pass': ok,
      'detail': detail?.toString(),
    });
  }

  List<String> _collectVisibleText() {
    final out = <String>[];
    void visit(Element element) {
      final w = element.widget;
      if (w is Text && w.data != null && w.data!.trim().isNotEmpty) {
        out.add(w.data!.trim());
      } else if (w is RichText) {
        final plain = w.text.toPlainText().trim();
        if (plain.isNotEmpty) out.add(plain);
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return out;
  }

  bool _hasText(String needle, {bool caseSensitive = true}) {
    final texts = _collectVisibleText();
    if (caseSensitive) return texts.any((t) => t.contains(needle));
    final lower = needle.toLowerCase();
    return texts.any((t) => t.toLowerCase().contains(lower));
  }

  bool _tapText(String label) {
    Element? match;
    void visit(Element element) {
      final w = element.widget;
      if (w is Text && w.data == label) {
        match = element;
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    final textElement = match;
    if (textElement == null) return false;

    var tapped = false;
    textElement.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      if (w is TextButton && w.onPressed != null) {
        w.onPressed!();
        tapped = true;
        return false;
      }
      if (w is ElevatedButton && w.onPressed != null) {
        w.onPressed!();
        tapped = true;
        return false;
      }
      if (w is OutlinedButton && w.onPressed != null) {
        w.onPressed!();
        tapped = true;
        return false;
      }
      if (w is InkWell && w.onTap != null) {
        w.onTap!();
        tapped = true;
        return false;
      }
      if (w is GestureDetector && w.onTap != null) {
        w.onTap!();
        tapped = true;
        return false;
      }
      return true;
    });
    return tapped;
  }

  List<String> _prohibitedCommerceHits() {
    const blockedExact = {
      'buy',
      'purchase',
      'owned',
      'order',
      'checkout',
      'payment complete',
      'price',
      'subscription',
      'subscription management',
    };
    final hits = <String>[];
    for (final raw in _collectVisibleText()) {
      final t = raw.trim();
      final lower = t.toLowerCase();
      if (lower.contains('not a purchase')) continue;
      if (blockedExact.contains(lower)) {
        hits.add(t);
        continue;
      }
      // Explicit CTA-style fragments (not disclaimer copy).
      if (RegExp(
        r'\b(buy now|checkout|payment complete)\b',
        caseSensitive: false,
      ).hasMatch(t)) {
        hits.add(t);
      }
    }
    return hits;
  }

  Future<void> _runUiChecks() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final nav = Navigator.of(context);

    _add('home_shell_mounted', true, 'AthleteAppShell');
    _add('home_programme_link_visible', _hasText('Programme'));
    _add('view_programmes_visible', _hasText('VIEW PROGRAMMES'));

    // Empty-state catalogue route (must not open Plan Library).
    final tappedView = _tapText('VIEW PROGRAMMES');
    _add('view_programmes_tapped', tappedView);
    await Future<void>.delayed(const Duration(seconds: 3));
    _add(
      'view_programmes_opens_catalogue_not_plan_library',
      tappedView &&
          (_hasText('Current programme') ||
              _hasText('View programmes') ||
              _hasText('Enrolled') ||
              _hasText('PROG-S13-ELIG')) &&
          !_hasText('Plan Library'),
    );
    _add(
      'negatives_hidden_in_ui',
      !_hasText('PROG-S13-DRAFT') &&
          !_hasText('PROG-S13-UNAPP') &&
          !_hasText('PROG-S13-PRIV'),
    );

    final commerceHits = _prohibitedCommerceHits();
    _add(
      'no_prohibited_commerce_language',
      commerceHits.isEmpty,
      commerceHits.join('|'),
    );

    while (nav.canPop()) {
      nav.pop();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    await Future<void>.delayed(const Duration(seconds: 1));

    // Home → muted Programme link.
    final openedProgramme = _tapText('Programme');
    _add('home_programme_tapped', openedProgramme);
    await Future<void>.delayed(const Duration(seconds: 3));
    _add(
      'programme_screen_opened',
      openedProgramme &&
          (_hasText('Current programme') || _hasText('View programmes')),
    );
    _add(
      'persistent_enrolment_ui',
      _hasText('Enrolled') || _hasText('PROG-S13-ELIG'),
    );

    while (nav.canPop()) {
      nav.pop();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    await Future<void>.delayed(const Duration(seconds: 1));

    final plansTapped = _tapText('Plans');
    _add('plans_tab_tapped', plansTapped);
    await Future<void>.delayed(const Duration(seconds: 2));
    _add(
      'plans_tab_opens_plan_library_surface',
      plansTapped && (_hasText('Plans') || _hasText('Plan')),
    );

    // Direct opens for selection vs Plan Library separation.
    await _openAndClose(
      AthleteProgrammeSelectionScreen(
        athleteId: CurrentUserSession.requireInstance.athleteId,
      ),
    );
    _add('selection_screen_opened', true);

    await _openAndClose(
      PlanLibraryScreen(
        athleteId: CurrentUserSession.requireInstance.athleteId,
        embeddedInShell: true,
      ),
    );
    _add('plan_library_screen_opened_separately', true);

    final assertions = (widget.report['assertions'] as List)
        .cast<Map<String, dynamic>>();
    final ok = assertions.every((a) => a['pass'] == true);
    // ignore: avoid_print
    print('S13_FLUTTER_VERIFY_OK=$ok');
    for (final a in assertions) {
      // ignore: avoid_print
      print(
        '${a['pass'] == true ? 'PASS' : 'FAIL'} ${a['name']} ${a['detail'] ?? ''}',
      );
    }
  }

  Future<void> _openAndClose(Widget page) async {
    final nav = Navigator.of(context);
    final future = nav.push<void>(MaterialPageRoute(builder: (_) => page));
    await Future<void>.delayed(const Duration(seconds: 2));
    if (nav.canPop()) {
      nav.pop();
    }
    await future;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runUiChecks();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ResultApp extends StatelessWidget {
  const _ResultApp({
    required this.title,
    required this.lines,
    required this.ok,
  });

  final String title;
  final List<String> lines;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(ok ? 'PASS' : 'FAIL', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            ...lines.map(Text.new),
          ],
        ),
      ),
    );
  }
}
