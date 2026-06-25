# SyncStay Mobile

A Flutter-based mobile application for student accommodation management and roommate matching.

## Features

- **Student Hostel Management**: Browse and manage student hostels with detailed information
- **Roommate Matching**: Smart matching algorithm to find compatible roommates based on preferences
- **Hostel Requests**: Submit and track hostel accommodation requests
- **Payment Management**: Handle rent payments and view payment history
- **Review System**: Rate and review hostels and roommates
- **Multi-Role Support**: Different dashboards for students, owners, wardens, and admins
- **Real-time Notifications**: Stay updated with instant notifications
- **Location Services**: Find hostels near educational institutions

## User Roles

- **Student**: Search hostels, find roommates, make requests, manage payments
- **Hostel Owner**: Manage properties, review requests, track payments
- **Warden**: Oversee hostel operations, manage residents
- **District Admin**: Monitor multiple hostels and users
- **Super Admin**: Full system access and analytics

## Tech Stack

- **Framework**: Flutter 3.x
- **Language**: Dart
- **Backend**: Firebase (Firestore, Authentication, Cloud Functions)
- **Storage**: Supabase Storage
- **State Management**: Provider/Riverpod
- **Maps**: OpenStreetMap (OSM)

## Getting Started

### Prerequisites

- Flutter SDK (3.0 or higher)
- Dart SDK
- Android Studio / Xcode
- Firebase account

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/1dpthr/SyncStay-Mobile.git
   cd SyncStay-Mobile
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Create a Firebase project
   - Add Android and iOS apps to Firebase
   - Download configuration files (google-services.json for Android, GoogleService-Info.plist for iOS)
   - Place them in the respective platform folders

4. Run the app:
   ```bash
   flutter run
   ```

## Building the App

### Debug Build
```bash
flutter build apk --debug
```

### Release Build
```bash
flutter build apk --release
```

The release APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── student.dart
│   ├── hostel.dart
│   ├── room.dart
│   ├── payment.dart
│   └── ...
├── services/
│   ├── firebase_service.dart     # Firebase operations
│   ├── firestore_repository.dart # Database operations
│   ├── matching_engine.dart      # Roommate matching algorithm
│   └── screens/                  # UI screens
│       ├── login_screen.dart
│       ├── signup_screen.dart
│       ├── dashboard_screen.dart
│       └── ...
├── theme/                    # App theming
└── utils/                    # Utility functions
```

## Screenshots

*Coming soon*

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For support or queries, please contact the development team.

## Download APK

You can download the latest APK from the [Releases](https://github.com/1dpthr/SyncStay-Mobile/releases) section.