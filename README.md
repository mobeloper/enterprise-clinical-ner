# HIPAA Enterprise Clinical NER Gateway 

An production-ready, HIPAA-compliant AI engine that automatically reads unstructured clinical documents, extracts medical concepts, and structures them into standardized healthcare data (like ICD-10 and RxNorm) inside your own secure cloud. 

It transforms unstructured medical records and scanned documents into structured, actionable healthcare data to automate clinical workflows and medical coding.

In includes a sagemaker real-time endpoint with CloudFormation Blueprint for private AWS Virtual Private Cloud (VPC).

Fully production-grade, secure, and observable.

## What is included here:

This multi-account codebase incorporates:

- Secure OIDC Federated pipelines with zero hardcoded long-lived secrets.

- Low-latency sub-second serving capabilities (~30ms–90ms) with isolated internal compute environments.

- Complete HIPAA-aligned zero-ingress network routing via PrivateLink Endpoints.

- Explicit cryptographic ownership and predictable budget safeguards.

## Future Work:
- Setting up CloudWatch Metric Filters to look for specific keywords (like "Exception" or "Error") in FastAPI logs and trigger PagerDuty/SNS alerts.

- Creating the SageMaker Auto-Scaling policies based on GPU memory utilization to handle fluctuating hospital traffic.


## 1. The CloudFormation Blueprint (sagemaker-clinical-ner.yaml)

This production blueprint provisions a fully private Amazon SageMaker Real-Time Endpoint running the pre-built John Snow Labs Healthcare NLP container.

- High Availability Configuration: It distributes instances across multiple isolated private subnets automatically, preventing downtime while routing queries internally via AWS PrivateLink.

- Air-Gap License Security: It injects an environment variable pointing straight to your secure internal S3 model registry bucket (ModelDataS3Url) to load license credentials directly inside the local hypervisor layer with zero internet callouts.

## 2. The FastAPI Production Gateway App (app.py)

This Python application acts as your client-facing service layer. It acts as an absolute low-latency layer between internal users and the underlying hardware cluster.

- Startup Optimization: The script uses a singular instantiated boto3.client framework instance, keeping network connections alive over a local endpoint network path to meet your sub-second latency baseline (~30ms–90ms execution speeds).

- Strict Schema Validation: It leverages robust Pydantic structures to sanitize unstructured text inputs from medical databases or Electronic Health Records (EHR) systems before passing them to the GPU runtime.
  

## 3. Environments
To apply this stack safely across isolated environments, create distinct variable files and feed them straight into your execution engine step parameters.

Run commands:

### Run for Staging environment validation
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"

### Run for Production infrastructure synchronization
terraform plan -var-file="production.tfvars"
terraform apply -var-file="production.tfvars"

## 4. AWS KMS
to apply AWS KMS Customer Managed Keys, ensure your aws_ecr_repository block created in main.tf is updated to use this new resource reference:
```
# Update your previous ecr block encryption configuration to tie into the KMS resource:
encryption_configuration {
  encryption_type = "KMS"
  kms_key         = aws_kms_key.clinical_ai_key.arn
}
```

---

## 5. The information it extracts

This gateway identifies and extracts hundreds of specific healthcare data points, which are grouped into these core categories:

Personal & Demographic Information (HIPAA PHI)

Names: Patients, doctors, nurses, and family members.Dates: Birthdates, admission dates, discharge dates, and surgery dates.Locations: Hospital names, clinics, home addresses, cities, and zip codes.Contact Details: Phone numbers, fax numbers, emails, and IP addresses.Identifiers: Medical record numbers (MRN), health plan IDs, Social Security numbers (SSN), and account numbers.Demographics: Age (including flagging patients over 89), gender, race, and profession.

Clinical & Medical Findings

Diseases & Conditions: Diagnoses, chronic illnesses, acute injuries, and medical syndromic descriptions.Symptoms: Patient complaints, signs of illness (e.g., fever, pain, cough), and severity levels.Anatomy & Biology: Body parts, organs, tissues, cell types, and anatomical locations.Vital Signs: Blood pressure, heart rate, temperature, weight, and oxygen saturation.

Medications & Prescriptions (Posology)

Drug Names: Brand name medications, generic formulations, and over-the-counter drugs.Dosage & Strength: The exact amount of medicine (e.g., 50mg, 2 tablets).Frequency & Route: How often it is taken (twice daily, as needed) and how it enters the body (oral, IV, topical).Duration: How long the patient should take the medication (e.g., for 10 days).

Procedures & Medical Logic

Treatments & Procedures: Surgeries, therapeutic interventions, physical therapy, and lifestyle adjustments.Tests & Labs: Diagnostic tests (e.g., CBC, MRI, X-Ray) along with lab results and measurements.Medical Devices: Pacemakers, stents, crutches, and implants.Assertion Status: Contextual markers indicating if a disease is Present, Absent/Negated, Hypothetical, or part of Family History.

Lifestyle & Social Factors (SDOH)

Substance Use: Tobacco, alcohol, and drug usage history (including frequency and status).Social Determinants: Employment status, living situations, housing stability, and environmental risk factors.

```
Apache license 2.0 
Copyright: Eric Michel 
```
