# Signal Notifier - Project Structure

## 📁 Current Folders

```
signal_notifier/
├── .github/
│   └── workflows/
│       └── trading_strategy.yml    ← GitHub Actions (runs every 1 min)
│
├── android/                         ← Android app configuration
│   ├── app/
│   │   ├── google-services.json    ← Firebase config
│   │   ├── build.gradle            ← Firebase dependencies
│   │   └── src/
│   └── build.gradle.kts
│
├── lib/                             ← Flutter app code
│   ├── models/
│   │   └── signal_model.dart       ← Signal data structure
│   ├── services/
│   │   ├── firebase_service.dart   ← Real-time Firestore listener
│   │   ├── notification_service.dart
│   │   ├── signal_manager.dart
│   │   └── storage_service.dart
│   ├── screens/
│   │   └── home_screen.dart
│   └── main.dart                   ← App entry point
│
└── strategy/                        ← Python trading strategy
    ├── main.py                      ← Your Nifty strategy
    └── requirements.txt             ← Python dependencies
```

## ✅ What's Removed

- ❌ `cloud_function/` folder - Not needed (using GitHub Actions instead)

## 🚀 What You're Using

**For Running Strategy:**
- GitHub Actions (every 1 minute) OR
- Codemagic (every 1 minute)
- Files: `.github/workflows/trading_strategy.yml` + `strategy/main.py`

**For Flutter App:**
- Firebase Firestore (real-time database)
- Files: `lib/services/firebase_service.dart` + `android/app/google-services.json`

## 💡 Clean & Simple!

No Google Cloud Functions needed. Everything runs for FREE on GitHub Actions or Codemagic!
