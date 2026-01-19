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

echo "Installing xfg..."
npm install -g @aspruyt/xfg

echo "Running config sync..."
xfg --config ./config.yaml --work-dir /tmp/xfg

echo "Config sync completed"
