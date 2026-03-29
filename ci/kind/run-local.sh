#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="chartpack-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KEEP_CLUSTER=false
SKIP_TIER1=false
SKIP_TIER2=false
EXTRA_ARGS=()

# Parse flags
for arg in "$@"; do
  case $arg in
    --keep-cluster) KEEP_CLUSTER=true ;;
    --skip-tier1) SKIP_TIER1=true; EXTRA_ARGS+=(--skip-tier1) ;;
    --skip-tier2) SKIP_TIER2=true; EXTRA_ARGS+=(--skip-tier2) ;;
    *) EXTRA_ARGS+=("$arg") ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${YELLOW}INFO${NC}: $1"; }
log_step() { echo -e "\n${GREEN}==>${NC} $1"; }

# Pre-flight checks
for cmd in kind kubectl helm; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd is required but not installed."; exit 1; }
done

cleanup() {
  if [ "$KEEP_CLUSTER" = false ]; then
    log_step "Deleting kind cluster '$CLUSTER_NAME'..."
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
  else
    log_info "Keeping cluster '$CLUSTER_NAME' (use 'kind delete cluster --name $CLUSTER_NAME' to remove)"
  fi
}
trap cleanup EXIT

# Create cluster
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  log_info "Cluster '$CLUSTER_NAME' already exists, reusing it"
else
  log_step "Creating kind cluster '$CLUSTER_NAME'..."
  START=$(date +%s)
  kind create cluster --name "$CLUSTER_NAME" --wait 300s
  END=$(date +%s)
  log_info "Cluster created in $((END - START))s"
fi

# Install CRDs
log_step "Installing CRDs..."
START=$(date +%s)

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml 2>/dev/null

kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/crds/rollout-crd.yaml 2>/dev/null
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/crds/experiment-crd.yaml 2>/dev/null
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/crds/analysis-run-crd.yaml 2>/dev/null
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/crds/analysis-template-crd.yaml 2>/dev/null
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/crds/cluster-analysis-template-crd.yaml 2>/dev/null

kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.19.0/keda-2.19.0-crds.yaml 2>/dev/null

kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.90.1/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml 2>/dev/null
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.90.1/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml 2>/dev/null
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.90.1/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml 2>/dev/null

kubectl apply --server-side -f https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.68.3/config/crd/overlay/crd.yaml 2>/dev/null

kubectl apply --server-side -f https://raw.githubusercontent.com/external-secrets/external-secrets/v2.2.0/deploy/crds/bundle.yaml 2>/dev/null

kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.7.1/envoy-gateway-crds.yaml 2>/dev/null

kubectl apply --server-side -f https://raw.githubusercontent.com/grafana-operator/grafana-operator/v5.22.2/config/crd/bases/grafana.integreatly.org_grafanadashboards.yaml 2>/dev/null

kubectl apply --server-side -f https://raw.githubusercontent.com/istio/istio/1.29.0/manifests/charts/base/files/crd-all.gen.yaml 2>/dev/null

END=$(date +%s)
log_info "CRDs installed in $((END - START))s"

# Run tests
log_step "Running integration tests..."
cd "$REPO_ROOT"
exec ./ci/kind/test.sh ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
