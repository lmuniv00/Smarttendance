# Smarttendance

**Smarttendance** is a Flutter application for automatic attendance tracking of participants using Bluetooth Low Energy (BLE) technology. The application is designed for FESB (Faculty of Electrical Engineering, Mechanical Engineering and Naval Architecture) and enables coordinators to automatically record participant attendance via BLE scanning.

## Table of Contents

- [Project Description](#project-description)
- [Main Features](#main-features)
- [Technologies](#technologies)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)

## Project Description

Smarttendance is a mobile application that uses BLE technology for automatic attendance tracking of participants during lectures. The application has two types of users:

- **Coordinators**: Can initiate BLE scanning to detect present participants
- **Participants**: Emit their unique UUID via BLE to be detected

The application automatically updates attendance records in the Firebase Firestore database.

## Main Features

### For Coordinators:
- Sign in to the system via Firebase authentication
- View assigned courses/sessions
- BLE scanning of participants (duration 5 seconds)
- Automatic attendance record updates
- View attendance statistics per participant
- Option to log scans in CSV format
- View detailed BLE device metrics (RSSI, latency, etc.)
- Increment lecture count

### For Participants:
- Sign in to the system via Firebase authentication
- View enrolled courses/sessions
- View own attendance statistics
- BLE advertising (emitting unique UUID)
- View own unique UUID

## Technologies

- **Flutter** (SDK ^3.6.0) - Cross-platform framework
- **Dart** - Programming language
- **Firebase**:
  - Firebase Authentication - User authentication
  - Cloud Firestore - Database
- **Bluetooth Low Energy (BLE)**:
  - `flutter_blue_plus` (^1.35.2) - BLE scanning
  - `flutter_ble_peripheral` (^1.2.6) - BLE advertising
- **GetX** (^4.6.6) - State management
- **UUID** (4.1.0) - Unique identifier generation
- **permission_handler** (^11.0.0) - Permission management
- **flutter_animate** (^4.2.0) - Animations

## Prerequisites

Before installation, ensure you have:

- **Flutter SDK** (3.6.0 or newer)
- **Dart SDK** (comes with Flutter)
- **Android Studio** or **Xcode** (for mobile development)
- **Firebase project** with configured:
  - Firebase Authentication (Email/Password)
  - Cloud Firestore
- **Android Studio** with Android SDK (minSdkVersion 23)
- **Xcode** (for iOS development, macOS only)

## Installation

### 1. Clone the repository

```bash
git clone <repository-url>
cd Smarttendance
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Firebase configuration

#### Android:
- Download `google-services.json` from Firebase console
- Place it in `android/app/google-services.json`

#### iOS:
- Download `GoogleService-Info.plist` from Firebase console
- Place it in `ios/Runner/GoogleService-Info.plist`

### 4. Firebase project configuration

Firebase data is already configured in `lib/main.dart`. If you are using your own Firebase project, update:

```dart
FirebaseOptions(
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_AUTH_DOMAIN",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_STORAGE_BUCKET",
    messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
    appId: "YOUR_APP_ID"
)
```

## Configuration

### Android permissions

The application automatically requests necessary permissions:
- Bluetooth
- Bluetooth Scan
- Bluetooth Advertise
- Location (required for BLE on Android)

### iOS permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Permission needed for BLE scanning</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Permission needed for BLE advertising</string>
```

## Usage

### Running the application

```bash
# For Android
flutter run

# For iOS (macOS only)
flutter run

# For specific device
flutter devices
flutter run -d <device-id>
```

### Sign in

1. Open the application
2. Enter email address (format: `username@fesb.hr`)
3. Enter password
4. Click "Sign in"

The application will automatically recognize whether you are a Coordinator or Participant and redirect you to the appropriate page.

### Using as Coordinator:

1. **View courses**: After signing in, you see all assigned courses
2. **Select course**: Click the radio button next to the course you want to scan
3. **Start scanning**:
   - (Optional) Enable "Enable Scan Logging" for CSV logging
   - Click "Start scan"
   - Scanning lasts 5 seconds
4. **Update attendance**: After scanning completes, confirm attendance record update
5. **View results**: See all detected devices with detailed metrics

### Using as Participant:

1. **View courses**: See all courses you are enrolled in
2. **View statistics**: See your attendance per course
3. **Start BLE advertising**:
   - Click "Start Advertising"
   - Your device will emit a unique UUID
   - Keep advertising enabled during scanning
4. **Stop**: Click "Stop Advertising" when finished

## Project Structure

```
Smarttendance/
├── lib/
│   ├── components/          # UI components
│   │   ├── button.dart      # Custom button
│   │   └── textfields.dart  # Custom input fields
│   ├── images/              # Images and resources
│   │   └── fesb_logo.png
│   ├── pages/               # Application pages
│   │   ├── login_page.dart           # Login page
│   │   ├── professor_home_page.dart  # Home page for coordinators
│   │   └── student_home_page.dart    # Home page for participants
│   ├── services/            # Services and logic
│   │   ├── bluetooth_controller.dart # BLE scanning and management
│   │   └── firestore.dart            # Firestore operations
│   └── main.dart            # Application entry point
├── android/                 # Android configuration
├── ios/                     # iOS configuration
├── pubspec.yaml             # Flutter dependencies
└── README.md                # This file
```

## Troubleshooting

### Problem: BLE not working on Android

**Solution:**
- Check that location is enabled (required for BLE on Android)
- Check that all permissions are granted
- Restart the application

### Problem: Firebase authentication not working

**Solution:**
- Check that `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is placed correctly
- Check Firebase configuration in `main.dart`
- Check internet connection

### Problem: Participants not detected during scanning

**Solution:**
- Check that participants have BLE advertising enabled
- Check that participants are nearby (BLE has limited range)
- Check that Bluetooth is enabled on both devices
- Check that participants are using the correct UUID

### Problem: CSV logging not working

**Solution:**
- Check that "Enable Scan Logging" is enabled
- Check file system access permissions
- CSV files are saved in the Download folder

### Problem: Application crashes on startup

**Solution:**
```bash
# Clear build cache
flutter clean
flutter pub get

# Run again
flutter run
```

## Firebase Firestore Structure

The application uses the following database structure:

### Collection: `Professors`
```json
{
  "Email": "coordinator@fesb.hr",
  "Courses": [DocumentReference, ...]
}
```

### Collection: `Students`
```json
{
  "Email": "participant@fesb.hr",
  "UUID": "generated-uuid",
  "Name": "Name",
  "Surname": "Surname",
  "Courses": [DocumentReference, ...]
}
```

### Collection: `Courses`
```json
{
  "Name": "Course Name",
  "Lectures": 10,
  "Attendance": [
    {
      "StudentUUID": "uuid",
      "Attendances": 5
    },
    ...
  ]
}
```

## Security

**Important**: Currently, Firebase configuration data is visible in the code. For production, we recommend:

1. Using environment variables (`flutter_dotenv`)
2. Moving sensitive data to secure configuration files
3. Implementing additional security measures in Firebase console

## Notes

- BLE scanning lasts 5 seconds (fixed)
- Participants must be near the coordinator during scanning
- UUID is generated based on Firebase User ID
- CSV logging is optional and saved in the Download folder

## Authors

Project developed for FESB (Faculty of Electrical Engineering, Mechanical Engineering and Naval Architecture).

## License

This project is a private project and is not intended for public distribution.

---

For additional help or questions, contact the development team.
