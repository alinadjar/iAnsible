#!/bin/bash

set -e

# Configuration
LOCAL_FG_AGENT="http://192.168.10.244:4000"
API_URL="https://api-license-alpha.sadgan.com/api/licensemanagement/instanceLock"
# API_URL="https://dev.api.license-manage.sadgan.int/api/licensemanagement/instanceLock"
LICENSE_LOCK="./instance.lock"

# Check input
if [ $# -ne 1 ]; then
    echo "Usage: $0 <instance-id>"
    exit 1
fi

INSTANCE_ID=$1

echo "Getting fingerprint from $LOCAL_FG_AGENT..."
FINGERPRINT=$(curl -s -f -H "Accept: application/json" "$LOCAL_FG_AGENT/fingerprint")

if [ -z "$FINGERPRINT" ]; then
    echo "Error: Could not get fingerprint"
    exit 1
fi

echo "Fingerprint received"
echo "Requesting license for instance: $INSTANCE_ID"

# Create directory
mkdir -p "$(dirname "$LICENSE_LOCK")"

# Send request and save license
curl -k -X 'POST' \
  "$API_URL" \
  -H 'accept: application/json' \
  -H 'Accept-Language: fa' \
  -H 'Content-Type: application/json' \
  -d "{\"instanceCode\":\"$INSTANCE_ID\",\"fingerprint\":\"$FINGERPRINT\"}" \
  -o "$LICENSE_LOCK" \
  --fail

if [ $? -eq 0 ]; then
    echo "✅ License lock saved to: $LICENSE_LOCK"
    echo "📊 File size: $(wc -c < "$LICENSE_LOCK") bytes"
else
    echo "❌ Failed to download license"
    exit 1
fi
