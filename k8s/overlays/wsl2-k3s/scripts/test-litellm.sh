#!/bin/bash
# test-litellm.sh — Verify LiteLLM connectivity from K3s pods
# Usage: Run from a machine with kubectl access to the K3s cluster

set -euo pipefail

echo "=== LiteLLM Connectivity Test ==="
echo ""

echo "1. Testing direct connectivity to LiteLLM (Mac 192.168.8.75:4000)..."
kubectl exec -n nem deploy/nem-mimir -- curl -sf --connect-timeout 10 http://192.168.8.75:4000/health || echo "WARN: Direct connectivity to Mac LiteLLM failed (Mac may be offline)"
echo ""

echo "2. Testing K8s service abstraction (http://litellm:4000)..."
kubectl exec -n nem deploy/nem-mimir -- curl -sf --connect-timeout 10 http://litellm:4000/health || echo "WARN: K8s service abstraction connectivity failed"
echo ""

echo "3. Listing available models..."
kubectl exec -n nem deploy/nem-mimir -- curl -sf --connect-timeout 10 http://192.168.8.75:4000/v1/models 2>/dev/null | head -100 || echo "WARN: Could not list models (Mac may be offline)"
echo ""

echo "=== LiteLLM Model Categories ==="
echo "- Embedding models"
echo "- Small-mid language models"
echo "- Coding models"
echo "- Vision models"
echo ""
echo "=== Test Complete ==="
