#!/bin/bash
set -e

echo "🌙 Cleoselene Installer (Linux)"
URL="https://cleoselene.com/downloads/cleoselene-linux"
DEST="/usr/local/bin/cleoselene"

echo "Downloading..."
# Check if we can write to DEST, else use sudo
if [ -w "/usr/local/bin" ]; then
    curl -fsSL "$URL" -o "$DEST"
    chmod +x "$DEST"
else
    echo "Installing to $DEST (requires sudo)..."
    sudo curl -fsSL "$URL" -o "$DEST"
    sudo chmod +x "$DEST"
fi

echo "✅ Installed successfully!"
echo "Run 'cleoselene --help' to get started."
