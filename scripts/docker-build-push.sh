#!/bin/bash

# scripts/docker-build-push.sh

# Ensure AWS CLI is configured with your credentials
aws configure

# Get the AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Navigate to the project root directory
cd "$(dirname "$0")/.."

# Build and push backend
echo "Building and pushing backend..."
docker build -t smart-home-backend:latest -f backend/Dockerfile backend
docker tag smart-home-backend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/smart-home-backend:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/smart-home-backend:latest

# Build and push frontend
echo "Building and pushing frontend..."
docker build -t smart-home-frontend:latest -f frontend/Dockerfile frontend
docker tag smart-home-frontend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/smart-home-frontend:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/smart-home-frontend:latest

echo "Docker build and push completed."