#!/bin/sh
set -e

# Generate env.js from template using envsubst so the container can be configured at runtime
TEMPLATE_FILE="/usr/share/nginx/html/env.template.js"
OUT_FILE="/usr/share/nginx/html/env.js"

if [ -f "$TEMPLATE_FILE" ]; then
  echo "[entrypoint] Generating env.js from template"
  # Only substitute variables that exist in environment; leave others empty
  envsubst '
    ${API_BASE} ${INVENTORY_HOSTNAME} ${ANSIBLE_HOST} ${PRIVATE_IP} ${REGION} ${DEPLOYMENT_VERSION}
  ' < "$TEMPLATE_FILE" > "$OUT_FILE"
  echo "[entrypoint] env.js generated"
else
  echo "[entrypoint] No env.template.js found, skipping generation"
fi

exec "$@"
