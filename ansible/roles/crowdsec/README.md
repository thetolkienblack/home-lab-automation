# Ansible Role: CrowdSec

[![Ansible Role](https://img.shields.io/badge/role-graylock.crowdsec-blue.svg)](https://galaxy.ansible.com/graylock/crowdsec/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Comprehensive Ansible role for deploying and configuring CrowdSec IDS/IPS with central LAPI architecture, agents, bouncers, and complete integration with Docker, Kubernetes, and various services.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Role Variables](#role-variables)
- [Architecture](#architecture)
- [Usage Examples](#usage-examples)
- [Advanced Configuration](#advanced-configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

### Core Capabilities
- **Central LAPI Server**: Deploy central Local API server for decision management
- **Agent Deployment**: Automatic agent enrollment with central LAPI
- **Auto-Detection**: Automatic collection and parser detection based on installed services
- **Docker Integration**: Full Docker daemon and container log parsing
- **Kubernetes Support**: Helm-based deployment for any Kubernetes flavor (K3s, K8s, EKS, GKE, AKS)
- **AppSec Module**: Application Security (WAF-like) protection
- **Multiple Bouncers**: Firewall, Traefik, and custom bouncer support
- **Blocklists**: Community and custom blocklist integration
- **Notifications**: Slack, Email, and Webhook alert channels

### Security & Performance
- Multi-OS support (Debian, Ubuntu, RHEL/CentOS)
- TLS support for LAPI
- Database backends: SQLite, PostgreSQL, MySQL/MariaDB
- Prometheus metrics integration
- Automatic hub updates
- Configurable log retention and rotation

## Requirements

### Control Node
- Ansible >= 2.14
- Python >= 3.8

### Managed Nodes
- Supported OS:
  - Ubuntu 20.04+
  - Debian 11+
  - RHEL/CentOS 8+
- Docker (optional, for Docker integration)
- Kubernetes cluster (optional, for Kubernetes deployment)

### Ansible Collections
```bash
ansible-galaxy collection install -r requirements.yml
```

Required collections:
- `community.general >= 11.2.1`
- `ansible.posix >= 1.4.0`
- `community.docker >= 4.7.0`
- `kubernetes.core >= 5.0.0` (for Kubernetes deployment)
- `community.postgresql >= 3.0.0` (for PostgreSQL database)
- `community.mysql >= 3.0.0` (for MySQL/MariaDB database)

## Installation

### From Ansible Galaxy (coming soon)
```bash
ansible-galaxy role install graylock.crowdsec
```

### From Source
```bash
cd roles
git clone https://github.com/your-org/ansible-role-crowdsec.git crowdsec
```

## Role Variables

### Deployment Mode
```yaml
# Mode: 'lapi' for central server, 'agent' for agents, 'kubernetes' for K8s
crowdsec_mode: agent
```

### LAPI Server Configuration
```yaml
# Central LAPI server (required for agents)
crowdsec_lapi_server: "lapi.example.com"
crowdsec_lapi_port: 8080
crowdsec_lapi_url: "http://{{ crowdsec_lapi_server }}:{{ crowdsec_lapi_port }}"

# TLS Configuration
crowdsec_lapi_tls_enabled: false
crowdsec_lapi_tls_cert_path: "/etc/crowdsec/ssl/cert.pem"
crowdsec_lapi_tls_key_path: "/etc/crowdsec/ssl/key.pem"
```

### Agent Enrollment
```yaml
# Auto-generate enrollment key or use pre-configured
crowdsec_enrollment_key: ""
crowdsec_auto_generate_enrollment_key: true
crowdsec_agent_name: "{{ ansible_hostname }}"
```

### Database Configuration (LAPI only)
```yaml
crowdsec_db_type: sqlite  # sqlite, mysql, postgresql
crowdsec_db_path: /var/lib/crowdsec/data/crowdsec.db

# For PostgreSQL/MySQL
crowdsec_db_host: localhost
crowdsec_db_port: 5432
crowdsec_db_name: crowdsec
crowdsec_db_user: crowdsec
crowdsec_db_password: "secret"  # Store in vault!
```

### Collections and Parsers
```yaml
# Auto-detect based on running services
crowdsec_auto_detect_collections: true

# Common collections on all hosts
crowdsec_common_collections:
  - crowdsecurity/linux
  - crowdsecurity/sshd
  - crowdsecurity/base-http-scenarios

# Manual additional collections
crowdsec_additional_collections:
  - crowdsecurity/traefik
  - crowdsecurity/nginx
  - crowdsecurity/postgresql
```

### Docker Integration
```yaml
crowdsec_docker_enabled: true
crowdsec_docker_daemon_logs: true
crowdsec_docker_container_logs: true
crowdsec_docker_socket: /var/run/docker.sock

# Monitor specific containers (empty = all)
crowdsec_docker_monitored_containers: []
```

### AppSec Configuration
```yaml
crowdsec_appsec_enabled: true
crowdsec_appsec_collections:
  - crowdsecurity/appsec-generic-rules
  - crowdsecurity/appsec-virtual-patching
  - crowdsecurity/appsec-crs
```

### Bouncers
```yaml
crowdsec_bouncers:
  - name: firewall
    enabled: true
    package: crowdsec-firewall-bouncer
  - name: blocklist
    enabled: true
    collections:
      - crowdsecurity/blocklist-nets
      - crowdsecurity/blocklist-net-seclists
  - name: traefik
    enabled: false
    package: crowdsec-traefik-bouncer

crowdsec_firewall_bouncer_mode: nftables  # or iptables
```

### Notifications
```yaml
# Slack
crowdsec_slack_enabled: true
crowdsec_slack_webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
crowdsec_slack_channel: "#security"

# Email
crowdsec_email_enabled: true
crowdsec_email_smtp_host: smtp.example.com
crowdsec_email_smtp_port: 587
crowdsec_email_to:
  - security@example.com

# Webhook
crowdsec_webhook_enabled: true
crowdsec_webhook_url: "https://your-webhook.example.com"
```

### Kubernetes Deployment
```yaml
crowdsec_mode: kubernetes
crowdsec_kubernetes_enabled: true
crowdsec_kubernetes_namespace: crowdsec
crowdsec_kubernetes_helm_chart: crowdsec/crowdsec
crowdsec_kubernetes_helm_values:
  lapi:
    replicas: 1
    persistentVolume:
      enabled: true
      size: 10Gi
```

For complete variable documentation, see [defaults/main.yml](defaults/main.yml).

## Architecture

### Central LAPI Deployment

```
┌─────────────────┐
│  LAPI Server    │
│  (Decision DB)  │
└────────┬────────┘
         │
    ┌────┴────┬────────┬────────┐
    │         │        │        │
┌───▼───┐ ┌──▼───┐ ┌──▼───┐ ┌──▼───┐
│Agent 1│ │Agent2│ │Agent3│ │Agent4│
└───┬───┘ └──┬───┘ └──┬───┘ └──┬───┘
    │        │        │        │
┌───▼───────────────────────────▼───┐
│      Firewall Bouncers            │
└───────────────────────────────────┘
```

### Component Flow

1. **Agents** parse logs and detect threats
2. **Agents** send decisions to **LAPI Server**
3. **LAPI Server** stores decisions in database
4. **Bouncers** query LAPI for active decisions
5. **Bouncers** enforce blocking at firewall/application level

## Usage Examples

### Example 1: Deploy Central LAPI Server

**inventory.yml:**
```yaml
all:
  children:
    crowdsec_lapi:
      hosts:
        crowdsec-server:
          ansible_host: 192.168.1.100
          crowdsec_mode: lapi
          crowdsec_db_type: postgresql
          crowdsec_db_password: !vault |
            $ANSIBLE_VAULT;1.1;AES256
            ...
```

**Run:**
```bash
ansible-playbook playbooks/security/crowdsec_setup.yml -l crowdsec_lapi
```

### Example 2: Deploy Agents

**inventory.yml:**
```yaml
all:
  children:
    crowdsec_agents:
      vars:
        crowdsec_mode: agent
        crowdsec_lapi_server: 192.168.1.100
        crowdsec_docker_enabled: true
        crowdsec_appsec_enabled: true
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
```

**Run:**
```bash
ansible-playbook playbooks/security/crowdsec_setup.yml -l crowdsec_agents
```

### Example 3: Kubernetes Deployment

**inventory.yml:**
```yaml
kubernetes_masters:
  hosts:
    k8s-master:
      ansible_host: 192.168.1.50
      crowdsec_mode: kubernetes
      crowdsec_kubernetes_enabled: true
      crowdsec_kubernetes_namespace: security
```

**Run:**
```bash
ansible-playbook playbooks/security/crowdsec_setup.yml -l kubernetes_masters
```

### Example 4: Auto-Detection

The role automatically detects running services and installs appropriate collections:

```yaml
# Automatically detects and installs collections for:
# - nginx (if running)
# - postgresql (if running)
# - docker containers (traefik, redis, etc.)

crowdsec_auto_detect_collections: true
```

## Advanced Configuration

### Custom Log Sources

```yaml
crowdsec_custom_log_sources:
  - source: file
    filenames:
      - /var/log/myapp/access.log
    labels:
      type: myapp

  - source: journalctl
    journalctl_filter:
      - "_SYSTEMD_UNIT=myservice.service"
    labels:
      type: myservice
```

### Custom Blocklists

```yaml
crowdsec_custom_blocklists:
  - name: "my-custom-blocklist"
    url: "https://example.com/blocklist.txt"
    type: "ip"
```

### Multiple Database Backends

**PostgreSQL:**
```yaml
crowdsec_db_type: postgresql
crowdsec_db_host: postgres.example.com
crowdsec_db_port: 5432
crowdsec_db_name: crowdsec
crowdsec_db_user: crowdsec_user
crowdsec_db_password: "{{ vault_crowdsec_db_password }}"
crowdsec_db_ssl_mode: require
```

**MySQL:**
```yaml
crowdsec_db_type: mysql
crowdsec_db_host: mysql.example.com
crowdsec_db_port: 3306
crowdsec_db_name: crowdsec
crowdsec_db_user: crowdsec_user
crowdsec_db_password: "{{ vault_crowdsec_db_password }}"
```

## Testing

### Molecule Tests

Run full test suite:
```bash
cd roles/crowdsec
molecule test
```

Run specific scenario:
```bash
molecule test -s lapi
molecule test -s agent
molecule test -s collections
```

### Manual Verification

**Check CrowdSec status:**
```bash
cscli metrics
cscli hub list
cscli collections list
cscli machines list
cscli bouncers list
```

**View decisions:**
```bash
cscli decisions list
cscli alerts list
```

**Test detection:**
```bash
# Trigger SSH brute force detection
for i in {1..10}; do ssh invalid_user@localhost; done
cscli decisions list
```

## Troubleshooting

### Agent Can't Connect to LAPI

**Symptoms:**
Agent logs show connection refused

**Solutions:**
1. Check LAPI firewall rules:
   ```yaml
   crowdsec_configure_firewall: true
   crowdsec_firewall_allowed_ips:
     - "192.168.1.0/24"
   ```

2. Verify LAPI is listening:
   ```bash
   ss -tlnp | grep 8080
   ```

3. Check agent credentials:
   ```bash
   cat /etc/crowdsec/local_api_credentials.yaml
   ```

### Collections Not Installing

**Symptoms:**
Collection install fails with "can't find"

**Solutions:**
1. Update hub:
   ```bash
   cscli hub update
   ```

2. Check collection name:
   ```bash
   cscli collections list -a
   ```

### Docker Integration Not Working

**Symptoms:**
No Docker logs being parsed

**Solutions:**
1. Verify CrowdSec user in docker group:
   ```bash
   groups crowdsec
   ```

2. Check acquis configuration:
   ```bash
   cat /etc/crowdsec/acquis.yaml
   ```

3. Restart CrowdSec:
   ```bash
   systemctl restart crowdsec
   ```

## Directory Structure

```
crowdsec/
├── defaults/
│   └── main.yml              # Default variables
├── vars/
│   └── main.yml              # OS-specific variables
├── tasks/
│   ├── main.yml              # Main task orchestration
│   ├── install_repo.yml      # Repository setup
│   ├── install_lapi.yml      # LAPI server installation
│   ├── install_agent.yml     # Agent installation
│   ├── configure.yml         # Main configuration
│   ├── configure_collections.yml  # Auto-detection logic
│   ├── configure_docker.yml  # Docker integration
│   ├── configure_bouncers.yml # Bouncer setup
│   ├── configure_notifications.yml # Alert channels
│   ├── configure_appsec.yml  # AppSec configuration
│   ├── configure_firewall.yml # Firewall rules
│   └── kubernetes_helm.yml   # Kubernetes deployment
├── templates/
│   ├── config.yaml.j2        # Main CrowdSec config
│   ├── acquis.yaml.j2        # Log acquisition config
│   ├── profiles.yaml.j2      # Decision profiles
│   ├── notifications/        # Notification templates
│   └── kubernetes/           # Helm values
├── handlers/
│   └── main.yml              # Service handlers
├── meta/
│   └── main.yml              # Role metadata
├── molecule/
│   ├── default/              # Default test scenario
│   ├── lapi/                 # LAPI-specific tests
│   ├── agent/                # Agent-specific tests
│   └── collections/          # Collection tests
└── README.md                 # This file
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Run `molecule test`
5. Submit a pull request

## License

MIT

## Author

Created by Sidney for Graylock Homelab

## Support

- **Documentation**: [CrowdSec Docs](https://docs.crowdsec.net/)
- **Community**: [CrowdSec Discourse](https://discourse.crowdsec.net/)
- **Issues**: Create an issue in this repository

## Changelog

### Version 1.0.0 (2025-10-26)
- Initial release
- Central LAPI architecture support
- Agent auto-enrollment
- Automatic service detection
- Docker integration
- Kubernetes Helm deployment
- Multiple bouncer support
- Notification channels (Slack, Email, Webhook)
- AppSec module integration
- Comprehensive molecule tests
- Full ansible-lint compliance
