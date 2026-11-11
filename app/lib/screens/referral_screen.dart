import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/gradient_button.dart';

/// Referrals: my invite code (copy) + apply someone else's code.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  ReferralInfo? _info;
  bool _loading = true;
  bool _applying = false;
  String? _message;
  bool _success = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await widget.session.api.referrals();
      if (mounted) setState(() => _info = info);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _applying = true;
      _message = null;
    });
    try {
      final coins =
          await widget.session.api.applyReferral(_codeController.text.trim());
      final current = widget.session.user.value;
      if (current != null) {
        widget.session.updateBalance(current.coins + coins);
      }
      setState(() {
        _success = true;
        _message = 'You earned $coins coins! Thanks for joining with a code.';
      });
      _codeController.clear();
      await _load();
    } on ApiException catch (e) {
      setState(() {
        _success = false;
        _message = e.message;
      });
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('Invite friends'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.pink),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Your invite code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Share it with friends. When someone signs up with your code, you earn 50 coins and they earn 25.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _info?.inviteCode ?? '—',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filled(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: _info?.inviteCode ?? '',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invite code copied'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.violet,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_info?.referredCount ?? 0} friends joined  •  ${_info?.earnedCoins ?? 0} coins earned from referrals',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Have a code?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Enter invite code',
                          ),
                          onSubmitted: (_) => _apply(),
                        ),
                        const SizedBox(height: 14),
                        GradientButton(
                          label: 'Apply code (+25 coins)',
                          isLoading: _applying,
                          onPressed: _apply,
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _success
                                  ? AppTheme.green
                                  : Colors.redAccent,
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
