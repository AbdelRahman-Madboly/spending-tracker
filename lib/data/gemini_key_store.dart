import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the Gemini key is kept (spec §2): secure storage only, never the
/// database, logs, exports or backups. `app_settings` refuses any key that
/// looks like a secret, so it cannot end up there by mistake either.
abstract class GeminiKeyStore {
  /// The saved key, or null when none is.
  Future<String?> read();

  /// Saves [key]; null or blank removes it.
  Future<void> write(String? key);
}

/// [GeminiKeyStore] on `flutter_secure_storage` (the Android Keystore).
class SecureGeminiKeyStore implements GeminiKeyStore {
  SecureGeminiKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _name = 'gemini';

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String? key) {
    final value = key?.trim() ?? '';
    return value.isEmpty
        ? _storage.delete(key: _name)
        : _storage.write(key: _name, value: value);
  }
}
