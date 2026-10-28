#!/usr/bin/env bash
set -euo pipefail

destination="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/cz.saruman.bakalari"
if [[ $# -eq 2 && $1 == --destination && -n $2 ]]; then
    destination=$2
elif [[ $# -ne 0 ]]; then
    echo "Usage: $0 [--destination DIRECTORY]" >&2
    exit 2
fi

if [[ ! -d $destination ]]; then
    echo "Widget is not installed: $destination"
    exit 0
fi

rm -rf -- "$destination"
echo "Removed widget: $destination"
echo "KWallet credentials and Plasma settings were kept."

if command -v systemctl >/dev/null \
        && systemctl --user restart plasma-plasmashell.service; then
    echo "Plasma restarted."
else
    echo "Plasma could not be restarted; log out and back in to finish removal." >&2
fi
