import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/services/api_service.dart';
import 'package:thefastandtherich/models/user.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(baseUrl: 'http://localhost:8080/v1');
});

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final ApiService _api;

  AuthNotifier(this._api) : super(const AsyncValue.data(null)) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final user = await _api.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _api.login(email, password);
      final user = await _api.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Registriert einen neuen User und gibt die userId zurück (für VerifyScreen)
  Future<String> register(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final userId = await _api.register(email, password);
      state = const AsyncValue.data(null);
      return userId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    state = const AsyncValue.data(null);
  }
}
