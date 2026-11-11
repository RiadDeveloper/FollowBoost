import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/staggered_item.dart';

/// Leaderboard: ranked list with a top-3 highlight.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.session.api.leaderboard();
      if (mounted) setState(() => _entries = entries);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _rankColor(int rank) {
    return switch (rank) {
      1 => AppTheme.gold,
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppTheme.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final myName = widget.session.user.value?.name;
    return Scaffold(
      appBar: gradientAppBar('Leaderboard'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.pink),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.pink,
              child: _entries.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            'No leaderboard yet.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = _entries[i];
                        final isMe = myName != null && e.name == myName;
                        final top3 = e.rank <= 3;
                        return StaggeredItem(
                          index: i,
                          child: Card(
                            color: top3 ? AppTheme.surfaceLight : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: top3
                                    ? _rankColor(e.rank)
                                    : AppTheme.surfaceLight,
                                child: Text(
                                  '${e.rank}',
                                  style: TextStyle(
                                    color: top3
                                        ? Colors.black87
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                e.name + (isMe ? '  (you)' : ''),
                                style: TextStyle(
                                  fontWeight: top3 || isMe
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.monetization_on,
                                    size: 16,
                                    color: AppTheme.gold,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${e.coins}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
