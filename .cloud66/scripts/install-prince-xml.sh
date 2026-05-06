#!/usr/bin/env bash
set -e

if which prince >/dev/null 2>&1; then
  echo "PrinceXML is already installed: $(which prince)"
  echo "PrinceXML version: $(prince --version)"
  exit 0
fi

if ! which wget >/dev/null 2>&1; then
  echo "wget is not installed. Installing wget..."
  apt-get update
  apt-get install -yy wget
else
  echo "wget is installed: $(which wget)"
fi

if ! which gdebi >/dev/null 2>&1; then
  echo "gdebi is not installed. Installing gdebi..."
  apt-get update
  apt-get install -yy gdebi
else
  echo "gdebi is installed: $(which gdebi)"
fi

PRINCE_DEB_URL="https://www.princexml.com/download/prince_16.1-1_ubuntu22.04_amd64.deb"
PRINCE_DEB_FILE="/tmp/prince.deb"

echo "Downloading PrinceXML package from $PRINCE_DEB_URL"
wget -O "$PRINCE_DEB_FILE" "$PRINCE_DEB_URL"

echo "Installing PrinceXML..."
gdebi --non-interactive "$PRINCE_DEB_FILE"

if which prince >/dev/null 2>&1; then
  echo "PrinceXML installed successfully: $(which prince)"
  echo "PrinceXML version: $(prince --version)"
else
  echo "Failed to install PrinceXML." >&2
  exit 1
fi

# Clean up
echo "Cleaning up temporary files..."
rm -f "$PRINCE_DEB_FILE"
