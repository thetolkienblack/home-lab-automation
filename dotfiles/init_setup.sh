#!/bin/bash

# Debian 12 Initial Server Setup Script
# Run as root or with sudo privileges

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

log "Starting Debian 12 initial server setup..."

# 1. Update system packages
log "Updating package lists and upgrading system..."
apt update
apt upgrade -y

# 2. Install essential packages
log "Installing essential packages..."
apt install -y \
    curl \
    wget \
    vim \
    git \
    htop \
    tree \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    fail2ban \
    ufw \
    logrotate \
    rsyslog \
    ntp \
    sudo

# 3. Configure timezone
log "Configuring timezone..."
timedatectl set-timezone UTC
log "Timezone set to UTC. Current time: $(date)"

# 4. Create a non-root user (if not exists)
read -p "Enter username for new admin user (leave empty to skip): " NEW_USER
if [[ -n "$NEW_USER" ]]; then
    if ! id "$NEW_USER" &>/dev/null; then
        log "Creating user: $NEW_USER"
        adduser --gecos "" "$NEW_USER"
        usermod -aG sudo "$NEW_USER"

        # Setup SSH directory for new user
        sudo -u "$NEW_USER" mkdir -p /home/"$NEW_USER"/.ssh
        sudo -u "$NEW_USER" chmod 700 /home/"$NEW_USER"/.ssh
        sudo -u "$NEW_USER" touch /home/"$NEW_USER"/.ssh/authorized_keys
        sudo -u "$NEW_USER" chmod 600 /home/"$NEW_USER"/.ssh/authorized_keys

        log "User $NEW_USER created and added to sudo group"
        warn "Remember to add SSH public keys to /home/$NEW_USER/.ssh/authorized_keys"
    else
        log "User $NEW_USER already exists"
    fi
fi

# 5. Configure SSH security
log "Configuring SSH security..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# SSH hardening configuration
cat > /etc/ssh/sshd_config.d/99-custom-security.conf << 'EOF'
# Custom SSH security configuration
Port 22
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
Protocol 2
IgnoreRhosts yes
HostbasedAuthentication no
PermitEmptyPasswords no
EOF

# 6. Configure UFW firewall
log "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# 7. Configure fail2ban
log "Configuring fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

cat > /etc/fail2ban/jail.d/custom.conf << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

# 8. Configure automatic security updates
log "Configuring automatic security updates..."
apt install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# 9. Configure kernel parameters for security
log "Configuring kernel security parameters..."
cat > /etc/sysctl.d/99-security.conf << 'EOF'
# IP Spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 1

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# TCP SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 3
EOF

sysctl -p /etc/sysctl.d/99-security.conf

# 10. Set up log rotation
log "Configuring log rotation..."
cat > /etc/logrotate.d/custom << 'EOF'
/var/log/auth.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}
EOF

# 11. Configure system limits
log "Configuring system limits..."
cat > /etc/security/limits.d/99-custom.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# 12. Enable and start services
log "Enabling and starting services..."
systemctl enable ssh
systemctl enable fail2ban
systemctl enable ufw
systemctl enable unattended-upgrades

systemctl restart ssh
systemctl restart fail2ban
systemctl restart rsyslog

# 13. Clean up
log "Cleaning up..."
apt autoremove -y
apt autoclean

# 14. Create useful aliases
log "Creating useful aliases..."
cat >> /root/.bashrc << 'EOF'

# Custom aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias netstat='netstat -tuln'
alias ports='netstat -tulanp'
EOF

# Add aliases for the new user if created
if [[ -n "$NEW_USER" ]]; then
    cat >> /home/"$NEW_USER"/.bashrc << 'EOF'

# Custom aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias netstat='netstat -tuln'
alias ports='netstat -tulanp'
EOF
    chown "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.bashrc
fi

# 15. Display system information
log "Initial setup completed successfully!"

echo
echo "=== SYSTEM INFORMATION ==="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime)"
echo

echo "=== SECURITY STATUS ==="
echo "SSH Configuration: Hardened (Port 22, No root login, Key-based auth only)"
echo "Firewall (UFW): $(ufw status | head -1)"
echo "Fail2ban: $(systemctl is-active fail2ban)"
echo "Automatic Updates: Enabled"
echo

echo "=== NEXT STEPS ==="
echo "1. Add SSH public keys to authorized_keys files"
if [[ -n "$NEW_USER" ]]; then
    echo "2. Test SSH login with user: $NEW_USER"
fi
echo "3. Consider changing SSH port (edit /etc/ssh/sshd_config.d/99-custom-security.conf)"
echo "4. Install additional software as needed"
echo "5. Configure monitoring (optional)"
echo

warn "IMPORTANT: Test SSH access before logging out!"
warn "Reboot recommended to ensure all changes take effect."

log "Setup script completed. Logs available in /var/log/syslog"