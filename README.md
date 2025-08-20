# TV Subscription Payment App

A modern, minimal, and user-friendly Android app to handle yearly subscription fees for a local TV channel.

## Project Structure

```
lib/
├── l10n/                    # Localization files
│   ├── app_en.arb          # English translations
│   └── app_gu.arb          # Gujarati translations
├── models/                  # Data models
├── services/               # Business logic services
├── screens/                # UI screens
├── widgets/                # Reusable UI components
└── main.dart               # App entry point
```

## Dependencies

### Firebase Dependencies
- `firebase_core`: Core Firebase functionality
- `firebase_auth`: Authentication services
- `cloud_firestore`: NoSQL database
- `firebase_storage`: File storage

### Localization Dependencies
- `flutter_localizations`: Flutter localization support
- `intl`: Internationalization utilities

## Firebase Setup

### Prerequisites
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication and Firestore services

### Configuration Files
Replace the placeholder configuration file with actual one from Firebase Console:

#### Android
- Replace `android/app/google-services.json` with your project's configuration

### Firebase Initialization
Uncomment the Firebase initialization line in `lib/main.dart`:
```dart
await Firebase.initializeApp();
```

## Localization Setup

The app supports English and Gujarati languages. Localization files are located in `lib/l10n/`.

To generate localization files:
```bash
flutter gen-l10n
```

After generation, uncomment the import and delegate in `lib/main.dart`:
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// ...
AppLocalizations.delegate,
```

## Build System Configuration

The project uses modern Android build configuration:
- **Gradle Wrapper**: 8.10 (configured in `android/gradle/wrapper/gradle-wrapper.properties`)
- **Java Compatibility**: Java 1.8 for both source and target compatibility
- **Kotlin JVM Target**: Java 1.8
- **Android Namespace**: Configured with modern namespace support
- **NDK Version**: 27.0.12077973 (required for Firebase plugins)
- **Minimum SDK**: 23 (required for Firebase Authentication)

## Getting Started

1. Ensure you have Flutter 3.32.0+ and Dart 3.8.0+ installed:
```bash
flutter --version
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate localization files:
```bash
flutter gen-l10n
```

4. Set up Firebase configuration files (see Firebase Setup section)

5. Run the app:
```bash
flutter run
```

## Next Steps

This is the initial project setup. The following features will be implemented in subsequent tasks:
- User authentication with OTP
- Payment processing with UPI integration
- Wallet system
- Receipt generation
- Admin dashboard
- Multi-language support
- And more...

## Development Notes

- **Flutter Version**: 3.32.0+
- **Dart Version**: 3.8.0+
- **Gradle Wrapper**: 8.10 (latest stable version)
- **Build System**: Uses Gradle with Flutter's integrated build system
- **Java Compatibility**: Java 1.8 (VERSION_1_8)
- **Android Configuration**: Modern Android Gradle Plugin setup with namespace support
- **Minimum Android SDK**: 23 (required for Firebase)
- **Firebase**: Used as the backend service
- **Platform Support**: Android only
- **Localization**: Set up for English and Gujarati languages