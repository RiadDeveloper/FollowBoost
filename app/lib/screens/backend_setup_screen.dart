import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_button.dart';
import 'auth_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

/// The screen the app routes to after onboarding/auth when no backend
/// is configured or reachable. FollowBoost is live-only: every account,
/// coin, task and order lives on the backend server, so the app cannot
/// do anything until it can talk to one.
///
/// Steps shown to the user:
/// 1. Deploy the backend (see backend/README.md: Render or a VPS).
/// 2. Paste the backend URL below.
/// 3. Tap "Save & test connection".
Widget nextScreenAfterBackendCheck(SessionService session) {
  if (session.isSignedIn) return MainShell(session: session);
  if (!session.onboardingSeen) return OnboardingScreen(session: session);
  return AuthScreen(session: session);
}

class BackendSetupScreen extends StatefulWidget {
  const BackendSetupScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<BackendSetupScreen> createState() => _BackendSetupScreenState();
}

class _BackendSetupScreenState extends State<BackendSetupScreen> {
  final _urlController = TextEditingController();
  bool _testing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.session.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    final url = _urlController.text.trim();
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      if (url.isEmpty) {
        setState(() => _error = 'Please paste your backend URL.');
        return;
      }
      await widget.session.updateBaseUrl(url);
      final ok = await widget.session.checkBackend();
      if (!mounted) return;
      if (ok) {
        await Navigator.of(context).pushReplacement(
          AppTheme.fadeSlideRoute(
            nextScreenAfterBackendCheck(widget.session),
          ),
        );
      } else {
        setState(
          () => _error =
              'Could not reach the backend at $url.\nCheck the URL and that the server is running, then try again.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not reach the backend at $url.\nCheck the URL and that the server is running, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.dns,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Connect to your backend',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'FollowBoost needs its backend server — your account, coins, tasks and orders all live there.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
              ),
              const SizedBox(height: 24),
              const _Step(number: '1', text: 'Deploy the backend server (see backend/README.md — Render or a VPS).'),
              const SizedBox(height: 12),
              const _Step(number: '2', text: 'Paste the backend URL below.'),
              const SizedBox(height: 12),
              const _Step(number: '3', text: 'Tap "Save & test connection".'),
              const SizedBox(height: 28),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Backend URL, e.g. https://your-app.onrender.com',
                  prefixIcon: Icon(Icons.link),
                ),
                onSubmitted: (_) => _saveAndTest(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              GradientButton(
                label: 'Save & test connection',
                isLoading: _testing,
                onPressed: _saveAndTest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppTheme.violet,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
