#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

CONTAINER="bakalari-dev"
PLASMOID_ID="cz.saruman.bakalari"

echo "Building Bakaláři widget..."

toolbox run \
    --container "$CONTAINER" \
    cmake \
        -S . \
        -B build \
        -DCMAKE_BUILD_TYPE=Release

toolbox run \
    --container "$CONTAINER" \
    cmake \
        --build build

echo "Removing old installed widget files..."

rm -rf \
    "$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"

echo "Installing widget..."

toolbox run \
    --container "$CONTAINER" \
    cmake \
        --install build \
        --prefix "$HOME/.local"

echo "Restarting Plasma..."

systemctl --user restart \
    plasma-plasmashell.service

echo "Done."