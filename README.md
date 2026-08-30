# enterprise-clinical-ner
Sagemaker real-time endpoint with CloudFormation Blueprint for private AWS Virtual Private Cloud (VPC)

## 1. The CloudFormation Blueprint (sagemaker-clinical-ner.yaml)

This production blueprint provisions a fully private Amazon SageMaker Real-Time Endpoint running the pre-built John Snow Labs Healthcare NLP container.

- High Availability Configuration: It distributes instances across multiple isolated private subnets automatically, preventing downtime while routing queries internally via AWS PrivateLink.

- Air-Gap License Security: It injects an environment variable pointing straight to your secure internal S3 model registry bucket (ModelDataS3Url) to load license credentials directly inside the local hypervisor layer with zero internet callouts.

## 2. The FastAPI Production Gateway App (app.py)

This Python application acts as your client-facing service layer. It acts as an absolute low-latency layer between internal users and the underlying hardware cluster.

- Startup Optimization: The script uses a singular instantiated boto3.client framework instance, keeping network connections alive over a local endpoint network path to meet your sub-second latency baseline (~30ms–90ms execution speeds).

- Strict Schema Validation: It leverages robust Pydantic structures to sanitize unstructured text inputs from medical databases or Electronic Health Records (EHR) systems before passing them to the GPU runtime.
