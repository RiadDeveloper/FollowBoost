import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/gradient_button.dart';

/// Gift codes: redeem a code for coins.
class GiftScreen extends StatefulWidget {
  const GiftScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends State<GiftScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result =
          await widget.session.api.redeemGiftCode(_codeController.text.trim());
      widget.session.updateBalance(result.newBalance);
      setState(() {
        _success = true;
        _message = 'You got ${result.coins} coins! New balance: ${result.newBalance}';
      });
      _codeController.clear();
    } on ApiException catch (e) {
      setState(() {
        _success = false;
        _message = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('Gift codes'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.card_giftcard,
                    color: AppTheme.pink,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Redeem a gift code',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter a code from FollowBoost to get free coins.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'e.g. WELCOME100',
                    ),
                    onSubmitted: (_) => _redeem(),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: 'Redeem',
                    isLoading: _loading,
                    onPressed: _redeem,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _success ? AppTheme.green : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
