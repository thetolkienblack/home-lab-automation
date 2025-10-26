# CheckMK Ansible Role

Comprehensive Ansible role for deploying and configuring CheckMK monitoring infrastructure with server and agent support, Docker container monitoring, TLS encryption, and automated service discovery.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Role Variables](#role-variables)
- [Dependencies](#dependencies)
- [Example Inventory](#example-inventory)
- [Example Playbook](#example-playbook)
- [Usage Examples](#usage-examples)
- [Docker Monitoring](#docker-monitoring)
- [TLS Configuration](#tls-configuration)
- [Firewall Configuration](#firewall-configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

### Server Features
- ✅ Automated CheckMK Raw Edition installation (Debian & RHEL families)
- ✅ Site creation and configuration
- ✅ Automation user setup for API access
- ✅ Apache web server configuration
- ✅ Self-signed TLS certificate generation
- ✅ SELinux configuration (RHEL)
- ✅ Firewall configuration (UFW/firewalld)

### Agent Features
- ✅ Automated agent installation and registration
- ✅ TLS encryption for agent-server communication
- ✅ Automatic host creation and service discovery
- ✅ Docker container monitoring plugin
- ✅ Comprehensive metrics collection
- ✅ Piggyback host support for containers

### Monitoring Capabilities
- ✅ System resource monitoring (CPU, memory, disk, network)
- ✅ Docker container monitoring (all metrics)
- ✅ Service discovery and auto-configuration
- ✅ Custom check integration
- ✅ Performance data collection

### Security Features
- ✅ TLS/SSL encryption
- ✅ Self-signed certificate generation
- ✅ Firewall rule management
- ✅ SELinux integration
- ✅ Secure automation user credentials

## Requirements

### Ansible
- Ansible >= 2.14
- Python >= 3.6

### Target Systems
- **Debian Family:** Debian 11/12, Ubuntu 20.04/22.04/24.04
- **RHEL Family:** RHEL 8/9, Rocky Linux 8/9, AlmaLinux 8/9

### Collections
```yaml
collections:
  - community.general
  - ansible.posix
  - community.docker
  - community.crypto
```

Install with:
```bash
ansible-galaxy collection install community.general ansible.posix community.docker community.crypto
```

## Role Variables

### Mode Configuration

```yaml
# Deployment mode: server, agent, or both
checkmk_mode: "agent"  # Options: server, agent, both
```

### Server Variables

```yaml
# CheckMK Version
checkmk_version: "2.4.0p14"
checkmk_edition: "raw"  # Options: raw, enterprise

# Site Configuration
checkmk_site_name: "Graylock CMK"
checkmk_site_id: "graylocksite"  # Must be alphanumeric, no spaces
checkmk_admin_user: "cmkadmin"
checkmk_admin_password: "{{ vault_checkmk_admin_password }}"

# Automation User
checkmk_create_automation_user: true
checkmk_automation_user: "automation"
checkmk_automation_secret: "{{ vault_checkmk_automation_secret }}"

# Apache Configuration
checkmk_server_http_port: 80
checkmk_server_https_port: 443
```

### Agent Variables

```yaml
# Agent Server Configuration
checkmk_agent_server: "192.168.1.100"  # IP/hostname of CheckMK server
checkmk_agent_port: 6556

# Auto-registration
checkmk_auto_discovery: true
```

### TLS Configuration

```yaml
# TLS/SSL Settings
checkmk_tls_enabled: true
checkmk_tls_self_signed: true
checkmk_tls_cert_validity_days: 3650

# Certificate Details
checkmk_tls_country: "US"
checkmk_tls_state: "California"
checkmk_tls_locality: "San Francisco"
checkmk_tls_organization: "Graylock Homelab"
checkmk_tls_organizational_unit: "IT"
checkmk_tls_common_name: "{{ ansible_fqdn }}"
```

### Docker Monitoring

```yaml
# Docker Monitoring Configuration
checkmk_docker_monitoring: true
checkmk_docker_api_endpoint: "unix://var/run/docker.sock"
```

### Firewall Configuration

```yaml
# Firewall Settings
checkmk_configure_firewall: true
checkmk_firewall_allowed_ips:
  - "192.168.1.0/24"
  - "10.0.0.0/8"
```

### Complete Variable Reference

See [defaults/main.yml](defaults/main.yml) for all available variables with descriptions.

## Dependencies

None. This role is self-contained.

## Example Inventory

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
          checkmk_site_name: "Production Monitoring"

    checkmk_agents:
      vars:
        checkmk_mode: agent
        checkmk_agent_server: 192.168.1.100
        checkmk_site_id: mainsite
        checkmk_docker_monitoring: true
      hosts:
        web01:
          ansible_host: 192.168.1.10
        web02:
          ansible_host: 192.168.1.11
        db01:
          ansible_host: 192.168.1.20
        docker01:
          ansible_host: 192.168.1.30
```

## Example Playbook

### Basic Server and Agent Deployment

```yaml
---
- name: Deploy CheckMK Server
  hosts: checkmk_servers
  become: true
  roles:
    - checkmk

- name: Deploy CheckMK Agents
  hosts: checkmk_agents
  become: true
  roles:
    - checkmk
```

### Advanced Configuration

```yaml
---
- name: Deploy CheckMK with Custom Settings
  hosts: all
  become: true

  vars:
    # Server settings (for server hosts)
    checkmk_site_name: "{{ company_name }} Monitoring"
    checkmk_admin_password: "{{ vault_checkmk_password }}"

    # TLS configuration
    checkmk_tls_enabled: true
    checkmk_tls_organization: "{{ company_name }}"

    # Firewall
    checkmk_firewall_allowed_ips:
      - "{{ management_network }}"
      - "{{ vpn_network }}"

  roles:
    - role: checkmk
      when: inventory_hostname in groups['checkmk_servers'] or inventory_hostname in groups['checkmk_agents']
```

## Usage Examples

### Deploy Server Only

```bash
# Deploy CheckMK server
ansible-playbook playbooks/monitoring/checkmk_setup.yml -l checkmk_servers

# Verify deployment
curl http://192.168.1.100/mainsite/
```

### Deploy Agents Only

```bash
# Deploy agents to all agent hosts
ansible-playbook playbooks/monitoring/checkmk_setup.yml -l checkmk_agents

# Deploy to specific host
ansible-playbook playbooks/monitoring/checkmk_setup.yml -l web01

# Deploy in batches (5 at a time)
ansible-playbook playbooks/monitoring/checkmk_setup.yml -l checkmk_agents --forks=5
```

### Deploy Everything

```bash
# Deploy server first, then agents
ansible-playbook playbooks/monitoring/checkmk_setup.yml

# With custom variables
ansible-playbook playbooks/monitoring/checkmk_setup.yml \
  -e "checkmk_site_name='My Custom Site'"
```

### Check Mode (Dry Run)

```bash
# Test what would change
ansible-playbook playbooks/monitoring/checkmk_setup.yml --check --diff
```

## Docker Monitoring

The role automatically configures Docker monitoring when `checkmk_docker_monitoring: true`:

### What's Monitored

- **Container Status:** Running, stopped, health checks
- **Resource Usage:** CPU, memory, network I/O, disk I/O
- **Images:** Image inventory and disk usage
- **Networks:** Network configuration and statistics
- **Volumes:** Volume information and usage
- **Node Info:** Docker daemon version and configuration
- **Disk Usage:** Overall Docker disk consumption

### Configuration

The Docker monitoring plugin is configured via [templates/docker.cfg.j2](templates/docker.cfg.j2):

```yaml
# Enable Docker monitoring
checkmk_docker_monitoring: true

# Docker API endpoint (default: Unix socket)
checkmk_docker_api_endpoint: "unix://var/run/docker.sock"
```

### Piggyback Hosts

Docker containers appear as individual hosts in CheckMK using the piggyback mechanism:
- Container ID becomes the hostname
- Set "No IP" for network address
- Configure "No API integrations, no Checkmk agent"
- Optionally set Docker host as parent

## TLS Configuration

### Self-Signed Certificates (Default)

The role automatically generates self-signed certificates:

```yaml
checkmk_tls_enabled: true
checkmk_tls_self_signed: true
checkmk_tls_cert_validity_days: 3650  # 10 years
```

Certificate files are created at:
- Certificate: `/etc/ssl/certs/checkmk-<hostname>.crt`
- Private Key: `/etc/ssl/private/checkmk-<hostname>.key`

### Custom Certificates

To use custom certificates:

```yaml
checkmk_tls_enabled: true
checkmk_tls_self_signed: false
```

Then manually place your certificates:
- `/etc/ssl/certs/checkmk-<hostname>.crt`
- `/etc/ssl/private/checkmk-<hostname>.key`

### Agent TLS Registration

Agents automatically register with TLS encryption when `checkmk_tls_enabled: true`:

```bash
# Check agent TLS status
sudo cmk-agent-ctl status

# View agent connection details
sudo cmk-agent-ctl dump
```

## Firewall Configuration

### UFW (Debian/Ubuntu)

```yaml
checkmk_configure_firewall: true
checkmk_firewall_allowed_ips:
  - "192.168.1.0/24"  # Your network
```

Configured ports:
- **Server:** 80 (HTTP), 443 (HTTPS), 6557 (Livestatus)
- **Agent:** 6556 (from allowed IPs only)

Verify:
```bash
sudo ufw status verbose
```

### firewalld (RHEL/CentOS)

Same configuration, automatically uses firewalld on RHEL systems:

```yaml
checkmk_configure_firewall: true
```

Verify:
```bash
sudo firewall-cmd --list-all
```

## Testing

### Molecule Tests

The role includes comprehensive Molecule tests:

```bash
# Run all tests
cd ansible/roles/checkmk
molecule test

# Test specific scenario
molecule test -s default

# Individual steps
molecule create
molecule converge
molecule verify
molecule destroy
```

### Test Platforms

- Debian 12 (Server & Agent)
- Rocky Linux 9 (Server & Agent)

### Ansible Lint

```bash
# Run ansible-lint
ansible-lint ansible/roles/checkmk

# Auto-fix issues
ansible-lint --fix ansible/roles/checkmk
```

## Troubleshooting

### Server Issues

#### Site Not Starting

```bash
# Check site status
sudo omd status <site_id>

# View logs
sudo tail -f /opt/omd/sites/<site_id>/var/log/cmc.log

# Restart site
sudo omd restart <site_id>
```

#### Web Interface Not Accessible

```bash
# Check Apache
sudo systemctl status apache2  # or httpd on RHEL

# Check site is running
sudo omd status <site_id>

# Test locally
curl http://localhost/<site_id>/
```

#### SELinux Issues (RHEL)

```bash
# Check SELinux denials
sudo ausearch -m avc -ts recent

# Set boolean
sudo setsebool -P httpd_can_network_connect 1

# Check context
ls -Z /opt/omd/
```

### Agent Issues

#### Agent Not Responding

```bash
# Check agent socket
sudo systemctl status check-mk-agent.socket

# Test agent output
sudo check_mk_agent

# Check port
sudo ss -tlnp | grep 6556
```

#### Agent Not Registered

```bash
# Check registration status
sudo cmk-agent-ctl status

# Re-register (if needed)
sudo cmk-agent-ctl register \
  --hostname $(hostname -f) \
  --server <server_ip> \
  --site <site_id> \
  --user automation \
  --password <secret> \
  --trust-cert
```

#### Docker Monitoring Not Working

```bash
# Test Docker plugin
sudo python3 /usr/lib/check_mk_agent/plugins/mk_docker.py

# Check Docker permissions
sudo usermod -aG docker root

# Verify Docker socket
ls -la /var/run/docker.sock
```

### Firewall Issues

#### Agent Can't Connect to Server

```bash
# Test connectivity
telnet <server_ip> 80

# Check firewall (Debian)
sudo ufw status verbose

# Check firewall (RHEL)
sudo firewall-cmd --list-all

# Temporarily disable for testing
sudo ufw disable  # Debian
sudo systemctl stop firewalld  # RHEL
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "Site already exists" | Change `checkmk_site_id` or remove existing site |
| "Package not found" | Check version in `checkmk_version` is valid |
| "Permission denied" | Ensure running with `become: true` |
| "Agent not in server" | Check `checkmk_agent_server` points to correct server |
| "TLS handshake failed" | Verify certificates and trust configuration |

### Debug Mode

Run with verbosity for detailed output:

```bash
# Level 1
ansible-playbook playbooks/monitoring/checkmk_setup.yml -v

# Level 2
ansible-playbook playbooks/monitoring/checkmk_setup.yml -vv

# Level 3 (connection debug)
ansible-playbook playbooks/monitoring/checkmk_setup.yml -vvv
```

## Architecture

### Server Components

```
CheckMK Server
├── OMD (Open Monitoring Distribution)
├── Apache Web Server
├── Monitoring Core (Nagios/CMC)
├── Livestatus API
├── REST API
└── Web Interface
```

### Agent Components

```
CheckMK Agent
├── Agent Binary (check_mk_agent)
├── Agent Controller (cmk-agent-ctl)
├── Agent Socket (systemd)
├── Plugins
│   ├── mk_docker.py
│   └── Custom plugins
└── TLS Configuration
```

### Communication Flow

```
1. Server creates automation user and API credentials
2. Agent downloads from server
3. Agent registers with server using automation credentials
4. Agent establishes TLS encrypted connection
5. Server performs service discovery
6. Server activates monitoring
7. Metrics collected at regular intervals
```

## Performance Considerations

- **Agent Deployment:** Use `serial` in playbooks to avoid overwhelming server
- **Docker Monitoring:** May increase CPU/memory usage on monitored hosts
- **TLS Encryption:** Minimal overhead, recommended for production
- **Service Discovery:** Run during low-traffic periods for large environments

## Security Best Practices

1. **Use Ansible Vault** for sensitive variables:
   ```bash
   ansible-vault encrypt_string 'your_password' --name 'vault_checkmk_admin_password'
   ```

2. **Limit firewall access** to management networks only

3. **Enable TLS** for all agent-server communication

4. **Regular updates** to latest CheckMK version

5. **Strong passwords** for admin and automation users

6. **Review and audit** monitoring configurations regularly

## Contributing

1. Test changes with Molecule
2. Run ansible-lint
3. Update documentation
4. Follow existing code patterns

## License

MIT

## Author

Sidney - Graylock Homelab

## Support

For issues:
- Review role documentation
- Check [Troubleshooting](#troubleshooting) section
- Run with `-vvv` for debug output
- Consult [CheckMK official documentation](https://docs.checkmk.com/)

## Additional Resources

- [CheckMK Official Documentation](https://docs.checkmk.com/latest/en/)
- [CheckMK GitHub Repository](https://github.com/Checkmk/checkmk)
- [OMD Documentation](https://labs.consol.de/omd/)
- [CheckMK Community Forum](https://forum.checkmk.com/)
