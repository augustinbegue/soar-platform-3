#!/bin/bash

# Script to create 1000 users using the backend API
# Usage: ./create-users.sh <base_url>
# Example: ./create-users.sh http://localhost:3000

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if URL is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Base URL is required${NC}"
    echo "Usage: $0 <base_url>"
    echo "Example: $0 http://localhost:3000"
    exit 1
fi

BASE_URL="$1"
ENDPOINT="${BASE_URL}/db/users/bulk"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMES_FILE="${SCRIPT_DIR}/names.json"

# Check if names.json exists
if [ ! -f "$NAMES_FILE" ]; then
    echo -e "${RED}Error: names.json not found at $NAMES_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}===== User Creation Script =====${NC}"
echo "Base URL: $BASE_URL"
echo "Endpoint: $ENDPOINT"
echo "Names file: $NAMES_FILE"
echo ""

# Read names from JSON file
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    echo "Install it with: brew install jq"
    exit 1
fi

# Extract names array
NAMES_ARRAY=()
while IFS= read -r line; do
    NAMES_ARRAY+=("$line")
done < <(jq -r '.[]' "$NAMES_FILE" 2>/dev/null)

NAMES_COUNT=${#NAMES_ARRAY[@]}
if [ "$NAMES_COUNT" -eq 0 ]; then
    echo -e "${RED}Error: Could not parse names.json${NC}"
    exit 1
fi

echo -e "${GREEN}Loaded ${NAMES_COUNT} unique names${NC}"
echo ""

# Function to generate email
generate_email() {
    local name=$1
    local index=$2
    # Convert name to lowercase and replace spaces with dots
    local email_base=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '.')
    echo "${email_base}${index}@example.com"
}

# Create users in batches
TOTAL_USERS=1000
BATCH_SIZE=50
CREATED_COUNT=0
FAILED_COUNT=0
BATCH_NUM=0

echo -e "${YELLOW}Creating ${TOTAL_USERS} users in batches of ${BATCH_SIZE}...${NC}"
echo ""

while [ $CREATED_COUNT -lt $TOTAL_USERS ]; do
    BATCH_NUM=$((BATCH_NUM + 1))
    CURRENT_BATCH_SIZE=$BATCH_SIZE
    
    # Adjust batch size for the last batch if needed
    if [ $((CREATED_COUNT + BATCH_SIZE)) -gt $TOTAL_USERS ]; then
        CURRENT_BATCH_SIZE=$((TOTAL_USERS - CREATED_COUNT))
    fi
    
    # Build JSON payload for this batch
    USERS_JSON="["
    for ((i = 0; i < CURRENT_BATCH_SIZE; i++)); do
        USER_INDEX=$((CREATED_COUNT + i))
        NAME_INDEX=$((USER_INDEX % NAMES_COUNT))
        NAME="${NAMES_ARRAY[$NAME_INDEX]}"
        EMAIL=$(generate_email "$NAME" "$USER_INDEX")
        
        if [ $i -gt 0 ]; then
            USERS_JSON="${USERS_JSON},"
        fi
        USERS_JSON="${USERS_JSON}{\"name\":\"${NAME}\",\"email\":\"${EMAIL}\"}"
    done
    USERS_JSON="${USERS_JSON}]"
    
    # Send request
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{\"users\":${USERS_JSON}}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" == "201" ] || [ "$HTTP_CODE" == "200" ]; then
        BATCH_CREATED=$(echo "$BODY" | jq -r '.count' 2>/dev/null || echo "0")
        BATCH_CREATED=${BATCH_CREATED:-0}
        
        CREATED_COUNT=$((CREATED_COUNT + BATCH_CREATED))
        echo -e "${GREEN}✓ Batch ${BATCH_NUM}: Created ${BATCH_CREATED}/${CURRENT_BATCH_SIZE} users (Total: ${CREATED_COUNT}/${TOTAL_USERS})${NC}"
    else
        echo -e "${RED}✗ Batch ${BATCH_NUM}: Failed (HTTP ${HTTP_CODE})${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        # Still advance to next batch to continue
        CREATED_COUNT=$((CREATED_COUNT + CURRENT_BATCH_SIZE))
    fi
    
    # Small delay between batches to avoid overwhelming the server
    sleep 0.5
done

echo ""
echo -e "${BLUE}===== Summary =====${NC}"
echo -e "Total batches sent: ${BATCH_NUM}"
echo -e "Total users created: ${GREEN}${CREATED_COUNT}${NC}"
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "Failed batches: ${RED}${FAILED_COUNT}${NC}"
else
    echo -e "Failed batches: ${GREEN}0${NC}"
fi

if [ $CREATED_COUNT -eq $TOTAL_USERS ]; then
    echo -e "${GREEN}✓ Successfully created all ${TOTAL_USERS} users!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Only created ${CREATED_COUNT} out of ${TOTAL_USERS} users${NC}"
    exit 1
fi
