#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Validate GH_TOKEN is set
if [ -z "${GH_TOKEN:-}" ]; then
  echo "Error: GH_TOKEN environment variable is required" >&2
  exit 1
fi

# Validate required files exist
if [ ! -f "config.yaml" ]; then
  echo "Error: config.yaml not found" >&2
  exit 1
fi

echo "Installing json-config-sync..."
npm install -g @aspruyt/json-config-sync

echo "Running config sync..."
json-config-sync --config ./config.yaml --work-dir /tmp/json-config-sync

echo "Config sync completed"
