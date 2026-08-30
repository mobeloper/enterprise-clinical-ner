# ==========================================
# Multi-Account Framework Variables
# ==========================================

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "The target deployment AWS region."
}

variable "environment" {
  type        = string
  description = "Operational environment context indicator (e.g., staging, production)."
  
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "The environment variable value must be explicitly set to 'staging' or 'production'."
  }
}

variable "aws_account_id" {
  type        = string
  description = "The target AWS Account ID used to scope scoped policy resources cleanly."
}

# ==========================================
# Network Topology Parameters
# ==========================================

variable "vpc_id" {
  type        = string
  description = "The target VPC ID where the CodeBuild computation task executes."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "A list of completely isolated private subnets inside the VPC."
}

variable "codebuild_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Optional pre-existing security groups. Leaving empty creates a custom secure group below."
}

# ==========================================
# Application Repository Configurations
# ==========================================

variable "github_repo_url" {
  type        = string
  description = "The absolute path URL pointing straight to your enterprise code repository."
}
