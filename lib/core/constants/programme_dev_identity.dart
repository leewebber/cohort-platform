/// Development identity constants aligned with Programme Engine RLS policies.
///
/// Replace with Supabase Auth `auth.uid()` before external beta.
/// See `supabase/migrations/20260715130000_add_programme_engine_dev_policies.sql`.
class ProgrammeDevIdentity {
  ProgrammeDevIdentity._();

  static const athleteId = 'lee';

  static const coachId = 'dev-coach';
}
