#!/bin/bash

set -euo pipefail

# Override via environment (Ansible sets these in the ERP role).
LOCAL_FG_AGENT="${LOCAL_FG_AGENT:-http://127.0.0.1:4000}"
API_URL="${API_URL:-https://api-license-alpha.sadgan.com/api/licensemanagement/instanceLock}"
LICENSE_LOCK="${LICENSE_LOCK:-./instance.lock}"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <instance-id>"
    exit 1
fi

INSTANCE_ID="$1"

echo "Getting fingerprint from ${LOCAL_FG_AGENT}..."
FINGERPRINT="$(curl -s -f -H "Accept: application/json" "${LOCAL_FG_AGENT%/}/fingerprint")"

if [ -z "$FINGERPRINT" ]; then
    echo "Error: Could not get fingerprint"
    exit 1
fi

echo "Fingerprint received"
echo "Requesting license for instance: ${INSTANCE_ID}"

mkdir -p "$(dirname "$LICENSE_LOCK")"

curl -k -f -X POST \
  "$API_URL" \
  -H 'accept: application/json' \
  -H 'Accept-Language: fa' \
  -H 'Content-Type: application/json' \
  -d "{\"instanceCode\":\"${INSTANCE_ID}\",\"fingerprint\":\"${FINGERPRINT}\"}" \
  -o "$LICENSE_LOCK"

echo "License lock saved to: ${LICENSE_LOCK}"
echo "File size: $(wc -c < "$LICENSE_LOCK") bytes"
