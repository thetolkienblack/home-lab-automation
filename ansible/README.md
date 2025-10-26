# Ansible Infrastructure Project

Comprehensive Ansible automation framework for managing home lab and production infrastructure with a security-first approach. Supports multi-OS environments (Debian/Ubuntu, RHEL/CentOS) with playbooks for system configuration, security hardening, networking, and virtualization.

## Table of Contents

- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Available Roles](#available-roles)
- [Playbook Guides](#playbook-guides)
  - [System Configuration](#system-configuration-playbooks)
  - [Security](#security-playbooks)
  - [Networking](#networking-playbooks)
  - [Maintenance](#maintenance-playbooks)
  - [Virtualization](#virtualization-playbooks)
- [Configuration Guide](#configuration-guide)
- [Security Features](#security-features)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Install Dependencies
```bash
ansible-galaxy install -r requirements.yml
```

### 2. Configure Ansible Vault
```bash
# Create vault password file
echo "your-vault-password" > ~/.ansible/.ansible_vault_pass
chmod 600 ~/.ansible/.ansible_vault_pass

# Edit vault variables
ansible-vault edit group_vars/all/vault.yml
```

### 3. Update Inventory
Edit `inventories/production.yml` to match your infrastructure:
```yaml
all:
  hosts:
    server01:
      ansible_host: 192.168.1.10
    server02:
      ansible_host: 192.168.1.11
  children:
    proxmox_nodes:
      hosts:
        pve01:
          ansible_host: 192.168.1.100
```

### 4. Test Connectivity
```bash
ansible all -m ping
```

### 5. Deploy
```bash
# Run individual playbooks
ansible-playbook playbooks/system/ntp_timezone_config.yml
ansible-playbook playbooks/security/system_hardening.yml

# Or run a complete setup
ansible-playbook playbooks/system/ntp_timezone_config.yml && \
ansible-playbook playbooks/security/system_hardening.yml && \
ansible-playbook playbooks/networking/system_network_config.yml
```

---

## Project Structure

```
ansible/
├── inventories/          # Environment-specific host definitions
│   ├── production.yml    # Production inventory
│   └── development.yml   # Development/testing inventory
├── group_vars/           # Group-specific variables
│   ├── all/
│   │   ├── main.yml      # Global variables
│   │   └── vault.yml     # Encrypted secrets
│   ├── debian/           # Debian/Ubuntu variables
│   └── rhel/             # RHEL/CentOS variables
├── host_vars/            # Host-specific variables
├── playbooks/            # Organized playbooks
│   ├── system/           # System configuration
│   ├── security/         # Security hardening
│   ├── networking/       # Network configuration
│   ├── maintenance/      # Maintenance tasks
│   └── virtualization/   # Virtualization setup
├── templates/            # Jinja2 configuration templates
│   ├── system/           # System templates
│   ├── security/         # Security templates
│   └── virt/             # Virtualization templates
├── roles/                # Custom Ansible roles
│   ├── proxmox/          # Proxmox VE role
│   ├── common/           # Common tasks
│   ├── docker/           # Docker setup
│   ├── ntp/              # NTP configuration
│   ├── security_hardening/ # Security hardening
│   └── tailscale/        # Tailscale VPN
└── ansible.cfg           # Ansible configuration
```

---

## Available Roles

### Infrastructure Roles
- **common** - Common system configuration and utilities
- **docker** - Docker installation and management
- **ntp** - NTP time synchronization configuration
- **tailscale** - Tailscale VPN setup and configuration

### Security Roles
- **security_hardening** - Comprehensive system security hardening
  - SSH hardening
  - Firewall configuration (UFW/firewalld)
  - Fail2ban integration
  - TCP wrappers
  - Sysctl tuning
- **crowdsec** - CrowdSec IDS/IPS deployment
  - Central LAPI server or agent mode
  - Automatic service detection and collection installation
  - Docker and Kubernetes integration
  - Multiple bouncers (firewall, Traefik, blocklists)
  - AppSec (WAF-like) protection
  - Notification channels (Slack, Email, Webhook)
  - PostgreSQL/MySQL/SQLite database backends

### Virtualization Roles
- **proxmox** - Proxmox VE installation and configuration
  - Automated installation (Proxmox VE 7.x, 8.x, 9.x)
  - Cluster setup (create/join)
  - Storage backends (NFS, CIFS, iSCSI, LVM, ZFS, Ceph)
  - Network configuration (bridges, VLANs, bonds, SDN)
  - Security hardening
  - Backup configuration
  - SSL/TLS management
  - High Availability (HA) setup

### Monitoring Roles
- **checkmk** - CheckMK monitoring infrastructure
  - Server and agent deployment
  - Docker container monitoring (all metrics)
  - TLS encryption for agent-server communication
  - Self-signed certificate generation
  - Automatic service discovery
  - Firewall configuration
  - Web-based monitoring interface
  - Supports Debian/Ubuntu and RHEL/CentOS

### Maintenance Roles
- **maintenance** - System maintenance and updates

---

## Playbook Guides

### System Configuration Playbooks

#### 1. NTP and Timezone Configuration

**File:** `playbooks/system/ntp_timezone_config.yml`

**Purpose:** Configures NTP time synchronization and system timezone for both RHEL and Debian distributions.

**Target Hosts:** `all`

**Features:**
- Dual OS support (RHEL with Chrony, Debian with systemd-timesyncd)
- Automatic firewall rule configuration
- NTP security hardening
- Synchronization verification

**Required Variables:**

```yaml
# In group_vars/all/main.yml
timezone: "Europe/Sofia"                    # Your timezone

# NTP Configuration
ntp_enabled: true
ntp_security_hardening: true
ntp_servers:
  - pool.ntp.org
  - time.google.com
  - time.cloudflare.com
  - time.nist.gov
ntp_pool_servers:
  - "0.pool.ntp.org"
  - "1.pool.ntp.org"
  - "2.pool.ntp.org"
  - "3.pool.ntp.org"
ntp_pool_maxsources: 4
ntp_poll_interval_min: 32
ntp_poll_interval_max: 2048
ntp_connection_retry: 30
ntp_save_interval: 60
ntp_makestep_threshold: 1.0
ntp_makestep_limit: 3
ntp_log_level: "measurements statistics tracking"

# Firewall (if enabled)
firewall_enabled: true
```

**Usage:**

```bash
# Run on all hosts
ansible-playbook playbooks/system/ntp_timezone_config.yml

# Run on specific hosts
ansible-playbook playbooks/system/ntp_timezone_config.yml -l server01

# Check mode (dry run)
ansible-playbook playbooks/system/ntp_timezone_config.yml --check

# Override timezone
ansible-playbook playbooks/system/ntp_timezone_config.yml -e "timezone=America/New_York"
```

**Verification:**

```bash
# Check timezone
timedatectl

# Check NTP synchronization
timedatectl status | grep "System clock synchronized"

# Check NTP service (Debian)
systemctl status systemd-timesyncd

# Check NTP service (RHEL)
systemctl status chronyd

# Check time sources (RHEL)
chronyc sources
```

---

### Security Playbooks

#### 2. CrowdSec IDS/IPS Setup

**File:** `playbooks/security/crowdsec_setup.yml`

**Purpose:** Deploy CrowdSec Intrusion Detection/Prevention System with central LAPI architecture, agents, and bouncers.

**Target Hosts:** `crowdsec_lapi`, `crowdsec_agents`, `kubernetes_masters`

**Features:**
- Central LAPI server for decision management
- Automatic agent enrollment
- Service-based collection auto-detection
- Docker container log parsing
- Kubernetes Helm deployment
- Firewall and Traefik bouncers
- AppSec (WAF) protection
- Notification channels (Slack, Email, Webhook)

**Required Variables:**

```yaml
# In group_vars/all/main.yml or host_vars

# For LAPI Server
crowdsec_mode: lapi
crowdsec_db_type: postgresql  # or sqlite, mysql
crowdsec_db_password: "{{ vault_crowdsec_db_password }}"
crowdsec_configure_firewall: true
crowdsec_firewall_allowed_ips:
  - "192.168.1.0/24"  # Your agent network

# For Agents
crowdsec_mode: agent
crowdsec_lapi_server: "192.168.1.100"  # Your LAPI server
crowdsec_docker_enabled: true
crowdsec_appsec_enabled: true

# Bouncers
crowdsec_bouncers:
  - name: firewall
    enabled: true
  - name: blocklist
    enabled: true
  - name: traefik
    enabled: true  # If using Traefik

# Notifications
crowdsec_slack_enabled: true
crowdsec_slack_webhook_url: "{{ vault_slack_webhook }}"
crowdsec_email_enabled: true
crowdsec_email_to:
  - security@example.com
```

**Inventory Example:**

```yaml
# inventories/production.yml
all:
  children:
    crowdsec_lapi:
      hosts:
        crowdsec-server:
          ansible_host: 192.168.1.100
          crowdsec_mode: lapi
          crowdsec_db_type: postgresql

    crowdsec_agents:
      vars:
        crowdsec_mode: agent
        crowdsec_lapi_server: 192.168.1.100
        crowdsec_docker_enabled: true
      hosts:
        web01:
          ansible_host: 192.168.1.10
          crowdsec_additional_collections:
            - crowdsecurity/traefik
            - crowdsecurity/nginx
        db01:
          ansible_host: 192.168.1.20
          crowdsec_additional_collections:
            - crowdsecurity/postgresql
        docker01:
          ansible_host: 192.168.1.30
```

**Usage:**

```bash
# Deploy LAPI server first
ansible-playbook playbooks/security/crowdsec_setup.yml -l crowdsec_lapi

# Deploy agents (captures enrollment key from LAPI)
ansible-playbook playbooks/security/crowdsec_setup.yml -l crowdsec_agents

# Deploy on Kubernetes
ansible-playbook playbooks/security/crowdsec_setup.yml -l kubernetes_masters

# Deploy everything
ansible-playbook playbooks/security/crowdsec_setup.yml
```

**Verification:**

```bash
# On LAPI server
cscli machines list      # Show enrolled agents
cscli bouncers list      # Show active bouncers
cscli decisions list     # Show active decisions
cscli metrics            # Show LAPI metrics

# On Agents
cscli metrics            # Show agent metrics
cscli collections list   # Show installed collections
cscli hub list           # Show available hub items

# Check service status
systemctl status crowdsec
systemctl status crowdsec-firewall-bouncer

# View logs
journalctl -u crowdsec -f
tail -f /var/log/crowdsec/crowdsec.log
```

**Auto-Detection:**

The role automatically detects and configures collections based on:
- Running system services (nginx, postgresql, redis, etc.)
- Docker containers (traefik, mysql, apache, etc.)
- Installed applications

**Important Notes:**
- ⚠️ **Deploy LAPI server first** before agents
- ⚠️ Store sensitive data in Ansible Vault (`crowdsec_db_password`, webhook URLs, etc.)
- ⚠️ Configure firewall rules to allow agents to reach LAPI port (default: 8080)
- ⚠️ Test in development environment first
- 📝 The enrollment key is auto-generated on LAPI and displayed in playbook output
- 📝 For complete documentation, see [roles/crowdsec/README.md](roles/crowdsec/README.md)

---

#### 3. CheckMK Monitoring Setup

**File:** `playbooks/monitoring/checkmk_setup.yml`

**Purpose:** Deploy comprehensive CheckMK monitoring infrastructure with server and agent support, Docker container monitoring, and TLS encryption.

**Target Hosts:** `checkmk_servers`, `checkmk_agents`

**Features:**
- CheckMK Raw Edition server installation
- Automated agent deployment and registration
- Docker container monitoring with all metrics
- TLS encryption for agent-server communication
- Self-signed certificate generation
- Firewall configuration (UFW/firewalld)
- Automatic service discovery
- Web-based monitoring interface

**Required Variables:**

```yaml
# In group_vars/all/main.yml or inventory

# Server Configuration (for server hosts)
checkmk_mode: server
checkmk_site_id: "mainsite"
checkmk_site_name: "Production Monitoring"
checkmk_admin_password: "{{ vault_checkmk_admin_password }}"
checkmk_automation_secret: "{{ vault_checkmk_automation_secret }}"

# Agent Configuration (for agent hosts)
checkmk_mode: agent
checkmk_agent_server: "192.168.1.100"  # Your CheckMK server
checkmk_site_id: "mainsite"
checkmk_docker_monitoring: true
checkmk_tls_enabled: true

# Firewall
checkmk_configure_firewall: true
checkmk_firewall_allowed_ips:
  - "192.168.1.0/24"
```

**Inventory Example:**

```yaml
# inventories/production.yml
all:
  children:
    checkmk_servers:
      hosts:
        monitoring-server:
          ansible_host: 192.168.1.100
          checkmk_mode: server
          checkmk_site_id: mainsite

    checkmk_agents:
      vars:
        checkmk_mode: agent
        checkmk_agent_server: 192.168.1.100
        checkmk_docker_monitoring: true
      hosts:
        web01:
          ansible_host: 192.168.1.10
        db01:
          ansible_host: 192.168.1.20
        docker01:
          ansible_host: 192.168.1.30
```

**Usage:**

```bash
# Deploy server first
ansible-playbook playbooks/monitoring/checkmk_setup.yml -l checkmk_servers

# Then deploy agents
ansible-playbook playbooks/monitoring/checkmk_setup.yml -l checkmk_agents

# Or deploy everything
ansible-playbook playbooks/monitoring/checkmk_setup.yml

# Deploy to specific host
ansible-playbook playbooks/monitoring/checkmk_setup.yml -l web01
```

**Verification:**

```bash
# On server - check site status
sudo omd status <site_id>

# Access web interface
http://<server-ip>/<site_id>/

# On agent - check agent status
sudo systemctl status check-mk-agent.socket
sudo cmk-agent-ctl status

# Test agent output
sudo check_mk_agent | head -20
```

**Docker Monitoring:**

When `checkmk_docker_monitoring: true`, the role automatically:
- Installs mk_docker.py plugin
- Configures Docker API access
- Enables container metrics collection
- Creates piggyback hosts for containers

Monitored metrics include:
- Container status and health
- CPU and memory usage
- Network I/O and disk I/O
- Image and volume information
- Docker daemon statistics

**TLS Encryption:**

The role automatically generates self-signed certificates and configures:
- TLS encryption for agent-server communication
- Agent registration with certificate trust
- Secure API access
- HTTPS web interface (optional)

**Important Notes:**
- ⚠️ **Deploy server before agents**
- ⚠️ Store passwords in Ansible Vault
- ⚠️ Ensure firewall rules allow agent-server communication
- ⚠️ Server requires adequate resources (2GB RAM minimum)
- 📝 Default credentials displayed during server installation
- 📝 Agents automatically register and discover services
- 📝 For complete documentation, see [roles/checkmk/README.md](roles/checkmk/README.md)

---

#### 4. Comprehensive Security Hardening

**File:** `playbooks/security/system_hardening.yml`

**Purpose:** Complete server security hardening for RHEL/CentOS, Ubuntu, and Debian systems.

**Target Hosts:** `all`

**Features:**
- SSH security hardening
- Firewall configuration (UFW/firewalld)
- Fail2ban intrusion prevention
- Unattended security updates
- Kernel security parameters (sysctl)
- TCP wrappers
- Log rotation
- System limits configuration

**Required Variables:**

```yaml
# In group_vars/all/main.yml

# Whitelist IPs (REQUIRED for firewall)
whitelist_ips:
  - "192.168.1.0/24"      # Your local network
  - "10.0.0.0/8"          # VPN network
  - "specific.ip.address" # Specific IPs

# SSH Configuration
ssh_port: 22
ssh_permit_root_login: "no"
ssh_password_authentication: "no"
ssh_pubkey_authentication: "yes"
ssh_challenge_response_auth: "no"
ssh_x11_forwarding: "no"
ssh_max_auth_tries: 3
ssh_max_sessions: 2
ssh_client_alive_interval: 300
ssh_client_alive_count_max: 2

# Firewall Settings
firewall_enabled: true
firewall_reset_before_config: true
firewall_default_incoming: "deny"
firewall_default_outgoing: "allow"
firewall_allow_ssh_from_anywhere: true  # Or false to use whitelist_ips only
firewall_allow_http: true
firewall_allow_https: true

# Fail2ban Configuration
fail2ban_enabled: true
fail2ban_bantime: 3600
fail2ban_findtime: 600
fail2ban_maxretry: 5
fail2ban_ssh_maxretry: 3
fail2ban_backend: "systemd"

# Security Features
enable_unattended_upgrades: true
configure_sysctl_security: true
tcp_wrappers_enabled: true
configure_custom_logrotate: true
configure_system_limits: true

# System Limits
max_open_files: 65536
max_processes: 32768
```

**Usage:**

```bash
# Run security hardening
ansible-playbook playbooks/security/system_hardening.yml

# Check mode
ansible-playbook playbooks/security/system_hardening.yml --check --diff

# Run on specific hosts
ansible-playbook playbooks/security/system_hardening.yml -l webservers

# With extra verbosity
ansible-playbook playbooks/security/system_hardening.yml -vv
```

**Post-Hardening Verification:**

```bash
# Check SSH configuration
grep -E '^PermitRootLogin|^PasswordAuthentication' /etc/ssh/sshd_config

# Check firewall status (Debian/Ubuntu)
sudo ufw status verbose

# Check firewall status (RHEL/CentOS)
sudo firewall-cmd --list-all

# Check fail2ban status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Check sysctl settings
sysctl net.ipv4.tcp_syncookies
sysctl net.ipv4.conf.all.rp_filter

# Check TCP wrappers
cat /etc/hosts.allow
cat /etc/hosts.deny
```

**Important Notes:**
- ⚠️ **ALWAYS test in development first!**
- ⚠️ Ensure `whitelist_ips` includes your management IPs
- ⚠️ If SSH port changes, update your ansible.cfg or inventory
- ⚠️ Keep a backup access method (console, BMC) available

---

### Networking Playbooks

#### 3. System Network Configuration

**File:** `playbooks/networking/system_network_config.yml`

**Purpose:** Universal NetworkManager-based network configuration with support for DHCP and static IP, including automatic rollback on connectivity loss.

**Target Hosts:** `all`

**Features:**
- NetworkManager installation and configuration
- DHCP or static IP configuration
- IP conflict detection
- Automatic rollback on connectivity loss
- Network security hardening
- IPv6 management
- DNS configuration

**Required Variables:**

```yaml
# Network Mode
network_config_mode: "dhcp"  # or "static"

# Interface (auto-detected if not specified)
default_network_interface: "eth0"
network_interface: "{{ default_network_interface }}"

# For Static IP Configuration
network_static_ip: "192.168.1.100"
network_netmask: "24"  # or "255.255.255.0"
network_gateway: "192.168.1.1"
network_dns_servers:
  - "9.9.9.9"
  - "1.1.1.1"

# Network Settings
network_rollback_timeout: 300  # 5 minutes
network_mtu: 1500
network_wake_on_lan: true
network_ipv6_enabled: false
```

**Usage:**

**DHCP Configuration:**
```bash
ansible-playbook playbooks/networking/system_network_config.yml \
  -e "network_config_mode=dhcp"
```

**Static IP Configuration:**
```bash
ansible-playbook playbooks/networking/system_network_config.yml \
  -e "network_config_mode=static" \
  -e "network_static_ip=192.168.1.100" \
  -e "network_netmask=24" \
  -e "network_gateway=192.168.1.1" \
  -e "network_dns_servers=[9.9.9.9,1.1.1.1]"
```

**Per-Host Configuration (Recommended):**

In `host_vars/server01/main.yml`:
```yaml
network_config_mode: "static"
network_static_ip: "192.168.1.100"
network_netmask: "24"
network_gateway: "192.168.1.1"
network_dns_servers:
  - "9.9.9.9"
  - "1.1.1.1"
```

Then run:
```bash
ansible-playbook playbooks/networking/system_network_config.yml
```

**Verification:**

```bash
# Check IP configuration
ip addr show

# Check DNS
cat /etc/resolv.conf
nslookup google.com

# Check connectivity
ping -c 4 google.com
curl -I https://google.com

# Check NetworkManager status
nmcli connection show
nmcli device status
```

---

#### 4. Tailscale VPN Setup

**File:** `playbooks/networking/tailscale_setup.yml`

**Purpose:** Installs and configures Tailscale VPN on both Debian and RHEL systems.

**Target Hosts:** `all`

**Features:**
- OS-specific installation
- Authentication with auth tokens
- Subnet routing configuration
- Exit node support
- IP forwarding configuration
- SSH over Tailscale

**Required Variables:**

```yaml
# In group_vars/all/vault.yml (ENCRYPTED)
tailscale_tokens:
  server01: "tskey-auth-xxxxxxxxxxxxx"
  server02: "tskey-auth-xxxxxxxxxxxxx"

# In group_vars/all/main.yml
tailscale_accept_dns: true
tailscale_accept_routes: false
tailscale_advertise_exit_node: false
tailscale_advertise_routes: []  # e.g., ["192.168.1.0/24"]
tailscale_snat_subnet_routes: false
tailscale_ssh: true

# Service Configuration
tailscale_service_enabled: true
tailscale_service_state: started
tailscale_timeout: 300
```

**Vault Configuration:**

```bash
# Edit encrypted vault
ansible-vault edit group_vars/all/vault.yml

# Add Tailscale tokens:
tailscale_tokens:
  server01: "tskey-auth-xxxxx"  # Get from https://login.tailscale.com/admin/settings/keys
  server02: "tskey-auth-yyyyy"
```

**Usage:**

```bash
# Install and configure Tailscale
ansible-playbook playbooks/networking/tailscale_setup.yml

# Run on specific hosts
ansible-playbook playbooks/networking/tailscale_setup.yml -l server01

# With subnet routing
ansible-playbook playbooks/networking/tailscale_setup.yml \
  -e 'tailscale_advertise_routes=["192.168.1.0/24"]'
```

**Verification:**

```bash
# Check Tailscale status
tailscale status

# Check IP
tailscale ip

# Test connectivity to another Tailscale node
ping <tailscale-ip>
```

---

#### 5. Tailscale Configuration Update

**File:** `playbooks/networking/tailscale_set_configure.yml`

**Purpose:** Updates Tailscale configuration on already-installed instances.

**Target Hosts:** `all`

**Features:**
- Reconfigure Tailscale settings
- Update route advertisements
- Modify DNS/SSH settings
- No reinstallation required

**Usage:**

```bash
# Update configuration
ansible-playbook playbooks/networking/tailscale_set_configure.yml

# Enable SSH over Tailscale
ansible-playbook playbooks/networking/tailscale_set_configure.yml \
  -e "tailscale_ssh=true"

# Add route advertisement
ansible-playbook playbooks/networking/tailscale_set_configure.yml \
  -e 'tailscale_advertise_routes=["192.168.50.0/24"]'
```

---

### Maintenance Playbooks

#### 6. System Maintenance and Updates

**File:** `playbooks/maintenance/updates/system_maintenance.yml`

**Purpose:** System package updates, hostname configuration, and system resource reporting.

**Target Hosts:** `all`

**Features:**
- OS-specific package updates
- Common package installation
- Hostname/FQDN configuration
- System resource reporting

**Required Variables:**

```yaml
# In group_vars/all/main.yml
hostname_fqdn: "server01.example.com"

common_packages:
  - curl
  - wget
  - vim
  - htop
  - tree
  - unzip
  - git
  - jq
  - btop

# OS-specific packages (optional)
os_specific_packages: []
```

**Per-Host Configuration:**

In `host_vars/server01/main.yml`:
```yaml
hostname_fqdn: "server01.example.com"
```

**Usage:**

```bash
# Run system maintenance
ansible-playbook playbooks/maintenance/updates/system_maintenance.yml

# Update packages only (skip reporting)
ansible-playbook playbooks/maintenance/updates/system_maintenance.yml \
  --tags packages

# Check what would be updated
ansible-playbook playbooks/maintenance/updates/system_maintenance.yml --check
```

**Verification:**

```bash
# Check hostname
hostname
hostname -f

# Check installed packages (Debian)
dpkg -l | grep <package>

# Check installed packages (RHEL)
rpm -qa | grep <package>
```

---

#### 7. SSH Key Management

**File:** `playbooks/maintenance/cleanup/update_ssh_keys.yml`

**Purpose:** Securely manage SSH authorized_keys across multiple users and hosts.

**Target Hosts:** `all`

**Features:**
- Multi-user SSH key management
- Automatic backup of existing keys
- User creation if needed
- Exclusive mode (replace all keys) or additive mode
- Key removal/revocation
- Comprehensive audit logging

**Required Variables:**

```yaml
# In group_vars/all/main.yml
ssh_users:
  - name: "deploy"
    shell: "/bin/bash"
    groups: ["sudo"]
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@host"
      - "ssh-rsa AAAAB3NzaC1yc2EAAAADA... admin@laptop"
    remove_keys:  # Optional - keys to remove
      - "ssh-rsa AAAAB3NzaC1yc2EAAAADA... old-key"
    ensure_user: true  # Create user if doesn't exist

  - name: "admin"
    shell: "/bin/bash"
    groups: ["sudo", "docker"]
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... admin@desktop"

# Key Management Options
authorized_keys_exclusive: true   # Replace all keys (true) or add to existing (false)
backup_keys: true                # Backup before changes
ssh_port: 22
```

**Usage:**

```bash
# Update SSH keys
ansible-playbook playbooks/maintenance/cleanup/update_ssh_keys.yml

# Add keys without removing existing ones
ansible-playbook playbooks/maintenance/cleanup/update_ssh_keys.yml \
  -e "authorized_keys_exclusive=false"

# Update for specific user
ansible-playbook playbooks/maintenance/cleanup/update_ssh_keys.yml \
  --extra-vars '{"ssh_users": [{"name": "deploy", "authorized_keys": ["ssh-ed25519..."]}]}'

# Check mode
ansible-playbook playbooks/maintenance/cleanup/update_ssh_keys.yml --check
```

**Verification:**

```bash
# Check authorized keys
cat ~/.ssh/authorized_keys

# Check backup
ls -la ~/.ssh/authorized_keys.backup.*

# Test SSH connection
ssh -i ~/.ssh/id_ed25519 user@host
```

**Important Notes:**
- ⚠️ **Always test with `authorized_keys_exclusive: false` first!**
- ⚠️ Keep backup access method available
- ⚠️ Verify keys before setting `authorized_keys_exclusive: true`

---

### Virtualization Playbooks

#### 8. Proxmox VE Setup

**File:** `playbooks/virtualization/proxmox_setup.yml`

**Purpose:** Comprehensive Proxmox VE installation and configuration.

**Target Hosts:** `proxmox_nodes` (host group)

**Features:**
- Automated Proxmox VE installation (7.x, 8.x, 9.x)
- Cluster creation and joining
- Storage backend configuration
- Network configuration
- Security hardening
- Backup configuration
- SSL/TLS management
- High Availability setup

**Required Variables:**

```yaml
# In group_vars/all/main.yml

# Basic Configuration
proxmox_subscription_type: "no-subscription"  # or "enterprise"
proxmox_remove_subscription_notice: true

# Features
proxmox_cluster_enabled: false
proxmox_security_hardening: true
proxmox_firewall_enabled: true
proxmox_network_configure: true
proxmox_storage_configure: true
proxmox_backup_configure: true
proxmox_ssl_enabled: true

# Network Configuration
proxmox_network_bridges:
  - name: vmbr0
    type: bridge
    address: "{{ ansible_default_ipv4.address }}"
    netmask: "{{ ansible_default_ipv4.netmask }}"
    gateway: "{{ ansible_default_ipv4.gateway }}"
    bridge_ports: "{{ ansible_default_ipv4.interface }}"
    bridge_stp: "off"
    bridge_fd: 0
    comment: "Main bridge for VMs"
```

**Cluster Configuration:**

For cluster setup, see the detailed guide in [roles/proxmox/README.md](roles/proxmox/README.md).

**Basic cluster example:**

```yaml
# First node (creates cluster)
proxmox_cluster_enabled: true
proxmox_cluster_create: true
proxmox_cluster_name: "homelab"

# Other nodes (join cluster)
proxmox_cluster_enabled: true
proxmox_cluster_join: true
proxmox_cluster_name: "homelab"
proxmox_cluster_master_node: "192.168.1.100"
```

**Usage:**

```bash
# Basic installation
ansible-playbook playbooks/virtualization/proxmox_setup.yml

# Cluster setup (run on first node)
ansible-playbook playbooks/virtualization/proxmox_setup.yml -l pve-node01

# Join cluster (run on other nodes, one at a time)
ansible-playbook playbooks/virtualization/proxmox_setup.yml -l pve-node02

# With specific tags
ansible-playbook playbooks/virtualization/proxmox_setup.yml --tags proxmox_security

# Check mode
ansible-playbook playbooks/virtualization/proxmox_setup.yml --check
```

**Verification:**

```bash
# Check Proxmox version
pveversion

# Check cluster status
pvecm status

# Check storage
pvesm status

# Check firewall
pve-firewall status

# Access web interface
https://<proxmox-ip>:8006
```

**For complete documentation, see:** [roles/proxmox/README.md](roles/proxmox/README.md)

---

## Configuration Guide

### Inventory Setup

**Example inventory** (`inventories/production.yml`):

```yaml
all:
  vars:
    ansible_user: root
    ansible_python_interpreter: /usr/bin/python3

  children:
    webservers:
      hosts:
        web01:
          ansible_host: 192.168.1.10
        web02:
          ansible_host: 192.168.1.11

    databases:
      hosts:
        db01:
          ansible_host: 192.168.1.20

    proxmox_nodes:
      hosts:
        pve01:
          ansible_host: 192.168.1.100
        pve02:
          ansible_host: 192.168.1.101
        pve03:
          ansible_host: 192.168.1.102
```

### Variable Hierarchy

Variables are loaded in this order (later overrides earlier):

1. `group_vars/all/main.yml` - Global defaults
2. `group_vars/<os_family>/main.yml` - OS-specific (debian or rhel)
3. `group_vars/<group>/main.yml` - Group-specific
4. `host_vars/<hostname>/main.yml` - Host-specific
5. Command-line `-e` parameters - Highest priority

### Vault Management

```bash
# Create encrypted vault
ansible-vault create group_vars/all/vault.yml

# Edit vault
ansible-vault edit group_vars/all/vault.yml

# View vault
ansible-vault view group_vars/all/vault.yml

# Encrypt existing file
ansible-vault encrypt group_vars/all/vault.yml

# Decrypt file
ansible-vault decrypt group_vars/all/vault.yml

# Change vault password
ansible-vault rekey group_vars/all/vault.yml
```

**Vault content example:**

```yaml
---
# Tailscale tokens
tailscale_tokens:
  server01: "tskey-auth-xxxxxxxxxxxxx"
  server02: "tskey-auth-yyyyyyyyyyyyy"

# Proxmox passwords (if needed)
vault_proxmox_admin_password: "secure_password"
vault_smb_password: "smb_password"
vault_pbs_password: "pbs_password"
```

---

## Security Features

### Implemented Security Measures

1. **SSH Hardening**
   - Key-based authentication only
   - Disabled root login with password
   - Custom SSH port support
   - Rate limiting and connection limits

2. **Firewall Configuration**
   - Default deny incoming policy
   - Whitelist-based access control
   - Service-specific rules
   - Proxmox-specific firewall rules

3. **Intrusion Prevention**
   - Fail2ban with custom filters
   - Proxmox-specific fail2ban rules
   - Configurable ban times and retry limits

4. **System Hardening**
   - Kernel parameter tuning (sysctl)
   - TCP/IP stack hardening
   - Disabled unnecessary services
   - AppArmor/SELinux enforcement

5. **Automated Updates**
   - Unattended security updates
   - Configurable update schedules
   - Automatic reboot support

6. **Access Control**
   - TCP wrappers
   - IP-based whitelisting
   - User and group management
   - API token support (Proxmox)

7. **Audit Logging**
   - Configuration change tracking
   - User activity logging
   - Security event monitoring
   - Log rotation

---

## Troubleshooting

### Common Issues

#### SSH Connection Failures

**Problem:** Can't connect after security hardening

**Solution:**
```bash
# Check if your IP is whitelisted
# Add to group_vars/all/main.yml:
whitelist_ips:
  - "your.ip.address"

# Or temporarily disable firewall to troubleshoot
sudo ufw disable  # Debian
sudo systemctl stop firewalld  # RHEL
```

#### Ansible Vault Errors

**Problem:** `ERROR! Attempting to decrypt but no vault secrets found`

**Solution:**
```bash
# Ensure vault password file exists
echo "your-password" > ~/.ansible/.ansible_vault_pass
chmod 600 ~/.ansible/.ansible_vault_pass

# Or provide password at runtime
ansible-playbook playbook.yml --ask-vault-pass
```

#### Network Configuration Rollback

**Problem:** Lost connectivity after network change

**Solution:**
The playbook has automatic rollback. Wait 5 minutes (default `network_rollback_timeout`) and configuration will revert. Or:

```bash
# Manually restore backup
sudo cp /etc/NetworkManager/system-connections/backup-* /etc/NetworkManager/system-connections/
sudo nmcli connection reload
```

#### Proxmox Cluster Issues

**Problem:** Cluster join fails

**Solution:**
```bash
# Ensure SSH connectivity to master
ssh root@master-node pvecm status

# Check cluster ports are open (5404-5405)
telnet master-node 5405

# Verify hostnames resolve
ping pve-node01
```

### Debug Mode

Run playbooks with increased verbosity:

```bash
# Level 1 - Basic debug
ansible-playbook playbook.yml -v

# Level 2 - More details
ansible-playbook playbook.yml -vv

# Level 3 - Connection debug
ansible-playbook playbook.yml -vvv

# Level 4 - Everything
ansible-playbook playbook.yml -vvvv
```

### Check Mode (Dry Run)

Test changes without applying:

```bash
ansible-playbook playbook.yml --check --diff
```

---

## Best Practices

1. **Always test in development first**
   - Use `--check` mode
   - Test on non-production systems
   - Verify in staging environment

2. **Use version control**
   - Track all configuration changes
   - Document customizations
   - Use branches for testing

3. **Backup before changes**
   - Configuration files backed up automatically
   - Keep manual backups of critical data
   - Document rollback procedures

4. **Security first**
   - Use Ansible Vault for all secrets
   - Rotate credentials regularly
   - Review firewall rules periodically

5. **Monitor and verify**
   - Check playbook output
   - Verify services after changes
   - Monitor logs for issues

---

## Contributing

1. Test all changes thoroughly
2. Update documentation
3. Follow existing patterns
4. Add tests where applicable

---

## License

MIT

---

## Support

For issues:
- Review playbook output
- Check logs in `/var/log/`
- Run with `-vvv` for debug info
- Consult role-specific README files

---

## Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Role-Specific Documentation](roles/)
  - [Proxmox Role README](roles/proxmox/README.md)
  - [Proxmox Testing Guide](roles/proxmox/TESTING.md)
