import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists chef registration **step-1 fields only** (never the password).
/// Native: [FlutterSecureStorage]. Web: [SharedPreferences] (browser storage).
class ChefRegDraftStorage {
  static const _legacyPrefix = 'chef_reg_fields_v1_';
  static const _legacyName = '${_legacyPrefix}name';
  static const _legacyEmail = '${_legacyPrefix}email';
  static const _legacyPhone = '${_legacyPrefix}phone';

  static const _skName = 'chef_reg_secure_name_v2';
  static const _skEmail = 'chef_reg_secure_email_v2';
  static const _skPhone = 'chef_reg_secure_phone_v2';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static Future<void> saveFields({
    required String name,
    required String email,
    String? phone,
  }) async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_skName, name);
      await p.setString(_skEmail, email);
      if (phone != null && phone.isNotEmpty) {
        await p.setString(_skPhone, phone);
      } else {
        await p.remove(_skPhone);
      }
      await _clearLegacyPrefs(p);
      return;
    }
    await _secure.write(key: _skName, value: name);
    await _secure.write(key: _skEmail, value: email);
    if (phone != null && phone.isNotEmpty) {
      await _secure.write(key: _skPhone, value: phone);
    } else {
      await _secure.delete(key: _skPhone);
    }
    final p = await SharedPreferences.getInstance();
    await _clearLegacyPrefs(p);
  }

  static Future<({String name, String email, String? phone})?> loadFields() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      final name = p.getString(_skName)?.trim() ?? '';
      final email = p.getString(_skEmail)?.trim() ?? '';
      final phone = p.getString(_skPhone)?.trim();
      if (email.isEmpty) {
        final migrated = await _migrateLegacyFromPrefs(p);
        if (migrated != null) return migrated;
        return null;
      }
      return (name: name, email: email, phone: phone);
    }

    final name = (await _secure.read(key: _skName))?.trim() ?? '';
    final email = (await _secure.read(key: _skEmail))?.trim() ?? '';
    final phone = (await _secure.read(key: _skPhone))?.trim();
    if (email.isEmpty) {
      final p = await SharedPreferences.getInstance();
      final migrated = await _migrateLegacyFromPrefs(p);
      if (migrated != null) return migrated;
      return null;
    }
    return (name: name, email: email, phone: phone);
  }

  static Future<({String name, String email, String? phone})?> _migrateLegacyFromPrefs(
    SharedPreferences p,
  ) async {
    final name = p.getString(_legacyName)?.trim() ?? '';
    final email = p.getString(_legacyEmail)?.trim() ?? '';
    if (email.isEmpty) return null;
    final phone = p.getString(_legacyPhone)?.trim();
    await saveFields(name: name.isEmpty ? '' : name, email: email, phone: phone);
    await _clearLegacyPrefs(p);
    return (name: name, email: email, phone: phone);
  }

  static Future<void> _clearLegacyPrefs(SharedPreferences p) async {
    await p.remove(_legacyName);
    await p.remove(_legacyEmail);
    await p.remove(_legacyPhone);
  }

  static Future<void> clear() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.remove(_skName);
      await p.remove(_skEmail);
      await p.remove(_skPhone);
      await _clearLegacyPrefs(p);
      return;
    }
    await _secure.delete(key: _skName);
    await _secure.delete(key: _skEmail);
    await _secure.delete(key: _skPhone);
    final p = await SharedPreferences.getInstance();
    await _clearLegacyPrefs(p);
  }
}
