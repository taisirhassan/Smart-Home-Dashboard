#!/bin/bash

# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring

# Get Grafana password
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port forward Grafana (run this in a separate terminal)
# kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80