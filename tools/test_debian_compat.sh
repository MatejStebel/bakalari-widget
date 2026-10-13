#!/usr/bin/env bash
# Run inside a disposable Debian 13 container, NOT on the user's host.
set -euo pipefail
if [[ ${1:-} != --inside-container ]]; then
    echo "Run with Podman as documented in README.md; this script installs container test dependencies." >&2
    exit 2
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    python3-pyside6.qtqml python3-pyside6.qtgui python3-dbus python3-gi \
    qml6-module-qtquick qml6-module-qtqml-workerscript qml6-module-qtqml-models \
    dbus-daemon curl ca-certificates xz-utils

mkdir -p /tmp/debian-plasma
curl -fLsS https://deb.debian.org/debian/pool/main/p/plasma-workspace/plasma-workspace_6.3.6-2_amd64.deb \
    -o /tmp/debian-plasma/workspace.deb
dpkg-deb -x /tmp/debian-plasma/workspace.deb /tmp/debian-plasma

dbus-run-session -- bash -euo pipefail -c '
    BAKALARI_TEST_PRIVATE_BUS=1 python3 /work/tools/mock_wallet_service.py > /tmp/mock-wallet-ready &
    service_pid=$!
    trap "kill $service_pid" EXIT
    for attempt in {1..100}; do
        if grep -q READY /tmp/mock-wallet-ready; then break; fi
        sleep 0.1
    done
    grep -q READY /tmp/mock-wallet-ready
    python3 /work/tools/test_wallet_qml.py --live \
        --qml-import-path /tmp/debian-plasma/usr/lib/x86_64-linux-gnu/qt6/qml
'
