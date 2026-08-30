# ==========================================
# Centralized S3 & DynamoDB Remote Backend
# ==========================================
terraform {
  backend "s3" {
    # The central, secure bucket residing in your management or shared services account
    bucket         = "enterprise-clinical-ai-tfstate-central"
    
    # Dynamic key layout allowing complete segregation of env files
    key            = "clinical-ner/terraform.tfstate"
    region         = "us-east-1"
    
    # Enables strong, concurrent execution protection via distributed locks
    dynamodb_table = "enterprise-clinical-ai-tflocks"
    encrypt        = true

    # Instructs Terraform to assume a cross-account role inside your target environments
    # Change this role ARN dynamically via your CI/CD parameter triggers per workspace run
    role_arn       = "arn:aws:iam::${var.aws_account_id}:role/TerraformDeploymentExecutionRole"
  }
}
