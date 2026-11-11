/// A signed-in FollowBoost user.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.coins,
    this.isAdmin = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        isAdmin: json['isAdmin'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'coins': coins,
        'isAdmin': isAdmin,
      };

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    int? coins,
    bool? isAdmin,
  }) =>
      AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        coins: coins ?? this.coins,
        isAdmin: isAdmin ?? this.isAdmin,
      );

  final String id;
  final String name;
  final String email;
  final int coins;
  final bool isAdmin;
}
