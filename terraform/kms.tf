# ==========================================
# 1. Dedicated AWS KMS Customer Managed Key
# ==========================================
resource "aws_kms_key" "clinical_ai_key" {
  description             = "Explicit encryption key for Clinical AI ECR images, S3 states, and logs."
  deletion_window_in_days = 30
  enable_key_rotation     = true # Crucial requirement for enterprise compliance (SOC2/HIPAA)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Root Account & Admin Permissions
      {
        Sid    = "Enable Root and Admin Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Allow ECR Service to encrypt/decrypt image layers dynamically
      {
        Sid    = "Allow ECR Service Use"
        Effect = "Allow"
        Principal = {
          Service = "://amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:Encrypt"
        ]
        Resource = "*"
      },
      # Allow CodeBuild role to decrypt and read S3 states/cache layers
      {
        Sid    = "Allow CodeBuild Pipeline Access"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codebuild_role.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "clinical-ai-kms-${var.environment}"
    Environment = var.environment
  }
}

# Human-readable alias for easy infrastructure references
resource "aws_kms_alias" "clinical_ai_key_alias" {
  name          = "alias/clinical-ai-key-${var.environment}"
  target_key_id = aws_kms_key.clinical_ai_key.key_id
}
