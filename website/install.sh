#!/bin/bash
set -e

# Colors
RESET='\033[0m'
BOLD='\033[1m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'

echo -e "${BOLD}🌙 Installing Cleoselene...${RESET}"

# 1. Detect OS
OS="$(uname -s)"
case "$OS" in
  Linux)
    PLATFORM="linux"
    ;;
  Darwin)
    PLATFORM="macos"
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

# 2. Setup Directories
INSTALL_DIR="$HOME/.cleoselene"
BIN_DIR="$INSTALL_DIR/bin"
EXE="$BIN_DIR/cleoselene"
URL="https://cleoselene.com/downloads/cleoselene-$PLATFORM"

mkdir -p "$BIN_DIR"

# 3. Download
echo -e "Downloading for ${YELLOW}$PLATFORM${RESET}..."
curl -fsSL --progress-bar "$URL" -o "$EXE"
chmod +x "$EXE"

# 4. macOS Quarantine Fix
if [ "$PLATFORM" == "macos" ]; then
    xattr -d com.apple.quarantine "$EXE" 2>/dev/null || true
fi

# 5. Add to PATH
case ":$PATH:" in
  *:":$BIN_DIR:"*) 
    # Already in path
    ;;
  *)
    SHELL_NAME=$(basename "$SHELL")
    RC_FILE=""
    
    case "$SHELL_NAME" in
      bash) RC_FILE="$HOME/.bashrc" ;;
      zsh)  RC_FILE="$HOME/.zshrc" ;; 
      fish) 
        echo "Please add '$BIN_DIR' to your fish_user_paths manually."
        ;;
    esac
    
    if [ -n "$RC_FILE" ]; then
        echo -e "Adding to PATH in ${YELLOW}$RC_FILE${RESET}..."
        echo "" >> "$RC_FILE"
        echo "# Cleoselene Game Engine" >> "$RC_FILE"
        echo "export PATH=\"$PATH:$BIN_DIR\"" >> "$RC_FILE"
        echo -e "${GREEN}✅ Added to PATH.${RESET} Restart your terminal or run: source $RC_FILE"
    else
        echo -e "${YELLOW}Could not detect shell profile.${RESET} Add this to your PATH manually:"
        echo "  $BIN_DIR"
    fi
    ;;
esac

echo -e "${GREEN}✅ Installation complete!${RESET}"
echo -e "Run '${BOLD}cleoselene --help${RESET}' to get started."
