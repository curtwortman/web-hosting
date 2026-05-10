#!/usr/bin/env bash

# test.sh – Verify installation and deployment of web-hosting stack
# Checks that Nginx is running, that all expected endpoints return HTTP 200
# and that no 404 or server errors are encountered.

set -euo pipefail

# Helper functions
log() {
  echo "[+] $*"
}
error() {
  echo "[!] $*" >&2
  exit 1
}

# Verify Nginx service status
log "Checking Nginx service status..."
if ! systemctl is-active --quiet nginx; then
  error "Nginx is not running."
fi
log "Nginx is active."

# Dynamically build URL list from repos.yaml
CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/config/repos.yaml"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[!] Config file $CONFIG_FILE not found" >&2
  exit 1
fi

# Determine base URL from config (strip protocol, use http)
BASE_DOMAIN=$(grep '^primary_domain:' "$CONFIG_FILE" | cut -d ':' -f2- | tr -d ' ')
# Remove leading https:// if present
BASE_DOMAIN=${BASE_DOMAIN#https://}
BASE_URL="http://$BASE_DOMAIN"

# Start with the root URL
URLS=("$BASE_URL/")

# Extract nginx_location entries from the YAML (ignore nulls)
while IFS= read -r loc; do
  # Trim whitespace and quotes
  loc=$(echo "$loc" | sed -E 's/^[[:space:]]*"?//;s/"?[[:space:]]*$//')
  # Ensure it starts with a slash
  [[ $loc == /* ]] && URLS+=("$BASE_URL${loc}")
done < <(grep -E '^\s*nginx_location:' "$CONFIG_FILE" | cut -d ':' -f2-)

# Add specific subpages to verify extended routing
URLS+=("$BASE_URL/llm-benchmark/pages/deploy")
URLS+=("$BASE_URL/llm-benchmark/pages/view")
URLS+=("$BASE_URL/llm-benchmark/pages/report")
URLS+=("$BASE_URL/llm-benchmark/pages/index")
URLS+=("$BASE_URL/llm-benchmark/pages/plan")
URLS+=("$BASE_URL/llm-benchmark/pages/present")
URLS+=("$BASE_URL/llm-benchmark/pages/profile")

# Explicit self-checks for identified UI asset issues
URLS+=("$BASE_URL/cluster-manager/shared/css/base.css")
URLS+=("$BASE_URL/dc-planner/shared/css/base.css")
URLS+=("$BASE_URL/llm-benchmark/shared/css/base.css")
URLS+=("$BASE_URL/cluster-manager/")
URLS+=("$BASE_URL/dc-planner/pages/index.html")


# Perform checks
FAIL=0
for u in "${URLS[@]}"; do
  log "Fetching $u"
  # -f makes curl exit non‑zero on HTTP errors (>=400)
  # -s silent, -S shows errors, -L follows redirects, -o discards body
  # Use --resolve to force local routing instead of public DNS
  if ! curl -fsSL --max-time 5 --resolve "$BASE_DOMAIN:80:127.0.0.1" -o /dev/null "$u"; then
    echo "[!] Error: $u returned non‑200 response" >&2
    FAIL=1
  else
    log "✅ $u returned 200 OK"
  fi
done

if [[ $FAIL -ne 0 ]]; then
  error "One or more endpoints returned a non-200 response."
fi

log "All endpoints responded with HTTP 200."

# Run automated UI testing for console errors and button clicks
if command -v node >/dev/null 2>&1; then
  log "Running Playwright UI tests..."
  # Use HTTP URLs resolving to localhost
  node "$(dirname "${BASH_SOURCE[0]}")/test-ui.js" "${URLS[@]}"
else
  log "Node.js not found, skipping Playwright UI tests."
fi

# Run HTML consistency audit across the three dashboard repos
AUDIT_SCRIPT="/home/ubuntu/workspace/webtools-ui/scripts/html_consistency_audit.py"
if command -v python3 >/dev/null 2>&1 && [[ -f "$AUDIT_SCRIPT" ]]; then
  log "Running HTML consistency audit across dashboard repos..."
  if python3 "$AUDIT_SCRIPT"; then
    log "✅ HTML consistency audit: all checks passed."
  else
    echo "[!] HTML consistency audit reported issues — see output above." >&2
    FAIL=1
  fi
else
  log "python3 or audit script not found, skipping HTML consistency audit."
fi

# Optional: verify Apache is also running (if needed)
if systemctl is-active --quiet apache2; then
  log "Apache is also running (optional check)."
fi

log "Verification complete."
