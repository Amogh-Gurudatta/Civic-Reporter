import os
import json
import base64
import io
import datetime
import requests
from typing import Optional
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv
from PIL import Image
import firebase_admin
from firebase_admin import credentials, firestore
from google import genai

# Load environment variables
load_dotenv()

# Configure Google Gen AI SDK Client
gemini_key = os.getenv("GEMINI_API_KEY")
if not gemini_key:
    raise RuntimeError("GEMINI_API_KEY environment variable is not set or empty.")
client = genai.Client(api_key=gemini_key)

# Configure Firebase Admin SDK
firebase_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
try:
    if firebase_cred_path and os.path.exists(firebase_cred_path):
        cred = credentials.Certificate(firebase_cred_path)
        firebase_admin.initialize_app(cred)
    else:
        # Fall back to application default credentials
        firebase_admin.initialize_app()
except Exception as e:
    # Print a warning but don't crash immediately in case mock is used,
    # though it will fail during DB operations if not authenticated properly.
    print(f"Warning: Firebase Admin SDK initialization failed/skipped: {e}")

db = firestore.client()

# Initialize FastAPI App
app = FastAPI(
    title="Civic Issue Reporting Backend",
    description="Secure FastAPI backend for classifying civic issues using Gemini and saving to Firestore.",
    version="1.0.0",
)

# Enable CORS for all origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request schema for reporting issue
class IssueReportRequest(BaseModel):
    image: Optional[str] = Field(None, description="Base64 encoded image string.")
    imageUrl: Optional[str] = Field(
        None, description="Remote HTTP URL of the image to analyze."
    )
    latitude: float = Field(
        ..., ge=-90.0, le=90.0, description="GPS Latitude coordinate."
    )
    longitude: float = Field(
        ..., ge=-180.0, le=180.0, description="GPS Longitude coordinate."
    )
    userId: str = Field("anonymous", description="ID of the reporting user.")


@app.get("/")
def read_root():
    return {"status": "running", "app": "Civic Issue Reporting API"}


@app.post("/report-issue", status_code=status.HTTP_201_CREATED)
async def report_issue(payload: IssueReportRequest):
    if not payload.image and not payload.imageUrl:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either 'image' or 'imageUrl' must be provided.",
        )

    # 1. Download image from URL or decode base64
    if payload.imageUrl:
        try:
            response = requests.get(payload.imageUrl, timeout=10)
            response.raise_for_status()
            image = Image.open(io.BytesIO(response.content))
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid image URL or failed to download image: {str(e)}",
            )
    else:
        try:
            base64_str = payload.image
            if "," in base64_str:
                base64_str = base64_str.split(",", 1)[1]
            base64_str = base64_str.strip()
            missing_padding = len(base64_str) % 4
            if missing_padding:
                base64_str += "=" * (4 - missing_padding)
            image_bytes = base64.b64decode(base64_str)
            image = Image.open(io.BytesIO(image_bytes))
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid base64 image data: {str(e)}",
            )

    # 2. Configure Gemini model & instruct it
    fallback_models = [
        "gemini-2.5-pro",
        "gemini-3.5-flash",
        "gemini-3-flash",
        "gemini-2.5-flash",
        "gemini-2-flash",
        "gemini-2.5-flash-lite",
    ]

    prompt = (
        "You are an expert civic inspector. Analyze the provided image of an infrastructure/civic issue.\n"
        "1. Classify the issue into one specific category (e.g. Pothole, Trash, Broken Streetlight, Graffiti, Flooding, Road Damage, Water Leak, etc.).\n"
        "2. Rate the severity of the issue as either: Low, Medium, or High.\n"
        "3. Keep descriptions brief and accurate.\n\n"
        "You must return a JSON object with exactly the following structure:\n"
        "{\n"
        '  "classification": "Category of the issue",\n'
        '  "severity": "Low/Medium/High",\n'
        '  "description": "A short one-sentence description of what is visible in the image"\n'
        "}"
    )

    analysis_succeeded = False
    classification = "Unknown"
    severity = "Medium"
    description = ""

    for model_name in fallback_models:
        try:
            # Send prompt and image to Gemini with JSON output constraint
            response = client.models.generate_content(
                model=model_name,
                contents=[prompt, image],
                config={"response_mime_type": "application/json"},
            )

            # Parse Gemini response text as JSON
            analysis = json.loads(response.text)
            classification = analysis.get("classification", "Unknown")
            severity = analysis.get("severity", "Medium")
            description = analysis.get("description", "")

            analysis_succeeded = True
            break

        except Exception as e:
            error_str = str(e)
            if any(
                quota_keyword in error_str
                for quota_keyword in ["429", "Quota", "ResourceExhausted"]
            ):
                print(f"Model {model_name} rate limited, falling back...")
                continue
            else:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Failed to analyze image with AI: {error_str}",
                )

    if not analysis_succeeded:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI processing is currently at capacity. Please try again in a minute.",
        )

    # 3. Store in Firestore collection `reports`
    try:
        new_report = {
            "classification": classification,
            "severity": severity,
            "description": description,
            "latitude": payload.latitude,
            "longitude": payload.longitude,
            "imageUrl": payload.imageUrl or "",
            "userId": payload.userId,
            "status": "Pending",
            "timestamp": datetime.datetime.now(datetime.timezone.utc),
        }

        # Add to Firestore
        doc_ref = db.collection("reports").document()
        doc_ref.set(new_report)

        # Update user's karma score
        user_ref = db.collection("users").document(payload.userId)
        user_ref.set({"karma": firestore.Increment(50)}, merge=True)

        # Construct response containing document ID and generated data
        response_data = {
            "id": doc_ref.id,
            **new_report,
            # Format timestamp string for json response compatibility
            "timestamp": new_report["timestamp"].isoformat(),
        }
        return response_data

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save report to database: {str(e)}",
        )


@app.get("/issues")
async def get_issues():
    """
    Fetches all reported civic issues from the Firestore reports collection.
    """
    try:
        reports_ref = db.collection("reports")
        docs = reports_ref.stream()

        issues = []
        for doc in docs:
            data = doc.to_dict()
            # Convert datetime timestamp to ISO string for JSON output
            if "timestamp" in data and isinstance(data["timestamp"], datetime.datetime):
                data["timestamp"] = data["timestamp"].isoformat()

            data["id"] = doc.id
            issues.append(data)

        return issues
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch issues from database: {str(e)}",
        )


if __name__ == "__main__":
    import uvicorn

    # Read the PORT environment variable provided by Cloud Run, fallback to 8080 locally
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
