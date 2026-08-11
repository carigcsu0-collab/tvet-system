import 'package:dio/dio.dart';
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
      // Trust the token immediately so user stays logged in
      // even if the server is cold-starting on Render
      _token = stored;
      _isAuthenticated = true;
      notifyListeners();
      // Validate in background — only clear on 401, not network errors
      try {
        await ApiClient.get('/auth/me');
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          _token = null;
          _isAuthenticated = false;
          _rememberedEmail = null;
          ApiClient.setToken(null);
          await prefs.remove('token');
          await prefs.remove('remembered_email');
          await prefs.remove('remember_me');
          notifyListeners();
        }
      } catch (_) {
        // Network error, server cold start, etc. — keep session alive
      }
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

  Future<void> logout() async {
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
