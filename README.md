# Scalable Short Video App — Flutter Frontend

Cross-platform mobile application for the Scalable Short Video Application thesis project. Built with Flutter (Dart), targeting Android and iOS. The app communicates with the NestJS microservices backend via REST APIs and Socket.IO WebSocket for real-time features.

---

## Application Overview

The app provides a TikTok-like short video experience with the following capabilities:

Core video features:
- Vertical-swipe video feed with HLS adaptive bitrate playback (720p/480p/360p)
- Video upload with progress tracking (single file and chunked upload)
- Video processing status screen with real-time updates
- Video editing (title, description, visibility, privacy settings)
- Video sharing with tracking

Social interaction:
- Like and unlike videos
- Nested comment threads with comment likes
- Follow and unfollow users
- Follower/following lists and follow request management
- User profile viewing
- Discover people suggestions
- Save/bookmark videos

Communication:
- Real-time one-on-one chat via Socket.IO WebSocket
- Message types: text, image, multiple images
- Message unsend, pinned messages, chat theming
- Chat search and media gallery
- Push notifications via Firebase Cloud Messaging (FCM)
- In-app notification overlay banners
- Notification settings (push and in-app)

Authentication and account management:
- Email/password registration with multi-step flow (birthday, email, username, password)
- Phone number registration via Firebase Phone OTP
- Google Sign-In (OAuth 2.0)
- Two-factor authentication (TOTP-based 2FA with QR code)
- Login with username or email
- Forgot password flow (email OTP and phone OTP)
- Change password
- Account linking (link email or phone to existing account)
- Logged devices / active sessions management
- Account deactivation and deletion

Content discovery and recommendations:
- Elasticsearch-powered video and user search
- Content recommendations based on watch time, interests, and engagement
- Category-based content filtering (For You / Following feeds)
- Interest selection during onboarding

Creator tools:
- Creator analytics dashboard with charts (views, likes, comments, shares over time)
- Video management (edit, hide, delete owned videos)
- Privacy settings per video (comments, duet, visibility)

Settings and personalization:
- Dark mode / light mode theme switching
- Language selection (English / Vietnamese via timeago)
- Privacy settings (private account, message permissions)
- Push notification preferences
- Blocked users management
- User reporting
- Activity/login history

---

## Tech Stack

- Flutter SDK ^3.9.2 (Dart)
- State management: StatefulWidget with service singletons
- HTTP client: `http` package
- Real-time: `socket_io_client` for Socket.IO WebSocket
- Video playback: `video_player` with custom HLS player widget
- Firebase: `firebase_core`, `firebase_auth` (phone OTP), `firebase_messaging` (FCM push notifications)
- Google Sign-In: `google_sign_in`
- Local storage: `shared_preferences` (non-sensitive), `flutter_secure_storage` (tokens)
- Charts: `fl_chart` for analytics
- Image picker: `image_picker` for avatar and chat image uploads
- In-app browser: `flutter_inappwebview`
- Local notifications: `flutter_local_notifications`

---

## Project Structure

```
lib/
  main.dart                       — App entry point, Firebase init, auto-login
  firebase_options.dart           — Firebase project configuration (auto-generated)
  src/
    config/
      app_config.dart             — Environment switching (dev/prod URLs)
    services/
      api_service.dart            — HTTP client with auth token injection
      auth_service.dart           — Login, register, token management, auto-login
      video_service.dart          — Video CRUD, upload, feed, chunked upload
      comment_service.dart        — Comment CRUD
      like_service.dart           — Like/unlike
      follow_service.dart         — Follow/unfollow, follower lists
      message_service.dart        — Chat messages, Socket.IO real-time
      notification_service.dart   — In-app notifications
      saved_video_service.dart    — Save/unsave bookmarks
      share_service.dart          — Video sharing
      fcm_service.dart            — Firebase push notification handling
      firebase_phone_auth_service.dart — Firebase Phone OTP
      theme_service.dart          — Dark/light mode persistence
      locale_service.dart         — Language preference
      video_playback_service.dart — HLS playback management
      video_prefetch_service.dart — Video feed prefetching
      analytics_tracking_service.dart — Creator analytics
      in_app_notification_service.dart — Overlay notification banners
    presentation/
      screens/                    — All app screens (44 screens)
      widgets/                    — Reusable UI components (27 widgets)
    features/
      auth/
        presentation/screens/     — Multi-step registration flow screens
    utils/
      message_utils.dart          — Chat message formatting helpers
      navigation_utils.dart       — Navigation utility functions
```

