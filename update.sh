#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# The installer also restarts Plasma after a successful update.
exec bash ./install.sh "$@"
