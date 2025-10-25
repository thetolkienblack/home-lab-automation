# Homelab Ansible Automation

Ansible automation for homelab infrastructure management with security hardening, Docker deployments, and system configuration.

## Features

- **Security Hardening**: SSH, firewall (UFW/firewalld), fail2ban, automatic updates
- **Docker Management**: Installation, configuration, and stack deployment
- **Kubernetes**: k3s lightweight Kubernetes with Calico CNI support
- **Container Monitoring**: cAdvisor for container resource monitoring and metrics
- **Network Configuration**: Tailscale VPN setup and management
- **System Management**: NTP/timezone, package updates, maintenance tasks
- **Modular Roles**: Reusable roles with Molecule testing

## Prerequisites

- Ansible 2.15+
- Python 3.9+
- Molecule (for testing)
- SSH access to target hosts

## Quick Start

### 1. Setup SSH Agent

```bash
# Use the helper script
./scripts/setup-ssh-agent.sh

# Or manually
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_graylock
```

### 2. Configure Inventory

Edit `inventories/production.yml` or `inventories/development.yml` with your hosts.

### 3. Configure Variables

Encrypted vault file: `inventories/group_vars/all/vault.yml`

```bash
# Edit vault
ansible-vault edit inventories/group_vars/all/vault.yml

# View vault
ansible-vault view inventories/group_vars/all/vault.yml
```

### 4. Run Playbooks

```bash
# System hardening
ansible-playbook playbooks/security/system_hardening.yml --ask-vault-pass

# Install Docker
ansible-playbook playbooks/docker/install_docker.yml

# Deploy cAdvisor monitoring
ansible-playbook playbooks/monitoring/cadvisor.yml

# Deploy k3s Kubernetes
ansible-playbook playbooks/kubernetes/k3s-server.yml

# Configure NTP
ansible-playbook playbooks/system/ntp_timezone_config.yml

# System maintenance
ansible-playbook playbooks/maintenance/system_maintenance.yml
```

## Project Structure

```
.
├── ansible.cfg                 # Ansible configuration
├── inventories/
│   ├── production.yml          # Production inventory
│   ├── development.yml         # Development inventory
│   ├── group_vars/
│   │   └── all/
│   │       ├── main.yml        # Global variables
│   │       ├── docker.yml      # Docker configuration
│   │       └── vault.yml       # Encrypted secrets
│   └── host_vars/              # Host-specific variables
├── playbooks/
│   ├── docker/                 # Docker playbooks
│   ├── kubernetes/             # Kubernetes (k3s) playbooks
│   ├── monitoring/             # Monitoring playbooks
│   ├── security/               # Security playbooks
│   ├── networking/             # Network playbooks
│   ├── system/                 # System playbooks
│   └── maintenance/            # Maintenance playbooks
├── roles/
│   ├── common/                 # Common system setup
│   ├── docker/                 # Docker installation
│   ├── k3s/                    # Kubernetes (k3s) with Calico CNI
│   ├── cadvisor/               # Container monitoring
│   ├── security_hardening/     # Security configuration
│   ├── tailscale/              # Tailscale VPN
│   ├── ntp/                    # Time synchronization
│   └── maintenance/            # System maintenance
├── templates/                  # Jinja2 templates
└── scripts/                    # Helper scripts

```

## Roles

### common
Basic system setup: package installation, timezone configuration, hostname setup.

```yaml
- hosts: all
  roles:
    - common
```

### docker
Docker and Docker Compose installation with security hardening.

```yaml
- hosts: docker_hosts
  roles:
    - docker
```

### security_hardening
Comprehensive security: SSH hardening, firewall, fail2ban, automatic updates.

```yaml
- hosts: all
  roles:
    - security_hardening
```

### tailscale
Tailscale VPN installation and configuration.

```yaml
- hosts: all
  roles:
    - tailscale
```

### ntp
NTP/chronyd configuration for time synchronization.

```yaml
- hosts: all
  roles:
    - ntp
```

### maintenance
System maintenance tasks: updates, cleanup, monitoring.

```yaml
- hosts: all
  roles:
    - maintenance
```

### cadvisor
cAdvisor container monitoring for resource usage and performance metrics.

```yaml
- hosts: docker_hosts
  roles:
    - cadvisor
  vars:
    cadvisor_install_method: docker  # or 'binary'
    cadvisor_port: 8080
```

### k3s
Lightweight Kubernetes with Calico CNI support for container orchestration.

```yaml
# Server mode with Calico CNI
- hosts: k3s_servers
  roles:
    - k3s
  vars:
    k3s_mode: server
    k3s_cni: calico

# Agent mode
- hosts: k3s_agents
  roles:
    - k3s
  vars:
    k3s_mode: agent
    k3s_server_url: "https://server-ip:6443"
    k3s_server_token: "your-token"
```

## Testing with Molecule

```bash
# Test a specific role
cd roles/docker
molecule test

# Create and converge test instance
molecule create
molecule converge

# Run verification tests
molecule verify

# Cleanup
molecule destroy
```

## Variables

### Global Variables (group_vars/all/main.yml)

```yaml
timezone: "Europe/Sofia"
common_packages:
  - curl
  - wget
  - vim
  - htop
firewall_enabled: true
ssh_port: 22
```

### Vault Variables (group_vars/all/vault.yml)

Encrypt sensitive data:

```yaml
ansible_become_password: "secure_password"
ssh_users:
  - name: "sidney"
    authorized_keys:
      - "ssh-ed25519 AAAA..."
tailscale_tokens:
  hostname: "tskey-..."
```

## Security Best Practices

1. **Always encrypt the vault file:**
   ```bash
   ansible-vault encrypt inventories/group_vars/all/vault.yml
   ```

2. **Use SSH agent instead of storing keys:**
   ```bash
   ./scripts/setup-ssh-agent.sh
   ```

3. **Enable host key checking for production** (edit `ansible.cfg:44`)

4. **Review firewall rules** before applying security playbook

5. **Test playbooks in development environment first**

## Common Tasks

### Update All Systems
```bash
ansible-playbook playbooks/maintenance/system_maintenance.yml
```

### Deploy Docker Stack
```bash
ansible-playbook playbooks/docker/deploy-docker-stack.yml -e stack=adguardhome
```

### Deploy Container Monitoring
```bash
ansible-playbook playbooks/monitoring/cadvisor.yml
```

### Deploy k3s Kubernetes
```bash
# Single server
ansible-playbook playbooks/kubernetes/k3s-server.yml

# Multi-node cluster
ansible-playbook playbooks/kubernetes/k3s-cluster.yml -i inventories/k3s-cluster.yml
```

### Update SSH Keys
```bash
ansible-playbook playbooks/maintenance/update_ssh_keys.yml
```

## Troubleshooting

### Vault Password Issues
```bash
# Set vault password file path
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/ansible_vault_pass

# Or use --ask-vault-pass flag
ansible-playbook playbook.yml --ask-vault-pass
```

### SSH Connection Issues
```bash
# Test connectivity
ansible all -m ping

# Check SSH agent
ssh-add -l

# Test with verbose output
ansible-playbook playbook.yml -vvv
```

### Permission Denied
Ensure your user has sudo/su privileges and the become password is correct in the vault.

## Contributing

1. Test changes with Molecule
2. Run ansible-lint before committing
3. Update documentation
4. Follow existing code style

## License

MIT

## Author

Sidney - Homelab Infrastructure Automation
