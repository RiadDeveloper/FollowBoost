import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'live_api.dart';

/// Holds the signed-in state and the backend URL.
///
/// Live-only: the app works ONLY against the real FollowBoost backend
/// ([LiveApiClient]). There is no demo/offline mode — the splash flow
/// routes to [BackendSetupScreen] when no backend URL is set or the
/// backend cannot be reached, and the app never falls back to local data.
///
/// [user] is a [ValueNotifier] so the UI reacts to sign-in / sign-out and
/// balance changes.
class SessionService {
  SessionService({ApiClient? api, SharedPreferences? prefs})
      : _prefsOverride = prefs,
        _apiOverride = api;

  static const _kToken = 'fb_token';
  static const _kUser = 'fb_user';
  static const _kBaseUrl = 'fb_base_url';
  static const _kOnboardingSeen = 'fb_onboarding_seen';

  final SharedPreferences? _prefsOverride;
  final ApiClient? _apiOverride;

  SharedPreferences? _prefs;
  late ApiClient _api;
  String _baseUrl = '';
  bool _loaded = false;
  bool onboardingSeen = false;

  /// The signed-in user, or null. Listened to by the UI.
  final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);

  ApiClient get api => _api;
  String get baseUrl => _baseUrl;
  bool get isSignedIn => user.value != null;
  bool get isLoaded => _loaded;

  Future<void> init() async {
    _prefs = _prefsOverride ?? await SharedPreferences.getInstance();
    _baseUrl = _prefs!.getString(_kBaseUrl) ?? '';
    onboardingSeen = _prefs!.getBool(_kOnboardingSeen) ?? false;
    _rebuildApi();
    final token = _prefs!.getString(_kToken);
    final userJson = _prefs!.getString(_kUser);
    if (token != null && userJson != null) {
      try {
        user.value =
            AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        _applyToken(token);
      } catch (_) {
        await _clearStoredAuth();
      }
    }
    _loaded = true;
  }

  void _rebuildApi() {
    if (_apiOverride != null) {
      _api = _apiOverride;
      return;
    }
    _api = LiveApiClient(baseUrl: _baseUrl);
  }

  void _applyToken(String? token) {
    final api = _api;
    if (api is LiveApiClient) api.setToken(token);
  }

  Future<void> _storeAuth(String token, AppUser u) async {
    await _prefs?.setString(_kToken, token);
    await _prefs?.setString(_kUser, jsonEncode(u.toJson()));
  }

  Future<void> _clearStoredAuth() async {
    await _prefs?.remove(_kToken);
    await _prefs?.remove(_kUser);
  }

  /// Returns true only when the configured backend answers GET / with
  /// HTTP 200 and a JSON body whose `name` is "FollowBoost API".
  /// False when no URL is set, the server is unreachable, or the
  /// response is anything else. Never throws.
  Future<bool> checkBackend() async {
    if (_baseUrl.isEmpty) return false;
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body);
      return json is Map && json['name'] == 'FollowBoost API';
    } catch (_) {
      return false;
    }
  }

  Future<void> markOnboardingSeen() async {
    onboardingSeen = true;
    await _prefs?.setBool(_kOnboardingSeen, true);
  }

  Future<void> signIn(String token, AppUser u) async {
    _applyToken(token);
    user.value = u;
    await _storeAuth(token, u);
  }

  /// Clears auth only (token + cached user). No backend data is reset.
  Future<void> signOut() async {
    user.value = null;
    await _clearStoredAuth();
    _applyToken(null);
  }

  /// Refresh the cached user (balance) from the backend.
  Future<void> refreshUser() async {
    if (!isSignedIn) return;
    try {
      user.value = await _api.me();
      final token = _prefs?.getString(_kToken);
      if (token != null && user.value != null) {
        await _storeAuth(token, user.value!);
      }
    } on ApiException {
      // Keep the cached user; the screen shows its own error if needed.
    }
  }

  void updateBalance(int coins) {
    final u = user.value;
    if (u != null) user.value = u.copyWith(coins: coins);
  }

  /// Save a new backend URL and rebuild the API client against it.
  /// The stored auth token (if any) is re-applied to the new client.
  Future<void> updateBaseUrl(String baseUrl) async {
    _baseUrl = baseUrl.trim();
    await _prefs?.setString(_kBaseUrl, _baseUrl);
    final token = _prefs?.getString(_kToken);
    _rebuildApi();
    if (token != null) _applyToken(token);
  }
}
