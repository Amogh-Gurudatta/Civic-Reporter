# 🏙️ Civic Issue Reporting — Backend

A secure, production-ready **FastAPI** backend that accepts civic issue reports from a mobile client, classifies the infrastructure problem using **Google Gemini AI** with an automatic model-cascading fallback strategy, and persists the results in **Firebase Firestore**. Deployed on **Google Cloud Run**.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started (Local)](#getting-started-local)
  - [Prerequisites](#prerequisites)
  - [Environment Variables](#environment-variables)
  - [Running Locally](#running-locally)
- [API Reference](#api-reference)
  - [GET /](#get-)
  - [POST /report-issue](#post-report-issue)
  - [GET /issues](#get-issues)
- [Key Features](#key-features)
  - [Dual Image Input Support](#dual-image-input-support)
  - [Gemini Model Cascading](#gemini-model-cascading)
  - [Karma Gamification](#karma-gamification)
  - [Firestore Data Model](#firestore-data-model)
- [Running Tests](#running-tests)
- [Docker](#docker)
- [Deploying to Google Cloud Run](#deploying-to-google-cloud-run)
- [Interactive API Docs](#interactive-api-docs)

---

## Architecture Overview

```
Flutter App
    │
    │  POST /report-issue  (imageUrl or base64 + GPS + userId)
    ▼
FastAPI Backend (Cloud Run)
    │
    ├── 1. Download / decode image (requests / PIL)
    │
    ├── 2. Gemini AI Classification  ◄──── Model Cascade Fallback
    │         gemini-2.5-pro
    │         gemini-3.5-flash
    │         gemini-3-flash
    │         gemini-2.5-flash
    │         gemini-2-flash
    │         gemini-2.5-flash-lite
    │
    └── 3. Persist to Firebase Firestore
              ├── reports/{docId}   ← Issue record
              └── users/{userId}    ← karma += 50
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Web Framework | [FastAPI](https://fastapi.tiangolo.com/) |
| ASGI Server | [Uvicorn](https://www.uvicorn.org/) |
| AI / Vision | [Google Gemini](https://ai.google.dev/) via `google-genai` SDK |
| Database | [Firebase Firestore](https://firebase.google.com/docs/firestore) via `firebase-admin` |
| Image Processing | [Pillow](https://pillow.readthedocs.io/) |
| Config Management | `python-dotenv` |
| Containerisation | Docker (Python 3.14-slim) |
| Hosting | Google Cloud Run |

---

## Project Structure

```
Backend/
├── main.py              # FastAPI application — routes, models, and business logic
├── test_main.py         # Pytest unit test suite (11 test cases)
├── requirements.txt     # Python dependencies
├── Dockerfile           # Container build definition for Cloud Run
├── .env                 # Local secrets (NOT committed to git)
├── .env.example         # Template for required environment variables
├── .gitignore
└── firebase-key.json    # Firebase service account key (NOT committed to git)
```

---

## Getting Started (Local)

### Prerequisites

- Python **3.11+** (project uses 3.14)
- A Google AI Studio account → [Get a Gemini API Key](https://aistudio.google.com/app/apikey)
- A Firebase project with Firestore enabled → [Firebase Console](https://console.firebase.google.com/)
- A Firebase **service account key** JSON file (downloaded from Firebase Console → Project Settings → Service Accounts)

### Environment Variables

Copy the example file and fill in your credentials:

```bash
cp .env.example .env
```

Edit `.env`:

```dotenv
# Gemini API Key (get from Google AI Studio)
GEMINI_API_KEY=your_gemini_api_key_here

# Path to your Firebase service account credentials JSON file.
# If using Application Default Credentials (e.g. on Cloud Run), leave empty.
FIREBASE_CREDENTIALS_PATH=firebase-key.json
```

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | ✅ Yes | Google AI Studio API key used to authenticate with the Gemini SDK |
| `FIREBASE_CREDENTIALS_PATH` | ⚠️ Local only | Path to the Firebase service account JSON key. Omit when deploying to Cloud Run (uses Application Default Credentials) |

> [!CAUTION]
> **Never commit `.env` or `firebase-key.json` to version control.** Both are listed in `.gitignore`.

### Running Locally

```bash
# 1. Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Start the development server (defaults to port 8080)
uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

The server will be available at `http://localhost:8080`. Interactive docs are at `http://localhost:8080/docs`.

---

## API Reference

### GET /

Health-check endpoint.

**Response `200 OK`**
```json
{
  "status": "running",
  "app": "Civic Issue Reporting API"
}
```

---

### POST /report-issue

Submit a new civic issue report. The backend downloads or decodes the image, classifies it with Gemini AI, saves the result to Firestore, and awards karma to the reporting user.

**Request Body** (`application/json`)

| Field | Type | Required | Description |
|---|---|---|---|
| `imageUrl` | `string` | ✅ (or `image`) | Public HTTP/HTTPS URL of the image to analyze |
| `image` | `string` | ✅ (or `imageUrl`) | Base64-encoded image string (data URI prefix optional) |
| `latitude` | `float` | ✅ | GPS latitude — must be between `-90.0` and `90.0` |
| `longitude` | `float` | ✅ | GPS longitude — must be between `-180.0` and `180.0` |
| `userId` | `string` | ❌ | Firebase UID of the reporting user. Defaults to `"anonymous"` |

> [!IMPORTANT]
> **At least one** of `imageUrl` or `image` must be provided. If both are supplied, `imageUrl` takes priority.

**Example Request (image URL)**
```json
{
  "imageUrl": "https://storage.googleapis.com/my-bucket/pothole.jpg",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "userId": "user_firebase_uid_abc123"
}
```

**Example Request (base64)**
```json
{
  "image": "data:image/jpeg;base64,/9j/4AAQSkZJRgAB...",
  "latitude": 12.9716,
  "longitude": 77.5946
}
```

**Response `201 Created`**
```json
{
  "id": "Kx9aLmN3pQrTvWyZ",
  "classification": "Pothole",
  "severity": "High",
  "description": "A large, deep pothole spanning most of the lane.",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "imageUrl": "https://storage.googleapis.com/my-bucket/pothole.jpg",
  "userId": "user_firebase_uid_abc123",
  "status": "Pending",
  "timestamp": "2026-06-28T11:19:00+00:00"
}
```

**Error Responses**

| Status | Condition |
|---|---|
| `400 Bad Request` | Neither `image` nor `imageUrl` provided, invalid base64 data, or failed to download from URL |
| `422 Unprocessable Entity` | GPS coordinates out of valid range |
| `502 Bad Gateway` | Gemini API returned a non-rate-limit error |
| `503 Service Unavailable` | All Gemini fallback models are rate-limited |
| `500 Internal Server Error` | Firestore write failure |

---

### GET /issues

Fetch all civic issue reports from the Firestore `reports` collection.

**Response `200 OK`** — Array of issue objects
```json
[
  {
    "id": "Kx9aLmN3pQrTvWyZ",
    "classification": "Pothole",
    "severity": "High",
    "description": "A large, deep pothole spanning most of the lane.",
    "latitude": 12.9716,
    "longitude": 77.5946,
    "imageUrl": "https://...",
    "userId": "user_firebase_uid_abc123",
    "status": "Pending",
    "timestamp": "2026-06-28T11:19:00+00:00"
  }
]
```

| Status | Condition |
|---|---|
| `500 Internal Server Error` | Failed to read from Firestore |

---

## Key Features

### Dual Image Input Support

The `POST /report-issue` endpoint accepts images in two ways, giving the Flutter client flexibility:

- **`imageUrl`** (preferred): The backend fetches the image bytes directly from the provided URL using `requests.get()` with a 10-second timeout.
- **`image`** (legacy): A base64-encoded string, with optional data URI prefix (e.g. `data:image/jpeg;base64,...`). Padding is added automatically if missing.

Both paths produce a PIL `Image` object that is passed directly to the Gemini SDK for multimodal analysis.

---

### Gemini Model Cascading

To handle API rate limits gracefully, the backend tries a prioritised list of Gemini models in order:

```python
fallback_models = [
    "gemini-2.5-pro",       # Most powerful — tried first
    "gemini-3.5-flash",
    "gemini-3-flash",
    "gemini-2.5-flash",
    "gemini-2-flash",
    "gemini-2.5-flash-lite", # Most lightweight — last resort
]
```

If a model returns a `429 / Quota / ResourceExhausted` error, the backend logs a warning and automatically moves to the next model. Non-rate-limit errors fail immediately with `502`. If all models are exhausted, the endpoint returns `503`.

---

### Karma Gamification

Every successfully processed report awards **50 karma points** to the reporting user in Firestore:

```python
user_ref = db.collection("users").document(payload.userId)
user_ref.set({"karma": firestore.Increment(50)}, merge=True)
```

`merge=True` ensures the operation works even if the user document does not yet exist — it will be created with `karma: 50`.

---

### Firestore Data Model

#### `reports` collection

| Field | Type | Description |
|---|---|---|
| `classification` | `string` | Issue category (e.g. `Pothole`, `Flooding`) |
| `severity` | `string` | `Low`, `Medium`, or `High` |
| `description` | `string` | One-sentence AI-generated description |
| `latitude` | `number` | GPS latitude |
| `longitude` | `number` | GPS longitude |
| `imageUrl` | `string` | Source image URL (empty string if base64 input) |
| `userId` | `string` | Reporter's Firebase UID or `"anonymous"` |
| `status` | `string` | Always `"Pending"` on creation |
| `timestamp` | `timestamp` | UTC creation time |

#### `users` collection

| Field | Type | Description |
|---|---|---|
| `karma` | `number` | Cumulative karma points. Incremented by 50 per report. |

---

## Running Tests

The test suite uses `pytest` with `unittest.mock` to fully isolate Firebase Admin, the Gemini SDK, and `requests.get` — no live API keys or network access required.

```bash
# Run all 11 tests with verbose output
GEMINI_API_KEY="mock_key" ./.venv/bin/pytest -v test_main.py
```

**Test coverage:**

| Test | Description |
|---|---|
| `test_read_root` | Health check endpoint returns correct status |
| `test_report_issue_success` | Full happy-path with imageUrl, Gemini mock, Firestore mock, and karma check |
| `test_report_issue_success_default_user` | Anonymous user defaults + karma increment |
| `test_report_issue_invalid_coordinates` | 422 on out-of-range GPS values |
| `test_report_issue_download_failure` | 400 when `requests.get` raises a network exception |
| `test_report_issue_gemini_failure` | 502 on non-rate-limit Gemini error |
| `test_report_issue_firestore_failure` | 500 when Firestore write throws |
| `test_get_issues_success` | Returns correctly serialised issue list |
| `test_get_issues_firestore_failure` | 500 when Firestore read throws |
| `test_report_issue_model_cascading_success` | Falls back to 3rd model after two rate-limit errors |
| `test_report_issue_model_cascading_all_exhausted` | 503 after all 6 models hit rate limits |

---

## Docker

Build and run the container locally:

```bash
# Build
docker build -t civic-backend .

# Run (supply environment variables at runtime)
docker run -p 8080:8080 \
  -e GEMINI_API_KEY=your_key_here \
  -e FIREBASE_CREDENTIALS_PATH=/app/firebase-key.json \
  -v $(pwd)/firebase-key.json:/app/firebase-key.json \
  civic-backend
```

The `Dockerfile` uses Python 3.14-slim, installs dependencies, and starts Uvicorn on the `$PORT` environment variable (defaulting to `8080`), which is the convention required by Google Cloud Run.

---

## Deploying to Google Cloud Run

The backend is deployed to Cloud Run and is live at:

```
https://civic-backend-446777296937.asia-south1.run.app
```

### Manual Deployment Steps

```bash
# 1. Authenticate with Google Cloud
gcloud auth login

# 2. Set your project ID
gcloud config set project YOUR_PROJECT_ID

# 3. Build and push the container image to Artifact Registry
gcloud builds submit --tag asia-south1-docker.pkg.dev/YOUR_PROJECT_ID/REPO/civic-backend

# 4. Deploy to Cloud Run
gcloud run deploy civic-backend \
  --image asia-south1-docker.pkg.dev/YOUR_PROJECT_ID/REPO/civic-backend \
  --region asia-south1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY=your_key_here
```

> [!TIP]
> On Cloud Run, **do not set `FIREBASE_CREDENTIALS_PATH`**. Instead, grant the Cloud Run service account the **Firebase Admin SDK Administrator Service Agent** IAM role. The `firebase_admin.initialize_app()` call will automatically use Application Default Credentials.

---

## Interactive API Docs

FastAPI auto-generates interactive documentation available at these paths when the server is running:

| Interface | URL |
|---|---|
| Swagger UI | `/docs` |
| ReDoc | `/redoc` |
| OpenAPI JSON | `/openapi.json` |
