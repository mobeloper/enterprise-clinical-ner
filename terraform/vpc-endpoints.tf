# ==========================================
# Gateway Endpoint for Amazon S3
# ==========================================
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # Automatically attaches the endpoint routing rules to your private subnets
  route_table_ids = [data.aws_route_table.private_rt.id]

  tags = {
    Name        = "s3-gateway-${var.environment}"
    Environment = var.environment
  }
}

# ==========================================
# Interface Endpoint for ECR API Authentication
# ==========================================
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]

  tags = {
    Name        = "ecr-api-endpoint-${var.environment}"
    Environment = var.environment
  }
}

# ==========================================
# Interface Endpoint for ECR Docker Image Layers (DKR)
# ==========================================
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]

  tags = {
    Name        = "ecr-dkr-endpoint-${var.environment}"
    Environment = var.environment
  }
}

# ==========================================
# Interface Endpoint for CloudWatch Logs (CodeBuild Output)
# ==========================================
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]

  tags = {
    Name        = "logs-endpoint-${var.environment}"
    Environment = var.environment
  }
}

# ==========================================
# Dedicated Security Group for Interface Endpoints
# ==========================================
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-${var.environment}-sg"
  description = "Controls private entry to internal AWS microservices loopbacks."
  vpc_id      = var.vpc_id

  # Inbound Rule: Allow HTTPS (443) traffic originating ONLY from within the VPC subnets
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
  }
}

# ==========================================
# Data Lookups for Networking References
# ==========================================
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Grabs a sample route table reference bound to your target subnets
data "aws_route_table" "private_rt" {
  subnet_id = var.private_subnet_ids[0]
}
