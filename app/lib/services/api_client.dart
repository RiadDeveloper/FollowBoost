import '../models/leaderboard_entry.dart';
import '../models/order_item.dart';
import '../models/task_item.dart';
import '../models/user.dart';
import '../models/wallet_entry.dart';

/// Thrown when an API call fails (network error, bad status, bad data).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message';
}

/// Result of POST /api/auth/register and POST /api/auth/login.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String? ?? '',
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String token;
  final AppUser user;
}

/// Result of GET /api/wallet.
class WalletSummary {
  const WalletSummary({
    required this.coins,
    required this.totalEarned,
    required this.totalSpent,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) =>
      WalletSummary(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        totalEarned: (json['totalEarned'] as num?)?.toInt() ?? 0,
        totalSpent: (json['totalSpent'] as num?)?.toInt() ?? 0,
      );

  final int coins;
  final int totalEarned;
  final int totalSpent;
}

/// Result of POST /api/rewards/daily.
class DailyRewardResult {
  const DailyRewardResult({
    required this.coins,
    required this.awarded,
    required this.streak,
    required this.alreadyClaimed,
  });

  factory DailyRewardResult.fromJson(Map<String, dynamic> json) =>
      DailyRewardResult(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        awarded: (json['awarded'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        alreadyClaimed: json['alreadyClaimed'] as bool? ?? false,
      );

  final int coins;
  final int awarded;
  final int streak;
  final bool alreadyClaimed;
}

/// Result of POST /api/tasks/:id/complete.
class TaskCompleteResult {
  const TaskCompleteResult({required this.coins, required this.newBalance});

  factory TaskCompleteResult.fromJson(Map<String, dynamic> json) =>
      TaskCompleteResult(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        newBalance: (json['newBalance'] as num?)?.toInt() ?? 0,
      );

  final int coins;
  final int newBalance;
}

/// Result of POST /api/orders.
class OrderResult {
  const OrderResult({required this.order, required this.newBalance});

  factory OrderResult.fromJson(Map<String, dynamic> json) => OrderResult(
        order: OrderItem.fromJson(json['order'] as Map<String, dynamic>),
        newBalance: (json['newBalance'] as num?)?.toInt() ?? 0,
      );

  final OrderItem order;
  final int newBalance;
}

/// Result of POST /api/gift-codes/redeem.
class GiftRedeemResult {
  const GiftRedeemResult({required this.coins, required this.newBalance});

  factory GiftRedeemResult.fromJson(Map<String, dynamic> json) =>
      GiftRedeemResult(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        newBalance: (json['newBalance'] as num?)?.toInt() ?? 0,
      );

  final int coins;
  final int newBalance;
}

/// Result of GET /api/referrals.
class ReferralInfo {
  const ReferralInfo({
    required this.inviteCode,
    required this.referredCount,
    required this.earnedCoins,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) => ReferralInfo(
        inviteCode: json['inviteCode'] as String? ?? '',
        referredCount: (json['referredCount'] as num?)?.toInt() ?? 0,
        earnedCoins: (json['earnedCoins'] as num?)?.toInt() ?? 0,
      );

  final String inviteCode;
  final int referredCount;
  final int earnedCoins;
}

/// Result of GET /api/instagram/status.
///
/// [profilePicUrl], [accountType] and [mediaCount] come from the real
/// Instagram profile (via Meta OAuth) and are null when the account is
/// not connected, or when it was linked by username only.
class InstagramStatus {
  const InstagramStatus({
    required this.connected,
    this.username,
    this.profilePicUrl,
    this.accountType,
    this.mediaCount,
  });

  factory InstagramStatus.fromJson(Map<String, dynamic> json) =>
      InstagramStatus(
        connected: json['connected'] as bool? ?? false,
        username: json['username'] as String?,
        profilePicUrl: json['profilePicUrl'] as String?,
        accountType: json['accountType'] as String?,
        mediaCount: (json['mediaCount'] as num?)?.toInt(),
      );

  final bool connected;
  final String? username;
  final String? profilePicUrl;
  final String? accountType;
  final int? mediaCount;
}

/// Result of GET /api/instagram/oauth-url.
class InstagramOAuthUrl {
  const InstagramOAuthUrl({required this.configured, this.url});

  factory InstagramOAuthUrl.fromJson(Map<String, dynamic> json) =>
      InstagramOAuthUrl(
        configured: json['configured'] as bool? ?? false,
        url: json['url'] as String?,
      );

  /// True when the backend has a Meta developer app configured
  /// (OAUTH_CLIENT_ID / OAUTH_CLIENT_SECRET / OAUTH_REDIRECT_URI).
  final bool configured;

  /// The Instagram authorization URL, when [configured] is true.
  final String? url;
}

/// The FollowBoost API contract. [LiveApiClient] (HTTP, against the real
/// backend) is the only implementation — the app is live-only and the UI
/// never falls back to local/demo data.
abstract class ApiClient {
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthResult> login({
    required String email,
    required String password,
  });

  Future<AppUser> me();

  Future<WalletSummary> wallet();

  Future<List<WalletEntry>> walletHistory();

  Future<DailyRewardResult> claimDaily();

  Future<List<TaskItem>> tasks();

  Future<TaskCompleteResult> completeTask(String taskId);

  Future<OrderResult> createOrder({
    required String type,
    required String targetHandle,
    required int count,
  });

  Future<List<OrderItem>> orders();

  /// Admin only (403 otherwise): every order, with owner name/email.
  Future<List<OrderItem>> adminOrders();

  Future<GiftRedeemResult> redeemGiftCode(String code);

  Future<List<LeaderboardEntry>> leaderboard();

  Future<ReferralInfo> referrals();

  Future<int> applyReferral(String code);

  Future<InstagramStatus> connectInstagram(String username);

  Future<InstagramStatus> instagramStatus();

  /// GET /api/instagram/oauth-url: whether Meta OAuth is configured on
  /// the backend, and the authorization URL when it is.
  Future<InstagramOAuthUrl> instagramOAuthUrl();

  /// POST /api/instagram/oauth/start: starts the Meta OAuth flow.
  /// Returns the Instagram authorization URL, to be opened in an
  /// external browser (never a WebView — a WebView could ask for a
  /// password). When the user finishes, the backend callback page links
  /// back into the app and the profile refreshes on resume.
  Future<String> startInstagramOAuth();
}
