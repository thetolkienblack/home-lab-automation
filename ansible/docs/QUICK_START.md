# Quick Start Guide - Refactored Ansible Roles

## Overview

All playbooks have been refactored into reusable roles. This guide shows you how to use them.

## 🚀 Quick Commands

### Deploy SSH Keys Only
```bash
# Add your SSH keys to vault first
ansible-vault edit inventories/group_vars/all/vault.yml

# Deploy keys
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh_keys
```

### System Maintenance
```bash
# Update all packages and monitor system
ansible-playbook -i inventories/production.yml \
  playbooks/maintenance/system_maintenance_role.yml

# Only update packages
ansible-playbook -i inventories/production.yml \
  playbooks/maintenance/system_maintenance_role.yml \
  --tags updates

# Only monitor (no changes)
ansible-playbook -i inventories/production.yml \
  playbooks/maintenance/system_maintenance_role.yml \
  --tags monitoring
```

### Docker Installation
```bash
# Install Docker with security hardening
ansible-playbook -i inventories/production.yml \
  playbooks/docker/install_docker_role.yml

# Configure only (skip installation)
ansible-playbook -i inventories/production.yml \
  playbooks/docker/install_docker_role.yml \
  --tags configure
```

### NTP/Time Synchronization
```bash
# Configure timezone and NTP
ansible-playbook -i inventories/production.yml \
  playbooks/system/ntp_timezone_config_role.yml

# Only timezone
ansible-playbook -i inventories/production.yml \
  playbooks/system/ntp_timezone_config_role.yml \
  --tags timezone
```

### Tailscale VPN
```bash
# Setup Tailscale VPN
ansible-playbook -i inventories/production.yml \
  playbooks/networking/tailscale_setup_role.yml

# Skip authentication (install only)
ansible-playbook -i inventories/production.yml \
  playbooks/networking/tailscale_setup_role.yml \
  --skip-tags auth
```

### Security Hardening
```bash
# ⚠️ IMPORTANT: Can lock you out! Have console access ready!
# Full security hardening
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --check  # Dry-run first!

# Only SSH hardening
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh

# Only firewall
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --tags firewall
```

## 📋 Required Configuration

### 1. SSH Keys (Security Hardening Role)

Edit vault:
```bash
ansible-vault edit inventories/group_vars/all/vault.yml
```

Add your keys:
```yaml
ssh_authorized_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-key@host"

ssh_authorized_keys_exclusive: false  # Set true to remove other keys
```

### 2. Whitelist IPs (Security Hardening Role)

In `inventories/group_vars/all/main.yml`:
```yaml
whitelist_ips:
  - "192.168.1.0/24"      # Home network
  - "10.0.0.5"            # Jump box
  - "203.0.113.10"        # Office IP
```

### 3. Tailscale Tokens (Tailscale Role)

In vault:
```bash
ansible-vault edit inventories/group_vars/all/vault.yml
```

Add tokens per host:
```yaml
tailscale_tokens:
  webserver01: "tskey-auth-k..."
  dbserver01: "tskey-auth-k..."
  skynet: "tskey-auth-k..."
```

### 4. Timezone (NTP Role)

In `inventories/group_vars/all/main.yml`:
```yaml
timezone: "America/New_York"  # or your timezone
```

## 🏷️ Common Tags

### All Roles
- `--check` - Dry-run mode (no changes)
- `--diff` - Show differences
- `--limit hostname` - Run on specific host only

### Docker Role
- `install` - Installation tasks only
- `configure` - Configuration only
- `service` - Service management only
- `users` - Docker group management
- `verify` - Verification tasks

### Maintenance Role
- `updates` - Package updates only
- `cleanup` - System cleanup only
- `monitoring` - Monitoring/reporting only

### NTP Role
- `timezone` - Timezone configuration
- `debian` - Debian/Ubuntu tasks
- `rhel` - RHEL/CentOS tasks
- `verify` - Verification tasks

### Tailscale Role
- `install` - Installation only
- `configure` - Configuration only
- `auth` - Authentication only

### Security Hardening Role
- `ssh` - SSH hardening only
- `ssh_keys` - SSH key deployment only
- `firewall` - Firewall configuration only
- `fail2ban` - Fail2ban setup only
- `sysctl` - Kernel parameters only
- `tcp_wrappers` - TCP wrappers only
- `auto_updates` - Automatic updates only

## 🧪 Testing Workflow

### 1. Syntax Check
```bash
ansible-playbook playbooks/docker/install_docker_role.yml --syntax-check
```

### 2. Dry-Run (Check Mode)
```bash
ansible-playbook -i inventories/production.yml \
  playbooks/docker/install_docker_role.yml \
  --check --diff
```

### 3. Test on One Host
```bash
ansible-playbook -i inventories/production.yml \
  playbooks/docker/install_docker_role.yml \
  --limit test-server
```

### 4. Full Deployment
```bash
ansible-playbook -i inventories/production.yml \
  playbooks/docker/install_docker_role.yml
```

## 🔧 Troubleshooting

### View Vault Contents
```bash
ansible-vault view inventories/group_vars/all/vault.yml
```

### Edit Vault
```bash
ansible-vault edit inventories/group_vars/all/vault.yml
```

### Verify Host Connectivity
```bash
ansible all -i inventories/production.yml -m ping
```

### Check Variables for a Host
```bash
ansible -i inventories/production.yml webserver01 -m debug -a "var=hostvars[inventory_hostname]"
```

### Test SSH Access
```bash
ssh -i ~/.ssh/id_ed25519 root@hostname
```

## 📚 Documentation

- **SSH Key Management**: `docs/SSH_KEY_MANAGEMENT.md`
- **Implementation Progress**: `IMPLEMENTATION_PROGRESS.md`
- **Refactoring Status**: `REFACTORING_STATUS.md`
- **Main README**: `README.md`

## ⚠️ Important Warnings

1. **Security Hardening** - Can lock you out! Always have console access
2. **Exclusive SSH Keys** - Setting `exclusive: true` removes ALL other keys
3. **Firewall Rules** - Test firewall rules before applying to all hosts
4. **Vault Password** - Keep your vault password safe! (`~/.ansible/ansible_vault_pass`)

## 🎯 Recommended Deployment Order

For new hosts, deploy in this order:

```bash
# 1. Basic setup
ansible-playbook -i inventories/production.yml playbooks/maintenance/system_maintenance_role.yml --limit newhost

# 2. Time sync
ansible-playbook -i inventories/production.yml playbooks/system/ntp_timezone_config_role.yml --limit newhost

# 3. Docker (if needed)
ansible-playbook -i inventories/production.yml playbooks/docker/install_docker_role.yml --limit newhost

# 4. VPN (if needed)
ansible-playbook -i inventories/production.yml playbooks/networking/tailscale_setup_role.yml --limit newhost

# 5. Security hardening (LAST - can lock you out!)
ansible-playbook -i inventories/production.yml playbooks/security/system_hardening_role.yml --limit newhost --check
ansible-playbook -i inventories/production.yml playbooks/security/system_hardening_role.yml --limit newhost
```

---

**Last Updated**: October 25, 2025
**Quick Reference**: For detailed usage, see individual role documentation
