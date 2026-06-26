#!/usr/bin/env bash
set -euo pipefail

if command -v prince >/dev/null 2>&1; then
  echo "PrinceXML is already installed: $(command -v prince)"
  echo "PrinceXML version: $(prince --version)"
  exit 0
fi

if ! command -v wget >/dev/null 2>&1; then
  echo "wget is not installed. Installing wget..."
  apt-get update
  apt-get install -y wget
else
  echo "wget is installed: $(command -v wget)"
fi

PRINCE_VERSION="16.1-1"
SYSTEM_ARCH="$(dpkg --print-architecture)"

case "$SYSTEM_ARCH" in
  amd64|arm64)
    PRINCE_ARCH="$SYSTEM_ARCH"
    ;;
  *)
    echo "Unsupported architecture for PrinceXML package: $SYSTEM_ARCH" >&2
    exit 1
    ;;
esac

if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "Cannot detect operating system: /etc/os-release is missing" >&2
  exit 1
fi

# PrinceXML ships a separate package per Ubuntu LTS / Debian release whose
# dependencies are pinned to that release (e.g. the ubuntu22.04 build requires
# libavif13, which does not exist on Ubuntu 24.04 "noble" — noble ships
# libavif16). The package MUST match the running release, not a hardcoded one.
if [ "${ID:-}" = "ubuntu" ] && [ -n "${VERSION_ID:-}" ]; then
  PRINCE_PLATFORM="ubuntu${VERSION_ID}"
elif [ "${ID:-}" = "debian" ] && [ -n "${VERSION_ID:-}" ]; then
  PRINCE_PLATFORM="debian${VERSION_ID%%.*}"
elif echo " ${ID_LIKE:-} " | grep -q " ubuntu "; then
  PRINCE_PLATFORM="ubuntu22.04"
elif echo " ${ID_LIKE:-} " | grep -q " debian "; then
  PRINCE_PLATFORM="debian12"
else
  echo "Unsupported Linux distribution for PrinceXML package: ${ID:-unknown} ${VERSION_ID:-}" >&2
  exit 1
fi

echo "Detected OS: ${ID:-unknown} ${VERSION_ID:-} -> PrinceXML platform: ${PRINCE_PLATFORM}, arch: ${PRINCE_ARCH}"

PRINCE_DEB_NAME="prince_${PRINCE_VERSION}_${PRINCE_PLATFORM}_${PRINCE_ARCH}.deb"
PRINCE_DEB_URL="https://www.princexml.com/download/${PRINCE_DEB_NAME}"
PRINCE_DEB_FILE="/tmp/${PRINCE_DEB_NAME}"

echo "Downloading PrinceXML package from $PRINCE_DEB_URL"
wget --tries=3 --timeout=60 -O "$PRINCE_DEB_FILE" "$PRINCE_DEB_URL"

# Guard against a server returning an HTML error page with a 200 status.
if ! file "$PRINCE_DEB_FILE" | grep -qi "debian binary package"; then
  echo "Downloaded file is not a valid .deb package:" >&2
  file "$PRINCE_DEB_FILE" >&2
  exit 1
fi

echo "Installing PrinceXML..."
# apt-get installs a local .deb and resolves its dependencies itself
# (apt >= 1.1). This avoids depending on gdebi, whose default package is the
# GTK GUI frontend (gdebi, not gdebi-core) and is unavailable on minimal
# server images.
apt-get update
apt-get install -y "$PRINCE_DEB_FILE"

if command -v prince >/dev/null 2>&1; then
  echo "PrinceXML installed successfully: $(command -v prince)"
  echo "PrinceXML version: $(prince --version)"
else
  echo "Failed to install PrinceXML." >&2
  exit 1
fi

# Clean up
echo "Cleaning up temporary files..."
rm -f "$PRINCE_DEB_FILE"
