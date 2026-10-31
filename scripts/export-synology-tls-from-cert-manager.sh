#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-cert-manager}"
SECRET_NAME="${SECRET_NAME:-synology-services-tls}"
OUTPUT_DIR="${1:-./out/synology-tls}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not found" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "Exporting certificate material from ${NAMESPACE}/${SECRET_NAME}..."

kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.tls\.crt}' \
  | base64 --decode > "${OUTPUT_DIR}/synology-services.crt"

kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.tls\.key}' \
  | base64 --decode > "${OUTPUT_DIR}/synology-services.key"

kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.ca\.crt}' \
  | base64 --decode > "${OUTPUT_DIR}/homelab-ca.crt"

cat "${OUTPUT_DIR}/synology-services.crt" "${OUTPUT_DIR}/homelab-ca.crt" \
  > "${OUTPUT_DIR}/synology-services-fullchain.crt"

echo
echo "Wrote:"
echo "- ${OUTPUT_DIR}/synology-services.crt"
echo "- ${OUTPUT_DIR}/synology-services.key"
echo "- ${OUTPUT_DIR}/homelab-ca.crt"
echo "- ${OUTPUT_DIR}/synology-services-fullchain.crt"
echo
echo "Import into Synology Certificate Center:"
echo "- Certificate: synology-services-fullchain.crt"
echo "- Private key: synology-services.key"
