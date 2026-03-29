#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="."
NAMESPACE="chartpack-test"
FAILURES=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}PASS${NC}: $1"; }
log_fail() { echo -e "${RED}FAIL${NC}: $1"; FAILURES=$((FAILURES + 1)); }
log_info() { echo -e "${YELLOW}INFO${NC}: $1"; }

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Tier 1: Install and verify resources exist (all ci/ values files, no wait for pods)
tier1_test() {
  local name="$1" values_file="$2"
  shift 2
  local expected_kinds=("$@")

  log_info "Tier 1: Installing '$name' from $values_file"
  if ! helm install "$name" "$CHART_DIR" -n "$NAMESPACE" -f "$values_file" --wait=hookOnly --timeout 60s 2>&1; then
    log_fail "$name: helm install failed"
    return
  fi

  for kind in "${expected_kinds[@]}"; do
    if kubectl get "$kind" -n "$NAMESPACE" -l "app.kubernetes.io/instance=$name" -o name 2>/dev/null | grep -q .; then
      log_pass "$name: $kind exists"
    elif kubectl get "$kind" -n "$NAMESPACE" 2>/dev/null | grep -q "$name"; then
      log_pass "$name: $kind exists (name match)"
    else
      log_fail "$name: expected $kind not found"
    fi
  done

  helm uninstall "$name" -n "$NAMESPACE" --wait --timeout 60s 2>/dev/null || true
  sleep 2
}

# Tier 2: Install with real images and verify pods Ready/Complete
tier2_test() {
  local name="$1" values_file="$2" wait_condition="$3" timeout="${4:-120s}"

  log_info "Tier 2: Installing '$name' from $values_file (expecting $wait_condition)"
  local helm_args=(install "$name" "$CHART_DIR" -n "$NAMESPACE" -f "$values_file" --timeout "$timeout")
  [ "$wait_condition" != "none" ] && helm_args+=(--wait)

  if ! helm "${helm_args[@]}" 2>&1; then
    log_fail "$name: helm install failed"
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$name" 2>/dev/null || true
    helm uninstall "$name" -n "$NAMESPACE" --wait --timeout 60s 2>/dev/null || true
    return
  fi

  if [ "$wait_condition" = "ready" ]; then
    local not_ready
    not_ready=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$name" --no-headers 2>/dev/null | grep -cv "Running\|Completed" || true)
    [ "$not_ready" -eq 0 ] && log_pass "$name: all pods running" || log_fail "$name: some pods not ready"
  elif [ "$wait_condition" = "complete" ]; then
    if kubectl wait --for=condition=complete job -n "$NAMESPACE" -l "app.kubernetes.io/instance=$name" --timeout=120s 2>/dev/null; then
      log_pass "$name: job completed"
    else
      log_fail "$name: job did not complete"
    fi
  fi

  helm uninstall "$name" -n "$NAMESPACE" --wait --timeout 60s 2>/dev/null || true
  sleep 2
}

echo "============================================"
echo "  Tier 1: Resource Creation Tests"
echo "============================================"

tier1_test "t1-deploy" "ci/deployment-values.yaml" deployment service configmap ingress horizontalpodautoscaler poddisruptionbudget serviceaccount servicemonitor
tier1_test "t1-sts" "ci/statefulset-values.yaml" statefulset service serviceaccount
tier1_test "t1-ds" "ci/daemonset-values.yaml" daemonset service serviceaccount podmonitor
tier1_test "t1-cj" "ci/cronjob-values.yaml" cronjob secret serviceaccount
tier1_test "t1-job" "ci/job-values.yaml" job serviceaccount
tier1_test "t1-rollout" "ci/rollout-values.yaml" rollout service horizontalpodautoscaler poddisruptionbudget serviceaccount
tier1_test "t1-keda" "ci/keda-values.yaml" deployment scaledobject service serviceaccount
tier1_test "t1-sj" "ci/scaledjob-values.yaml" scaledjob serviceaccount
tier1_test "t1-full" "ci/full-values.yaml" deployment service configmap secret ingress horizontalpodautoscaler poddisruptionbudget serviceaccount role rolebinding clusterrole clusterrolebinding persistentvolumeclaim httproute grpcroute tlsroute backendtrafficpolicy servicemonitor podmonitor vmservicescrape vmpodscrape externalsecret grafanadashboard prometheusrule vmrule certificate networkpolicy virtualservice destinationrule peerauthentication authorizationpolicy verticalpodautoscaler

echo ""
echo "============================================"
echo "  Tier 1.5: Autowiring Content Tests"
echo "============================================"

