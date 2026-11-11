import 'package:flutter/material.dart';

import '../services/session.dart';
import '../theme.dart';
import '../widgets/coin_badge.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';

/// Main shell: bottom navigation with 5 tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.session});

  final SessionService session;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final List<Widget> _tabs = [
    HomeScreen(session: widget.session),
    TasksScreen(session: widget.session),
    OrdersScreen(session: widget.session),
    LeaderboardScreen(session: widget.session),
    ProfileScreen(session: widget.session),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _index == 0
          ? AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: const Text(
                  'FollowBoost',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ValueListenableBuilder(
                    valueListenable: widget.session.user,
                    builder: (_, user, _) =>
                        CoinBadge(coins: user?.coins ?? 0),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Tasks'),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Ranks',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
