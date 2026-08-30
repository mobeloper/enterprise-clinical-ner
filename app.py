#Open source: Apache 2.0 license 
#Copyright: Eric Michel

import os
import boto3
import json
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

# Initialize FastAPI instance
app = FastAPI(
    title="Enterprise Clinical NER & De-ID Gateway",
    description="Sub-second low-latency API gateway invoking a private AWS SageMaker clinical pipeline for NER and HIPAA De-identification.",
    version="1.0.1"
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

class DeIDResponse(BaseModel):
    status: str
    mode_applied: str
    deidentified_text: str
    detected_phi_summary: dict

@app.post("/api/v1/extract-clinical-entities", response_model=NERResponse)
async def extract_clinical_entities(payload: ClinicalTextPayload):
    """
    Accepts raw unstructured clinical text, formats it for the John Snow Labs marketplace container,
    invokes the private SageMaker endpoint securely over AWS PrivateLink, and returns structured data.
    """
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="Provided clinical note text payload cannot be empty.")
    
    # Format the request to match the expected inference schema of the JSL container
    input_payload = {
        "text": payload.text
    }
    
    try:
        # Invoke the real-time SageMaker endpoint
        response = sagemaker_runtime.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT_NAME,
            ContentType="application/json",
            Accept="application/json",
            Body=json.dumps(input_payload)
        )
        
        # Stream and decode the binary response payload from AWS
        response_body = response["Body"].read().decode("utf-8")
        structured_output = json.loads(response_body)
        
        return {
            "status": "success",
            "processed_text": payload.text,
            "predictions": structured_output.get("predictions", [])
        }
        
    except sagemaker_runtime.exceptions.ValidationError as ve:
        raise HTTPException(status_code=422, detail=f"SageMaker payload validation anomaly: {str(ve)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal clinical gateway pipeline connection failure: {str(e)}")

@app.post("/api/v1/deidentify-clinical-text", response_model=DeIDResponse)
async def deidentify_clinical_text(
    payload: ClinicalTextPayload, 
    mode: str = Query("mask", regex="^(mask|obfuscate)$", description="De-identification technique: 'mask' replaces PHI with structural tags, 'obfuscate' replaces it with fake synthetic data.")
):
    """
    Accepts raw text, invokes the John Snow Labs clinical de-identification model stack on SageMaker,
    and returns HIPAA compliance-safe structural variants (masked tags or obfuscated synthetic data).
    """
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="Provided clinical note text payload cannot be empty.")
    
    # Format payload for John Snow Labs De-ID pipeline configurations
    input_payload = {
        "text": payload.text,
        "mode": mode  # Evaluates parameters inside the JSL pipeline configuration setup
    }
    
    try:
        # Invoke the SageMaker endpoint hosting the JSL De-identification container profile
        response = sagemaker_runtime.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT_NAME,
            ContentType="application/json",
            Accept="application/json",
            Body=json.dumps(input_payload)
        )
        
        response_body = response["Body"].read().decode("utf-8")
        structured_output = json.loads(response_body)
        
        # Parse JSL structural pipeline outputs
        # Note: adjust fallbacks if your specific deployment formats the keys differently
        deidentified_text_list = structured_output.get("deidentified", [])
        sanitized_output = " ".join(deidentified_text_list) if isinstance(deidentified_text_list, list) else structured_output.get("deidentified_text", "")
        
        return {
            "status": "success",
            "mode_applied": mode,
            "deidentified_text": sanitized_output,
            "detected_phi_summary": {
                "names": structured_output.get("NAME", []),
                "dates": structured_output.get("DATE", []),
                "contact_info": structured_output.get("CONTACT", []),
                "locations": structured_output.get("LOCATION", [])
            }
        }
        
    except sagemaker_runtime.exceptions.ValidationError as ve:
        raise HTTPException(status_code=422, detail=f"SageMaker payload validation anomaly: {str(ve)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal clinical de-identification pipeline failure: {str(e)}")

@app.get("/healthz")
async def health_check():
    """
    Lightweight health endpoint for internal VPC load balancers or Kubernetes liveness probes.
    """
    return {"status": "healthy", "target_endpoint": SAGEMAKER_ENDPOINT_NAME}
