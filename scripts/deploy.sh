#!/bin/bash

# FileSure DevOps Deployment Script
# This script deploys the complete FileSure document processing system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="filesure"
DOCKER_REGISTRY="docker.io"
API_IMAGE="filesure/api:latest"
WORKER_IMAGE="filesure/worker:latest"

echo -e "${BLUE}🚀 Starting FileSure DevOps Deployment${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

# Check if KEDA is installed
if ! kubectl get crd scaledjobs.keda.sh >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  KEDA not found. Installing KEDA...${NC}"
    kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml
    echo -e "${GREEN}✅ KEDA installed${NC}"
    
    # Wait for KEDA to be ready
    echo -e "${YELLOW}⏳ Waiting for KEDA to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=keda-operator -n keda-system --timeout=300s
fi

# Check if Ingress controller exists
if ! kubectl get ingressclass nginx >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  NGINX Ingress Controller not found. You may need to install it.${NC}"
    echo -e "${BLUE}ℹ️  For minikube: minikube addons enable ingress${NC}"
    echo -e "${BLUE}ℹ️  For other clusters: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml${NC}"
fi

# Build Docker images
echo -e "${YELLOW}🔨 Building Docker images...${NC}"

# Build API image
docker build -t $API_IMAGE -f api/Dockerfile .
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ API image built successfully${NC}"
else
    echo -e "${RED}❌ Failed to build API image${NC}"
    exit 1
fi

# Build Worker image
docker build -t $WORKER_IMAGE -f worker/Dockerfile .
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Worker image built successfully${NC}"
else
    echo -e "${RED}❌ Failed to build Worker image${NC}"
    exit 1
fi

# Optional: Push images to registry
read -p "Do you want to push images to Docker Hub? (y/N): " push_images
if [[ $push_images =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}📤 Pushing images to registry...${NC}"
    docker push $API_IMAGE
    docker push $WORKER_IMAGE
    echo -e "${GREEN}✅ Images pushed successfully${NC}"
fi

# Create namespace
echo -e "${YELLOW}📁 Creating namespace...${NC}"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy configurations and secrets
echo -e "${YELLOW}⚙️  Deploying configurations...${NC}"

# Prompt for Azure Blob Storage connection string
read -p "Enter your Azure Blob Storage connection string (or press Enter to skip): " azure_conn
if [ ! -z "$azure_conn" ]; then
    # Update the secret with the actual connection string
    azure_conn_b64=$(echo -n "$azure_conn" | base64 -w 0)
    kubectl create secret generic filesure-secrets \
        --from-literal=AZURE_BLOB_CONN="$azure_conn" \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    echo -e "${GREEN}✅ Azure credentials configured${NC}"
else
    # Apply default secret
    kubectl apply -f k8s/01-namespace-config.yaml
    echo -e "${YELLOW}⚠️  Using default Azure configuration (uploads will be skipped)${NC}"
fi

# Deploy all Kubernetes manifests
echo -e "${YELLOW}🚀 Deploying Kubernetes resources...${NC}"

kubectl apply -f k8s/01-namespace-config.yaml
kubectl apply -f k8s/02-mongodb.yaml
kubectl apply -f k8s/03-api-service.yaml
kubectl apply -f k8s/04-keda-scaledjob.yaml
kubectl apply -f k8s/05-prometheus.yaml
kubectl apply -f k8s/06-grafana.yaml

echo -e "${GREEN}✅ All resources deployed${NC}"

# Wait for deployments to be ready
echo -e "${YELLOW}⏳ Waiting for deployments to be ready...${NC}"

kubectl wait --for=condition=available deployment/mongodb -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=available deployment/filesure-api -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=available deployment/prometheus -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=available deployment/grafana -n $NAMESPACE --timeout=300s

echo -e "${GREEN}✅ All deployments are ready${NC}"

# Display access information
echo -e "${BLUE}🌐 Access Information:${NC}"
echo ""

# Get service information
api_service=$(kubectl get svc filesure-api-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
grafana_service=$(kubectl get svc grafana-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
prometheus_service=$(kubectl get svc prometheus-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')

echo -e "${GREEN}📊 Services:${NC}"
echo "  API Service: http://$api_service (or use port-forward)"
echo "  Grafana: http://$grafana_service:3000 (admin/admin123)"
echo "  Prometheus: http://$prometheus_service:9090"
echo ""

echo -e "${GREEN}🔌 Port Forwarding Commands:${NC}"
echo "  API: kubectl port-forward svc/filesure-api-service 8080:80 -n $NAMESPACE"
echo "  Grafana: kubectl port-forward svc/grafana-service 3000:3000 -n $NAMESPACE"
echo "  Prometheus: kubectl port-forward svc/prometheus-service 9090:9090 -n $NAMESPACE"
echo ""

# Setup ingress hosts (if using)
echo -e "${GREEN}🌍 Ingress Setup (optional):${NC}"
echo "  Add to /etc/hosts:"
echo "  127.0.0.1 filesure.local"
echo "  127.0.0.1 grafana.local"
echo ""

echo -e "${GREEN}🎯 Testing:${NC}"
echo "  1. Access the API at http://localhost:8080 (after port-forward)"
echo "  2. Create some jobs using the web interface"
echo "  3. Watch KEDA scale workers: kubectl get jobs -n $NAMESPACE -w"
echo "  4. Check metrics in Grafana at http://localhost:3000"
echo ""

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${BLUE}📖 Next steps:${NC}"
echo "  - Configure Azure Blob Storage if not done already"
echo "  - Set up monitoring alerts"
echo "  - Test the complete workflow"
echo "  - Check logs: kubectl logs -l app=filesure-api -n $NAMESPACE"