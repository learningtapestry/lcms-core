#!/bin/bash
set -e

echo "Installing Google Chrome for PDF generation..."

wget -q -O /tmp/google-chrome.gpg https://dl-ssl.google.com/linux/linux_signing_key.pub
gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg /tmp/google-chrome.gpg
echo "deb [signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -qqy
apt-get install -y --no-install-recommends google-chrome-stable

echo "Chrome installed at: $(which google-chrome-stable)"
