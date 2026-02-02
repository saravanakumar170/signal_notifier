import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Request notification permission
    await Permission.notification.request();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(initSettings);

    // Create high-priority notification channel
    final androidChannel = AndroidNotificationChannel(
      'trading_signals',
      'Trading Signals',
      description: 'High-priority trading signal notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> showSignalNotification(String signalType) async {
    final androidDetails = AndroidNotificationDetails(
      'trading_signals',
      'Trading Signals',
      channelDescription: 'High-priority trading signal notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'New Trading Signal',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 500,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(
        'Signal Type: $signalType\nTap to open app',
        contentTitle: '🔔 New Trading Signal',
      ),
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🔔 Trading Signal: $signalType',
      'Signal Type: $signalType\nTap to open app',
      notificationDetails,
    );
    
    // Blink flashlight 3 times
    await _blinkFlashlight();
  }
  
  Future<void> _blinkFlashlight() async {
    try {
      // Check if flashlight is available
      if (await TorchLight.isTorchAvailable()) {
        // Blink 3 times
        for (int i = 0; i < 3; i++) {
          await TorchLight.enableTorch();
          await Future.delayed(const Duration(milliseconds: 200));
          await TorchLight.disableTorch();
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    } catch (e) {
      // Flashlight not available or permission denied - continue without it
      debugPrint('Flashlight error: $e');
    }
  }
}
