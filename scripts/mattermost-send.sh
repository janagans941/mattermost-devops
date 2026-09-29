#!/bin/bash

set -euo pipefail

MATTERMOST_URL="${MATTERMOST_URL:-http://localhost:8065}"
CHANNEL_ID="${MATTERMOST_CHANNEL_ID:-uprbuzmupbg4znkq3qgmpscq3y}"

if [ -z "${MM_TOKEN:-}" ]; then
    echo "ERROR: MM_TOKEN is not set."
    echo "Export the Mattermost API token before running this script."
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 \"message\""
    exit 1
fi

MESSAGE="$*"

curl -fsS -X POST \
    "${MATTERMOST_URL}/api/v4/posts" \
    -H "Authorization: Bearer ${MM_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"channel_id": sys.argv[1], "message": sys.argv[2]}))' "$CHANNEL_ID" "$MESSAGE")"

echo
echo "Message sent successfully."
