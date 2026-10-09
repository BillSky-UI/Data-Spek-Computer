import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _backupEnabledKey = 'backup_enabled';
  static const _backupIntervalKey = 'backup_interval_days';
  static const _backupLastAtKey = 'backup_last_at';

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  bool _backupEnabled = false;
  bool get backupEnabled => _backupEnabled;

  int _backupIntervalDays = 1;
  int get backupIntervalDays => _backupIntervalDays;

  String? _lastBackupAt;
  String? get lastBackupAt => _lastBackupAt;

  /// Backup otomatis dianggap jatuh tempo bila belum pernah backup atau
  /// sudah melewati selang [backupIntervalDays] hari sejak terakhir kali.
  bool get backupDue {
    if (!_backupEnabled) return false;
    final last = _lastBackupAt;
    if (last == null || last.isEmpty) return true;
    final t = DateTime.tryParse(last);
    if (t == null) return true;
    final selisih = DateTime.now().difference(t.toLocal());
    return selisih >= Duration(days: _backupIntervalDays);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_themeKey);
    _mode = switch (v) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    _backupEnabled = prefs.getBool(_backupEnabledKey) ?? false;
    _backupIntervalDays = prefs.getInt(_backupIntervalKey) ?? 1;
    if (_backupIntervalDays != 1 && _backupIntervalDays != 7) {
      _backupIntervalDays = 1;
    }
    _lastBackupAt = prefs.getString(_backupLastAtKey);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        _ => 'dark',
      },
    );
  }

  String labelFor(ThemeMode m) => switch (m) {
        ThemeMode.system => 'Mengikuti sistem',
        ThemeMode.light => 'Terang',
        ThemeMode.dark => 'Gelap',
      };

  Future<void> setBackupEnabled(bool enabled) async {
    _backupEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupEnabledKey, enabled);
  }

  Future<void> setBackupIntervalDays(int days) async {
    _backupIntervalDays = days == 7 ? 7 : 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_backupIntervalKey, _backupIntervalDays);
  }

  Future<void> markBackupDone(DateTime at) async {
    _lastBackupAt = at.toIso8601String();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupLastAtKey, _lastBackupAt!);
  }
}