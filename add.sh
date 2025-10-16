#!/bin/bash
set -e
set -o pipefail


# tool name or error if not provided
TOOL_NAME=${1?"Usage: $0 '-s -- <tool name>'

Example: $0 -s -- 'ONT QC Pipeline'"}
LOCAL_BACKEND_PORT=${2:-8000}
API_URL=http://127.0.0.1:$LOCAL_BACKEND_PORT/api/v1
USERNAME=admin@example.com
PASSWORD=changethis

API_TOKEN=$(curl -X 'POST' \
  "${API_URL}/login/access-token" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password&username=${USERNAME}&password=${PASSWORD}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# URL encode the tool name
ENCODED_TOOL_NAME=$(printf '%s\n' "${TOOL_NAME}" | sed 's/ /%20/g')

TOOL_JSON_CONFIG=$(curl -X 'GET' \
  "https://portal.cpg.unimelb.edu.au/api/v1/tools/name/${ENCODED_TOOL_NAME}" \
  -H 'accept: application/json')

# check if tool already exists id is UUID
EXISTING_TOOL=$(curl -X 'GET' \
    "${API_URL}/tools/name/${ENCODED_TOOL_NAME}" \
    -H 'accept: application/json'   \
    -H "Authorization: Bearer ${API_TOKEN}")

EXISTING_TOOL_ID=$(echo $EXISTING_TOOL | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
TOOL_INSTALLED_STATUS=$(echo $EXISTING_TOOL | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

# if EXISTING_TOOL_ID is empty, then tool does not exist add it
if [ -z "$EXISTING_TOOL_ID" ]; then
    echo "Tool does not exist, adding '${TOOL_NAME}'"
    EXISTING_TOOL=$(curl -X 'POST' \
    "${API_URL}/tools/" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "${TOOL_JSON_CONFIG}" \
        -H "Authorization: Bearer ${API_TOKEN}")
    TOOL_INSTALLED_STATUS=$(echo $EXISTING_TOOL | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
 
else
    echo "Tool '${TOOL_NAME}' already exists with ID: ${EXISTING_TOOL_ID}"
fi

# enable tool 
MSG=$(curl -X 'POST' \
  "${API_URL}/tools/${EXISTING_TOOL_ID}/enable" \
    -H 'accept: application/json' \
    -H "Authorization: Bearer ${API_TOKEN}")

echo $MSG

# check if the tool is installed 
if [ "$TOOL_INSTALLED_STATUS" == "uninstalled" ]; then
    echo "Tool is not installed, installing..."
    curl -X 'POST' \
      "${API_URL}/tools/${EXISTING_TOOL_ID}/install" \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{}' \
      -H "Authorization: Bearer ${API_TOKEN}"
else
    echo "Tool is already installed."
fi





