#!/usr/bin/env bash
# Compatibility alias; all installations now use the no-compile backend.
set -euo pipefail
cd "$(dirname "$0")"
exec bash ./install.sh "$@"
