terraform {
  required_version = ">= 1.5.0"  # Required for native S3 state locking
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
  # Backend configuration will be added by setup-backend.sh
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

variable "region" {
  default = "eu-north-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_version" {
  default = "1.28"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  sensitive   = true
}

module "vpc" {
  source = "./modules/vpc"
  
  environment = var.environment
  cidr_block  = var.environment == "development" ? "10.0.0.0/16" : var.environment == "staging" ? "10.1.0.0/16" : "10.2.0.0/16"
}

module "eks" {
  source = "./modules/eks"
  
  cluster_name    = "eks-${var.environment}"
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  environment     = var.environment
}

resource "aws_ecr_repository" "app" {
  name = "web-app"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "lambda_csv_processor" {
  name = "lambda-csv-processor"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "lambda_slack_notifier" {
  name = "lambda-slack-notifier"
  image_tag_mutability = "MUTABLE"
}

resource "aws_s3_bucket" "gitlab_groups_csv" {
  count  = var.environment == "development" ? 1 : 0
  bucket = "gitlab-groups-csv-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_object" "csv_file" {
  count  = var.environment == "development" ? 1 : 0
  bucket = aws_s3_bucket.gitlab_groups_csv[0].id
  key    = "groups.csv"
  content = <<-CSV
group_name,description,visibility
developers,Development Team,private
devops,DevOps Team,private
qa,QA Team,private
frontend,Frontend Team,private
backend,Backend Team,private
CSV
}

resource "aws_dynamodb_table" "app_table" {
  name           = "app-table-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "app_queue" {
  name = "app-queue-${var.environment}"
  
  tags = {
    Environment = var.environment
  }
}

module "alb" {
  source = "./modules/alb"
  
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids
  environment = var.environment
}

resource "aws_cloudfront_distribution" "app" {
  count = var.environment != "development" ? 1 : 0
  
  origin {
    domain_name = module.alb.alb_dns_name
    origin_id   = "ALB-${var.environment}"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  enabled             = true
  default_root_object = "index.html"
  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-${var.environment}"
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

module "lambda_csv_processor" {
  count  = var.environment == "development" ? 1 : 0
  source = "./modules/lambda"
  
  function_name = "gitlab-csv-processor"
  ecr_uri       = aws_ecr_repository.lambda_csv_processor.repository_url
  environment   = var.environment
  
  environment_variables = {
    GITLAB_URL = "http://gitlab.${var.environment}.local"
    S3_BUCKET  = aws_s3_bucket.gitlab_groups_csv[0].id
  }
}

module "lambda_slack_notifier" {
  source = "./modules/lambda"
  
  function_name = "slack-notifier"
  ecr_uri       = aws_ecr_repository.lambda_slack_notifier.repository_url
  environment   = var.environment
  
  environment_variables = {
    SLACK_WEBHOOK_URL = var.slack_webhook_url
  }
}

module "ack_controllers" {
  source = "./modules/ack"
  
  cluster_name = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  value = {
    app              = aws_ecr_repository.app.repository_url
    csv_processor    = aws_ecr_repository.lambda_csv_processor.repository_url
    slack_notifier   = aws_ecr_repository.lambda_slack_notifier.repository_url
  }
}
