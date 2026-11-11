import 'package:flutter/material.dart';

import '../theme.dart';

/// Coin balance chip with an animated count-up whenever the value changes.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.coins, this.large = false});

  final int coins;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 30.0 : 18.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 10 : 6,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(large ? 20 : 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on, color: AppTheme.gold, size: size),
          const SizedBox(width: 6),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: coins),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, value, _) => Text(
              '$value',
              key: ValueKey<int>(value),
              style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
