import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences/
/// Keystore-backed on Android) for anything token-shaped. Per
/// ARCHITECTURE.md §1: "flutter_secure_storage for tokens" — no auth or
/// OAuth token is ever written to Drift, SharedPreferences, or plain files.
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _firebaseIdTokenKey = 'firebase_id_token';
  static const _firebaseRefreshTokenKey = 'firebase_refresh_token';
  static const _garminSessionRefKey = 'garmin_session_ref';

  Future<void> saveFirebaseIdToken(String token) => _storage.write(key: _firebaseIdTokenKey, value: token);

  Future<String?> readFirebaseIdToken() => _storage.read(key: _firebaseIdTokenKey);

  Future<void> saveFirebaseRefreshToken(String token) =>
      _storage.write(key: _firebaseRefreshTokenKey, value: token);

  Future<String?> readFirebaseRefreshToken() => _storage.read(key: _firebaseRefreshTokenKey);

  /// Short-lived reference the backend hands back after completing the
  /// server-side Garmin OAuth token exchange (ARCHITECTURE.md §6). The
  /// actual Garmin access/refresh tokens never reach the device.
  Future<void> saveGarminSessionRef(String ref) => _storage.write(key: _garminSessionRefKey, value: ref);

  Future<String?> readGarminSessionRef() => _storage.read(key: _garminSessionRefKey);

  Future<void> clearGarminSessionRef() => _storage.delete(key: _garminSessionRefKey);

  Future<void> clearAll() => _storage.deleteAll();
}
