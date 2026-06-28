import sys
import os
import json
import datetime
import base64
from unittest.mock import MagicMock
import pytest
from fastapi.testclient import TestClient

# 1. Setup Mock objects for external dependencies (Firebase & Gemini) BEFORE importing main
mock_db = MagicMock()
mock_firestore_client = MagicMock(return_value=mock_db)

mock_firebase_admin = MagicMock()
mock_credentials = MagicMock()
mock_firestore = MagicMock()
mock_firestore.client = mock_firestore_client

mock_firebase_admin.credentials = mock_credentials
mock_firebase_admin.firestore = mock_firestore

# Inject Firebase mocks into sys.modules
sys.modules['firebase_admin'] = mock_firebase_admin
sys.modules['firebase_admin.credentials'] = mock_credentials
sys.modules['firebase_admin.firestore'] = mock_firestore

# Mock the google-genai SDK
mock_genai = MagicMock()
mock_client_instance = MagicMock()
mock_genai.Client.return_value = mock_client_instance

mock_google = MagicMock()
mock_google.genai = mock_genai
sys.modules['google'] = mock_google
sys.modules['google.genai'] = mock_genai

# Ensure environment variables are set so main.py doesn't crash on import
os.environ["GEMINI_API_KEY"] = "mock_gemini_key_for_testing"
os.environ["FIREBASE_CREDENTIALS_PATH"] = "mock_firebase_path_for_testing"

# Now import the FastAPI app and helpers from main
from main import app
import main

# Global mock for requests.get in main.py
mock_requests_get = MagicMock()
main.requests.get = mock_requests_get

client = TestClient(app)

# 1x1 transparent PNG bytes for testing
VALID_IMAGE_BYTES = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=")
VALID_IMAGE_URL = "http://example.com/pothole.jpg"
INVALID_IMAGE_URL = "http://example.com/bad-url.jpg"

@pytest.fixture(autouse=True)
def reset_mocks():
    """Reset the mock call histories and configurations before each test."""
    mock_db.reset_mock()
    mock_firestore_client.reset_mock()
    mock_genai.reset_mock()
    mock_client_instance.reset_mock()
    mock_requests_get.reset_mock()
    
    # Configure default successful requests response
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = VALID_IMAGE_BYTES
    mock_resp.raise_for_status = MagicMock()
    mock_requests_get.return_value = mock_resp
    mock_requests_get.side_effect = None
    
    # Explicitly clear side_effect and return_value changes from other tests
    mock_db.collection.side_effect = None
    mock_db.collection.return_value = MagicMock()
    mock_firestore_client.side_effect = None
    mock_client_instance.models.generate_content.side_effect = None
    mock_client_instance.models.generate_content.return_value = MagicMock()

