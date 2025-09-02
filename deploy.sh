#!/bin/bash
# deploy.sh - Main deployment script with native S3 state locking

set -e

# Configuration
export AWS_REGION="eu-north-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check Terraform version
check_terraform_version() {
    REQUIRED_VERSION="1.5.0"
    CURRENT_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n 1 | cut -d' ' -f2 | cut -d'v' -f2)
    
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
        echo "❌ Error: Terraform >= $REQUIRED_VERSION is required for native S3 state locking"
        echo "Current version: $CURRENT_VERSION"
        exit 1
    fi
    echo "✅ Terraform version $CURRENT_VERSION supports native S3 locking"
}

# 0. Setup backend if not exists
setup_backend() {
    if [ ! -f "terraform/backend.tf" ]; then
        echo "Setting up Terraform backend..."
        ./setup-backend.sh
    fi
}

# 1. Deploy Terraform Infrastructure
deploy_infrastructure() {
    echo "Deploying infrastructure for $1 environment..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Create workspace if doesn't exist
    terraform workspace new $1 || terraform workspace select $1
    
    # Apply Terraform
    terraform apply -var-file="environments/$1.tfvars" -auto-approve
    
    # Update kubeconfig
    aws eks update-kubeconfig --name eks-$1 --region $AWS_REGION
    
    cd ..
}

# 2. Build and push Lambda images
build_lambdas() {
    echo "Building Lambda images..."
    
    # CSV Processor Lambda
    cd lambda-csv-processor
    docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lambda-csv-processor:latest .
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lambda-csv-processor:latest
    cd ..
    
    # Slack Notifier Lambda
    cd lambda-slack-notifier
    docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lambda-slack-notifier:latest .
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lambda-slack-notifier:latest
    cd ..
}

# 3. Deploy Helm charts
deploy_helm() {
    echo "Deploying Helm charts for $1 environment..."
    
    # Install Helmfile
    helmfile -e $1 sync
}

# 4. Configure GitLab and Jenkins (dev only)
configure_ci() {
    if [ "$1" == "development" ]; then
        echo "Configuring CI/CD tools..."
        
        # Wait for services to be ready
        sleep 60
        
        # Run Ansible playbook
        cd ansible
        ansible-playbook -i inventory.ini setup-ci.yml
        cd ..
    fi
}

# 5. Deploy ArgoCD applications
deploy_argocd() {
    echo "Deploying ArgoCD applications..."
    
    # Apply ArgoCD apps
    kubectl apply -f argocd/applications/
}

# Main deployment flow
main() {
    ENVIRONMENT=${1:-development}
    
    echo "Starting deployment for $ENVIRONMENT environment..."
    
    # Check Terraform version
    check_terraform_version
    
    # Setup backend
    setup_backend
    
    # Deploy infrastructure
    deploy_infrastructure $ENVIRONMENT
    
    # Build Lambda images
    build_lambdas
    
    # Deploy Helm charts
    deploy_helm $ENVIRONMENT
    
    # Configure CI tools (dev only)
    configure_ci $ENVIRONMENT
    
    # Deploy ArgoCD apps
    deploy_argocd
    
    echo ""
    echo "✅ Deployment completed successfully!"
    echo ""
    echo "📍 Access points:"
    echo "- EKS Cluster: $(cd terraform && terraform output -raw eks_cluster_endpoint)"
    if [ "$ENVIRONMENT" == "development" ]; then
        echo "- GitLab: http://$(kubectl get svc -n gitlab gitlab-webservice -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
        echo "- Jenkins: http://$(kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
        echo "- ArgoCD: http://$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    fi
    echo "- Grafana: http://$(kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
}

# Parse arguments
case "$1" in
    development|staging|production)
        main $1
        ;;
    *)
        echo "Usage: $0 {development|staging|production}"
        exit 1
        ;;
esac
