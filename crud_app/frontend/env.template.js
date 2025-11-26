// This file is generated at container start by envsubst (docker-entrypoint.sh)
window.__API_BASE__ = "${API_BASE}";

window.__SERVER_INFO__ = {
  inventory_hostname: "${INVENTORY_HOSTNAME}",
  ansible_host: "${ANSIBLE_HOST}",
  private_ip: "${PRIVATE_IP}",
  region: "${REGION}",
  deployment_version: "${DEPLOYMENT_VERSION}"
};

// If variables are empty, frontend will show sensible defaults.
