#!/usr/bin/env bash
set -e

if command -v prince >/dev/null 2>&1; then
  echo "PrinceXML is already installed: $(command -v prince)"
  echo "PrinceXML version: $(prince --version)"
  exit 0
fi

if ! command -v wget >/dev/null 2>&1; then
  echo "wget is not installed. Installing wget..."
  apt-get update
  apt-get install -yy wget
else
  echo "wget is installed: $(command -v wget)"
fi

if ! command -v gdebi >/dev/null 2>&1; then
  echo "gdebi is not installed. Installing gdebi..."
  apt-get update
  apt-get install -yy gdebi
else
  echo "gdebi is installed: $(command -v gdebi)"
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

if [ "${ID:-}" = "ubuntu" ]; then
  PRINCE_PLATFORM="ubuntu22.04"
elif [ "${ID:-}" = "debian" ]; then
  PRINCE_PLATFORM="debian12"
elif echo " ${ID_LIKE:-} " | grep -q " ubuntu "; then
  PRINCE_PLATFORM="ubuntu22.04"
elif echo " ${ID_LIKE:-} " | grep -q " debian "; then
  PRINCE_PLATFORM="debian12"
else
  echo "Unsupported Linux distribution for PrinceXML package: ${ID:-unknown}" >&2
  exit 1
fi

PRINCE_DEB_NAME="prince_${PRINCE_VERSION}_${PRINCE_PLATFORM}_${PRINCE_ARCH}.deb"
PRINCE_DEB_URL="https://www.princexml.com/download/${PRINCE_DEB_NAME}"
PRINCE_DEB_FILE="/tmp/${PRINCE_DEB_NAME}"

echo "Downloading PrinceXML package from $PRINCE_DEB_URL"
wget -O "$PRINCE_DEB_FILE" "$PRINCE_DEB_URL"

echo "Installing PrinceXML..."
gdebi --non-interactive "$PRINCE_DEB_FILE"

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
