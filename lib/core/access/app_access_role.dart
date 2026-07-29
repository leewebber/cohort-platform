/// Application-level experience role.
///
/// Distinct from [UserRole] coach/athlete profile flags.
/// Coach-only strings on a profile never imply [founder].
enum AppAccessRole {
  athlete,
  founder,
}