log_info "Tier 1.5: Installing 't1-wiring' from ci/full-values.yaml"
if helm install "t1-wiring" "$CHART_DIR" -n "$NAMESPACE" -f "ci/full-values.yaml" --wait=hookOnly --timeout 60s 2>&1; then
  RELEASE_NAME="t1-wiring-full-test"

  # oauth2Proxy deployment mode: proxy Deployment + Service created
  if kubectl get deployment -n "$NAMESPACE" "${RELEASE_NAME}-oauth2-gateway-auth" -o name 2>/dev/null | grep -q .; then
    log_pass "autowiring: oauth2Proxy deployment-mode Deployment exists"
  else
    log_fail "autowiring: oauth2Proxy deployment-mode Deployment missing"
  fi
  if kubectl get service -n "$NAMESPACE" "${RELEASE_NAME}-oauth2-gateway-auth" -o name 2>/dev/null | grep -q .; then
    log_pass "autowiring: oauth2Proxy deployment-mode Service exists"
  else
    log_fail "autowiring: oauth2Proxy deployment-mode Service missing"
  fi

  # oauth2Proxy sidecar mode: sidecar injected as initContainer
  INIT_CONTAINERS=$(kubectl get deployment -n "$NAMESPACE" "${RELEASE_NAME}" -o jsonpath='{.spec.template.spec.initContainers[*].name}' 2>/dev/null)
  if echo "$INIT_CONTAINERS" | grep -q "oauth2-corporate"; then
    log_pass "autowiring: oauth2Proxy sidecar injected into pod"
  else
    log_fail "autowiring: oauth2Proxy sidecar not found in initContainers (got: $INIT_CONTAINERS)"
  fi

  # Ingress backend port rewritten to 4180 (sidecar mode)
  INGRESS_PORT=$(kubectl get ingress -n "$NAMESPACE" "${RELEASE_NAME}-public" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)
  if [ "$INGRESS_PORT" = "4180" ]; then
    log_pass "autowiring: ingress backend port rewritten to 4180 (sidecar)"
  else
    log_fail "autowiring: ingress backend port expected 4180, got $INGRESS_PORT"
  fi

  # Ingress without oauth2Proxy keeps default service port (not 4180)
  API_PORT=$(kubectl get ingress -n "$NAMESPACE" "${RELEASE_NAME}-api" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)
  if [ "$API_PORT" != "4180" ] && [ -n "$API_PORT" ]; then
    log_pass "autowiring: ingress without proxy keeps default service port ($API_PORT)"
  else
    log_fail "autowiring: ingress without proxy should not have port 4180"
  fi

  # HTTPRoute backendRefs rewritten to proxy service (deployment mode)
  ROUTE_BACKEND=$(kubectl get httproute -n "$NAMESPACE" "${RELEASE_NAME}-http" -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)
  ROUTE_PORT=$(kubectl get httproute -n "$NAMESPACE" "${RELEASE_NAME}-http" -o jsonpath='{.spec.rules[0].backendRefs[0].port}' 2>/dev/null)
  if [ "$ROUTE_BACKEND" = "${RELEASE_NAME}-oauth2-gateway-auth" ]; then
    log_pass "autowiring: HTTPRoute backendRef rewritten to proxy service"
  else
    log_fail "autowiring: HTTPRoute backendRef expected '${RELEASE_NAME}-oauth2-gateway-auth', got '$ROUTE_BACKEND'"
  fi
  if [ "$ROUTE_PORT" = "4180" ]; then
    log_pass "autowiring: HTTPRoute backendRef port rewritten to 4180"
  else
    log_fail "autowiring: HTTPRoute backendRef port expected 4180, got $ROUTE_PORT"
  fi

  # GRPCRoute without proxy keeps original backendRefs
  GRPC_BACKEND=$(kubectl get grpcroute -n "$NAMESPACE" "${RELEASE_NAME}-grpc" -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)
  GRPC_PORT=$(kubectl get grpcroute -n "$NAMESPACE" "${RELEASE_NAME}-grpc" -o jsonpath='{.spec.rules[0].backendRefs[0].port}' 2>/dev/null)
  if [ "$GRPC_BACKEND" = "${RELEASE_NAME}-grpc" ] && [ "$GRPC_PORT" = "9090" ]; then
    log_pass "autowiring: GRPCRoute without proxy keeps original backend"
  else
    log_fail "autowiring: GRPCRoute expected '${RELEASE_NAME}-grpc:9090', got '$GRPC_BACKEND:$GRPC_PORT'"
  fi

  helm uninstall "t1-wiring" -n "$NAMESPACE" --wait --timeout 60s 2>/dev/null || true
  sleep 2
else
  log_fail "autowiring: helm install failed"
fi

echo ""
echo "============================================"
echo "  Tier 2: Pod Readiness Tests"
echo "============================================"

tier2_test "t2-deploy" "ci/kind/deployment-values.yaml" "ready"
tier2_test "t2-sts" "ci/kind/statefulset-values.yaml" "ready"
tier2_test "t2-ds" "ci/kind/daemonset-values.yaml" "ready"
tier2_test "t2-cj" "ci/kind/cronjob-values.yaml" "none"
tier2_test "t2-job" "ci/kind/job-values.yaml" "complete"
tier2_test "t2-full" "ci/kind/full-values.yaml" "ready" "180s"

echo ""
echo "=============================="
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed${NC}"
fi
