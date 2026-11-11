/// One row of the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.coins,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        coins: (json['coins'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'rank': rank, 'name': name, 'coins': coins};

  final int rank;
  final String name;
  final int coins;
}
