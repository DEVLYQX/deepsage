// lib/services/auth_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // API URLs from the documentation
  final String cryptoApiUrl = 'https://api-stg.3lgn.com/auth';
  final String onyxApiUrl = 'https://stg.deepsage.io/api/auth';

  // Token storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String onyxTokenKey = 'onyx_token';

  // Sign in to Crypto API
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      print('Attempting to sign in with email: $email');
      final response = await http.post(
        Uri.parse('$cryptoApiUrl/sign-in'),
        headers: {
          'Content-Type': 'application/json',
          'x-cypress-env': 'true', // To bypass CAPTCHA as specified in docs
        },
        body: jsonEncode({
          'login':
              email, // Using 'login' as the field name as per documentation
          'password': password,
        }),
      );

      print('Sign-in response status: ${response.statusCode}');
      print('Sign-in response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to sign in: ${response.body}');
      }

      final data = jsonDecode(response.body);

      // Check if 2FA is required
      if (data['isTwoFactorEnabled'] == true) {
        return {
          'requiresTwoFactor': true,
          'twoFactorToken': data['twoFactorResponse']['accessToken'],
        };
      } else {
        // Store tokens
        await _saveTokens(data['accessToken'], data['refreshToken']);

        // Get email from the response to use for Onyx login
        final userEmail = data['userData']['email'] ?? email;

        // Now sign in to Onyx system
        await _signInToOnyxSystem(userEmail);

        return {'requiresTwoFactor': false, 'user': data['userData']};
      }
    } catch (e) {
      print('Sign in error: $e');
      throw Exception('Authentication failed: $e');
    }
  }

  // Verify 2FA code
  Future<Map<String, dynamic>> verifyTwoFactor(
    String twoFactorToken,
    String code,
    String method, // 'authenticator', 'email', or 'backup'
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$cryptoApiUrl/sign-in/verify-2fa'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $twoFactorToken',
        },
        body: jsonEncode({'code': code, 'method': method}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to verify 2FA: ${response.body}');
      }

      final data = jsonDecode(response.body);

      // Store tokens
      await _saveTokens(data['accessToken'], data['refreshToken']);

      // Get email from user data
      final email = data['userData']['email'];

      // Now sign in to Onyx system
      await _signInToOnyxSystem(email);

      return {'user': data['userData']};
    } catch (e) {
      print('2FA verification error: $e');
      throw Exception('2FA verification failed: $e');
    }
  }

  // Sign in to Onyx system
  Future<void> _signInToOnyxSystem(String email) async {
    // Using the exact strongPassword from the documentation
    const strongPassword = "T\$4mX!zP2q@6Ld#9vB";

    try {
      print('Attempting Onyx registration with email: $email');
      // Try to register first (it's fine if this fails)
      try {
        final registerResponse = await http.post(
          Uri.parse('$onyxApiUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': strongPassword}),
        );
        print(
          'Registration response: ${registerResponse.statusCode} - ${registerResponse.body}',
        );
      } catch (e) {
        // User might already exist, continue to login
        print('Registration to Onyx failed, trying login: $e');
      }

      // Now login to Onyx
      print('Attempting Onyx login with email: $email');
      final loginResponse = await http.post(
        Uri.parse('$onyxApiUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': strongPassword}),
      );

      print(
        'Onyx login response: ${loginResponse.statusCode} - ${loginResponse.body}',
      );

      if (loginResponse.statusCode != 200) {
        throw Exception('Onyx login failed: ${loginResponse.body}');
      }

      final data = jsonDecode(loginResponse.body);

      // Store Onyx token
      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(onyxTokenKey, data['token']);
        print('Stored Onyx token: ${data['token']}');
      }

      print('Successfully logged into Onyx system');
    } catch (e) {
      print('Onyx system login error: $e');
      throw Exception('Onyx system authentication failed: $e');
    }
  }

  // Save tokens to local storage
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accessTokenKey, accessToken);
    await prefs.setString(refreshTokenKey, refreshToken);
    print('Stored access and refresh tokens');
  }

  // Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
  }

  // Get Onyx token
  Future<String?> getOnyxToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(onyxTokenKey);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    await prefs.remove(onyxTokenKey);
  }
}
