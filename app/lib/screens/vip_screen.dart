import 'package:flutter/material.dart';

import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_app_bar.dart';

/// VIP: info + upgrade placeholder. Clearly marked "coming soon" —
/// no payment is wired up.
class VipScreen extends StatelessWidget {
  const VipScreen({super.key, required this.session});

  final SessionService session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('FollowBoost VIP'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: const Column(
              children: [
                Icon(Icons.star, color: AppTheme.gold, size: 56),
                SizedBox(height: 12),
                Text(
                  'FollowBoost VIP',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Coming soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What VIP will include',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  _Perk(icon: Icons.bolt, text: 'Double coins on every task'),
                  _Perk(icon: Icons.card_giftcard, text: 'Bigger daily rewards'),
                  _Perk(icon: Icons.speed, text: 'Faster order delivery'),
                  _Perk(icon: Icons.workspace_premium, text: 'Exclusive VIP badge'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'VIP upgrades are not available yet. No payment is taken in this version — check back in a future update!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.pink),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
