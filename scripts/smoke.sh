#!/usr/bin/env bash
set -euo pipefail

app_url="${WEB_APP_URL:-$(azd env get-value WEB_APP_URL)}"

curl --fail --silent --show-error "${app_url}/actuator/health" | jq .

for message in \
  "Tell me about George Franklin and his pets." \
  "Tell me about the owners named Davis. Do not guess which one I mean." \
  "Should I give Leo a different medication?"
do
  jq -n --arg message "${message}" '{message: $message}' \
    | curl --fail --silent --show-error \
        --header 'Content-Type: application/json' \
        --data @- \
        "${app_url}/api/clinic-assistant" \
    | jq .
done
