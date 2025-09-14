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
starlink:~/scripts# ls
docker_setup.sh  firewall_setup.sh  init_setup.sh  k3s  k3s_setup.sh  mysql_complete_migration_script.sh  pg_complete_migration_script.sh
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts# cat firewall_setup.sh
#!/bin/bash

# Fail2ban IP Whitelist Configuration Script
# This script configures fail2ban to ignore specific IP addresses

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Whitelisted IPs
WHITELIST_IPS='91.216.57.29 85.14.55.128 100.73.121.62 100.110.201.70 100.67.7.113 100.84.189.46 100.101.107.37 100.103.91.2 100.117.119.74 100.95.29.89 100.68.28.91'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check if fail2ban is installed
if ! command -v fail2ban-client &> /dev/null; then
    echo "fail2ban is not installed. Installing..."
    apt update && apt install -y fail2ban
fi

log "Configuring fail2ban IP whitelist..."

# 1. Backup existing configuration
log "Backing up existing fail2ban configuration..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
if [ -f /etc/fail2ban/jail.local ]; then
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d_%H%M%S)
fi

# 2. Create or update jail.local with whitelist
log "Creating fail2ban local configuration with IP whitelist..."

cat > /etc/fail2ban/jail.local << EOF
# Fail2ban local configuration
# This file overrides settings in jail.conf

[DEFAULT]
# IP addresses/ranges to ignore (whitelist)
# Add your trusted IP addresses here
ignoreip = 127.0.0.1/8 ::1 ${WHITELIST_IPS}

# Ban settings
bantime = 3600
findtime = 600
maxretry = 5

# Email notifications (optional)
# destemail = admin@yourdomain.com
# sender = fail2ban@yourdomain.com
# mta = sendmail

# Backend to use
backend = systemd

[sshd]
# SSH jail configuration
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600

# Additional SSH-related jails
[ssh-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 2
bantime = 3600

[ssh-badprotocol]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 1
bantime = 3600
EOF

log "Created jail.local with current IP ($WHITELIST_IPS) in whitelist"

# 3. Create a script to easily add IPs to whitelist
log "Creating IP whitelist management script..."

cat > /usr/local/bin/fail2ban-whitelist << 'EOF'
#!/bin/bash

# Fail2ban Whitelist Management Script

show_help() {
    echo "Usage: fail2ban-whitelist [OPTION] [IP_ADDRESS]"
    echo ""
    echo "Options:"
    echo "  add IP        Add IP to whitelist"
    echo "  remove IP     Remove IP from whitelist"
    echo "  list          Show current whitelist"
    echo "  help          Show this help"
    echo ""
    echo "Examples:"
    echo "  fail2ban-whitelist add 192.168.1.100"
    echo "  fail2ban-whitelist add 203.0.113.0/24"
    echo "  fail2ban-whitelist remove 192.168.1.100"
    echo "  fail2ban-whitelist list"
}

add_ip() {
    local ip="$1"
    if [[ -z "$ip" ]]; then
        echo "Error: IP address required"
        exit 1
    fi

    # Backup current config
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d_%H%M%S)

    # Add IP to ignoreip line
    if grep -q "ignoreip" /etc/fail2ban/jail.local; then
        sed -i "/^ignoreip/s/$/ $ip/" /etc/fail2ban/jail.local
    else
        sed -i '/^\[DEFAULT\]/a ignoreip = 127.0.0.1/8 ::1 '$ip /etc/fail2ban/jail.local
    fi

    echo "Added $ip to whitelist"
    systemctl restart fail2ban
    echo "fail2ban restarted"
}

remove_ip() {
    local ip="$1"
    if [[ -z "$ip" ]]; then
        echo "Error: IP address required"
        exit 1
    fi

    # Backup current config
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d_%H%M%S)

    # Remove IP from ignoreip line
    sed -i "s/ $ip//g" /etc/fail2ban/jail.local
    sed -i "s/$ip //g" /etc/fail2ban/jail.local

    echo "Removed $ip from whitelist"
    systemctl restart fail2ban
    echo "fail2ban restarted"
}

list_whitelist() {
    echo "Current whitelist:"
    grep "ignoreip" /etc/fail2ban/jail.local 2>/dev/null || echo "No whitelist found"
}

case "${1:-help}" in
    add)
        add_ip "$2"
        ;;
    remove)
        remove_ip "$2"
        ;;
    list)
        list_whitelist
        ;;
    help|*)
        show_help
        ;;
esac
EOF

chmod +x /usr/local/bin/fail2ban-whitelist

# 4. Add common trusted networks to whitelist
log "Adding common trusted networks to whitelist..."

# Add RFC1918 private networks (optional)
read -p "Do you want to whitelist private networks (192.168.x.x, 10.x.x.x, 172.16-31.x.x)? (y/N): " ADD_PRIVATE
if [[ $ADD_PRIVATE =~ ^[Yy]$ ]]; then
    sed -i '/^ignoreip/s/$/ 192.168.0.0\/16 10.0.0.0\/8 172.16.0.0\/12/' /etc/fail2ban/jail.local
    log "Added private networks to whitelist"
fi

# 5. Configure TCP Wrappers (hosts.allow/hosts.deny)
log "Configuring TCP Wrappers with whitelist rules..."

# Backup existing files
if [ -f /etc/hosts.allow ]; then
    cp /etc/hosts.allow /etc/hosts.allow.backup.$(date +%Y%m%d_%H%M%S)
fi
if [ -f /etc/hosts.deny ]; then
    cp /etc/hosts.deny /etc/hosts.deny.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create hosts.allow with whitelisted IPs
cat > /etc/hosts.allow << EOF
# /etc/hosts.allow - TCP Wrappers access control
# Allow whitelisted IPs full access to all services

