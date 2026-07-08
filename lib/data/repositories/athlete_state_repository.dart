import '../../models/athlete_state.dart';
import 'base_repository.dart';

class AthleteStateRepository extends BaseRepository<AthleteState> {
  const AthleteStateRepository();

  @override
  String get tableName => 'athlete_state';

  @override
  AthleteState fromMap(Map<String, dynamic> map) {
    return AthleteState.fromMap(map);
  }

  Future<AthleteState?> getAthleteState(String athleteId) async {
    final results = await getWhere(
      column: 'athlete_id',
      value: athleteId,
    );

    if (results.isEmpty) return null;

    return results.first;
  }
}
