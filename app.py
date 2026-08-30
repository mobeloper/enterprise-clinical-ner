#Open source: Apache 2.0 liscense 
#Copyright: Eric Michel

import os
import boto3
import json
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

# Initialize FastAPI instance
app = FastAPI(
    title="Enterprise Clinical NER Gateway",
    description="Sub-second low-latency API gateway invoking a private AWS SageMaker clinical pipeline.",
    version="1.0.0"
)

# Initialize AWS SageMaker Runtime Client
# Uses Boto3 credential provider chain. Inside a private VPC, this automatically routes traffic
# through the local AWS PrivateLink SageMaker Runtime Endpoint.
sagemaker_runtime = boto3.client("sagemaker-runtime", region_name=os.getenv("AWS_REGION", "us-east-1"))

# Get the target endpoint name from environment configurations
SAGEMAKER_ENDPOINT_NAME = os.getenv("SAGEMAKER_ENDPOINT_NAME", "jsl-clinical-ner-endpoint-prod")

# Define structural models for typing and strict payload enforcement
class ClinicalTextPayload(BaseModel):
    text: str = Field(
        ..., 
        example="Patient Jane Doe born May 5 1953 and social number 123 45 6789 is a 73-year-old female presenting with acute myocardial infarction at Parker Hospital at 17:42 hrs on april 8, 2026. Prescribed Aspirin 81mg daily.",
        description="The unstructured clinical note or EHR text string to process."
    )

class NERResponse(BaseModel):
    status: str
    processed_text: str
    predictions: list

@app.post("/api/v1/extract-clinical-entities", response_model=NERResponse)
async def extract_clinical_entities(payload: ClinicalTextPayload):
    """
    Accepts raw unstructured clinical text, formats it for the John Snow Labs marketplace container,
    invokes the private SageMaker endpoint securely over AWS PrivateLink, and returns structured data.
    """
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="Provided clinical note text payload cannot be empty.")
    
    # 1. Format the request to match the expected inference schema of the JSL container
    input_payload = {
        "text": payload.text
    }
    
    try:
        # 2. Invoke the real-time SageMaker endpoint
        # This call operates over a local network loop inside the VPC, ensuring sub-second response speeds.
        response = sagemaker_runtime.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT_NAME,
            ContentType="application/json",
            Accept="application/json",
            Body=json.dumps(input_payload)
        )
        
        # 3. Stream and decode the binary response payload from AWS
        response_body = response["Body"].read().decode("utf-8")
        structured_output = json.loads(response_body)
        
        return {
            "status": "success",
            "processed_text": payload.text,
            "predictions": structured_output.get("predictions", [])
        }
        
    except sagemaker_runtime.exceptions.ValidationError as ve:
        # Catch scaling or structural runtime configuration anomalies
        raise HTTPException(status_code=422, detail=f"SageMaker payload validation anomaly: {str(ve)}")
    except Exception as e:
        # Generic catch-all for internal enterprise system logging
        raise HTTPException(status_code=500, detail=f"Internal clinical gateway pipeline connection failure: {str(e)}")

@app.get("/healthz")
async def health_check():
    """
    Lightweight health endpoint for internal VPC load balancers or Kubernetes liveness probes.
    """
    return {"status": "healthy", "target_endpoint": SAGEMAKER_ENDPOINT_NAME}
