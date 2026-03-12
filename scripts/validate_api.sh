#!/bin/bash
# Script to validate Zabbix API readiness

echo "Checking Zabbix API..."

API_URL="http://localhost/api_jsonrpc.php"

# Default Zabbix credentials (from documentation/examples)
ZBX_USER="Admin"
ZBX_PASS="zabbix"

# Try to authenticate and get an auth token
# Note: In a production setup, these should be securely injected or randomized
RESPONSE=$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d "
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.login\",
    \"params\": {
        \"user\": \"$ZBX_USER\",
        \"password\": \"$ZBX_PASS\"
    },
    \"id\": 1,
    \"auth\": null
}" $API_URL)

AUTH_TOKEN=$(echo $RESPONSE | jq -r '.result')

if [ "$AUTH_TOKEN" != "null" ] && [ -n "$AUTH_TOKEN" ]; then
    echo "  [SUCCESS] Authenticated with Zabbix API."
    
    # Get Zabbix version as a further check
    VERSION_RESPONSE=$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d "
    {
        \"jsonrpc\": \"2.0\",
        \"method\": \"apiinfo.version\",
        \"params\": [],
        \"id\": 2,
        \"auth\": null
    }" $API_URL)
    ZBX_VERSION=$(echo $VERSION_RESPONSE | jq -r '.result')
    
    echo "  [SUCCESS] Zabbix API Version: $ZBX_VERSION"
    exit 0
else
    ERROR_MSG=$(echo $RESPONSE | jq -r '.error.data')
    echo "  [FAIL] Could not authenticate with Zabbix API."
    echo "  [INFO] Error detail: $ERROR_MSG"
    echo "  [INFO] Response: $RESPONSE"
    exit 1
fi
