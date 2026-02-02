import 'dart:async';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class SignalManager {
  static final SignalManager instance = SignalManager._internal();
  factory SignalManager() => instance;
  SignalManager._internal();

  final _storage = StorageService.instance;
  final _notifications = NotificationService.instance;
  
  Timer? _dailyResetTimer;

  Future<void> init() async {
    // Schedule daily reset at 9:17 AM
    _scheduleDailyReset();
  }

  void _scheduleDailyReset() {
    // Cancel existing timer
    _dailyResetTimer?.cancel();

    // Calculate time until next 9:17 AM
    final now = DateTime.now();
    var resetTime = DateTime(now.year, now.month, now.day, 9, 17);
    
    // If 9:17 AM has passed today, schedule for tomorrow
    if (now.isAfter(resetTime)) {
      resetTime = resetTime.add(const Duration(days: 1));
    }

    final duration = resetTime.difference(now);

    // Schedule the reset
    _dailyResetTimer = Timer(duration, () async {
      await _storage.resetDailyMemory();
      debugPrint('Daily reset completed at ${DateTime.now()}');
      
      // Schedule next day's reset
      _scheduleDailyReset();
    });

    debugPrint('Daily reset scheduled for: $resetTime');
  }

  /// Check if a signal can be sent
  bool canSendSignal(String signalType, {bool isTest = false}) {
    // Check if notifications are enabled
    if (!_storage.notificationEnabled) {
      debugPrint('Notifications are disabled');
      return false;
    }

    // For test signals, allow sending even if duplicate (for testing purposes)
    if (isTest) {
      debugPrint('Test signal - bypassing duplicate check');
      return true;
    }

    // Check if this is a duplicate of the last signal (for live signals only)
    final lastSignal = _storage.lastSignalType;
    if (lastSignal == signalType) {
      debugPrint('Duplicate signal blocked: $signalType');
      return false;
    }

    return true;
  }

  /// Send a trading signal notification
  Future<bool> sendSignal(String signalType, {bool isTest = false}) async {
    if (!canSendSignal(signalType, isTest: isTest)) {
      return false;
    }

    try {
      // Send notification
      await _notifications.showSignalNotification(signalType);
      
      // Update last signal
      await _storage.setLastSignalType(signalType);
      
      debugPrint('Signal sent successfully: $signalType (test: $isTest)');
      return true;
    } catch (e) {
      debugPrint('Error sending signal: $e');
      return false;
    }
  }

  /// Clear last signal (for testing)
  Future<void> clearLastSignal() async {
    await _storage.setLastSignalType('');
    debugPrint('Last signal cleared');
  }

  void dispose() {
    _dailyResetTimer?.cancel();
  }
}
