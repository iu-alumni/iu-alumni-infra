#!/bin/bash

set -e

USERNAME="$1"
PUBKEY="$2"
GRANT_SUDO="$3"

if [ -z "$USERNAME" ] || [ -z "$PUBKEY" ]; then
    echo "Usage: $0 <username> \"<ssh_public_key>\" [sudo]"
    exit 1
fi

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Create user if not exists
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists"
else
    adduser --gecos "" --disabled-password "$USERNAME"
    echo "$USERNAME:$USERNAME" | chpasswd
    echo "User $USERNAME created (password set to username)"
fi

# Grant sudo if requested
if [ "$GRANT_SUDO" == "sudo" ]; then
    usermod -aG sudo "$USERNAME"
    echo "User $USERNAME added to sudo group"
fi

# Ensure passwordless sudo is configured
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
if [ ! -f "$SUDOERS_FILE" ] || ! grep -q "NOPASSWD" "$SUDOERS_FILE"; then
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    echo "Passwordless sudo configured for $USERNAME"
else
    echo "Passwordless sudo already configured for $USERNAME"
fi

# Setup SSH directory
USER_HOME=$(eval echo "~$USERNAME")
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
echo "$PUBKEY" > "$AUTHORIZED_KEYS"

chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

echo "SSH key installed for $USERNAME"

echo "Done. User $USERNAME is ready."
echo "Note: Run the SSH hardening script separately to configure sshd."
