terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==========================================
# 1. Private Amazon ECR Repository
# ==========================================
resource "aws_ecr_repository" "clinical_ner_gateway" {
  name                 = "clinical-ner-gateway"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    # Mandates security vulnerability scanning on every push event
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = "Production"
    Application = "Clinical-NER"
  }
}

# Cleanup Policy: Retains the latest 30 images to control storage costs
resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  repository = aws_ecr_repository.clinical_ner_gateway.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 30 built images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ==========================================
# 2. IAM Execution Role for AWS CodeBuild
# ==========================================
resource "aws_iam_role" "codebuild_role" {
  name = "ClinicalNER-CodeBuildRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "ClinicalNER-CodeBuildPermissions"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs permissioning for build execution outputs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["*"]
      },
      # Scoped authorization to read/write tokens against the explicit ECR repository
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [aws_ecr_repository.clinical_ner_gateway.arn]
      }
    ]
  })
}

# ==========================================
# 3. AWS CodeBuild Project Pipeline
# ==========================================
resource "aws_codebuild_project" "clinical_ner_build" {
  name          = "ClinicalNER-Gateway-Build"
  description   = "Compiles, runs pytest tests, and pushes the FastAPI clinical NER container to ECR."
  build_timeout = "20"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    # Privileged mode is REQUIRED to execute Docker daemon operations inside CodeBuild
    privileged_mode             = true

    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.clinical_ner_gateway.repository_url
    }
  }

  # Configures CodeBuild to look for your buildspec.yml file in the root directory
  source {
    type      = "GITHUB" # Can be updated to CODECOMMIT or BITBUCKET depending on your source engine
    location  = "https://github.com"
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/clinical-ner-gateway"
      stream_name = "build-log"
    }
  }

  tags = {
    Environment = "Production"
  }
}

# ==========================================
# Outputs
# ==========================================
output "ecr_repository_url" {
  value       = aws_ecr_repository.clinical_ner_gateway.repository_url
  description = "The absolute URI to feed into your CI/CD configuration parameters."
}

output "codebuild_project_arn" {
  value       = aws_codebuild_project.clinical_ner_build.arn
  description = "The target project ARN required for your GitHub Actions OIDC workflow permissions."
}
