import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bali is privately assignable only after publication', () {
    final publication =
        jsonDecode(
              File(
                'content/programmes/bali_hybrid_base/v1/bali_hybrid_base.publication.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(publication['library_scope'], 'coach_private');
    expect(publication['public_catalogue'], isFalse);
    expect(publication['publication_kind'], 'private_exact_version');
    expect(publication['assignable_after'], 'private_publication');
    expect(publication['hosted_publication_established'], isFalse);

    final compiled = const PlanPackageCompiler().compile(
      File('tool/programmes/bali_hybrid_base_v1.plan-package.yaml').readAsStringSync(),
    );
    expect(compiled.manifest!.programme.libraryScope, ProgrammeLibraryScope.coachPrivate);
    expect(compiled.manifest!.programme.libraryScope.dbValue, 'coach_private');
  });
}
