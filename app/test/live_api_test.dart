import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:followboost/services/api_client.dart';
import 'package:followboost/services/live_api.dart';
import 'package:followboost/services/pricing.dart';

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

LiveApiClient clientFor(Map<String, http.Response> routes) {
  return LiveApiClient(
    baseUrl: 'https://api.example.com',
    client: MockClient((request) async {
      final key = '${request.method} ${request.url.path}';
      return routes[key] ??
          jsonResponse({'error': 'Not found'}, 404);
    }),
  );
}

void main() {
  group('auth', () {
    test('register parses token + user', () async {
      final api = clientFor({
        'POST /api/auth/register': jsonResponse({
          'token': 'tok-1',
          'user': {
            'id': 'u1',
            'name': 'Test User',
            'email': 'test@example.com',
            'coins': 50,
          },
        }),
      });
      final result = await api.register(
        name: 'Test User',
        email: 'test@example.com',
        password: 'secret1',
      );
      expect(result.token, 'tok-1');
      expect(result.user.id, 'u1');
      expect(result.user.coins, 50);
      expect(result.user.isAdmin, isFalse);
    });

    test('login parses token + user', () async {
      final api = clientFor({
        'POST /api/auth/login': jsonResponse({
          'token': 'tok-2',
          'user': {
            'id': 'u1',
            'name': 'Test User',
            'email': 'test@example.com',
            'coins': 75,
            'isAdmin': true,
          },
        }),
      });
      final result = await api.login(
        email: 'test@example.com',
        password: 'secret1',
      );
      expect(result.token, 'tok-2');
      expect(result.user.coins, 75);
      expect(result.user.isAdmin, isTrue);
    });
  });

  group('tasks', () {
    test('tasks parsing incl. orderId + availableAt', () async {
      final api = clientFor({
        'GET /api/tasks': jsonResponse([
          {
            'id': 't1',
            'type': 'follow',
            'handle': 'wander.earth',
            'displayName': 'Wander Earth',
            'avatarColor': '#7C3AED',
            'coins': 5,
            'availableAt': null,
          },
          {
            'id': 't2',
            'type': 'like',
            'handle': 'target.page',
            'displayName': 'target.page',
            'avatarColor': '#EC4899',
            'coins': 1,
            'availableAt': '2030-01-01T00:00:00.000Z',
            'orderId': 42,
          },
        ]),
      });
      final tasks = await api.tasks();
      expect(tasks.length, 2);
      expect(tasks[0].handle, 'wander.earth');
      expect(tasks[0].orderId, isNull);
      expect(tasks[0].isOrderTask, isFalse);
      expect(tasks[0].availableAt, isNull);
      expect(tasks[1].orderId, '42');
      expect(tasks[1].isOrderTask, isTrue);
      expect(tasks[1].availableAt, DateTime.utc(2030, 1, 1));
      expect(tasks[1].isOnCooldown, isTrue);
    });
  });

  group('orders', () {
    test('orders parsing incl. fulfilled + status', () async {
      final api = clientFor({
        'GET /api/orders': jsonResponse([
          {
            'id': 'o1',
            'type': 'follow',
            'targetHandle': 'target.page',
            'count': 10,
            'cost': 20,
            'status': 'partial',
            'createdAt': '2026-11-11T07:00:00.000Z',
            'fulfilled': 4,
          },
          {
            'id': 'o2',
            'type': 'like',
            'targetHandle': 'other.page',
            'count': 10,
            'cost': 10,
            'status': 'queued',
            'createdAt': '2026-11-11T06:00:00.000Z',
            'fulfilled': 0,
          },
        ]),
      });
      final orders = await api.orders();
      expect(orders.length, 2);
      expect(orders[0].status, 'partial');
      expect(orders[0].fulfilled, 4);
      expect(orders[0].cost, 20);
      expect(orders[1].status, 'queued');
      expect(orders[1].fulfilled, 0);
    });
  });

  group('admin', () {
    test('adminOrders 403 maps to ApiException with statusCode 403',
        () async {
      final api = clientFor({
        'GET /api/admin/orders':
            jsonResponse({'error': 'Admin only'}, 403),
      });
      expect(
        () => api.adminOrders(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', 'Admin only'),
        ),
      );
    });
  });

  group('instagram', () {
    test('status parses profilePicUrl, accountType, mediaCount', () async {
      final api = clientFor({
        'GET /api/instagram/status': jsonResponse({
          'connected': true,
          'username': 'my.page',
          'profilePicUrl': 'https://cdn.example.com/pic.jpg',
          'accountType': 'BUSINESS',
          'mediaCount': 128,
        }),
      });
      final status = await api.instagramStatus();
      expect(status.connected, isTrue);
      expect(status.username, 'my.page');
      expect(status.profilePicUrl, 'https://cdn.example.com/pic.jpg');
      expect(status.accountType, 'BUSINESS');
      expect(status.mediaCount, 128);
    });

    test('status not connected has null profile fields', () async {
      final api = clientFor({
        'GET /api/instagram/status': jsonResponse({
          'connected': false,
          'username': null,
        }),
      });
      final status = await api.instagramStatus();
      expect(status.connected, isFalse);
      expect(status.username, isNull);
      expect(status.profilePicUrl, isNull);
      expect(status.accountType, isNull);
      expect(status.mediaCount, isNull);
    });

    test('oauth-url {configured:false} parses', () async {
      final api = clientFor({
        'GET /api/instagram/oauth-url': jsonResponse({'configured': false}),
      });
      final oauth = await api.instagramOAuthUrl();
      expect(oauth.configured, isFalse);
      expect(oauth.url, isNull);
    });

    test('oauth-url {configured:true} parses the url', () async {
      final api = clientFor({
        'GET /api/instagram/oauth-url': jsonResponse({
          'configured': true,
          'url': 'https://www.instagram.com/oauth/authorize?client_id=x',
        }),
      });
      final oauth = await api.instagramOAuthUrl();
      expect(oauth.configured, isTrue);
      expect(oauth.url, contains('instagram.com/oauth/authorize'));
    });

    test('startInstagramOAuth returns the authorize URL', () async {
      const url =
          'https://www.instagram.com/oauth/authorize?client_id=x&state=abc';
      final api = clientFor({
        'POST /api/instagram/oauth/start': jsonResponse({'url': url}),
      });
      expect(await api.startInstagramOAuth(), url);
    });

    test('startInstagramOAuth without a url throws ApiException', () async {
      final api = clientFor({
        'POST /api/instagram/oauth/start': jsonResponse({}),
      });
      expect(() => api.startInstagramOAuth(), throwsA(isA<ApiException>()));
    });
  });

  group('errors', () {
    test('non-2xx with an error body maps to ApiException', () async {
      final api = clientFor({
        'GET /api/me': jsonResponse({'error': 'Invalid token'}, 401),
      });
      expect(
        () => api.me(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Invalid token'),
        ),
      );
    });

    test('non-JSON error body still throws with the status code', () async {
      final api = LiveApiClient(
        baseUrl: 'https://api.example.com',
        client: MockClient(
          (_) async => http.Response('Internal Server Error', 500),
        ),
      );
      expect(
        () => api.me(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('empty base URL throws a setup ApiException', () async {
      final api = LiveApiClient(baseUrl: '');
      expect(() => api.me(), throwsA(isA<ApiException>()));
    });
  });

  group('pricing', () {
    test('order cost: follow 2/follower, like 1/like, minimum 10', () {
      // Moved out of the deleted mock into Pricing with identical rules.
      expect(Pricing.orderCost('follow', 10), 20);
      expect(Pricing.orderCost('follow', 50), 100);
      expect(Pricing.orderCost('follow', 3), 10);
      expect(Pricing.orderCost('like', 10), 10);
      expect(Pricing.orderCost('like', 100), 100);
      expect(Pricing.orderCost('like', 5), 10);
    });
  });
}
