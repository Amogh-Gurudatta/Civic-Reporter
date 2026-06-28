# 🏙️ Civic Reporter — Community Hero: Hyperlocal Problem Solver

> **Vibe2Ship Hackathon Submission**
>
> *Empowering citizens to identify, report, validate, track, and resolve community issues through AI, real-time data, and collaborative engagement.*

### 🌐 [Live Demo → community-hero-app-500611.web.app](https://community-hero-app-500611.web.app/)
### 🌐 [Android APK](https://github.com/Amogh-Gurudatta/Civic-Reporter/releases/download/v1.0.0/app-release.apk)

---

## 📋 Table of Contents

- [Problem Statement](#-problem-statement)
- [My Solution](#-my-solution)
- [Key Features](#-key-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
  - [Backend Setup](#backend-setup-fastapi--google-cloud-run)
  - [Flutter App Setup](#flutter-app-setup)
- [API Reference](#-api-reference)
- [Environment Variables](#-environment-variables)
- [Deployment](#-deployment)

---

## 🎯 Problem Statement

Communities frequently face infrastructure issues — potholes, water leakages, damaged streetlights, waste management failures, and more. Reporting these issues today is:

- **Fragmented** — no unified channel for citizens to report
- **Opaque** — no transparency on status or resolution
- **Passive** — citizens report and forget; no community validation
- **Reactive** — problems are addressed only after they escalate

---

## 💡 My Solution

**Civic Reporter** is a full-stack, AI-powered civic issue reporting platform. Citizens can photograph a community problem, and the app automatically:

1. **Classifies** the issue type using Gemini AI (pothole, broken streetlight, flooding, etc.)
2. **Rates severity** (Low / Medium / High) from the image
3. **Geotags** the report with GPS coordinates
4. **Persists** the report to a live Firestore database
5. **Visualises** all issues on a live interactive map
6. **Gamifies** citizen participation through a karma / leaderboard system

---

## ✨ Key Features

| Feature | Description |
|---|---|
| 📸 **Image-Based Reporting** | Capture or upload a photo; AI does the rest |
| 🤖 **AI Categorisation** | Gemini 2.5 Pro classifies issue type & severity automatically |
| 🗺️ **Live Map View** | All community reports plotted on an interactive `flutter_map` with severity colour-coding |
| 📍 **GPS Geo-tagging** | Precise location attached to every report using device GPS |
| 📊 **Insights Dashboard** | Charts (via `fl_chart`) showing issue breakdown, severity trends, and resolution rates |
| 🏅 **Karma & Gamification** | Users earn +50 karma per verified report; profile page shows rank and contribution history |
| 👤 **Auth & Profiles** | Firebase Authentication with editable user profiles |
| 🔧 **Admin Dispatch Panel** | Admin screen to assign and update issue resolution status |
| ⚡ **Real-time Updates** | Firestore listeners push live changes to all clients instantly |
| 🚀 **Cloud-native Backend** | FastAPI deployed on Google Cloud Run; auto-scales to zero |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter App (Mobile)                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │  Report  │  │ Live Map │  │ Insights │  │Profile │  │
│  │  Screen  │  │  Screen  │  │  Screen  │  │ Screen │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬────┘  │
│       │             │              │             │       │
│       └─────────────┴──────────────┴─────────────┘      │
│                          │                              │
└──────────────────────────┼──────────────────────────────┘
                           │  HTTP / REST
          ┌────────────────┼──────────────────┐
          │                ▼                  │
          │    FastAPI Backend (Cloud Run)    │
          │  ┌────────────────────────────┐  │
          │  │  POST /report-issue        │  │
          │  │  GET  /issues              │  │
          │  └──────────┬─────────────────┘  │
          │             │                    │
          │      ┌──────┴──────┐             │
          │      ▼             ▼             │
          │  Gemini AI    Firestore DB       │
          │  (classify)   (persist/read)     │
          └──────────────────────────────────┘
                          │
          ┌───────────────┘
          ▼
   Firebase Auth + Storage
   (used directly by Flutter SDK)
```

The Flutter app communicates with the **FastAPI backend** for AI-powered issue analysis, and directly with **Firebase** for authentication, real-time data streaming, and file storage.

---

## 🛠️ Tech Stack

### Mobile App (`/App`)

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State Management | `setState` / `StreamBuilder` |
| Maps | `flutter_map` + OpenStreetMap tiles |
| Charts | `fl_chart` |
| Authentication | Firebase Auth |
| Database (client) | Cloud Firestore (real-time streams) |
| Storage | Firebase Storage |
| Location | `geolocator` |
| Image Picking | `image_picker` |
| HTTP Client | `http` |

### Backend (`/Backend`)

| Layer | Technology |
|---|---|
| Framework | FastAPI (Python 3.14) |
| AI / ML | Google Gemini 2.5 Pro (via `google-genai` SDK) |
| Database | Cloud Firestore (via `firebase-admin`) |
| Image Processing | Pillow |
| Server | Uvicorn |
| Containerisation | Docker |
| Hosting | Google Cloud Run |

---

## 📁 Project Structure

```
Vibe2Ship Hackathon/
├── README.md                     ← You are here
│
├── App/                          # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart             # App entry point, routing & theme
│   │   ├── api_config.dart       # Backend URL configuration
│   │   ├── firebase_options.dart # Firebase project config (FlutterFire CLI)
│   │   ├── models/               # Data models
│   │   ├── screens/
│   │   │   ├── login_screen.dart          # Firebase Auth (email / Google)
│   │   │   ├── auth_gate.dart             # Auth state router
│   │   │   ├── report_issue_screen.dart   # Issue capture & AI submission
│   │   │   ├── live_map_screen.dart       # Real-time issue map
│   │   │   ├── insights_screen.dart       # Analytics dashboard
│   │   │   ├── profile_screen.dart        # User profile & karma
│   │   │   ├── edit_profile_screen.dart   # Profile editor
│   │   │   └── admin_dispatch_screen.dart # Admin panel
│   │   └── widgets/              # Reusable UI components
│   ├── pubspec.yaml              # Flutter dependencies
│   └── .gitignore
│
└── Backend/                      # FastAPI backend service
    ├── main.py                   # All API routes & business logic
    ├── requirements.txt          # Python dependencies
    ├── Dockerfile                # Container definition for Cloud Run
    ├── .env.example              # Environment variable template
    ├── test_main.py              # API test suite
    └── .gitignore
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.12
- Python ≥ 3.11
- A [Firebase project](https://console.firebase.google.com/) with Firestore, Auth, and Storage enabled
- A [Google AI Studio](https://aistudio.google.com/) API key (Gemini)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) (for app Firebase config)

---

### Backend Setup (FastAPI + Google Cloud Run)

#### 1. Enter the backend directory

```bash
cd "Vibe2Ship Hackathon/Backend"
```

#### 2. Create and activate a virtual environment

```bash
python -m venv .venv
source .venv/bin/activate        # macOS / Linux
.venv\Scripts\activate           # Windows
```

#### 3. Install dependencies

```bash
pip install -r requirements.txt
```

#### 4. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env`:

```env
GEMINI_API_KEY=your_gemini_api_key_here
FIREBASE_CREDENTIALS_PATH=firebase-key.json
```

> ⚠️ **Never commit `.env` or `firebase-key.json` to version control.** Both are in `.gitignore`.

#### 5. Run locally

```bash
uvicorn main:app --reload --port 8080
```

The API will be available at `http://localhost:8080`.
Interactive Swagger docs: `http://localhost:8080/docs`

#### 6. Run tests

```bash
pytest test_main.py -v
```

---

### Flutter App Setup

#### 1. Enter the app directory

```bash
cd "Vibe2Ship Hackathon/App"
```

#### 2. Configure Firebase

Run the FlutterFire CLI to generate `firebase_options.dart`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

#### 3. Point the app at your backend

Edit `lib/api_config.dart`:

```dart
// Local development (Android emulator):
return 'http://10.0.2.2:8080';

// Production (Cloud Run):
return 'https://your-cloud-run-service.run.app';
```

#### 4. Install Flutter packages

```bash
flutter pub get
```

#### 5. Run the app

```bash
flutter run
```

---

## 📡 API Reference

**Production Base URL:** `https://civic-backend-446777296937.asia-south1.run.app`

---

### `GET /`

Health check endpoint.

**Response:**
```json
{ "status": "running", "app": "Civic Issue Reporting API" }
```

---

### `POST /report-issue`

Submit a new civic issue for AI analysis and storage.

**Request Body:**
```json
{
  "image": "<base64-encoded-image>",
  "imageUrl": "https://example.com/photo.jpg",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "userId": "firebase-user-uid"
}
```

> Provide either `image` (base64) **or** `imageUrl` — not both.

**Response `201 Created`:**
```json
{
  "id": "firestore-document-id",
  "classification": "Pothole",
  "severity": "High",
  "description": "Large pothole on main road causing traffic disruption.",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "imageUrl": "https://...",
  "userId": "user123",
  "status": "Pending",
  "timestamp": "2026-06-28T11:00:00+00:00"
}
```

**AI Model Fallback Chain (rate-limit resilient):**
`gemini-2.5-pro → gemini-2.5-flash → gemini-2.5-flash-lite`

**Side effects:**
- Report is saved to the `reports` Firestore collection
- Reporting user's karma is incremented by +50

---

### `GET /issues`

Fetch all reported civic issues from Firestore.

**Response `200 OK`:** Array of issue objects (same shape as above).

---

## 🔑 Environment Variables

### Backend (`Backend/.env`)

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | ✅ | Google AI Studio API key |
| `FIREBASE_CREDENTIALS_PATH` | ✅ | Path to Firebase service account JSON file |
| `PORT` | ❌ | Server port (default `8080`; auto-set by Cloud Run) |

---

## ☁️ Deployment

### Backend → Google Cloud Run

```bash
cd "Vibe2Ship Hackathon/Backend"

# Build and push container image
gcloud builds submit --tag gcr.io/<PROJECT_ID>/civic-backend

# Deploy to Cloud Run
gcloud run deploy civic-backend \
  --image gcr.io/<PROJECT_ID>/civic-backend \
  --platform managed \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY=<key>
```

### Flutter App → Android / iOS

```bash
# Android release APK
flutter build apk --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

---

## 📄 License

This project was built for a hackathon. Third-party service terms apply (Firebase, Google Gemini, OpenStreetMap).
