# Ansible Role: Prometheus Stack

A comprehensive Ansible role for deploying and configuring a complete Prometheus monitoring stack including Prometheus, Alertmanager, Node Exporter, and Blackbox Exporter. This role supports both Debian and RedHat family operating systems with extensive configuration options.

## Features

- **Complete Monitoring Stack**: Deploys Prometheus, Alertmanager, Node Exporter, and Blackbox Exporter
- **Multi-OS Support**: Works with Debian (11, 12, 13) and RedHat (RHEL 9, Rocky 9, AlmaLinux 9) families
- **Flexible Installation**: Supports both package manager (default) and binary installation methods
- **TLS Support**: Optional TLS encryption with self-signed certificate generation
- **Firewall Configuration**: Automatic firewall rules for both UFW (Debian) and firewalld (RedHat)
- **Default Alert Rules**: Pre-configured alerting rules for common scenarios
- **Template-Based Configuration**: All configurations use Jinja2 templates for flexibility
- **Comprehensive Testing**: Includes Molecule tests for multiple platforms
- **Retention Management**: Configurable data retention (default: 14 days)

## Quick Start

### 1. Install Dependencies

```bash
cd /Users/sidney/Developer/home-lab-automation/ansible
ansible-galaxy collection install -r requirements.yml
ansible-galaxy role install -r requirements.yml
```

### 2. Deploy Full Stack

```bash
ansible-playbook -i inventories/production playbooks/monitoring/prometheus_stack.yml
```

### 3. Access Services

- Prometheus UI: `http://your-server:9090`
- Alertmanager UI: `http://your-server:9093`
- Node Exporter: `http://your-server:9100/metrics`
- Blackbox Exporter: `http://your-server:9115/metrics`

## Requirements

- Ansible >= 2.15
- Supported Operating Systems:
  - Ubuntu 22.04 (Jammy)
  - Debian 12 (Bookworm), 13 (Trixie)
  - RHEL 9, Rocky Linux 9, AlmaLinux 9
- Python 3.x on target hosts
- systemd for service management

### Required Collections

```yaml
collections:
  - prometheus.prometheus
  - community.crypto
  - ansible.posix
  - community.general
```

Install with:
```bash
ansible-galaxy collection install -r requirements.yml
```

## Role Variables

### General Configuration

```yaml
# Component installation flags
prometheus_stack_install_prometheus: true
prometheus_stack_install_alertmanager: true
prometheus_stack_install_node_exporter: true
prometheus_stack_install_blackbox_exporter: true

# Installation method: 'package' or 'binary'
prometheus_stack_install_method: package
```

### Prometheus Configuration

```yaml
prometheus_version: latest
prometheus_web_listen_address: "0.0.0.0:9090"
prometheus_storage_retention: "14d"
prometheus_storage_retention_size: "0"  # 0 means no limit
prometheus_config_dir: /etc/prometheus
prometheus_db_dir: /var/lib/prometheus

# Scrape intervals
prometheus_global_scrape_interval: 15s
prometheus_global_scrape_timeout: 10s
prometheus_global_evaluation_interval: 15s
```

### Alertmanager Configuration

```yaml
alertmanager_version: latest
alertmanager_web_listen_address: "0.0.0.0:9093"
alertmanager_config_dir: /etc/alertmanager
alertmanager_db_dir: /var/lib/alertmanager

# Example email receiver
alertmanager_receivers:
  - name: 'default-receiver'
    email_configs:
      - to: 'admin@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager@example.com'
        auth_password: 'changeme'
        require_tls: true
```

### TLS Configuration

```yaml
prometheus_stack_enable_tls: false
prometheus_stack_generate_self_signed_cert: false
prometheus_stack_tls_cert_days: 365
prometheus_stack_tls_cert_common_name: prometheus.local
```

### Firewall Configuration

```yaml
prometheus_stack_configure_firewall: true
prometheus_stack_firewall_zone: public
prometheus_stack_firewall_ports:
  - 9090/tcp  # Prometheus
  - 9093/tcp  # Alertmanager
  - 9100/tcp  # Node Exporter
  - 9115/tcp  # Blackbox Exporter
```

## Dependencies

