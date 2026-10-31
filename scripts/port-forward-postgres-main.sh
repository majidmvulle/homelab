#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-database}"
RESOURCE="${RESOURCE:-svc/postgres-main-rw}"
LOCAL_PORT="${LOCAL_PORT:-5444}"
REMOTE_PORT="${REMOTE_PORT:-5432}"
ADDRESS="${ADDRESS:-127.0.0.1}"
RETRY_SECONDS="${RETRY_SECONDS:-2}"
MAX_RETRY_SECONDS="${MAX_RETRY_SECONDS:-2}"
ENDPOINTS_NAME="${ENDPOINTS_NAME:-postgres-main-rw}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--namespace <namespace>] [--resource <resource>] [--local-port <port>] [--remote-port <port>] [--address <address>]

Keeps a manual kubectl port-forward to the homelab postgres-main writer alive.

Defaults:
  namespace:   ${NAMESPACE}
  resource:    ${RESOURCE}
  local-port:  ${LOCAL_PORT}
  remote-port: ${REMOTE_PORT}
  address:     ${ADDRESS}

Environment overrides:
  NAMESPACE RESOURCE LOCAL_PORT REMOTE_PORT ADDRESS ENDPOINTS_NAME RETRY_SECONDS MAX_RETRY_SECONDS
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace|-n)
      NAMESPACE="$2"
      shift 2
      ;;
    --resource)
      RESOURCE="$2"
      shift 2
      ;;
    --local-port)
      LOCAL_PORT="$2"
      shift 2
      ;;
    --remote-port)
      REMOTE_PORT="$2"
      shift 2
      ;;
    --address)
      ADDRESS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

sleep_with_backoff() {
  local current_backoff="$1"
  echo "port-forward dropped, retrying in ${current_backoff}s..."
  sleep "${current_backoff}"
}

ready_endpoint_count() {
  { kubectl -n "${NAMESPACE}" get endpoints "${ENDPOINTS_NAME}" \
    -o jsonpath='{range .subsets[*].addresses[*]}x{"\n"}{end}' 2>/dev/null || true; } \
    | wc -l \
    | tr -d '[:space:]'
}

wait_for_ready_endpoints() {
  local endpoint_count

  while true; do
    endpoint_count="$(ready_endpoint_count)"
    if [[ "${endpoint_count}" != "0" ]]; then
      return 0
    fi

    echo "Waiting for ready endpoints on ${NAMESPACE}/${ENDPOINTS_NAME}..."
    sleep "${RETRY_SECONDS}"
  done
}

cleanup() {
  if [[ -n "${port_forward_pid:-}" ]]; then
    kill "${port_forward_pid}" >/dev/null 2>&1 || true
    wait "${port_forward_pid}" 2>/dev/null || true
  fi
}

require_command kubectl
trap cleanup EXIT INT TERM

backoff="${RETRY_SECONDS}"
echo "Forwarding ${ADDRESS}:${LOCAL_PORT} -> ${NAMESPACE}/${RESOURCE}:${REMOTE_PORT}"

while true; do
  wait_for_ready_endpoints

  kubectl -n "${NAMESPACE}" port-forward \
    --address "${ADDRESS}" \
    "${RESOURCE}" \
    "${LOCAL_PORT}:${REMOTE_PORT}" &
  port_forward_pid="$!"

  if wait "${port_forward_pid}"; then
    backoff="${RETRY_SECONDS}"
  else
    sleep_with_backoff "${backoff}"
    if (( backoff < MAX_RETRY_SECONDS )); then
      backoff=$((backoff * 2))
      if (( backoff > MAX_RETRY_SECONDS )); then
        backoff="${MAX_RETRY_SECONDS}"
      fi
    fi
  fi
done
