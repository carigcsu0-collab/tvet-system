import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _token;
  String? _rememberedEmail;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get rememberedEmail => _rememberedEmail;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberedEmail = prefs.getString('remembered_email');
    final remember = prefs.getBool('remember_me') ?? false;
    if (!remember) {
      await prefs.remove('token');
      _rememberedEmail = null;
      notifyListeners();
      return;
    }
    final stored = prefs.getString('token');
    if (stored != null && stored.isNotEmpty) {
      ApiClient.setToken(stored);
      // Trust the stored token immediately. We do NOT call /auth/me on
      // startup because a transient 401 (e.g. Render cold start) would
      // log the user out. The token has a 15-day sliding expiration on
      // the server, so it stays valid as long as the user is active.
      // If the token is truly expired, the first real API call will
      // return 401 and forceLogout() handles it.
      _token = stored;
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password,
      {bool rememberMe = false}) async {
    final res = await ApiClient.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    _token = res.data['token'] as String;
    _isAuthenticated = true;
    ApiClient.setToken(_token!);

    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('token', _token!);
      await prefs.setString('remembered_email', email);
      _rememberedEmail = email;
    } else {
      await prefs.setBool('remember_me', false);
      await prefs.remove('token');
      _rememberedEmail = null;
    }

    notifyListeners();
    return true;
  }

  /// Called when any API request receives a 401, meaning the token is
  /// genuinely invalid or expired. This is the ONLY path that should auto-
  /// logout — not the startup validation.
  void forceLogout() {
    _token = null;
    _isAuthenticated = false;
    _rememberedEmail = null;
    ApiClient.setToken(null);
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.remove('token');
      await prefs.remove('remember_me');
      await prefs.remove('remembered_email');
    });
    notifyListeners();
  }

  Future<void> logout() async {
    // Revoke this device's token on the server so it can no longer be used,
    // but only clear local state regardless of whether the call succeeds.
    try {
      await ApiClient.post('/auth/logout');
    } catch (_) {
      // Network/server failure — still log out locally.
    }
    _token = null;
    _isAuthenticated = false;
    _rememberedEmail = null;
    ApiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('remember_me');
    await prefs.remove('remembered_email');
    notifyListeners();
  }
}
