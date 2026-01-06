#!/bin/bash
set -e

DOMAIN="cleoselene.com"
TARGET_EMAIL="$1"

if [ -z "$TARGET_EMAIL" ]; then
    echo "Usage: ./setup_mail.sh <your_personal_email>"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

echo "✉️ Installing Postfix for $DOMAIN -> $TARGET_EMAIL..."

# Pre-seed answers for non-interactive install to avoid UI popups
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $DOMAIN" | debconf-set-selections

# Update and install
apt-get update
apt-get install -y postfix mailutils

echo "⚙️ Configuring Postfix..."

# Backup config
cp /etc/postfix/main.cf /etc/postfix/main.cf.bak 2>/dev/null || true

# Configure basic settings
postconf -e "myhostname = mail.$DOMAIN"
postconf -e "mydomain = $DOMAIN"
postconf -e "myorigin = /etc/mailname"
# Accept mail for these domains
postconf -e "mydestination = $DOMAIN, mail.$DOMAIN, localhost.$DOMAIN, localhost"
# Listen on all interfaces
postconf -e "inet_interfaces = all"
# Define path for virtual aliases (forwarding rules)
postconf -e "virtual_alias_maps = hash:/etc/postfix/virtual"

# Setup Virtual Aliases (Forwarding)
# 1. Specific contact email
# 2. Catch-all (optional, useful for solo devs)
echo "contact@$DOMAIN    $TARGET_EMAIL" > /etc/postfix/virtual
echo "@$DOMAIN           $TARGET_EMAIL" >> /etc/postfix/virtual

# Compile the map
postmap /etc/postfix/virtual

# Restart Service
systemctl restart postfix

echo "✅ Mail Server Configured!"
echo "Test by sending an email to contact@$DOMAIN"
echo ""
echo "⚠️ IMPORTANT:"
echo "1. Ensure DNS MX record points to 'mail.$DOMAIN' (IP: $(curl -s ifconfig.me))"
echo "2. Ensure Port 25 (Outbound) is NOT blocked by your cloud provider."
echo "   (DigitalOcean often blocks this for new accounts. If blocked, forwarding will fail)."
