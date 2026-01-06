#!/bin/bash
set -e

echo "🌙 Cleoselene Installer (macOS)"
URL="https://cleoselene.com/downloads/cleoselene-macos"
DEST="/usr/local/bin/cleoselene"

echo "Downloading..."
# Check if we can write to DEST, else use sudo
if [ -w "/usr/local/bin" ]; then
    curl -fsSL "$URL" -o "$DEST"
    chmod +x "$DEST"
    xattr -d com.apple.quarantine "$DEST" 2>/dev/null || true
else
    echo "Installing to $DEST (requires sudo)..."
    sudo curl -fsSL "$URL" -o "$DEST"
    sudo chmod +x "$DEST"
    sudo xattr -d com.apple.quarantine "$DEST" 2>/dev/null || true
fi

echo "✅ Installed successfully!"
echo "Run 'cleoselene --help' to get started."
