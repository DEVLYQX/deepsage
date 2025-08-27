// lib/services/auth_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Store these URLs in a config file in a real app
  final String cryptoApiUrl = 'https://api-stg.3lgn.com';
  final String onyxApiUrl = 'https://stg.deepsage.io/api';

  // Token storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // Sign in to Crypto API
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$cryptoApiUrl/auth/sign-in'),
        headers: {
          'Content-Type': 'application/json',
          'x-cypress-env': 'true', // To bypass CAPTCHA as mentioned
        },
        body: jsonEncode({'login': email, 'password': password}),
      );

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

        // Now sign in to Onyx system
        await _signInToOnyxSystem(email);

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
        Uri.parse('$cryptoApiUrl/auth/sign-in/verify-2fa'),
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
    const strongPassword = "T\$4mX!zP2q@6Ld#9vB";

    try {
      // Try to register first (it's fine if this fails)
      try {
        await http.post(
          Uri.parse('$onyxApiUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': strongPassword}),
        );
      } catch (e) {
        // User might already exist, continue to login
        print('Registration to Onyx failed, trying login: $e');
      }

      // Now login
      final loginResponse = await http.post(
        Uri.parse('$onyxApiUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': strongPassword}),
      );

      if (loginResponse.statusCode != 200) {
        throw Exception('Onyx login failed: ${loginResponse.body}');
      }

      // We could store Onyx-specific tokens here if needed
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
  }

  // Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
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
  }
}
