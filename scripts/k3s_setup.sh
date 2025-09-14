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
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts#
starlink:~/scripts# ls
docker_setup.sh  firewall_setup.sh  init_setup.sh  k3s  k3s_setup.sh  mysql_complete_migration_script.sh  pg_complete_migration_script.sh
starlink:~/scripts# cat k3s_setup.sh
#!/bin/bash

# K3s + Helmsman Installation and Setup Script for Debian 12
# Production-ready configuration with best practices

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Check if running on Debian 12
if ! grep -q "bookworm" /etc/os-release; then
    warn "This script is designed for Debian 12 (bookworm). Continuing anyway..."
fi

log "Starting K3s + Helmsman installation on Debian 12..."

# ============================================================================
# SECTION 1: SYSTEM PREPARATION
# ============================================================================
info "=== PREPARING SYSTEM ==="

# 1. Update system packages
log "Updating system packages..."
apt update && apt upgrade -y

# 2. Install prerequisite packages
log "Installing prerequisite packages..."
apt install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    vim \
    git \
    htop \
    tree \
    unzip \
    jq \
    yq

# 3. Configure system for K3s
log "Configuring system for K3s..."

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf

# Configure modules
cat > /etc/modules-load.d/k3s.conf << EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure kernel parameters
cat > /etc/sysctl.d/99-k3s.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# ============================================================================
# SECTION 2: K3S INSTALLATION
# ============================================================================
info "=== INSTALLING K3S ==="

# 4. Install K3s with production configuration
log "Installing K3s with production settings..."

# Production-optimized K3s installation
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --disable servicelb \
    --cluster-init \
    --etcd-expose-metrics" sh -

# 5. Configure kubectl access
log "Configuring kubectl access..."
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config

# Configure for non-root user if specified
read -p "Enter username for kubectl access (leave empty to skip): " K3S_USER
if [[ -n "$K3S_USER" ]]; then
    if id "$K3S_USER" &>/dev/null; then
        sudo -u "$K3S_USER" mkdir -p /home/"$K3S_USER"/.kube
        cp /etc/rancher/k3s/k3s.yaml /home/"$K3S_USER"/.kube/config
        chown "$K3S_USER":"$K3S_USER" /home/"$K3S_USER"/.kube/config
        chmod 600 /home/"$K3S_USER"/.kube/config
        log "Configured kubectl for user $K3S_USER"
    fi
fi

# 6. Install kubectl (latest stable)
log "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# 7. Install Helm
log "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 8. Wait for K3s to be ready
log "Waiting for K3s to be ready..."
sleep 30

# Check if K3s is running
for i in {1..30}; do
    if kubectl get nodes &>/dev/null; then
        log "K3s is ready!"
        break
    fi
    echo "Waiting for K3s... ($i/30)"
    sleep 10
done

# ============================================================================
# SECTION 3: ESSENTIAL K8S COMPONENTS
# ============================================================================
info "=== INSTALLING ESSENTIAL KUBERNETES COMPONENTS ==="

# 9. Install NGINX Ingress Controller
log "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# 10. Install Cert-Manager for SSL certificates
log "Installing Cert-Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml

# 11. Install Longhorn for persistent storage
log "Installing Longhorn storage..."
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/deploy/longhorn.yaml

# Wait for core components to be ready
log "Waiting for core components to be ready..."
sleep 60

# ============================================================================
# SECTION 4: HELMSMAN INSTALLATION
# ============================================================================
info "=== INSTALLING HELMSMAN ==="

