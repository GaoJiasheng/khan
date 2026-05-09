#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../cli/doris"

swift build -c release
echo "Built CLI at $(pwd)/.build/release/doris"