def test_read_root():
    """Test that the root endpoint returns the correct status message."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"status": "running", "app": "Civic Issue Reporting API"}

def test_report_issue_success():
    """Test successful reporting of a civic issue with valid inputs, userId, mocked Gemini, and mocked Firestore."""
    # Mock Gemini Client generate_content response
    mock_response = MagicMock()
    mock_response.text = json.dumps({
        "classification": "Pothole",
        "severity": "High",
        "description": "A deep pothole in the asphalt lane."
    })
    mock_client_instance.models.generate_content.return_value = mock_response

    # Mock Firestore collection for reports and users separately
    mock_reports_col = MagicMock()
    mock_users_col = MagicMock()
    
    def collection_side_effect(name):
        if name == "reports":
            return mock_reports_col
        elif name == "users":
            return mock_users_col
        return MagicMock()
    mock_db.collection.side_effect = collection_side_effect

    mock_doc_ref = MagicMock()
    mock_doc_ref.id = "mock_document_123"
    mock_reports_col.document.return_value = mock_doc_ref
    
    mock_user_doc_ref = MagicMock()
    mock_users_col.document.return_value = mock_user_doc_ref

    payload = {
        "imageUrl": VALID_IMAGE_URL,
        "latitude": 37.7749,
        "longitude": -122.4194,
        "userId": "test_user_456"
    }

    response = client.post("/report-issue", json=payload)
    assert response.status_code == 201
    
    data = response.json()
    assert data["id"] == "mock_document_123"
    assert data["classification"] == "Pothole"
    assert data["severity"] == "High"
    assert data["description"] == "A deep pothole in the asphalt lane."
    assert data["latitude"] == 37.7749
    assert data["longitude"] == -122.4194
    assert data["imageUrl"] == VALID_IMAGE_URL
    assert data["userId"] == "test_user_456"
    assert data["status"] == "Pending"
    assert "timestamp" in data

    # Verify requests.get was called to download the image
    mock_requests_get.assert_called_once_with(VALID_IMAGE_URL, timeout=10)

    # Verify Firestore interactions for reports
    mock_db.collection.assert_any_call("reports")
    mock_reports_col.document.assert_called_once()
    
    # Check that reports document set was called with the correct dictionary structure
    called_args, _ = mock_doc_ref.set.call_args
    saved_report = called_args[0]
    assert saved_report["classification"] == "Pothole"
    assert saved_report["severity"] == "High"
    assert saved_report["description"] == "A deep pothole in the asphalt lane."
    assert saved_report["latitude"] == 37.7749
    assert saved_report["longitude"] == -122.4194
    assert saved_report["imageUrl"] == VALID_IMAGE_URL
    assert saved_report["userId"] == "test_user_456"
    assert saved_report["status"] == "Pending"
    assert isinstance(saved_report["timestamp"], datetime.datetime)

    # Verify Firestore interactions for users karma increment
    mock_db.collection.assert_any_call("users")
    mock_users_col.document.assert_called_once_with("test_user_456")
    mock_user_doc_ref.set.assert_called_once_with({"karma": mock_firestore.Increment(50)}, merge=True)

def test_report_issue_success_default_user():
    """Test reporting a civic issue without providing userId, confirming it defaults to 'anonymous'."""
    # Mock Gemini Client generate_content response
    mock_response = MagicMock()
    mock_response.text = json.dumps({
        "classification": "Trash",
        "severity": "Low",
        "description": "Litter on road."
    })
    mock_client_instance.models.generate_content.return_value = mock_response

    # Mock Firestore collection for reports and users separately
    mock_reports_col = MagicMock()
    mock_users_col = MagicMock()
    
    def collection_side_effect(name):
        if name == "reports":
            return mock_reports_col
        elif name == "users":
            return mock_users_col
        return MagicMock()
    mock_db.collection.side_effect = collection_side_effect

    mock_doc_ref = MagicMock()
    mock_doc_ref.id = "mock_document_default"
    mock_reports_col.document.return_value = mock_doc_ref
    
    mock_user_doc_ref = MagicMock()
    mock_users_col.document.return_value = mock_user_doc_ref

    payload = {
        "imageUrl": VALID_IMAGE_URL,
        "latitude": 37.7749,
        "longitude": -122.4194
    }

    response = client.post("/report-issue", json=payload)
    assert response.status_code == 201
    
    data = response.json()
    assert data["userId"] == "anonymous"

    # Verify Firestore saved it with 'anonymous' and incremented 'anonymous' user's karma
    called_args, _ = mock_doc_ref.set.call_args
    assert called_args[0]["userId"] == "anonymous"
    assert called_args[0]["imageUrl"] == VALID_IMAGE_URL
    
    mock_users_col.document.assert_called_once_with("anonymous")
    mock_user_doc_ref.set.assert_called_once_with({"karma": mock_firestore.Increment(50)}, merge=True)

def test_report_issue_invalid_coordinates():
    """Test that invalid GPS coordinates (outside valid ranges) return a 422 validation error."""
    payload_invalid_lat = {
        "imageUrl": VALID_IMAGE_URL,
        "latitude": 95.0, # Valid latitude is -90 to 90
        "longitude": -122.4194
    }
    response = client.post("/report-issue", json=payload_invalid_lat)
    assert response.status_code == 422
    assert "latitude" in response.text

    payload_invalid_lon = {
        "imageUrl": VALID_IMAGE_URL,
        "latitude": 37.7749,
        "longitude": 185.0 # Valid longitude is -180 to 180
    }
    response = client.post("/report-issue", json=payload_invalid_lon)
    assert response.status_code == 422
    assert "longitude" in response.text

def test_report_issue_download_failure():
    """Test that a failure to download the image URL returns a 400 Bad Request error."""
    # Mock requests.get to throw an exception
    mock_requests_get.side_effect = Exception("Connection timed out")

    payload = {
        "imageUrl": INVALID_IMAGE_URL,
        "latitude": 37.7749,
        "longitude": -122.4194
    }
    response = client.post("/report-issue", json=payload)
    assert response.status_code == 400
    assert "Invalid image URL or failed to download image" in response.json()["detail"]

def test_report_issue_gemini_failure():
    """Test that a failure in the Gemini API returns a 502 Bad Gateway response."""
    # Mock Gemini Client generate_content to throw an exception
    mock_client_instance.models.generate_content.side_effect = Exception("Gemini service unavailable")

    payload = {
        "imageUrl": VALID_IMAGE_URL,
        "latitude": 37.7749,
        "longitude": -122.4194
    }
    response = client.post("/report-issue", json=payload)
    assert response.status_code == 502
    assert "Failed to analyze image with AI" in response.json()["detail"]

def test_report_issue_firestore_failure():
    """Test that a failure during Firestore saving returns a 500 Internal Server Error."""
    # Mock Gemini Client to succeed
    mock_response = MagicMock()
    mock_response.text = json.dumps({
        "classification": "Trash",
        "severity": "Low",
        "description": "Some litter on the sidewalk."
    })
    mock_client_instance.models.generate_content.return_value = mock_response

    # Mock Firestore to raise an error
    mock_db.collection.side_effect = Exception("Firestore database connection timeout")

    payload = {
        "imageUrl": VALID_IMAGE_URL,
        "latitude": 37.7749,
        "longitude": -122.4194
    }
    response = client.post("/report-issue", json=payload)
    assert response.status_code == 500
    assert "Failed to save report to database" in response.json()["detail"]

def test_get_issues_success():
    """Test successfully retrieving all reported issues from Firestore."""
    # Mock Firestore collection stream
    mock_doc1 = MagicMock()
    mock_doc1.id = "doc_1"
    mock_doc1.to_dict.return_value = {
        "classification": "Pothole",
        "severity": "High",
        "description": "Large pothole.",
        "latitude": 12.34,
        "longitude": 56.78,
        "status": "Pending",
        "timestamp": datetime.datetime(2026, 6, 27, 12, 0, 0, tzinfo=datetime.timezone.utc)
    }

    mock_doc2 = MagicMock()
    mock_doc2.id = "doc_2"
    mock_doc2.to_dict.return_value = {
        "classification": "Broken Streetlight",
        "severity": "Medium",
        "description": "Flickering street lamp.",
        "latitude": 12.35,
        "longitude": 56.79,
        "status": "In Progress",
        "timestamp": datetime.datetime(2026, 6, 27, 13, 0, 0, tzinfo=datetime.timezone.utc)
    }

    mock_db.collection.return_value.stream.return_value = [mock_doc1, mock_doc2]

    response = client.get("/issues")
    assert response.status_code == 200
    
    issues = response.json()
    assert len(issues) == 2
    
    assert issues[0]["id"] == "doc_1"
    assert issues[0]["classification"] == "Pothole"
    assert issues[0]["severity"] == "High"
    assert issues[0]["timestamp"] == "2026-06-27T12:00:00+00:00"

    assert issues[1]["id"] == "doc_2"
    assert issues[1]["classification"] == "Broken Streetlight"
    assert issues[1]["severity"] == "Medium"
    assert issues[1]["timestamp"] == "2026-06-27T13:00:00+00:00"

    mock_db.collection.assert_called_once_with("reports")
    mock_db.collection().stream.assert_called_once()

def test_get_issues_firestore_failure():
    """Test that a Firestore failure during get_issues returns a 500 error."""
    mock_db.collection.side_effect = Exception("Failed to read from Firestore database")
    response = client.get("/issues")
    assert response.status_code == 500
    assert "Failed to fetch issues from database" in response.json()["detail"]

def test_report_issue_model_cascading_success():
    """Test that model cascading fallback works when early models hit rate limits."""
    mock_response = MagicMock()
    mock_response.text = json.dumps({
        "classification": "Pothole",
        "severity": "Medium",
        "description": "Medium pothole."
    })
    
    mock_client_instance.models.generate_content.side_effect = [
        Exception("ResourceExhausted 429: rate limit exceeded"),
        Exception("Quota error"),
        mock_response
    ]
    
    # Mock Firestore collection for reports and users separately
    mock_reports_col = MagicMock()
    mock_users_col = MagicMock()
    mock_db.collection.side_effect = lambda name: mock_reports_col if name == "reports" else mock_users_col
    
    mock_doc_ref = MagicMock()
    mock_doc_ref.id = "mock_doc_cascading"
    mock_reports_col.document.return_value = mock_doc_ref
    
    mock_user_doc_ref = MagicMock()
    mock_users_col.document.return_value = mock_user_doc_ref

    payload = {
        "imageUrl": VALID_IMAGE_URL,
        "latitude": 37.7749,
        "longitude": -122.4194
    }
    
    response = client.post("/report-issue", json=payload)
    assert response.status_code == 201
    assert response.json()["classification"] == "Pothole"
    # Ensure it called Client's generate_content exactly 3 times
    assert mock_client_instance.models.generate_content.call_count == 3

def test_report_issue_model_cascading_all_exhausted():
    """Test that endpoint returns a 503 when all fallback models are rate limited."""
    # Make every instantiated model raise a 429 exception
    mock_client_instance.models.generate_content.side_effect = Exception("ResourceExhausted: rate limit reached")
    
    payload = {
        "imageUrl": VALID_IMAGE_URL,
        "latitude": 37.7749,
        "longitude": -122.4194
    }
    
    response = client.post("/report-issue", json=payload)
    assert response.status_code == 503
    assert "AI processing is currently at capacity" in response.json()["detail"]
    # Check that it attempted to use all 6 models in the cascade list
    assert mock_client_instance.models.generate_content.call_count == 6
