from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
import os

# Set mock environment variables before importing the app
os.environ["SAGEMAKER_ENDPOINT_NAME"] = "Mock-Endpoint"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"

# Import app inside the test execution to pick up environment variables safely
from app import app

client = TestClient(app)

def test_health_check_endpoint():
    """Validates the local API gateway container health status."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

@patch("app.boto3_client")
def test_successful_ner_extraction(mock_boto3):
    """Mocks a sub-second response from the underlying SageMaker infrastructure layer."""
    mock_sagemaker = MagicMock()
    # Mocking standard SageMaker JSON payload body output
    mock_sagemaker.invoke_endpoint.return_value = {
        "Body": MagicMock(read=lambda: b'{"entities": [{"text": "Metformin", "label": "DRUG"}]}')
    }
    mock_boto3.return_value = mock_sagemaker

    payload = {"text": "patient was prescribed metformin"}
    response = client.post("/extract", json=payload)
    
    assert response.status_code == 200
    assert "entities" in response.json()
