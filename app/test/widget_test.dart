import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:followboost/screens/tasks_screen.dart';
import 'package:followboost/services/live_api.dart';
import 'package:followboost/services/session.dart';
import 'package:followboost/theme.dart';
import 'package:followboost/widgets/coin_badge.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake backend over MockClient: register returns a 50-coin user,
/// tasks are two real-shaped tasks, completing one pays its coins and
/// puts it on a 24h cooldown (availableAt in the future).
LiveApiClient _fakeLiveApi() {
  final completed = <String>{};
  Map<String, dynamic> taskJson(String id, String type, String handle,
      String displayName, String color, int coins) {
    return {
      'id': id,
      'type': type,
      'handle': handle,
      'displayName': displayName,
      'avatarColor': color,
      'coins': coins,
      'availableAt': completed.contains(id)
          ? DateTime.now().add(const Duration(hours: 23)).toIso8601String()
          : null,
    };
  }

  return LiveApiClient(
    baseUrl: 'https://api.example.com',
    client: MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'POST' && path == '/api/auth/register') {
        return http.Response(
          jsonEncode({
            'token': 'tok-test',
            'user': {
              'id': 'u1',
              'name': 'Test User',
              'email': 'test@example.com',
              'coins': 50,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET' && path == '/api/tasks') {
        return http.Response(
          jsonEncode([
            taskJson('task-wander.earth', 'follow', 'wander.earth',
                'Wander Earth', '#7C3AED', 5),
            taskJson('task-sunset.frames', 'like', 'sunset.frames',
                'Sunset Frames', '#F59E0B', 3),
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' &&
          path.startsWith('/api/tasks/') &&
          path.endsWith('/complete')) {
        final id = path.split('/')[3];
        completed.add(id);
        final coins = id.contains('wander') ? 5 : 3;
        return http.Response(
          jsonEncode({'coins': coins, 'newBalance': 50 + coins}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"error":"Not found"}', 404);
    }),
  );
}

Future<SessionService> _signedInSession() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = _fakeLiveApi();
  final session = SessionService(api: api, prefs: prefs);
  await session.init();
  final auth = await api.register(
    name: 'Test User',
    email: 'test@example.com',
    password: 'secret1',
  );
  await session.signIn(auth.token, auth.user);
  return session;
}

void main() {
  testWidgets('CoinBadge counts up and shows the balance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.dark,
        home: Scaffold(body: Center(child: CoinBadge(coins: 42))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.monetization_on), findsOneWidget);
  });

  testWidgets('CoinBadge shows 0 for a fresh balance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CoinBadge(coins: 0))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('task confirm flow awards coins and shows cooldown',
      (tester) async {
    final session = await _signedInSession();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: TasksScreen(session: session),
      ),
    );
    // Explicit pumps only: TasksScreen runs a 30s periodic poll timer,
    // and pumpAndSettle would keep firing it under fake async time.
    // A few short pumps flush the mock HTTP futures instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('@wander.earth'), findsOneWidget);
    expect(find.text('I followed'), findsWidgets);

    // Confirm the first follow task.
    await tester.tap(find.text('I followed').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Did you follow?'), findsOneWidget);

    await tester.tap(find.text('Yes, I followed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    // +5 coins for the follow task: 50 signup + 5 = 55.
    expect(session.user.value?.coins, 55);
    expect(find.textContaining('coins earned'), findsOneWidget);

    // The completed task now shows its cooldown state.
    expect(find.textContaining('Available in'), findsOneWidget);
  });
}
