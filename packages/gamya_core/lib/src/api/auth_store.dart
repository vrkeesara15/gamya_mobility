import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Persists the JWT + user profile across restarts (web localStorage / Android prefs).
class AuthStore {
  static const _kToken = 'gamya.token';
  static const _kUser = 'gamya.user';
  static const _kBaseUrl = 'gamya.baseUrl';

  String? _token;
  AuthUser? _user;

  String? get token => _token;
  AuthUser? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString(_kToken);
    final u = p.getString(_kUser);
    _user = u == null ? null : AuthUser.fromJson(jsonDecode(u) as Map<String, dynamic>);
  }

  Future<void> save(String token, AuthUser user) async {
    _token = token;
    _user = user;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    await p.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> updateUser(AuthUser user) async {
    _user = user;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    _token = null;
    _user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
  }

  Future<String?> savedBaseUrl() async => (await SharedPreferences.getInstance()).getString(_kBaseUrl);
  Future<void> saveBaseUrl(String url) async => (await SharedPreferences.getInstance()).setString(_kBaseUrl, url);
}
