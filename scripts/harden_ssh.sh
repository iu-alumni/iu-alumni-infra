#!/bin/bash

set -e

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"

echo "Hardening SSH configuration..."

# Enable public key authentication
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"

# Disable password authentication
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"

# Disable challenge-response authentication
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"

# Enforce public key as the only authentication method
if ! grep -q "^AuthenticationMethods" "$SSHD_CONFIG"; then
    echo "AuthenticationMethods publickey" >> "$SSHD_CONFIG"
fi

# Restart SSH service
systemctl restart ssh || systemctl restart sshd

echo "SSH hardened: password auth disabled, public key only."
echo "Make sure you have a working SSH key before disconnecting!"
