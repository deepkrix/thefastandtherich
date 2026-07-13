import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thefastandtherich/models/user.dart';

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService({required String baseUrl}) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            e.requestOptions.headers['Authorization'] = 'Bearer $token';
            return handler.resolve(await _dio.fetch(e.requestOptions));
          }
        }
        handler.next(e);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await _dio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      await _storage.write(key: 'access_token', value: response.data['accessToken']);
      await _storage.write(key: 'refresh_token', value: response.data['refreshToken']);
      return true;
    } catch (_) {
      await _storage.deleteAll();
      return false;
    }
  }

  // ─── AUTH ───

  Future<void> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final tokens = TokenResponse.fromJson(response.data);
    await _storage.write(key: 'access_token', value: tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: tokens.refreshToken);
  }

  Future<String> register(String email, String password) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
    });
    return response.data['userId'] as String;
  }

  Future<void> verify(String userId, String code) async {
    await _dio.post('/auth/verify', data: {
      'userId': userId,
      'verificationCode': code,
    });
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await _storage.deleteAll();
  }

  Future<User?> getCurrentUser() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );

      return User(
        userId: payload['userId'],
        email: payload['email'],
        status: 'ACTIVE',
        kycStatus: 'NONE',
        role: payload['role'],
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  // ─── WALLET ───

  Future<Response> getWallet() async {
    return await _dio.get('/wallet');
  }

  Future<Response> deposit(int amountCoins, String paymentMethodId) async {
    return await _dio.post('/wallet/deposit', data: {
      'amountCoins': amountCoins,
      'paymentMethodId': paymentMethodId,
    });
  }

  Future<Response> withdraw(int amountCoins, String payoutDestination) async {
    return await _dio.post('/wallet/withdraw', data: {
      'amountCoins': amountCoins,
      'payoutDestination': payoutDestination,
    });
  }

  Future<Response> getTransactions({String? cursor, int limit = 20}) async {
    return await _dio.get('/wallet/transactions', queryParameters: {
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    });
  }

  // ─── MATCH ───

  Future<Response> getGames() async {
    return await _dio.get('/games');
  }

  Future<Response> getMatches(int category) async {
    return await _dio.get('/matches', queryParameters: {
      'category': category,
    });
  }

  Future<Response> getMatch(String matchId) async {
    return await _dio.get('/matches/$matchId');
  }

  Future<Response> joinMatch(String matchId, String userId) async {
    return await _dio.post('/matches/$matchId/join', data: {
      'userId': userId,
      'clientDeviceInfo': {
        'platform': 'Web',
        'attestationToken': 'web-mvp-token',
      },
    });
  }

  Future<Response> submitAttempt(String matchId, String attemptId, String payload, int durationMs) async {
    return await _dio.post('/matches/$matchId/attempts/$attemptId/submit', data: {
      'inputPayload': payload,
      'clientDurationMs': durationMs,
    });
  }

  Future<Response> getMatchResults(String matchId) async {
    return await _dio.get('/matches/$matchId/results');
  }

  // ─── WEBSOCKET ───

  String getWebSocketUrl() {
    return 'ws://localhost:8080/v1/ws?token=';
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }
}
