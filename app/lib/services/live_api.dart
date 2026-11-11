import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/leaderboard_entry.dart';
import '../models/order_item.dart';
import '../models/task_item.dart';
import '../models/user.dart';
import '../models/wallet_entry.dart';
import 'api_client.dart';

/// HTTP implementation of [ApiClient] against the FollowBoost backend.
///
/// Live-only: there is no demo mode. The base URL is configured in the
/// backend-setup screen / Settings, and the splash flow refuses to
/// continue until the backend answers. A real phone has no `10.0.2.2`
/// emulator address, so there is no usable default.
class LiveApiClient implements ApiClient {
  LiveApiClient({required String baseUrl, this._token, http.Client? client})
      : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  String? _token;

  /// The HTTP client every request goes through. Tests inject a
  /// [MockClient] from package:http/testing here.
  final http.Client _client;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _get(String path) async {
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        'Backend URL not set — add it in Settings.',
      );
    }
    final res = await _client
        .get(Uri.parse('$_baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        'Backend URL not set — add it in Settings.',
      );
    }
    final res = await _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      throw ApiException(
        'Bad response from server (HTTP ${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = json is Map
          ? (json['error'] ?? json['message'] ?? 'Request failed').toString()
          : 'Request failed (HTTP ${res.statusCode})';
      throw ApiException(message, statusCode: res.statusCode);
    }
    return json;
  }

  Map<String, dynamic> _asMap(dynamic json) {
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return Map<String, dynamic>.from(json);
    throw const ApiException('Unexpected response from server');
  }

  List<T> _asList<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    List raw;
    if (json is List) {
      raw = json;
    } else if (json is Map) {
      final first = json.values.firstWhere(
        (v) => v is List,
        orElse: () => <dynamic>[],
      );
      raw = first as List;
    } else {
      raw = const [];
    }
    return raw
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async =>
      AuthResult.fromJson(
        _asMap(await _post('/api/auth/register', {
          'name': name,
          'email': email,
          'password': password,
        })),
      );

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      AuthResult.fromJson(
        _asMap(await _post('/api/auth/login', {
          'email': email,
          'password': password,
        })),
      );

  @override
  Future<AppUser> me() async => AppUser.fromJson(_asMap(await _get('/api/me')));

  @override
  Future<WalletSummary> wallet() async =>
      WalletSummary.fromJson(_asMap(await _get('/api/wallet')));

  @override
  Future<List<WalletEntry>> walletHistory() async =>
      _asList(await _get('/api/wallet/history'), WalletEntry.fromJson);

  @override
  Future<DailyRewardResult> claimDaily() async =>
      DailyRewardResult.fromJson(_asMap(await _post('/api/rewards/daily')));

  @override
  Future<List<TaskItem>> tasks() async =>
      _asList(await _get('/api/tasks'), TaskItem.fromJson);

  @override
  Future<TaskCompleteResult> completeTask(String taskId) async =>
      TaskCompleteResult.fromJson(
        _asMap(await _post('/api/tasks/$taskId/complete')),
      );

  @override
  Future<OrderResult> createOrder({
    required String type,
    required String targetHandle,
    required int count,
  }) async =>
      OrderResult.fromJson(
        _asMap(await _post('/api/orders', {
          'type': type,
          'targetHandle': targetHandle,
          'count': count,
        })),
      );

  @override
  Future<List<OrderItem>> orders() async =>
      _asList(await _get('/api/orders'), OrderItem.fromJson);

  @override
  Future<List<OrderItem>> adminOrders() async =>
      _asList(await _get('/api/admin/orders'), OrderItem.fromJson);

  @override
  Future<GiftRedeemResult> redeemGiftCode(String code) async =>
      GiftRedeemResult.fromJson(
        _asMap(await _post('/api/gift-codes/redeem', {'code': code})),
      );

  @override
  Future<List<LeaderboardEntry>> leaderboard() async =>
      _asList(await _get('/api/leaderboard'), LeaderboardEntry.fromJson);

  @override
  Future<ReferralInfo> referrals() async =>
      ReferralInfo.fromJson(_asMap(await _get('/api/referrals')));

  @override
  Future<int> applyReferral(String code) async {
    final json = _asMap(await _post('/api/referrals/apply', {'code': code}));
    return (json['coins'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<InstagramStatus> connectInstagram(String username) async =>
      InstagramStatus.fromJson(
        _asMap(await _post('/api/instagram/connect', {'username': username})),
      );

  @override
  Future<InstagramStatus> instagramStatus() async =>
      InstagramStatus.fromJson(_asMap(await _get('/api/instagram/status')));

  @override
  Future<InstagramOAuthUrl> instagramOAuthUrl() async =>
      InstagramOAuthUrl.fromJson(
        _asMap(await _get('/api/instagram/oauth-url')),
      );

  @override
  Future<String> startInstagramOAuth() async {
    final json = _asMap(await _post('/api/instagram/oauth/start'));
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ApiException('Instagram login did not return a URL');
    }
    return url;
  }
}
