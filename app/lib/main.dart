import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/session.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionService();
  await session.init();
  runApp(FollowBoostApp(session: session));
}

class FollowBoostApp extends StatelessWidget {
  const FollowBoostApp({super.key, required this.session});

  final SessionService session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FollowBoost',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: SplashScreen(session: session),
    );
  }
}
