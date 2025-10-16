#!/bin/bash
set -e
set -o pipefail

# Enable detailed logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

log "Starting portal tool adder script"

# tool name or error if not provided
TOOL_NAME=${1?"Usage: $0 '-s -- <tool name>'

Example: $0 -s -- 'ONT QC Pipeline'"}
LOCAL_BACKEND_PORT=${2:-8000}
API_URL=http://127.0.0.1:$LOCAL_BACKEND_PORT/api/v1
USERNAME=admin@example.com
PASSWORD=changethis

log "Tool name: ${TOOL_NAME}"
log "Local backend port: ${LOCAL_BACKEND_PORT}"
log "API URL: ${API_URL}"

log "Authenticating with API..."
API_TOKEN=$(curl -X 'POST' \
  "${API_URL}/login/access-token" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password&username=${USERNAME}&password=${PASSWORD}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$API_TOKEN" ]; then
    log "ERROR: Failed to obtain API token"
    exit 1
fi
log "Successfully authenticated and obtained API token"

# URL encode the tool name
ENCODED_TOOL_NAME=$(printf '%s\n' "${TOOL_NAME}" | sed 's/ /%20/g')
log "URL encoded tool name: ${ENCODED_TOOL_NAME}"

log "Fetching tool configuration from portal..."
TOOL_JSON_CONFIG=$(curl -X 'GET' \
  "https://portal.cpg.unimelb.edu.au/api/v1/tools/name/${ENCODED_TOOL_NAME}" \
  -H 'accept: application/json')

if [ -z "$TOOL_JSON_CONFIG" ]; then
    log "ERROR: Failed to fetch tool configuration from portal"
    exit 1
fi
log "Successfully fetched tool configuration"

# check if tool already exists id is UUID
log "Checking if tool already exists in local backend..."
EXISTING_TOOL=$(curl -X 'GET' \
    "${API_URL}/tools/name/${ENCODED_TOOL_NAME}" \
    -H 'accept: application/json'   \
    -H "Authorization: Bearer ${API_TOKEN}")

EXISTING_TOOL_ID=$(echo $EXISTING_TOOL | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
TOOL_INSTALLED_STATUS=$(echo $EXISTING_TOOL | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

# if EXISTING_TOOL_ID is empty, then tool does not exist add it
if [ -z "$EXISTING_TOOL_ID" ]; then
    log "Tool does not exist, adding '${TOOL_NAME}'"
    EXISTING_TOOL=$(curl -X 'POST' \
    "${API_URL}/tools/" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "${TOOL_JSON_CONFIG}" \
        -H "Authorization: Bearer ${API_TOKEN}")
    EXISTING_TOOL_ID=$(echo $EXISTING_TOOL | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    TOOL_INSTALLED_STATUS=$(echo $EXISTING_TOOL | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    log "Tool successfully added with ID: ${EXISTING_TOOL_ID}"
else
    log "Tool '${TOOL_NAME}' already exists with ID: ${EXISTING_TOOL_ID}"
fi

# enable tool 
log "Enabling tool with ID: ${EXISTING_TOOL_ID}"
MSG=$(curl -X 'POST' \
  "${API_URL}/tools/${EXISTING_TOOL_ID}/enable" \
    -H 'accept: application/json' \
    -H "Authorization: Bearer ${API_TOKEN}")

log "Enable tool response: $MSG"

# check if the tool is installed 
log "Current tool installation status: ${TOOL_INSTALLED_STATUS}"
if [ "$TOOL_INSTALLED_STATUS" == "uninstalled" ]; then
    log "Tool is not installed, installing..."
    INSTALL_RESPONSE=$(curl -X 'POST' \
      "${API_URL}/tools/${EXISTING_TOOL_ID}/install" \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{}' \
      -H "Authorization: Bearer ${API_TOKEN}")
    log "Install response: ${INSTALL_RESPONSE}"
else
    log "Tool is already installed."
fi

log "Portal tool adder script completed successfully"