# SSH access for whitelisted IPs
EOF

for ip in $WHITELIST_IPS; do
    echo "sshd: $ip" >> /etc/hosts.allow
    echo "ALL: $ip" >> /etc/hosts.allow
    log "TCP Wrappers: Added $ip to hosts.allow"
done

# Add localhost access
cat >> /etc/hosts.allow << EOF

# Allow localhost
ALL: 127.0.0.1
ALL: ::1
ALL: localhost

# Allow local network (if needed)
# ALL: 192.168.0.0/255.255.0.0
# ALL: 10.0.0.0/255.0.0.0
EOF

# Create restrictive hosts.deny (only block SSH, not web services)
cat > /etc/hosts.deny << EOF
# /etc/hosts.deny - TCP Wrappers access control
# Only deny SSH connections from non-whitelisted IPs
# Web services (HTTP/HTTPS) remain open to all

# Deny SSH connections from non-whitelisted IPs
sshd: ALL: spawn /bin/echo "$(date) TCP Wrappers denied SSH from %c" >> /var/log/tcp_wrappers.log

# Note: HTTP/HTTPS services are not blocked here to allow public web access
# UFW firewall handles the broader network filtering
EOF

log "TCP Wrappers configured with whitelist rules"

# 6. Configure UFW firewall with whitelist rules
log "Configuring UFW firewall with whitelist rules..."

# Reset UFW to clean state
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow incoming from whitelisted IPs to any port
for ip in $WHITELIST_IPS; do
    ufw allow from $ip
    log "UFW: Allowed all traffic from $ip"
done

# Allow HTTP and HTTPS from anywhere
ufw allow 80/tcp
ufw allow 443/tcp
log "UFW: Allowed HTTP (80) and HTTPS (443) from anywhere"

# Allow SSH from whitelisted IPs only (more restrictive than fail2ban)
ufw allow from any to any port 22 proto tcp
log "UFW: Allowed SSH (22) from anywhere (fail2ban will handle restrictions)"

# Enable UFW
ufw --force enable
log "UFW firewall configured and enabled"

# Show UFW status
echo
log "=== UFW FIREWALL STATUS ==="
ufw status verbose

# 7. Restart fail2ban with new configuration
log "Restarting fail2ban with new configuration..."
systemctl restart fail2ban
sleep 2

# 8. Verify configuration
log "Verifying fail2ban configuration..."
fail2ban-client status

# 9. Show current whitelist
echo
log "=== CURRENT WHITELIST ==="
grep "ignoreip" /etc/fail2ban/jail.local

echo
log "=== TCP WRAPPERS CONFIGURATION ==="
echo "hosts.allow:"
cat /etc/hosts.allow
echo
echo "hosts.deny:"
cat /etc/hosts.deny

echo
log "=== UFW FIREWALL RULES ==="
ufw status numbered

echo
log "=== WHITELIST MANAGEMENT ==="
echo "To manage your whitelist in the future, use:"
echo
echo "  fail2ban-whitelist add IP_ADDRESS     # Add IP to whitelist"
echo "  fail2ban-whitelist remove IP_ADDRESS  # Remove IP from whitelist"
echo "  fail2ban-whitelist list               # Show current whitelist"
echo
echo "Examples:"
echo "  fail2ban-whitelist add $(curl -s ifconfig.me)"
echo "  fail2ban-whitelist add 203.0.113.0/24"
echo "  fail2ban-whitelist list"

echo
log "=== ADDITIONAL SECURITY TIPS ==="
echo "1. Use SSH key authentication instead of passwords"
echo "2. Change SSH port from default 22"
echo "3. Use VPN for remote access when possible"
echo "4. Regularly review fail2ban logs: journalctl -u fail2ban"
echo "5. Monitor SSH attempts: tail -f /var/log/auth.log"

echo
log "=== FAIL2BAN, UFW, AND TCP WRAPPERS STATUS ==="
echo "Fail2ban status:"
systemctl status fail2ban --no-pager -l
echo
echo "UFW status:"
ufw status verbose
echo
echo "TCP Wrappers configuration:"
echo "- hosts.allow: $(wc -l < /etc/hosts.allow) lines"
echo "- hosts.deny: $(wc -l < /etc/hosts.deny) lines"

log "Fail2ban whitelist, UFW firewall, and TCP Wrappers configuration completed!"

# 10. Create monitoring alias
echo "alias f2b-status='fail2ban-client status'" >> /root/.bashrc
echo "alias f2b-ssh='fail2ban-client status sshd'" >> /root/.bashrc
echo "alias f2b-logs='journalctl -u fail2ban -f'" >> /root/.bashrc
echo "alias fw-status='ufw status verbose'" >> /root/.bashrc
echo "alias fw-show='ufw status numbered'" >> /root/.bashrc
echo "alias tcp-allow='cat /etc/hosts.allow'" >> /root/.bashrc
echo "alias tcp-deny='cat /etc/hosts.deny'" >> /root/.bashrc
echo "alias tcp-logs='tail -f /var/log/tcp_wrappers.log'" >> /root/.bashrc

log "Added useful fail2ban, UFW, and TCP Wrappers aliases to .bashrc"
echo "  f2b-status  - Show fail2ban status"
echo "  f2b-ssh     - Show SSH jail status"
echo "  f2b-logs    - Follow fail2ban logs"
echo "  fw-status   - Show UFW firewall status"
echo "  fw-show     - Show UFW rules numbered"
echo "  tcp-allow   - Show hosts.allow file"
echo "  tcp-deny    - Show hosts.deny file"
echo "  tcp-logs    - Follow TCP Wrappers logs"