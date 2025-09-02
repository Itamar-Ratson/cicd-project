# CI/CD Infrastructure Project

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- Docker installed  
- kubectl installed
- **Terraform >= 1.5.0** (required for native S3 state locking)
- Helm & Helmfile installed
- Ansible installed

### Setup Steps

1. **Run the project setup script**
   ```bash
   chmod +x setup-project.sh
   ./setup-project.sh
   cd cicd-project
   ```

2. **Setup Terraform Backend (with native S3 locking)**
   ```bash
   ./setup-backend.sh
   ```

3. **Configure Slack Webhook**
   Edit `terraform/terraform.tfvars` and add your Slack webhook URL

4. **Deploy Environments**
   ```bash
   ./deploy.sh development
   ./deploy.sh staging
   ./deploy.sh production
   ```

## 📊 Access Services

### Development Environment
- **GitLab** - Get initial root password:
  ```bash
  kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d
  ```
- **Jenkins** - Login: `admin/admin123`
- **ArgoCD** - Get admin password:
  ```bash
  kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  ```
- **Grafana** - Login: `admin/admin123`

## 🏗️ Architecture

### Infrastructure
- **State Management**: Native S3 state locking (Terraform >= 1.5.0)
- **Kubernetes**: EKS on Fargate (serverless)
- **Service Mesh**: Istio with mTLS
- **Monitoring**: Prometheus, Grafana, Loki, Tempo, OpenTelemetry

### CI/CD Pipeline
- **SCM**: Self-hosted GitLab
- **CI**: Jenkins with dynamic agents
- **CD**: ArgoCD (GitOps)
- **Registry**: Amazon ECR
- **Testing**: SAST, Lint, Unit, Integration, DAST, Smoke tests

### AWS Services
- **Compute**: EKS Fargate, Lambda
- **Storage**: S3, DynamoDB
- **Messaging**: SQS
- **Networking**: ALB, CloudFront
- **IaC**: Terraform with native S3 locking

## 📁 Project Structure

```
cicd-project/
├── terraform/           # Infrastructure as Code
│   ├── main.tf         # Main configuration
│   ├── backend.tf      # S3 backend config (auto-generated)
│   ├── modules/        # Reusable modules
│   └── environments/   # Environment-specific configs
├── helmfile.yaml       # Helm releases configuration
├── k8s/                # Kubernetes manifests
├── argocd/             # ArgoCD applications
├── jenkins/            # CI pipelines
├── ansible/            # Configuration automation
├── app/                # Python web application
├── lambda-*/           # Lambda functions
├── setup-backend.sh    # Backend setup script
└── deploy.sh           # Main deployment script
```

## 🔒 Native S3 State Locking

Starting with Terraform 1.5.0, S3 backend supports native state locking without DynamoDB:

- **No DynamoDB table needed** - Simpler setup
- **Automatic locking** - S3 handles it natively
- **Cost savings** - No DynamoDB charges
- **Better performance** - Direct S3 operations

Requirements:
- Terraform >= 1.5.0
- S3 bucket with versioning enabled (script handles this)

## 🔧 Terraform Workspaces

The project uses Terraform workspaces for environment separation:

```bash
# List workspaces
terraform workspace list

# Switch workspace
terraform workspace select staging

# Create new workspace
terraform workspace new production
```

## 🚨 Troubleshooting

### Check pod logs
```bash
kubectl logs -n <namespace> <pod-name>
```

### Check Istio sidecar
```bash
istioctl proxy-config all <pod>.<namespace>
```

### Check ArgoCD sync status
```bash
argocd app sync <app-name>
```

### Verify Terraform version
```bash
terraform version
# Must be >= 1.5.0 for native S3 locking
```

## 📝 Notes

- All infrastructure uses native S3 state locking (no DynamoDB)
- Fargate profiles are configured for all namespaces
- mTLS is enabled cluster-wide via Istio
- Grafana includes pre-configured dashboards for all environments
- Jenkins uses dynamic Kubernetes agents for builds
