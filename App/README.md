# 🏙️ Civic Reporter — Flutter Frontend

<div align="center">

**A community-driven civic issue reporting platform with AI-powered classification, real-time maps, and gamified civic engagement.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%5E3.12-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Live App](https://img.shields.io/badge/Live%20App-Firebase%20Hosting-orange?logo=firebase)](https://community-hero-app-500611.web.app)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Live Demo](#-live-demo)
- [Features](#-features)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Screens & Navigation](#-screens--navigation)
- [Firebase Integration](#-firebase-integration)
- [Design System](#-design-system)
- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [Configuration](#-configuration)
- [Running the App](#-running-the-app)
- [Building for Production](#-building-for-production)
- [Backend API](#-backend-api)
- [Firestore Data Schema](#-firestore-data-schema)
- [Role-Based Access Control](#-role-based-access-control)
- [Gamification System](#-gamification-system)
- [Testing](#-testing)
- [Dependencies](#-dependencies)

---

## 🌍 Overview

**Civic Reporter** is a Flutter application that empowers citizens to report infrastructure and civic issues (potholes, broken streetlights, flooding, illegal dumping, etc.) directly from their mobile device or browser. Reports are automatically classified by an AI model (Google Gemini) on the backend, geotagged with GPS coordinates, uploaded with photographic evidence to Firebase Storage, and pinned to a live public map in real time.

Government administrators can log in with an admin account to access a dedicated **Dispatch Console** to triage active reports, advance issue resolution, and award Karma points to citizens whose reports are verified and resolved.

---

## 🔗 Live Demo

The app is deployed to **Firebase Hosting**:

> **🌐 [https://community-hero-app-500611.web.app](https://community-hero-app-500611.web.app)**

The backend API runs on **Google Cloud Run**:

> **🔧 [https://civic-backend-446777296937.asia-south1.run.app](https://civic-backend-446777296937.asia-south1.run.app)**

---

## ✨ Features

### Citizen Features
| Feature | Description |
|---|---|
| 📸 **AI-Powered Issue Reporting** | Capture or upload a photo. The backend uses Google Gemini to automatically classify the issue type, severity, and generate a description. |
| 📍 **GPS Geotagging** | Reports are automatically stamped with the device's current GPS coordinates. |
| ☁️ **Cloud Evidence Upload** | Images are uploaded directly to Firebase Storage before submission; the backend receives a secure download URL, not a raw base64 blob. |
| 🗺️ **Live Issue Map** | A real-time map powered by `flutter_map` (OpenStreetMap) showing all active civic reports as custom colour-coded markers. Firestore `snapshots()` stream ensures pins appear instantly without manual refresh. |
| 📊 **Impact Insights** | Aggregated dashboard with bar charts showing report distribution by category (Roads, Sanitation, Electrical, Water, Others), resolution rates, and an AI-generated predictive advisory. |
| 👤 **Citizen Profile** | Personal dashboard displaying Karma score, achievement badges, and a history of submitted reports. |
| ✏️ **Profile Editing** | Users can update their display name and bio, which sync back to Firestore. |
| 🔐 **Authentication** | Email/password sign-in and sign-up with Firebase Auth. Includes a "Forgot Password" reset flow via email. |
| 🏆 **Gamification / Karma** | Citizens earn **+50 Karma** on every accepted report and **+100 Karma** when an admin marks their issue as Resolved. |

### Admin Features
| Feature | Description |
|---|---|
| 🚔 **Admin Dispatch Console** | A 4th bottom-nav tab that appears exclusively when the signed-in user has `role: 'admin'` set in Firestore. |
| 📋 **Active Dispatch Queue** | Real-time list of all Pending and In-Progress reports sorted by timestamp (newest first). |
| ✅ **Resolved History** | Tabbed view of all resolved reports with timestamps and photographic evidence. |
| ▶️ **Start Work** | Advances a Pending report to "In Progress" status. |
| ✔️ **Resolve Issue** | Marks a report as "Resolved" and atomically awards the reporter +100 Karma via a Firestore write batch. |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Client)                  │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │  Report  │  │ Live Map │  │ Insights │  │Dispatch│  │
│  │  Issue   │  │ (Stream) │  │ (HTTP)   │  │(Admin) │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬────┘  │
│       │              │              │              │       │
│       ▼              ▼              ▼              ▼       │
│     Firebase      Firestore      Cloud Run     Firestore  │
│     Storage       Stream         REST API      Write      │
└─────────────────────────────────────────────────────────┘
        │                                      │
        ▼                                      ▼
  Firebase Storage              ┌──────────────────────────┐
  (reports/{uuid}.jpg)          │  Google Cloud Run Backend │
                                │  FastAPI + Gemini AI      │
                                │  → Classifies issue       │
                                │  → Writes to Firestore    │
                                └──────────────────────────┘
```

**Data Flow for a New Report:**
1. User captures a photo → image is uploaded to **Firebase Storage** → download URL obtained.
2. App sends `POST /report-issue` with `{ imageUrl, latitude, longitude, userId }` to the Cloud Run backend.
3. Backend downloads image from the URL → sends it to **Google Gemini** for classification.
4. Backend writes the classified report document to the **Firestore** `reports` collection.
5. The Live Map's `StreamBuilder` receives the new document instantly and renders a new pin — no refresh needed.

---

## 📁 Project Structure

```
App/
├── lib/
│   ├── main.dart                    # App entry point, theme, AppColors, MainContainer shell
│   ├── api_config.dart              # Centralised API base URL config
│   ├── firebase_options.dart        # Auto-generated FlutterFire platform options
│   │
│   ├── models/
│   │   └── issue.dart               # Issue data model with severity enum & computed props
│   │
│   ├── screens/
│   │   ├── auth_gate.dart           # Firebase Auth stream gate (Login ↔ App shell)
│   │   ├── login_screen.dart        # Sign In / Sign Up / Forgot Password UI
│   │   ├── report_issue_screen.dart # Photo capture, GPS, submission flow
│   │   ├── live_map_screen.dart     # Real-time Firestore map with flutter_map
│   │   ├── insights_screen.dart     # fl_chart analytics dashboard
│   │   ├── profile_screen.dart      # Citizen profile, Karma, badges, report history
│   │   ├── edit_profile_screen.dart # Profile name/bio editing
│   │   └── admin_dispatch_screen.dart # Role-gated admin triage console
│   │
│   └── widgets/
│       ├── scale_interactive_widget.dart  # Tap-scale micro-animation wrapper
│       └── fade_in_stagger_text.dart      # Staggered text fade-in animation
│
├── test/
│   └── widget_test.dart             # Smoke test for app startup
├── pubspec.yaml                     # Package manifest & dependencies
├── firebase.json                    # Firebase Hosting config
└── .firebaserc                      # Firebase project alias
```

---

## 📱 Screens & Navigation

The app uses an `IndexedStack` with a frosted-glass `BottomNavigationBar` to preserve screen state across tab switches (critical for the live map viewport).

```
AuthGate ──► LoginScreen
         └─► MainContainer
               ├── [0] ReportIssueScreen  (tab: Campaign icon)
               ├── [1] LiveMapScreen      (tab: Globe icon)
               ├── [2] InsightsScreen     (tab: Bar Chart icon)
               └── [3] AdminDispatchScreen (tab: Police icon — admin only)
```

The **profile icon** in the top-right corner of the AppBar opens `ProfileScreen` as a modal route, keeping the avatar in-sync with the Firestore user document.

### Screen Descriptions

#### 📣 Report Issue (`report_issue_screen.dart`)
- Camera/gallery image picker via `image_picker`.
- GPS location acquisition via `geolocator` with graceful permission handling.
- Image uploaded to Firebase Storage under `reports/{timestamp}_{random}.jpg` before HTTP submission.
- Animated loading overlay with a single circular progress spinner during submission.
- Real-time status messages ("Locating GPS…", "Uploading evidence…", "Submitting to AI…").

#### 🗺️ Live Map (`live_map_screen.dart`)
- `flutter_map` with OpenStreetMap tile layer.
- Firestore `collection('reports').snapshots()` `StreamBuilder` — zero-latency updates.
- Custom circular marker widgets colour-coded by severity (Red = High, Orange = Medium, Green = Low).
- Tapping a marker opens a bottom sheet with full report details and photographic evidence thumbnail.
- Legend overlay and user location crosshair button.

#### 📊 Insights (`insights_screen.dart`)
- Fetches live data from `GET /issues` on the Cloud Run backend.
- Calculates resolved vs. active counts, category breakdowns, and average resolution time.
- `fl_chart` `BarChart` showing issues per category.
- AI-generated predictive advisory based on the most reported category.

#### 👤 Profile (`profile_screen.dart`)
- Real-time Karma score streamed from `users/{uid}` Firestore document.
- Achievement badge system with lock/unlock indicators and progress rings.
- Report history list.
- Sign Out button.
- Routes to `EditProfileScreen` for name/bio updates.

#### 🚔 Admin Dispatch (`admin_dispatch_screen.dart`)
- Only visible when `users/{uid}.role == 'admin'`.
- Two tabs: **Active Dispatch** (Pending + In Progress) and **Resolved History**.
- Each card shows: evidence image, classification, description, severity badge, status pill, timestamp.
- "Start Work" → sets `status: 'In Progress'`.
- "Resolve Issue" → Firestore batch: sets `status: 'Resolved'` + increments reporter's `karma` by 100.

---

## 🔥 Firebase Integration

| Firebase Product | Usage |
|---|---|
| **Firebase Auth** | Email/password sign-in and sign-up; auth state stream drives `AuthGate` |
| **Cloud Firestore** | `reports` collection (all civic reports), `users` collection (profiles, karma, roles) |
| **Firebase Storage** | Stores photographic evidence at `reports/{uuid}.jpg` |
| **Firebase Analytics** | Logs `screen_view` events on each bottom-nav tab switch and `app_open` on launch |
| **Firebase Hosting** | Hosts the production Flutter Web build |

---

## 🎨 Design System

All brand colours are centralised in `AppColors` in `lib/main.dart`:

```dart
class AppColors {
  static const navyBlue  = Color(0xFF1E3A8A); // Authority & trust — primary
  static const orange    = Color(0xFFF97316); // Hazard & urgency — accent
  static const bgGray    = Color(0xFFF3F4F6); // Scaffold background
  static const textDark  = Color(0xFF0F172A); // Primary text
  static const textMid   = Color(0xFF475569); // Secondary text
  static const textLight = Color(0xFF94A3B8); // Placeholder / subtle text
  static const success   = Color(0xFF16A34A); // Resolved / Low severity
  static const warning   = Color(0xFFD97706); // Medium severity
  static const danger    = Color(0xFFDC2626); // High severity / errors
}
```

**Design Principles:**
- **Material 3** (`useMaterial3: true`) with a fully custom `ColorScheme`.
- **Frosted glass** bottom navigation bar via `BackdropFilter` + `ImageFilter.blur`.
- **Micro-animations**: `ScaleInteractiveWidget` applies a press-scale effect to tappable cards and buttons.
- **Staggered text fade-in** on report submission confirmation via `FadeInStaggerText`.
- Severity-colour-coded map markers and status badges for at-a-glance triage.

---

## ✅ Prerequisites

- **Flutter SDK** ≥ 3.12 — [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Dart SDK** ≥ 3.12 (bundled with Flutter)
- **Firebase CLI** — `npm install -g firebase-tools`
- **FlutterFire CLI** — `dart pub global activate flutterfire_cli`
- A **Firebase project** with Auth, Firestore, Storage, Analytics, and Hosting enabled
- A running instance of the **Civic Reporter Backend** (see [Backend API](#-backend-api))

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd "Vibe2Ship Hackathon/App"
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

The `lib/firebase_options.dart` file is already generated for the `community-hero-app-500611` project. To connect to your own Firebase project:

```bash
# Login to Firebase
firebase login

# Configure FlutterFire for your project
flutterfire configure
```

This will regenerate `lib/firebase_options.dart` with your project's credentials.

### 4. Set the Backend URL

Open [`lib/api_config.dart`](lib/api_config.dart) and update `baseUrl` to point to your backend:

```dart
static String get baseUrl {
  return 'https://your-cloud-run-url.run.app';
  // For local development: 'http://localhost:8000'
  // For Android emulator: 'http://10.0.2.2:8000'
}
```

---

## ⚙️ Configuration

### Firestore Security Rules

Ensure your Firestore rules allow authenticated users to read/write reports and their own user documents:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /reports/{reportId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      // Admin can write to any user document (for Karma awards)
      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### Firebase Storage Rules

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /reports/{imageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.size < 10 * 1024 * 1024;
    }
  }
}
```

---

## 🏃 Running the App

### Mobile (Android / iOS)

```bash
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device-id>
```

### Web (Local)

```bash
flutter run -d chrome
```

### With a specific environment

```bash
# Debug mode (default)
flutter run

# Profile mode (performance testing)
flutter run --profile

# Release mode
flutter run --release
```

---

## 📦 Building for Production

### Web (Firebase Hosting)

```bash
# Build the web bundle
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

Live URL: [https://community-hero-app-500611.web.app](https://community-hero-app-500611.web.app)

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS

```bash
flutter build ios --release
# Then archive in Xcode for App Store submission
```

---

## 🔧 Backend API

The app communicates with a FastAPI backend deployed on Google Cloud Run.

**Base URL:** `https://civic-backend-446777296937.asia-south1.run.app`

| Endpoint | Method | Description |
|---|---|---|
| `/` | `GET` | Health check — returns `{ status: "running" }` |
| `/report-issue` | `POST` | Accepts an image URL (or base64), GPS coords, and userId. Returns AI classification. |
| `/issues` | `GET` | Returns all reports from Firestore as a JSON array. |

**`POST /report-issue` — Request Body:**
```json
{
  "imageUrl": "https://storage.googleapis.com/...",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "userId": "uid_abc123"
}
```

**Response:**
```json
{
  "id": "firestore_document_id",
  "classification": "Pothole",
  "severity": "High",
  "description": "A large pothole spanning half the road width.",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "status": "Pending",
  "timestamp": "2026-06-28T08:00:00.000Z"
}
```

> **Note:** The backend source code lives in the `../Backend/` directory.

---

## 🗄️ Firestore Data Schema

### `reports` collection

```
reports/{reportId}
├── classification  : String   — e.g. "Pothole", "Broken Streetlight"
├── severity        : String   — "Low" | "Medium" | "High"
├── description     : String   — AI-generated one-sentence description
├── latitude        : Number   — GPS latitude
├── longitude       : Number   — GPS longitude
├── imageUrl        : String   — Firebase Storage download URL
├── userId          : String   — UID of the reporting user
├── status          : String   — "Pending" | "In Progress" | "Resolved"
└── timestamp       : Timestamp
```

### `users` collection

```
users/{uid}
├── name     : String   — Display name
├── email    : String   — Email address
├── karma    : Number   — Accumulated Karma points
├── role     : String   — "citizen" (default) | "admin"
└── bio      : String   — Optional bio text (optional)
```

---

## 🔐 Role-Based Access Control

Admin access is controlled entirely via Firestore. There is no separate login flow — admins use the same email/password authentication.

**To grant admin access to a user:**

1. Open the [Firebase Console](https://console.firebase.google.com/) → Firestore.
2. Navigate to the `users` collection.
3. Find the user's document (keyed by their UID).
4. Add or update the field: `role` → `"admin"`.

The app's `_MainContainerState._loadUser()` listens to the user document in real time. The moment `role` is set to `"admin"`, the Dispatch tab appears in the bottom navigation bar without requiring a restart.

---

## 🏆 Gamification System

Citizens accumulate **Karma points** as a measure of their civic contribution:

| Action | Karma Awarded |
|---|---|
| Submitting a report (accepted by AI) | **+50 points** |
| Report resolved by an admin | **+100 points** |

Karma is stored in `users/{uid}.karma` as a Firestore `Number` field, incremented server-side using `FieldValue.increment()` to prevent race conditions.

Future badge tiers are already scaffolded in `profile_screen.dart` and can be unlocked based on Karma thresholds.

---

## 🧪 Testing

The project includes a basic smoke test that validates the app starts without crashing:

```bash
flutter test
```

All Firebase-dependent screens include a `isTestMode` guard that detects the `FLUTTER_TEST` environment variable and renders a static placeholder instead of attempting to connect to Firestore, preventing uninitialized Firebase crashes in the test runner.

```bash
# Expected output
No issues found! (ran in ~1s)
All tests passed!
```

To run the static analyser:

```bash
flutter analyze
```

---

## 📦 Dependencies

| Package | Version | Purpose |
|---|---|---|
| `firebase_core` | ^4.11.0 | Firebase SDK initialisation |
| `firebase_auth` | ^6.5.4 | Email/password authentication |
| `cloud_firestore` | ^6.6.0 | Real-time database (reports, users) |
| `firebase_storage` | ^13.4.3 | Cloud image storage |
| `firebase_analytics` | ^12.4.3 | Screen-view and app-open event tracking |
| `flutter_map` | ^8.3.0 | OpenStreetMap-based interactive map |
| `latlong2` | ^0.9.1 | Lat/Lng coordinate types for flutter_map |
| `geolocator` | ^14.0.3 | Device GPS location access |
| `image_picker` | ^1.2.2 | Camera & gallery photo selection |
| `http` | ^1.6.0 | HTTP requests to the Cloud Run backend |
| `fl_chart` | ^0.70.0 | Bar charts on the Insights screen |
| `intl` | ^0.20.3 | Date/time formatting |
| `cupertino_icons` | ^1.0.8 | iOS-style icon set |

---

<div align="center">

Built with ❤️ for the **Vibe2Ship Hackathon**

</div>
