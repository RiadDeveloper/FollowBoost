import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/coin_badge.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_title.dart';
import 'gift_screen.dart';
import 'leaderboard_screen.dart';
import 'orders_screen.dart';
import 'referral_screen.dart';
import 'tasks_screen.dart';
import 'vip_screen.dart';
import 'wallet_screen.dart';

/// Home tab: coin balance with count-up, daily reward + streak,
/// quick stats and quick actions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WalletSummary? _wallet;
  bool _loading = true;
  bool _claiming = false;
  String? _dailyMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wallet = await widget.session.api.wallet();
      if (mounted) setState(() => _wallet = wallet);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimDaily() async {
    setState(() {
      _claiming = true;
      _dailyMessage = null;
    });
    try {
      final result = await widget.session.api.claimDaily();
      widget.session.updateBalance(result.coins);
      await _load();
      if (mounted) {
        setState(() {
          _dailyMessage = result.alreadyClaimed
              ? 'Already claimed today — come back tomorrow!'
              : 'You earned ${result.awarded} coins! Streak: ${result.streak} day(s)';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _dailyMessage = e.message);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _go(Widget page) {
    Navigator.of(context).push(AppTheme.fadeSlideRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user.value;
    return ValueListenableBuilder(
      valueListenable: widget.session.user,
      builder: (_, currentUser, _) {
        final name = currentUser?.name ?? user?.name ?? '';
        final coins = currentUser?.coins ?? _wallet?.coins ?? 0;
        return RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.pink,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                'Hello, $name 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your balance',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoinBadge(coins: coins, large: true),
                    const SizedBox(height: 12),
                    if (_loading)
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Text(
                        'Total earned: ${_wallet?.totalEarned ?? 0}  •  Spent: ${_wallet?.totalSpent ?? 0}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Claim daily reward',
                      icon: Icons.card_giftcard,
                      isLoading: _claiming,
                      onPressed: _claimDaily,
                    ),
                    if (_dailyMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _dailyMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Quick actions'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _ActionCard(
                    icon: Icons.task_alt,
                    label: 'Earn coins',
                    onTap: () => _go(TasksScreen(session: widget.session)),
                  ),
                  _ActionCard(
                    icon: Icons.people,
                    label: 'Get followers',
                    onTap: () => _go(OrdersScreen(session: widget.session)),
                  ),
                  _ActionCard(
                    icon: Icons.account_balance_wallet,
                    label: 'Wallet',
                    onTap: () => _go(WalletScreen(session: widget.session)),
                  ),
                  _ActionCard(
                    icon: Icons.card_giftcard,
                    label: 'Gift codes',
                    onTap: () => _go(GiftScreen(session: widget.session)),
                  ),
                  _ActionCard(
                    icon: Icons.group_add,
                    label: 'Invite friends',
                    onTap: () =>
                        _go(ReferralScreen(session: widget.session)),
                  ),
                  _ActionCard(
                    icon: Icons.emoji_events,
                    label: 'Leaderboard',
                    onTap: () =>
                        _go(LeaderboardScreen(session: widget.session)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.star, color: AppTheme.gold),
                  title: const Text('FollowBoost VIP'),
                  subtitle: const Text('Extra rewards, coming soon'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _go(VipScreen(session: widget.session)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.pink, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
