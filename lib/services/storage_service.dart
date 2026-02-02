import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  factory StorageService() => instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  // Storage keys
  static const String _keyNotificationEnabled = 'notification_enabled';
  static const String _keyLastSignalType = 'last_signal_type';
  static const String _keyLastResetDate = 'last_reset_date';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Check if daily reset is needed
    await _checkDailyReset();
  }

  // Check if we need to reset daily data
  Future<void> _checkDailyReset() async {
    if (_prefs == null) return;
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastReset = _prefs!.getString(_keyLastResetDate);
    
    if (lastReset != today) {
      // New day - reset last signal
      await _prefs!.remove(_keyLastSignalType);
      await _prefs!.setString(_keyLastResetDate, today);
    }
  }

  // Notification enabled state
  bool get notificationEnabled => _prefs?.getBool(_keyNotificationEnabled) ?? true;
  
  Future<void> setNotificationEnabled(bool enabled) async {
    await _prefs?.setBool(_keyNotificationEnabled, enabled);
  }

  // Last signal type
  String? get lastSignalType => _prefs?.getString(_keyLastSignalType);
  
  Future<void> setLastSignalType(String signalType) async {
    await _prefs?.setString(_keyLastSignalType, signalType);
  }

  // Reset daily memory (called at 9:17 AM)
  Future<void> resetDailyMemory() async {
    if (_prefs == null) return;
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _prefs!.remove(_keyLastSignalType);
    await _prefs!.setString(_keyLastResetDate, today);
  }

  // Clear all data (for testing)
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
