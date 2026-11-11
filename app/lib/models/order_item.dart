/// An order placed by the user: spend coins to receive followers/likes.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.type,
    required this.targetHandle,
    required this.count,
    required this.cost,
    required this.status,
    required this.createdAt,
    this.fulfilled = 0,
    this.ownerName,
    this.ownerEmail,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? 'follow',
        targetHandle: json['targetHandle'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        cost: (json['cost'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'queued',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        fulfilled: (json['fulfilled'] as num?)?.toInt() ?? 0,
        ownerName: json['ownerName'] as String?,
        ownerEmail: json['ownerEmail'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'targetHandle': targetHandle,
        'count': count,
        'cost': cost,
        'status': status,
        'createdAt': createdAt?.toIso8601String(),
        'fulfilled': fulfilled,
        'ownerName': ownerName,
        'ownerEmail': ownerEmail,
      };

  final String id;
  final String type; // 'follow' | 'like'
  final String targetHandle;
  final int count;
  final int cost;
  /// 'queued' | 'partial' | 'completed'
  final String status;
  final DateTime? createdAt;
  /// How many of [count] have been fulfilled by other users.
  final int fulfilled;
  /// Only filled in the admin order list.
  final String? ownerName;
  /// Only filled in the admin order list.
  final String? ownerEmail;
}
