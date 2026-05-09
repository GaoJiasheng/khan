#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found." >&2
  echo "Install: brew install xcodegen" >&2
  exit 1
fi

# Resolve packages and generate
xcodegen generate
echo
echo "Generated Doris.xcodeproj from project.yml."
echo "Next steps:"
echo "  1. open Doris.xcodeproj"
echo "  2. Set DEVELOPMENT_TEAM in Xcode (or export DORIS_TEAM_ID before running this)"
echo "  3. Build the Doris-macOS scheme."
