#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

CONTAINER="bakalari-dev"
PLASMOID_ID="cz.saruman.bakalari"

echo "Installing Bakaláři Schedule..."

# ----------------------------
# Check Toolbox
# ----------------------------

if ! command -v toolbox >/dev/null 2>&1; then
    echo
    echo "Error: toolbox is not installed."
    echo
    echo "Install Toolbox first, then run this script again."
    exit 1
fi


# ----------------------------
# Create development container
# ----------------------------

if ! toolbox list --containers \
    | awk '{print $2}' \
    | grep -Fxq "$CONTAINER"
then
    echo
    echo "Creating Toolbox container: $CONTAINER"

    toolbox create "$CONTAINER"
else
    echo
    echo "Toolbox container already exists: $CONTAINER"
fi


# ----------------------------
# Install build dependencies
# ----------------------------

echo
echo "Installing build dependencies..."

toolbox run \
    --container "$CONTAINER" \
    sudo dnf install -y \
        cmake \
        gcc-c++ \
        kf6-kwallet-devel \
        qt6-qtdeclarative-devel


# ----------------------------
# Configure
# ----------------------------

echo
echo "Configuring project..."

toolbox run \
    --container "$CONTAINER" \
    cmake \
        -S . \
        -B build \
        -DCMAKE_BUILD_TYPE=Release


# ----------------------------
# Build
# ----------------------------

echo
echo "Building widget..."

toolbox run \
    --container "$CONTAINER" \
    cmake \
        --build build


# ----------------------------
# Remove an old installation
# ----------------------------

echo
echo "Removing old installation if present..."

rm -rf \
    "$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"


# ----------------------------
# Install
# ----------------------------

echo
echo "Installing widget..."

toolbox run \
    --container "$CONTAINER" \
    cmake \
        --install build \
        --prefix "$HOME/.local"


# ----------------------------
# Restart Plasma
# ----------------------------

echo
echo "Restarting Plasma..."

systemctl --user restart \
    plasma-plasmashell.service


echo
echo "Installation complete."
echo
echo "You can now add 'Bakaláři Schedule' from Plasma's Add Widgets dialog."