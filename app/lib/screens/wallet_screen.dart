import 'package:flutter/material.dart';

import '../models/wallet_entry.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/coin_badge.dart';
import '../widgets/gradient_app_bar.dart';

/// Wallet: balance, earned/spent totals, history list.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletSummary? _summary;
  List<WalletEntry> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.session.api.wallet(),
        widget.session.api.walletHistory(),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as WalletSummary;
          _history = results[1] as List<WalletEntry>;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('Wallet'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.pink),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.pink,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Center(
                    child: CoinBadge(coins: _summary?.coins ?? 0, large: true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Total earned',
                          value: '${_summary?.totalEarned ?? 0}',
                          color: AppTheme.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Total spent',
                          value: '${_summary?.totalSpent ?? 0}',
                          color: AppTheme.pink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    const Text(
                      'No transactions yet.',
                      style: TextStyle(color: AppTheme.textMuted),
                    )
                  else
                    ..._history.map(
                      (e) => Card(
                        child: ListTile(
                          leading: Icon(
                            e.type == 'earn'
                                ? Icons.add_circle
                                : Icons.remove_circle,
                            color: e.type == 'earn'
                                ? AppTheme.green
                                : AppTheme.pink,
                          ),
                          title: Text(e.reason),
                          subtitle: Text(
                            e.createdAt?.toLocal().toString().split('.').first ??
                                '',
                          ),
                          trailing: Text(
                            '${e.type == 'earn' ? '+' : '-'}${e.amount}',
                            style: TextStyle(
                              color: e.type == 'earn'
                                  ? AppTheme.green
                                  : AppTheme.pink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
