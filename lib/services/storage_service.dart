import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  StorageService._();

  late FlutterSecureStorage _secureStorage;

  static final instance = StorageService._();

  Future<String?> get accessToken async => _secureStorage.read(key: 'accessToken');
  Future<String?> get refreshToken async => _secureStorage.read(key: 'refreshToken');
  Future<String?> get cookie async => _secureStorage.read(key: 'cookieToken');

  Future<Map<String, dynamic>?> get userMap async {
    final userStr = await _secureStorage.read(key: 'user');
    if (userStr == null) return null;
    return jsonDecode(userStr) as Map<String, dynamic>;
  }


  Future<void> clearAuth() async {
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');
    await _secureStorage.delete(key: 'user');
    await _secureStorage.delete(key: 'cookieToken');
  }

  Future<void> init() async {
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
  }

  Future<void> saveAuthTokens({required String accessToken, required String refreshToken}) async {
    await _secureStorage.write(key: 'accessToken', value: accessToken);
    await _secureStorage.write(key: 'refreshToken', value: refreshToken);
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'accessToken', value: token);
  }

  Future<void> saveCookieToken(String token) async {
    await _secureStorage.write(key: 'cookieToken', value: token);
  }


  Future<void> saveUserMap(Map<String, dynamic> user) async {
    await _secureStorage.write(key: 'user', value: jsonEncode(user));
  }

}