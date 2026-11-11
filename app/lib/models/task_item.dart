/// An engagement task: follow or like a profile to earn coins.
/// Follows are MANUAL — the user opens the profile in Instagram and
/// confirms they followed. No automation, no passwords.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.type,
    required this.handle,
    required this.displayName,
    required this.avatarColor,
    required this.coins,
    this.availableAt,
    this.orderId,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? 'follow',
        handle: json['handle'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        avatarColor: json['avatarColor'] as String? ?? '#7C3AED',
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        availableAt: json['availableAt'] == null
            ? null
            : DateTime.tryParse(json['availableAt'] as String),
        orderId: json['orderId']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'handle': handle,
        'displayName': displayName,
        'avatarColor': avatarColor,
        'coins': coins,
        'availableAt': availableAt?.toIso8601String(),
        'orderId': orderId,
      };

  /// True when this task was generated from a user's order (pays 1 coin).
  bool get isOrderTask => orderId != null;

  /// True while the 24h per-task cooldown is still running.
  bool get isOnCooldown =>
      availableAt != null && availableAt!.isAfter(DateTime.now());

  /// Remaining cooldown, or null when the task is available.
  Duration? get cooldownRemaining =>
      isOnCooldown ? availableAt!.difference(DateTime.now()) : null;

  final String id;
  final String type; // 'follow' | 'like'
  final String handle;
  final String displayName;
  final String avatarColor; // hex, e.g. '#7C3AED'
  final int coins;
  final DateTime? availableAt;
  /// The order this task fulfils, if any (null for seeded house tasks).
  final String? orderId;
}
