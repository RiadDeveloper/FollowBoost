import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/gradient_button.dart';
import 'auth_screen.dart';
import 'admin_screen.dart';
import 'gift_screen.dart';
import 'referral_screen.dart';
import 'vip_screen.dart';
import 'wallet_screen.dart';

/// Profile tab: user info, Instagram connect via official Meta OAuth
/// (opened in the external browser — never a WebView that could ask for
/// a password), a manual-username fallback, Settings (backend URL), logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  InstagramStatus? _igStatus;
  bool _igLoading = false;
  bool _oauthLoading = false;
  final _igController = TextEditingController();
  final _urlController = TextEditingController();
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _urlController.text = widget.session.baseUrl;
    _loadIgStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _igController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The OAuth flow leaves the app for the external browser; when the
    // user comes back (via the followboost://instagram/connected link or
    // manually), refresh the status — this is how the app learns the
    // OAuth login completed.
    if (state == AppLifecycleState.resumed) _loadIgStatus();
  }

  Future<void> _loadIgStatus() async {
    try {
      final status = await widget.session.api.instagramStatus();
      if (mounted) setState(() => _igStatus = status);
    } on ApiException {
      // Not critical — leave the connect form visible.
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Official Instagram login (Meta OAuth) in the external browser.
  Future<void> _connectWithInstagram() async {
    setState(() => _oauthLoading = true);
    try {
      final oauth = await widget.session.api.instagramOAuthUrl();
      if (!mounted) return;
      if (!oauth.configured) {
        _showMessage(
          'Instagram login is not set up yet — the owner needs to create '
          'a Meta developer app and set OAUTH_CLIENT_ID / '
          'OAUTH_CLIENT_SECRET / OAUTH_REDIRECT_URI on the backend '
          '(see backend/README.md).',
        );
        return;
      }
      final url = await widget.session.api.startInstagramOAuth();
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showMessage('Could not open the Instagram login page.');
      }
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _oauthLoading = false);
    }
  }

  /// Manual fallback: link a username so orders go to the right profile.
  /// This targets real orders — it is not demo data. We never ask for an
  /// Instagram password.
  Future<void> _connectInstagramManually() async {
    setState(() => _igLoading = true);
    try {
      final status = await widget.session.api.connectInstagram(
        _igController.text.trim(),
      );
      if (mounted) {
        setState(() => _igStatus = status);
        _showMessage('Connected as @${status.username}');
      }
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _igLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    await widget.session.updateBaseUrl(_urlController.text.trim());
    if (mounted) {
      setState(() => _savingSettings = false);
      _showMessage(
        'Backend URL saved: ${_urlController.text.trim().isEmpty ? '(none set)' : _urlController.text.trim()}',
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Log out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.session.signOut();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      AppTheme.fadeSlideRoute(AuthScreen(session: widget.session)),
      (_) => false,
    );
  }

  void _go(Widget page) {
    Navigator.of(context).push(AppTheme.fadeSlideRoute(page));
  }

  Widget _igAvatar() {
    final status = _igStatus;
    final picUrl = status?.profilePicUrl;
    if (picUrl != null && picUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(picUrl),
        backgroundColor: AppTheme.violet,
      );
    }
    final initial = (status?.username?.isNotEmpty ?? false)
        ? status!.username![0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppTheme.violet,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final igConnected = _igStatus?.connected ?? false;
    return Scaffold(
      appBar: gradientAppBar('Profile'),
      body: ValueListenableBuilder(
        valueListenable: widget.session.user,
        builder: (_, user, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.violet,
                      child: Text(
                        (user?.name.isNotEmpty ?? false)
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user?.coins ?? 0} coins',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Instagram',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (igConnected) ...[
                      Row(
                        children: [
                          _igAvatar(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.green,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '@${_igStatus!.username ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_igStatus!.accountType != null ||
                                    _igStatus!.mediaCount != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      if (_igStatus!.accountType != null)
                                        _igStatus!.accountType!,
                                      if (_igStatus!.mediaCount != null)
                                        '${_igStatus!.mediaCount} posts',
                                    ].join(' • '),
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh Instagram status',
                            onPressed: _loadIgStatus,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'Connect your real Instagram account with the official Instagram login. We never ask for your Instagram password.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      GradientButton(
                        label: 'Connect with Instagram',
                        isLoading: _oauthLoading,
                        onPressed: _connectWithInstagram,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'or link your username manually',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _igController,
                        decoration: const InputDecoration(
                          hintText: 'Instagram username',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GradientButton(
                        label: 'Link username',
                        isLoading: _igLoading,
                        onPressed: _connectInstagramManually,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'Backend URL, e.g. https://api.example.com',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      label: 'Save settings',
                      isLoading: _savingSettings,
                      onPressed: _saveSettings,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: AppTheme.pink,
                    ),
                    title: const Text('Wallet'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _go(WalletScreen(session: widget.session)),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.card_giftcard,
                      color: AppTheme.pink,
                    ),
                    title: const Text('Gift codes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _go(GiftScreen(session: widget.session)),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.group_add,
                      color: AppTheme.pink,
                    ),
                    title: const Text('Invite friends'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _go(ReferralScreen(session: widget.session)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.star, color: AppTheme.gold),
                    title: const Text('FollowBoost VIP'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _go(VipScreen(session: widget.session)),
                  ),
                  if (user?.isAdmin == true)
                    ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings,
                        color: AppTheme.violet,
                      ),
                      title: const Text('Admin — all orders'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _go(AdminScreen(session: widget.session)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                'Log out',
                style: TextStyle(color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'FollowBoost v1.0.2',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
