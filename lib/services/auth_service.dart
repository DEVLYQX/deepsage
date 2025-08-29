// lib/services/auth_service.dart
import 'dart:convert';
import 'package:deepsage/services/api_service.dart';
import 'package:deepsage/services/storage_service.dart';
import 'package:deepsage/utils/toast_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/web.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthServices {
  AuthServices._();

  static const _onyxPassword = "T\$4mX!zP2q@6Ld#9vB";
  static final instance = AuthServices._();

  final _api =ApiService.instance;
  final _db = StorageService.instance;
  String? _twoFactorToken;

  Future<bool> get isSignedIn async {
    final token = await _db.accessToken;
    final cookie = await _db.cookie;

    return token != null && cookie != null;

  }

  Future<ApiResponse<bool>?> signIn(String email, String password) async {
    final response = await _api.post('/auth/sign-in', {'email': email, 'password': password}, expectsData: true, isCrypto: true);
    if(!response.isSuccess) {
      ToastUtils.showError(response.message ?? 'unexpected error');
      return null;
    }
    final result = response.data;
    if(result case {'isTwoFactorEnabled': final bool tFAEnabled}) {
      if(tFAEnabled) {
        Logger().i('Logging in with 2fa');
        _twoFactorToken = result['twoFactorResponse']['accessToken'];
        await _db.saveToken(_twoFactorToken!);
         return ApiResponse.success(true);
        // return {
        //   'requiresTwoFactor': true,
        //   'twoFactorToken': result['twoFactorResponse']['accessToken'],
        // };
      } else {
        await _db.saveAuthTokens(accessToken: result['session']['accessToken'], refreshToken: result['session']['refreshToken']);
        final loginRes = await _signInToOnyxSystem(email, _onyxPassword);
        if(loginRes) return ApiResponse.success(false);
        return null;
          // return {'requiresTwoFactor': false, 'user': result['session']['user']};
        // return null;
      }
    }
    ToastUtils.showError('Something went wrong');

    return null;
  }

  Future<bool> _signInToOnyxSystem(String email, String password) async {
    Logger().i('Signing in to Onyx');
    final requestBody = 'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}';
    try {
      // Try to register first (it's fine if this fails)
      final regResult = await _api.post('/auth/register', {'email': email, 'password': password},isCrypto: false,);
      if(!regResult.isSuccess) Logger().i('Registration failed, user already exists');
      final loginResult = await _api.post('/auth/login',requestBody, isCrypto: false);
      if(!loginResult.isSuccess) {
        ToastUtils.showError(regResult.message ?? 'unexpected error');
      }
      return loginResult.isSuccess;
      // We could store Onyx-specific tokens here if needed
    } catch (e, s) {
      Logger().e('Onyx system login error: $e', stackTrace: s);
      ToastUtils.showError('Something went wrong');
      return false;
    }
  }


  Future<bool> verifyTwoFactor(String code, String method) async {
    final requestBody = {'code': code, 'method': method};
    debugPrint('Request body: $requestBody');

    final response = await _api.post('/auth/sign-in/verify-2fa', requestBody, expectsData: true);

    if(!response.isSuccess) {
      ToastUtils.showError('Verification failed: ${response.message}');
      return false;
    }
    final result = response.data;
    await _db.saveAuthTokens(accessToken: result['session']['accessToken'], refreshToken: result['session']['refreshToken']);

    final user = result['session']['user'];

    final loginRes = await _signInToOnyxSystem(user['email'], _onyxPassword);
    return loginRes;
  }

  Future<void> logout() async {
    await _db.clearAuth();
    debugPrint('Logged out, tokens cleared');
  }


}


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

    debugPrint('Response login [${response.statusCode}]: ${response.body}');

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
