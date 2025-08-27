// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _cryptoApi = 'https://api-stg.3lgn.com';
  static const _onyxApi = 'https://cloud.onyx.app/api';

  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _onyxPassword = "T\$4mX!zP2q@6Ld#9vB";

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw Exception('Email and password are required');
    }
    if (!_isValidEmail(email)) {
      throw Exception('Invalid email address');
    }

    final requestBody = {'email': email.trim(), 'password': password};
    debugPrint('[Auth] Sending login request to $_cryptoApi/auth/sign-in');
    debugPrint('Request body: $requestBody');

    final response = await http.post(
      Uri.parse('$_cryptoApi/auth/sign-in'),
      headers: {'Content-Type': 'application/json', 'x-cypress-env': 'true'},
      body: jsonEncode(requestBody),
    );

    debugPrint('Response [${response.statusCode}]: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Login failed: ${response.body}');
    }

    final data = jsonDecode(response.body);

    if (data['isTwoFactorEnabled'] == true) {
      debugPrint('2FA required for this account');
      return {
        'requiresTwoFactor': true,
        'twoFactorToken': data['twoFactorResponse']['accessToken'],
      };
    }

    final session = data['session'];
    if (session == null) throw Exception('Invalid response from server');

    final accessToken = session['accessToken'];
    final refreshToken = session['refreshToken'];
    final user = session['user'];

    if (accessToken == null || refreshToken == null || user == null) {
      throw Exception('Missing authentication data');
    }

    debugPrint('Login successful, storing tokens...');
    await _storeTokens(accessToken, refreshToken);

    await _setupOnyxAccess(user['email']);

    return {'requiresTwoFactor': false, 'user': user};
  }

  Future<Map<String, dynamic>> verifyTwoFactor(
    String token,
    String code,
    String method,
  ) async {
    final requestBody = {'code': code, 'method': method};
    debugPrint('[Auth] Verifying 2FA at $_cryptoApi/auth/sign-in/verify-2fa');
    debugPrint('Request body: $requestBody');

    final response = await http.post(
      Uri.parse('$_cryptoApi/auth/sign-in/verify-2fa'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    );

    debugPrint('Response [${response.statusCode}]: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('2FA verification failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final session = data['session'];
    if (session == null) throw Exception('Invalid server response');

    final accessToken = session['accessToken'];
    final refreshToken = session['refreshToken'];
    final user = session['user'];

    if (accessToken == null || refreshToken == null || user == null) {
      throw Exception('Missing authentication data');
    }

    debugPrint('2FA verified, storing tokens...');
    await _storeTokens(accessToken, refreshToken);

    await _setupOnyxAccess(user['email']);

    return {'user': user};
  }

  Future<void> _setupOnyxAccess(String email) async {
    debugPrint('Setting up Onyx access for $email');
    try {
      await _createOnyxUser(email, _onyxPassword);
    } catch (e) {
      debugPrint('Onyx registration skipped/failed, will try login: $e');
    }
    await _loginToOnyx(email, _onyxPassword);
  }

  Future<void> _createOnyxUser(String email, String password) async {
    final requestBody = {'email': email, 'password': password};
    debugPrint('[Onyx] Registering user at $_onyxApi/auth/register');
    debugPrint('Request body: $requestBody');

    final response = await http.post(
      Uri.parse('$_onyxApi/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    debugPrint('Response [${response.statusCode}]: ${response.body}');

    if (response.statusCode == 400 &&
        response.body.contains('REGISTER_USER_ALREADY_EXISTS')) {
      debugPrint('User already exists in Onyx, continuing to login...');
      return;
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Onyx registration failed: ${response.body}');
    }

    debugPrint('Onyx registration successful');
  }

  Future<void> _loginToOnyx(String email, String password) async {
    final requestBody =
        'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}';

    debugPrint('[Onyx] Logging in at $_onyxApi/auth/login');
    debugPrint('Request body: $requestBody');

    final response = await http.post(
      Uri.parse('$_onyxApi/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: requestBody,
    );

    debugPrint('Response [${response.statusCode}]: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Onyx login failed: ${response.body}');
    }

    debugPrint('Onyx login successful');
  }

  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
    debugPrint('Tokens stored locally');
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
    debugPrint('Logged out, tokens cleared');
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
