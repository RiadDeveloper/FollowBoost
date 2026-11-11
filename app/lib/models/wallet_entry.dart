/// One wallet ledger entry.
class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> json) => WalletEntry(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? 'earn',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'reason': reason,
        'createdAt': createdAt?.toIso8601String(),
      };

  final String id;
  final String type; // 'earn' | 'spend'
  final int amount;
  final String reason;
  final DateTime? createdAt;
}