---

## Prerequisites

- Flutter SDK 3.9.2 or later
- Dart SDK (included with Flutter)
- Android Studio or VS Code with Flutter extension
- For Android: Android SDK with minimum API level 21 (Android 5.0)
- For iOS: Xcode 15+ and CocoaPods
- A running instance of the backend services (see the backend README)

---

## Getting Started (Local Development)

### Step 1 — Clone the repository

```bash
git clone <repository-url>
cd scalable_short_video_app
```

### Step 2 — Install Flutter dependencies

```bash
flutter pub get
```

### Step 3 — Firebase configuration

The app uses Firebase for phone OTP authentication and push notifications. The Firebase configuration is already included in the repository via `lib/firebase_options.dart` and the platform-specific files (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`).

If you need to set up your own Firebase project:
- Create a new Firebase project at https://console.firebase.google.com
- Enable Authentication > Phone sign-in method
- Enable Cloud Messaging
- Run `flutterfire configure` to generate the configuration files
- Add your Android app's SHA-1 fingerprint to Firebase Console (required for phone auth)

### Step 4 — Configure backend URLs

The app connects to the backend services. The configuration is in `lib/src/config/app_config.dart`:

- In **debug mode** (running from IDE with F5), the app automatically uses local development URLs:
  - Android emulator: `http://10.0.2.2:3000` (user-service) and `http://10.0.2.2:3002` (video-service)
  - iOS simulator / web: `http://localhost:3000` and `http://localhost:3002`

- In **release mode** (built APK/IPA), the app uses production URLs configured in `app_config.dart`.

If your backend runs on a different machine (e.g., a remote server), update the `_devUserServiceUrl` and `_devVideoServiceUrl` getters in `app_config.dart` to point to the correct IP address.

### Step 5 — Ensure the backend is running

Before launching the app, make sure the backend services are running (refer to the backend README for setup instructions). At minimum, the following must be running:
- user-service on port 3000
- video-service on port 3002
- MySQL, Redis, and RabbitMQ (via Docker Compose)

For full functionality (video processing, search), also start:
- video-worker-service on port 3003
- Elasticsearch on port 9200

### Step 6 — Run the app

On an Android emulator or connected device:

```bash
flutter run
```

Or specify a device:

```bash
flutter devices              # List available devices
flutter run -d <device-id>   # Run on specific device
```

For web (limited video playback support):

```bash
flutter run -d chrome
```

---

## Building for Production

### Android APK

```bash
flutter build apk --release
```

The output APK is at `build/app/outputs/flutter-apk/app-release.apk`.

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

### iOS (requires macOS with Xcode)

```bash
flutter build ios --release
```

Then archive and distribute via Xcode.

### Before building for production

Update the production URLs in `lib/src/config/app_config.dart`:
- Set `_prodApiGatewayUrl` to your EC2 Elastic IP or domain name.
- Set `_prodCloudFrontUrl` to your CloudFront distribution URL.
- The `_forceProduction` flag can be set to `true` to test production URLs in debug mode.

---

## Running Tests

```bash
flutter test
```

For test coverage:

```bash
flutter test --coverage
```

The coverage report is generated at `coverage/lcov.info`. To view it as HTML:

```bash
genhtml coverage/lcov.info -o coverage/html
```

---

## Environment Switching

The app determines the environment automatically based on the Flutter build mode:

- `flutter run` (debug) → Development URLs (localhost or 10.0.2.2)
- `flutter build apk --release` (release) → Production URLs (EC2 Elastic IP via API Gateway)

This behavior is controlled by the `isProduction` getter in `app_config.dart`, which checks `kReleaseMode`. No `.env` files or environment variables are needed for the Flutter app — all configuration is compile-time in `app_config.dart`.