# Smart Signal Notifier

A professional Flutter-based Android trading signal notification app with intelligent duplicate detection and daily reset functionality.

## Features

- 🔔 **High-Priority Notifications** - Lock screen alerts with vibration and LED
- 🎯 **Smart Duplicate Blocking** - Only notifies when signal changes
- ♾️ **Unlimited Signals** - No daily limit, just intelligent filtering
- 🔄 **Daily Reset** - Automatic memory reset at 9:17 AM
- 🎚️ **User Control** - Simple ON/OFF toggle
- 💾 **Persistent Storage** - Survives app restarts and reboots

## Signal Logic

```
BUY → BUY → BUY        (only 1st notifies - duplicates blocked)
BUY → SELL → BUY       (all 3 notify - each is different)
Toggle OFF → Send      (no notification - disabled)
```

## Tech Stack

- **Flutter** 3.0+
- **Dart** 3.0+
- **Android** SDK 26-34
- **Kotlin** 1.9.0

### Dependencies
- `flutter_local_notifications` ^17.0.0
- `shared_preferences` ^2.2.2
- `permission_handler` ^11.0.1

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── services/
│   ├── notification_service.dart  # High-priority notifications
│   ├── signal_manager.dart        # Signal logic & duplicate detection
│   └── storage_service.dart       # Persistent data storage
└── screens/
    └── home_screen.dart           # Main UI

android/
└── app/src/main/kotlin/
    ├── MainActivity.kt            # Flutter activity & alarm setup
    ├── BootReceiver.kt            # Reboot handler
    └── DailyResetReceiver.kt      # 9:17 AM reset handler
```

## Setup

### Prerequisites
- Flutter SDK 3.0+
- Android SDK 26+
- Kotlin support

### Installation

```bash
# Get dependencies
flutter pub get

# Run on device
flutter run

# Build APK
flutter build apk --release
```

### Permissions Required
- POST_NOTIFICATIONS
- VIBRATE
- WAKE_LOCK
- RECEIVE_BOOT_COMPLETED
- SCHEDULE_EXACT_ALARM

## Usage

1. **Enable Notifications** - Toggle ON in app
2. **Test Signals** - Use BUY, SELL, NO ENTRY buttons
3. **Lock Screen Test** - Lock device and send signal
4. **Verify Duplicate Blocking** - Send same signal twice

## How It Works

### Signal Flow
1. External source sends signal every minute
2. App checks: Enabled? Different from last?
3. If yes → Send notification + Update storage
4. If no → Silently ignore

### Daily Reset
- Scheduled at 9:17 AM local time
- Clears last signal memory
- First signal of day always notifies
- Automatically reschedules for next day

## Configuration

### Change Reset Time
Edit `MainActivity.kt`, `BootReceiver.kt`, and `DailyResetReceiver.kt`:
```kotlin
set(Calendar.HOUR_OF_DAY, 9)  // Hour
set(Calendar.MINUTE, 17)       // Minute
```

## License

This project is for educational and personal use.

## Author

Built with Flutter ❤️
