#!/bin/bash
# SSH Agent Setup Script for Ansible
# This script helps manage SSH keys for Ansible automation

set -e

echo "=== SSH Agent Setup for Ansible ==="
echo ""

# Check if ssh-agent is running
if [ -z "$SSH_AUTH_SOCK" ]; then
    echo "Starting ssh-agent..."
    eval "$(ssh-agent -s)"
else
    echo "✓ ssh-agent is already running"
fi

# Default key location
DEFAULT_KEY="$HOME/.ssh/id_graylock"

# Allow custom key path as argument
SSH_KEY="${1:-$DEFAULT_KEY}"

if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found at $SSH_KEY"
    echo "Usage: $0 [path_to_ssh_key]"
    exit 1
fi

# Add key to agent
echo "Adding SSH key to agent: $SSH_KEY"
ssh-add "$SSH_KEY"

# List loaded keys
echo ""
echo "Currently loaded SSH keys:"
ssh-add -l

echo ""
echo "✓ SSH agent configured successfully!"
echo ""
echo "You can now run Ansible commands without specifying a key file."
echo "Example: ansible-playbook playbooks/system/ntp_timezone_config.yml"
echo ""
echo "Note: This agent session will persist until you log out or restart."
echo "To make it permanent, add the following to your ~/.bashrc or ~/.zshrc:"
echo ""
echo "  # Start SSH agent automatically"
echo "  if [ -z \"\$SSH_AUTH_SOCK\" ]; then"
echo "    eval \"\$(ssh-agent -s)\" > /dev/null"
echo "    ssh-add ~/.ssh/id_graylock 2>/dev/null"
echo "  fi"
