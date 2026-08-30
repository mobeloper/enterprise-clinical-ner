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

# Create a dedicated security group if none are passed via variables
resource "aws_security_group" "codebuild_sg" {
  count       = length(var.codebuild_security_group_ids) == 0 ? 1 : 0
  name        = "codebuild-${var.environment}-sg"
  description = "Isolated security rules container for CodeBuild pipeline workers."
  vpc_id      = var.vpc_id

  # Allow all outbound traffic internally to hit VPC Endpoints (S3, ECR)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Environment = var.environment
  }
}


# ==========================================
# 3. AWS CodeBuild Project Pipeline with VPC Routing
# ==========================================
resource "aws_codebuild_project" "clinical_ner_build" {
  name          = "ClinicalNER-Gateway-Build-${var.environment}"
  description   = "Compiles and executes test runs securely inside private subnets for ${var.environment}."
  build_timeout = "20"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.clinical_ner_gateway.repository_url
    }
  }

  source {
    type      = "GITHUB"
    location  = var.github_repo_url
    buildspec = "buildspec.yml"
  }

  # Mandates network routing entirely inside private subnets
  vpc_config {
    vpc_id             = var.vpc_id
    subnets            = var.private_subnet_ids
    security_group_ids = length(var.codebuild_security_group_ids) == 0 ? [aws_security_group.codebuild_sg[0].id] : var.codebuild_security_group_ids
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/clinical-ner-gateway-${var.environment}"
      stream_name = "build-log"
    }
  }

  tags = {
    Environment = var.environment
  }
}

# Add network interface permissions to the existing CodeBuild IAM Policy
resource "aws_iam_role_policy" "codebuild_vpc_policy" {
  name = "ClinicalNER-CodeBuildVPCAccess"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
      },
      # Required permissions for CodeBuild to generate ENIs inside your private subnets
      {
        Effect = "Allow"
        Action = [
          "ecid:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# The single-tenant ECR Repository remains isolated per environment block definition
resource "aws_ecr_repository" "clinical_ner_gateway" {
  name                 = "clinical-ner-gateway-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "ClinicalNER-CodeBuildRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
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
