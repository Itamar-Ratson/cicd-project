#!/bin/bash
# setup-backend.sh - Setup S3 backend with native state locking (Terraform 1.5.0+)

set -e

REGION="eu-north-1"
BUCKET_NAME="terraform-state-cicd-$(aws sts get-caller-identity --query Account --output text)"

echo "Setting up Terraform backend with native S3 state locking..."
echo "Terraform >= 1.5.0 required for native S3 locking"

# Create S3 bucket for state
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || echo "Bucket already exists"

# Enable versioning (REQUIRED for native state locking)
echo "Enabling bucket versioning (required for native locking)..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# Enable encryption
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create backend configuration file
cat > terraform/backend.tf << EOF
terraform {
  backend "s3" {
    bucket  = "${BUCKET_NAME}"
    key     = "infrastructure/terraform.tfstate"
    region  = "${REGION}"
    encrypt = true
    # Native S3 state locking (Terraform >= 1.5.0)
    # No DynamoDB table needed!
  }
}
EOF

echo ""
echo "✅ Backend setup complete!"
echo "📦 Bucket: $BUCKET_NAME"
echo "🔒 Using native S3 state locking (no DynamoDB required)"
echo "📄 Backend configuration written to terraform/backend.tf"
echo ""
echo "Note: Terraform >= 1.5.0 is required for native S3 locking"
