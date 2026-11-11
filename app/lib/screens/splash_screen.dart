import 'package:flutter/material.dart';

import '../services/session.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'backend_setup_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

/// Splash: logo + progress, then routes based on session state.
/// Live-only gating: when no backend URL is set, or the backend does
/// not answer, the app goes to [BackendSetupScreen] instead — it never
/// falls back to demo/mock data. Otherwise: signed in -> Home,
/// onboarding not seen -> Onboarding, else Auth.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final session = widget.session;
    final backendOk =
        session.baseUrl.isNotEmpty && await session.checkBackend();
    if (!mounted) return;
    Widget next;
    if (!backendOk) {
      next = BackendSetupScreen(session: session);
    } else if (session.isSignedIn) {
      next = MainShell(session: session);
    } else if (!session.onboardingSeen) {
      next = OnboardingScreen(session: session);
    } else {
      next = AuthScreen(session: session);
    }
    await Navigator.of(context).pushReplacement(AppTheme.fadeSlideRoute(next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (_, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/icon.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: const Text(
                'FollowBoost',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Grow your Instagram, earn coins.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: AppTheme.pink,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
