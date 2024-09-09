# Provider configuration
provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "smart-home-vpc"
  }
}

# Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 101}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "db" {
  name        = "database_sg"
  description = "Allow inbound traffic to the database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from VPC"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database_sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "My DB subnet group"
  }
}

# ECR Repositories
resource "aws_ecr_repository" "backend" {
  name = "smart-home-backend"
  force_delete = true  # Be cautious with this in production
}

resource "aws_ecr_repository" "frontend" {
  name = "smart-home-frontend"
  force_delete = true  # Be cautious with this in production
}

# RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  identifier           = "smart-home-db"
  engine               = "postgres"
  engine_version       = "16.4"  # Updated to the latest available version
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot  = true
  
  tags = {
    Name = "SmartHome-PostgreSQL"
  }
}

# Redis ElastiCache cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "smart-home-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"  # Updated to Redis 7
  engine_version       = "7.0"  # Specify Redis 7.0
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = {
    Name = "SmartHome-Redis"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "smart-home-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

# S3 bucket for frontend hosting
resource "aws_s3_bucket" "frontend" {
  bucket = "smart-home-frontend-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "SmartHome-Frontend-Bucket"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "SmartHome-CloudFront"
  }
}

# Security group for Redis
resource "aws_security_group" "redis" {
  name        = "redis_sg"
  description = "Security group for Redis cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from VPC"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    cidr_blocks     = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "redis_sg"
  }
}

# Existing provider and resource configurations...

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api_logs" {
  name = "/smart-home/api"
  retention_in_days = 14
}

# IAM Role for CloudWatch Logs
resource "aws_iam_role" "cloudwatch_logs_role" {
  name = "eks-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:cloudwatch-logs-sa"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_logs_policy" {
  name = "cloudwatch-logs-policy"
  role = aws_iam_role.cloudwatch_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# IAM Role for X-Ray
resource "aws_iam_role" "xray_role" {
  name = "eks-xray-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:xray-daemon"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "xray_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.xray_role.name
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Output values
output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "redis_endpoint" {
  description = "The connection endpoint for the Redis cluster"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for frontend hosting"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.domain_name
}