# 12. Install Helmsman
log "Installing Helmsman..."
HELMSMAN_VERSION=$(curl -s https://api.github.com/repos/Praqma/helmsman/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/Praqma/helmsman/releases/download/${HELMSMAN_VERSION}/helmsman_${HELMSMAN_VERSION#v}_linux_amd64.tar.gz" | tar xz
chmod +x helmsman
mv helmsman /usr/local/bin/

# Verify Helmsman installation
helmsman version

# 13. Create Helmsman configuration directory structure
log "Creating Helmsman configuration structure..."
mkdir -p /etc/helmsman/{values,secrets,charts}
mkdir -p /var/lib/helmsman/{state,backups}

# 14. Create sample Helmsman configuration
log "Creating sample Helmsman configuration..."
cat > /etc/helmsman/cluster.toml << 'EOF'
# Helmsman Configuration for K3s Cluster
# Edit this file to match your deployment requirements

[metadata]
org = "example-org"
maintainer = "admin@example.com"
description = "K3s cluster managed by Helmsman"

[settings]
kubeContext = "default"
storageBackend = "configMap"
slackWebhook = ""
reverseDelete = false

# Namespace definitions
[namespaces]
  [namespaces.monitoring]
  protected = true
  labels = {
    name = "monitoring"
    tier = "system"
  }

  [namespaces.ingress-nginx]
  protected = true
  labels = {
    name = "ingress-nginx"
    tier = "system"
  }

  [namespaces.cert-manager]
  protected = true
  labels = {
    name = "cert-manager"
    tier = "system"
  }

# Helm repository definitions
[helmRepos]
  [helmRepos.prometheus-community]
  url = "https://prometheus-community.github.io/helm-charts"

  [helmRepos.grafana]
  url = "https://grafana.github.io/helm-charts"

  [helmRepos.jetstack]
  url = "https://charts.jetstack.io"

  [helmRepos.longhorn]
  url = "https://charts.longhorn.io"

# Application definitions
[apps]
  # Monitoring Stack
  [apps.prometheus]
  namespace = "monitoring"
  enabled = true
  chart = "prometheus-community/kube-prometheus-stack"
  version = "51.2.0"
  priority = -100
  valuesFile = "/etc/helmsman/values/prometheus.yaml"

  [apps.grafana-dashboard]
  namespace = "monitoring"
  enabled = false
  chart = "grafana/grafana"
  version = "6.59.4"
  priority = -90
  needs = ["prometheus"]
  valuesFile = "/etc/helmsman/values/grafana.yaml"
EOF

# 15. Create sample values files
log "Creating sample Helmsman values files..."

# Prometheus values
cat > /etc/helmsman/values/prometheus.yaml << 'EOF'
# Prometheus Stack Configuration
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

grafana:
  adminPassword: admin123
  service:
    type: ClusterIP
  persistence:
    enabled: true
    storageClassName: longhorn
    size: 10Gi

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
EOF

# Grafana values (if using separate Grafana)
cat > /etc/helmsman/values/grafana.yaml << 'EOF'
# Standalone Grafana Configuration
adminPassword: admin123

service:
  type: NodePort
  nodePort: 30000

persistence:
  enabled: true
  storageClassName: longhorn
  size: 10Gi

ingress:
  enabled: false
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: grafana.yourdomain.com
      paths:
        - path: /
  tls:
    - secretName: grafana-tls
      hosts:
        - grafana.yourdomain.com
EOF

# ============================================================================
# SECTION 5: CONFIGURATION AND ALIASES
# ============================================================================
info "=== CONFIGURING SYSTEM ALIASES AND SCRIPTS ==="

# 16. Create useful aliases
log "Creating useful aliases..."
cat >> /root/.bashrc << 'EOF'

# K3s/Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kgi='kubectl get ingress'
alias kgns='kubectl get namespaces'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias klog='kubectl logs'
alias klogf='kubectl logs -f'
alias kexec='kubectl exec -it'
alias kns='kubectl config set-context --current --namespace'
alias kctx='kubectl config current-context'

# K3s specific
alias k3s-status='systemctl status k3s'
alias k3s-logs='journalctl -u k3s -f'
alias k3s-restart='systemctl restart k3s'

# Helmsman aliases
alias hm='helmsman'
alias hm-plan='helmsman -f /etc/helmsman/cluster.toml --dry-run'
alias hm-apply='helmsman -f /etc/helmsman/cluster.toml'
alias hm-diff='helmsman -f /etc/helmsman/cluster.toml --show-diff'
alias hm-debug='helmsman -f /etc/helmsman/cluster.toml --debug'

# Helm aliases
alias h='helm'
alias hls='helm list'
alias hlsa='helm list --all-namespaces'
alias hh='helm history'
alias hr='helm rollback'
EOF

# Add aliases for the K3s user if specified
if [[ -n "$K3S_USER" ]]; then
    cat >> /home/"$K3S_USER"/.bashrc << 'EOF'

# K3s/Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kgi='kubectl get ingress'
alias kgns='kubectl get namespaces'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias klog='kubectl logs'
alias klogf='kubectl logs -f'
alias kexec='kubectl exec -it'
alias kns='kubectl config set-context --current --namespace'
alias kctx='kubectl config current-context'

# Helmsman aliases
alias hm='helmsman'
alias hm-plan='helmsman -f /etc/helmsman/cluster.toml --dry-run'
alias hm-apply='helmsman -f /etc/helmsman/cluster.toml'
alias hm-diff='helmsman -f /etc/helmsman/cluster.toml --show-diff'

# Helm aliases
alias h='helm'
alias hls='helm list'
alias hlsa='helm list --all-namespaces'
EOF
    chown "$K3S_USER":"$K3S_USER" /home/"$K3S_USER"/.bashrc
fi

# ============================================================================
# SECTION 6: MAINTENANCE SCRIPTS
# ============================================================================
info "=== CREATING MAINTENANCE SCRIPTS ==="

# 17. Create K3s backup script
log "Creating K3s backup script..."
cat > /usr/local/bin/k3s-backup << 'EOF'
#!/bin/bash
# K3s Backup Script

BACKUP_DIR="/var/lib/helmsman/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Creating K3s backup: $DATE"

mkdir -p "$BACKUP_DIR"

# Backup etcd data
cp -r /var/lib/rancher/k3s/server/db "$BACKUP_DIR/db_$DATE"

# Backup config
cp /etc/rancher/k3s/k3s.yaml "$BACKUP_DIR/config_$DATE.yaml"

# Backup Helmsman config
cp -r /etc/helmsman "$BACKUP_DIR/helmsman_$DATE"

# Backup manifests
if [ -d /var/lib/rancher/k3s/server/manifests ]; then
    cp -r /var/lib/rancher/k3s/server/manifests "$BACKUP_DIR/manifests_$DATE"
fi

echo "Backup completed: $BACKUP_DIR"
ls -la "$BACKUP_DIR"
EOF

chmod +x /usr/local/bin/k3s-backup

# 18. Create cluster status script
log "Creating cluster status script..."
cat > /usr/local/bin/k3s-status << 'EOF'
#!/bin/bash
# K3s Cluster Status Script

echo "=== K3s Service Status ==="
systemctl status k3s --no-pager -l

echo -e "\n=== Cluster Info ==="
kubectl cluster-info

echo -e "\n=== Node Status ==="
kubectl get nodes -o wide

echo -e "\n=== Pod Status (All Namespaces) ==="
kubectl get pods --all-namespaces

echo -e "\n=== Helm Releases ==="
helm list --all-namespaces

echo -e "\n=== Persistent Volumes ==="
kubectl get pv

echo -e "\n=== Services ==="
kubectl get services --all-namespaces

echo -e "\n=== Ingress ==="
kubectl get ingress --all-namespaces

echo -e "\n=== Resource Usage ==="
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
EOF

chmod +x /usr/local/bin/k3s-status

# 19. Create Helmsman deployment script
log "Creating Helmsman deployment script..."
cat > /usr/local/bin/helmsman-deploy << 'EOF'
#!/bin/bash
# Helmsman Deployment Script

CONFIG_FILE="/etc/helmsman/cluster.toml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Helmsman config file not found at $CONFIG_FILE"
    exit 1
fi

echo "=== Helmsman Deployment Plan ==="
helmsman -f "$CONFIG_FILE" --dry-run

echo -e "\n=== Confirming Deployment ==="
read -p "Do you want to proceed with deployment? (y/N): " confirm

if [[ $confirm =~ ^[Yy]$ ]]; then
    echo "=== Executing Helmsman Deployment ==="
    helmsman -f "$CONFIG_FILE"

    echo -e "\n=== Deployment Complete ==="
    kubectl get pods --all-namespaces
else
    echo "Deployment cancelled"
fi
EOF

chmod +x /usr/local/bin/helmsman-deploy

# ============================================================================
# SECTION 7: FIREWALL CONFIGURATION
# ============================================================================
info "=== CONFIGURING FIREWALL ==="

# 20. Configure UFW for K3s (if UFW is active)
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    log "Configuring UFW for K3s..."

    # K3s API server
    ufw allow 6443/tcp

    # Flannel VXLAN
    ufw allow 8472/udp

    # Kubelet metrics
    ufw allow 10250/tcp

    # NodePort range
    ufw allow 30000:32767/tcp

    log "UFW configured for K3s"
fi

# ============================================================================
# SECTION 8: AUTOMATIC BACKUPS
# ============================================================================
info "=== CONFIGURING AUTOMATIC BACKUPS ==="

# 21. Configure automatic backups
log "Configuring automatic backups..."
cat > /etc/cron.d/k3s-backup << 'EOF'
# K3s automatic backup - daily at 2 AM
0 2 * * * root /usr/local/bin/k3s-backup >> /var/log/k3s-backup.log 2>&1

# Cleanup old backups - keep 7 days
0 3 * * * root find /var/lib/helmsman/backups -type f -mtime +7 -delete
EOF

# ============================================================================
# SECTION 9: FINAL VERIFICATION
# ============================================================================
info "=== PERFORMING FINAL VERIFICATION ==="

# 22. Final verification
log "Performing final verification..."

# Wait for all components to be ready
sleep 60

if kubectl get nodes | grep -q "Ready"; then
    log "K3s cluster is ready!"
else
    error "K3s cluster is not ready. Check logs: journalctl -u k3s -f"
    exit 1
fi

# Test Helmsman
if helmsman version &>/dev/null; then
    log "Helmsman is installed and working!"
else
    error "Helmsman installation failed"
    exit 1
fi

echo
log "=== INSTALLATION SUMMARY ==="
echo "K3s version: $(k3s --version | head -1)"
echo "Kubectl version: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "Helm version: $(helm version --short)"
echo "Helmsman version: $(helmsman version)"
echo "Cluster status: $(kubectl get nodes --no-headers | awk '{print $2}')"

echo
log "=== INSTALLED COMPONENTS ==="
echo "✅ K3s server with embedded etcd"
echo "✅ NGINX Ingress Controller"
echo "✅ Cert-Manager (SSL certificates)"
echo "✅ Longhorn storage"
echo "✅ Helmsman orchestration"
echo "✅ Automated backup system"

echo
log "=== USEFUL COMMANDS ==="
echo "k3s-status           - Show cluster status"
echo "k3s-backup           - Manual backup"
echo "helmsman-deploy      - Deploy with Helmsman"
echo "hm-plan             - Show Helmsman deployment plan"
echo "hm-apply            - Apply Helmsman configuration"

echo
log "=== CONFIGURATION FILES ==="
echo "K3s kubeconfig: /etc/rancher/k3s/k3s.yaml"
echo "Helmsman config: /etc/helmsman/cluster.toml"
echo "Values files: /etc/helmsman/values/"
echo "Backups: /var/lib/helmsman/backups/"

echo
log "=== NEXT STEPS ==="
echo "1. Edit /etc/helmsman/cluster.toml to configure your applications"
echo "2. Add your application charts and values"
echo "3. Run 'helmsman-deploy' to deploy your applications"
echo "4. Set up ingress for external access"
echo "5. Configure monitoring and alerting"

if [[ -n "$K3S_USER" ]]; then
    echo
    warn "IMPORTANT: User $K3S_USER needs to log out and back in for aliases to take effect"
fi

echo
log "K3s + Helmsman installation completed successfully!"
log "Your Kubernetes cluster is ready for production workloads!"