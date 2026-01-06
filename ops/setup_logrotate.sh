#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

echo "🔧 Configuring Logrotate for Cleoselene..."

CONFIG_FILE="/etc/logrotate.d/cleoselene"
LOG_PATH="/opt/game-server/server.log"

# Create config
cat > $CONFIG_FILE <<EOF
$LOG_PATH {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    copytruncate
    su root root
}
EOF

# Ensure permissions
chmod 644 $CONFIG_FILE
chown root:root $CONFIG_FILE

echo "✅ Logrotate configured at $CONFIG_FILE"
echo "Logs will be rotated daily and kept for 14 days."