This role depends on the following roles from the `prometheus.prometheus` collection:
- `prometheus.prometheus.prometheus`
- `prometheus.prometheus.alertmanager`
- `prometheus.prometheus.node_exporter`
- `prometheus.prometheus.blackbox_exporter`

## Example Playbook

### Basic Usage

```yaml
---
- name: Deploy Prometheus monitoring stack
  hosts: monitoring
  become: true
  roles:
    - role: prometheus_stack
```

### Custom Configuration

```yaml
---
- name: Deploy Prometheus with custom settings
  hosts: monitoring
  become: true
  vars:
    prometheus_storage_retention: "30d"
    prometheus_stack_enable_tls: true
    prometheus_stack_generate_self_signed_cert: true
    prometheus_stack_configure_firewall: true

    # Custom Slack receiver
    alertmanager_receivers:
      - name: 'slack-receiver'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
            channel: '#alerts'
            username: 'Alertmanager'
            title: '{{ "{{" }} .GroupLabels.alertname {{ "}}" }}'
            text: '{{ "{{" }} range .Alerts {{ "}}" }}{{ "{{" }} .Annotations.description {{ "}}" }}{{ "{{" }} end {{ "}}" }}'

    alertmanager_route:
      receiver: 'slack-receiver'
      group_by: ['alertname', 'cluster']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h

  roles:
    - role: prometheus_stack
```

### Prometheus Only

```yaml
---
- name: Deploy only Prometheus
  hosts: monitoring
  become: true
  vars:
    prometheus_stack_install_alertmanager: false
    prometheus_stack_install_node_exporter: false
    prometheus_stack_install_blackbox_exporter: false

  roles:
    - role: prometheus_stack
```

## Default Alert Rules

The role includes the following default alert rules:

- **InstanceDown**: Triggers when an instance is down for more than 5 minutes
- **HighCPUUsage**: Warns when CPU usage exceeds 80% for 10 minutes
- **HighMemoryUsage**: Warns when memory usage exceeds 80% for 10 minutes
- **DiskSpaceLow**: Warns when disk space falls below 20%
- **DiskSpaceCritical**: Critical alert when disk space falls below 10%
- **ServiceDown**: Alerts when a monitored service is down
- **PrometheusConfigReloadFailed**: Alerts on configuration reload failures
- **AlertmanagerConfigReloadFailed**: Alerts on Alertmanager configuration issues

## Scrape Configurations

Default scrape targets include:

1. **Prometheus** (self-monitoring) - localhost:9090
2. **Alertmanager** - localhost:9093
3. **Node Exporter** - localhost:9100
4. **Blackbox Exporter** - localhost:9115
5. **HTTP Endpoints** (via Blackbox) - Configurable external URLs

## Blackbox Exporter Modules

Pre-configured modules:

- **http_2xx**: HTTP/HTTPS endpoint checks
- **http_post_2xx**: HTTP POST endpoint checks
- **tcp_connect**: TCP connectivity checks
- **icmp**: ICMP ping checks
- **dns_query**: DNS resolution checks

## Testing

This role includes comprehensive Molecule tests for:

- Ubuntu 22.04
- Debian 12
- Rocky Linux 9

Run tests:

```bash
cd roles/prometheus_stack
molecule test
```

## Firewall Management

The role automatically configures firewall rules:

### Debian/Ubuntu (UFW)
- Installs and enables UFW if not present
- Opens required ports with descriptive comments

### RedHat/Rocky (firewalld)
- Installs and enables firewalld if not present
- Adds ports to the specified zone (default: public)

## Service Verification

The role includes verification tasks that:

1. Check systemd service status
2. Verify HTTP endpoints are responding
3. Validate configuration loading
4. Display comprehensive status report

## TLS Configuration

### Self-Signed Certificates

Enable TLS with self-signed certificates:

```yaml
prometheus_stack_enable_tls: true
prometheus_stack_generate_self_signed_cert: true
prometheus_stack_tls_cert_common_name: prometheus.example.com
```

### Custom Certificates

Use your own certificates:

```yaml
prometheus_stack_enable_tls: true
prometheus_stack_generate_self_signed_cert: false
prometheus_stack_tls_server_config:
  cert_file: /path/to/your/cert.pem
  key_file: /path/to/your/key.pem
```

## License

MIT

## Author

Sidney - Home Lab

## Contributing

Issues and pull requests are welcome at the repository.
