import '../../models/programme.dart';
import '../../models/programme_session.dart';
import '../../models/programme_week.dart';
import 'base_repository.dart';

class ProgrammeRepository extends BaseRepository<Programme> {
  @override
  String get tableName => 'programmes';

  @override
  Programme fromMap(Map<String, dynamic> map) {
    return Programme.fromMap(map);
  }

  Future<List<Programme>> getProgrammes() {
    return getWhere(
      column: 'published',
      value: true,
      orderBy: 'name',
    );
  }

  Future<Programme?> getProgrammeById(String programmeId) async {
    final results = await getWhere(
      column: 'programme_id',
      value: programmeId,
    );

    if (results.isEmpty) return null;

    return results.first;
  }
}

class ProgrammeWeekRepository
    extends BaseRepository<ProgrammeWeek> {
  @override
  String get tableName => 'programme_weeks';

  @override
  ProgrammeWeek fromMap(Map<String, dynamic> map) {
    return ProgrammeWeek.fromMap(map);
  }

  Future<List<ProgrammeWeek>> getWeeksForProgramme(
    String programmeId,
  ) {
    return getWhere(
      column: 'programme_id',
      value: programmeId,
      orderBy: 'week_number',
    );
  }
}

class ProgrammeSessionRepository
    extends BaseRepository<ProgrammeSession> {
  @override
  String get tableName => 'programme_sessions';

  @override
  ProgrammeSession fromMap(Map<String, dynamic> map) {
    return ProgrammeSession.fromMap(map);
  }

  Future<List<ProgrammeSession>> getSessionsForProgramme(
    String programmeId,
  ) {
    return getWhere(
      column: 'programme_id',
      value: programmeId,
      orderBy: 'week_number',
    );
  }
}