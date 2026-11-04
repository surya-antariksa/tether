/// Baris profil sendiri (public.profiles).
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.color,
    this.avatarUrl,
  });

  final String id;
  final String displayName;

  /// '#RRGGBB'.
  final String color;
  final String? avatarUrl;

  Profile copyWith({String? displayName, String? color}) => Profile(
    id: id,
    displayName: displayName ?? this.displayName,
    color: color ?? this.color,
    avatarUrl: avatarUrl,
  );
}
