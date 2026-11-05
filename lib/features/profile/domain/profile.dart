/// Baris profil sendiri (public.profiles).
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.color,
    this.avatarUrl,
    this.email,
  });

  final String id;
  final String displayName;

  /// '#RRGGBB'.
  final String color;
  final String? avatarUrl;

  /// Email akun (auth.users), bila tersedia. Bukan kolom profiles.
  final String? email;

  Profile copyWith({String? displayName, String? color}) => Profile(
    id: id,
    displayName: displayName ?? this.displayName,
    color: color ?? this.color,
    avatarUrl: avatarUrl,
    email: email,
  );
}
