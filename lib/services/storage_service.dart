import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/receipt.dart';

/// Penyimpanan lokal (offline) untuk pengaturan dan riwayat struk.
class StorageService {
  static const _kSettings = 'settings_v1';
  static const _kHistory = 'history_v1';
  static const maxHistory = 300;

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) =>
      _prefs.setString(_kSettings, jsonEncode(s.toJson()));

  List<Receipt> loadHistory() {
    final raw = _prefs.getString(_kHistory);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Receipt.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<Receipt> items) {
    final trimmed = items.length > maxHistory ? items.sublist(0, maxHistory) : items;
    return _prefs.setString(_kHistory, jsonEncode(trimmed.map((r) => r.toJson()).toList()));
  }
}
