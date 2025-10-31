# Grafana Stack Ansible Role

A comprehensive Ansible role for deploying and managing the complete Grafana observability stack, including Grafana, Loki, Tempo, Mimir, and Grafana Alloy.

## Features

- **Modular Installation**: Install components independently or as a complete stack
- **Multiple Installation Methods**: Support for package, binary, and Docker installations
- **Multi-OS Support**: Works with Debian/Ubuntu and RedHat/CentOS/Rocky Linux families
- **Flexible Database Backend**: Support for SQLite, PostgreSQL, and MySQL/MariaDB
- **Authentication Options**: Configurable authentication including basic auth, LDAP, and OAuth
- **Automated Provisioning**: Datasources and dashboards provisioning out-of-the-box
- **Security First**: Sensitive data stored in Ansible Vault
- **Fully Tested**: Molecule tests for multiple OS distributions

## Components

### Grafana Server
- Visualization and dashboarding platform
- Configurable database backend (SQLite, PostgreSQL, MySQL)
- Authentication and user management
- Plugin support
- SMTP configuration for alerts

### Loki
- Log aggregation system
- Configurable retention policies
- Filesystem or cloud storage backends
- Integration with Grafana datasources

### Tempo
- Distributed tracing backend
- Multi-protocol support (OTLP, Jaeger, Zipkin)
- Auto-configured Grafana datasource
- Trace storage and querying

### Mimir
- Scalable long-term metrics storage
- Prometheus-compatible
- Configurable storage backends
- High availability support

### Grafana Alloy
- Vendor-neutral telemetry collector
- Replaces Prometheus Agent and Grafana Agent
- Logs, metrics, and traces collection
- Service discovery (Kubernetes, Docker, file-based)

## Requirements

### Ansible
- Ansible >= 2.15
- Collections:
  - `community.general`
  - `community.docker` (for Docker installation method)
  - `community.postgresql` (for PostgreSQL backend)
  - `community.mysql` (for MySQL backend)
  - `ansible.posix`

### System Requirements
- Minimum 2GB RAM (4GB+ recommended for full stack)
- Minimum 2 CPU cores
- Sufficient disk space (varies by retention settings)
- Supported OS:
  - Ubuntu 20.04, 22.04
  - Debian 11, 12, Trixie
  - Rocky Linux 8, 9
  - CentOS 8, 9
  - Fedora 38, 39

## Installation

### Install Required Collections

```bash
ansible-galaxy collection install community.general community.docker community.postgresql community.mysql ansible.posix
```

### Clone or Download Role

```bash
cd ansible/roles
git clone <repository-url> grafana
```

## Configuration

### Required Variables (Store in Vault)

Create an encrypted vault file for sensitive data:

```bash
ansible-vault create roles/grafana/vars/vault.yml
```

Add the following required variables:

```yaml
---
# Admin credentials
grafana_security_admin_password: "YourSecurePassword123!"
grafana_security_secret_key: "GenerateALongRandomSecretKey"

# Database credentials (if not using SQLite)
grafana_database_password: "SecureDatabasePassword"

# SMTP password (if SMTP enabled)
grafana_smtp_password: "SmtpPassword"
```

### Basic Configuration

Create a host_vars or group_vars file for your Grafana servers:

```yaml
---
# Install all components
grafana_install_server: true
grafana_install_loki: true
grafana_install_tempo: true
grafana_install_mimir: true
grafana_install_alloy: true

# Installation method
grafana_install_method: package  # package, binary, or docker

# Database configuration
grafana_database_type: postgres
grafana_database_host: "localhost:5432"
grafana_database_name: grafana
grafana_database_user: grafana
grafana_database_setup: true  # Auto-create database and user

# Server configuration
grafana_server_domain: grafana.example.com
grafana_server_http_port: 3000

# Admin user
grafana_security_admin_user: admin
grafana_security_admin_email: admin@example.com
```

## Usage

### Basic Playbook

Create a playbook to deploy Grafana Stack:

```yaml
---
- name: Deploy Grafana Stack
  hosts: grafana_servers
  become: true

  vars_files:
    - roles/grafana/vars/vault.yml

  roles:
    - grafana
```

### Run the Playbook

```bash
# With vault password prompt
ansible-playbook -i inventory playbooks/monitoring/grafana.yml --ask-vault-pass

# With vault password file
ansible-playbook -i inventory playbooks/monitoring/grafana.yml --vault-password-file ~/.vault_pass
```

### Install Specific Components

```yaml
---
- name: Deploy Grafana Server Only
  hosts: grafana_servers
  become: true

  vars:
    grafana_install_server: true
    grafana_install_loki: false
    grafana_install_tempo: false
    grafana_install_mimir: false
    grafana_install_alloy: false

  vars_files:
    - roles/grafana/vars/vault.yml

  roles:
    - grafana
```

### Different Installation Methods

#### Package Installation (Default)
```yaml
grafana_install_method: package
```

#### Binary Installation
```yaml
grafana_install_method: binary
grafana_version: "10.2.3"
loki_version: "2.9.3"
tempo_version: "2.3.1"
mimir_version: "2.10.4"
alloy_version: "1.0.0"
```

#### Docker Installation
```yaml
grafana_install_method: docker
grafana_docker_tag: latest
loki_docker_tag: latest
tempo_docker_tag: latest
mimir_docker_tag: latest
alloy_docker_tag: latest
```

## Advanced Configuration

### Database Backends

#### SQLite (Default)
```yaml
grafana_database_type: sqlite3
grafana_database_path: grafana.db
```

#### PostgreSQL
```yaml
grafana_database_type: postgres
grafana_database_host: "db.example.com:5432"
grafana_database_name: grafana
grafana_database_user: grafana
grafana_database_ssl_mode: require
grafana_database_setup: true
# grafana_database_password: defined in vault
```

#### MySQL/MariaDB
```yaml
grafana_database_type: mysql
grafana_database_host: "db.example.com:3306"
grafana_database_name: grafana
grafana_database_user: grafana
grafana_database_setup: true
# grafana_database_password: defined in vault
```

### Authentication

#### Anonymous Access
```yaml
grafana_auth_anonymous_enabled: true
grafana_auth_anonymous_org_role: Viewer
```

#### LDAP
```yaml
grafana_auth_ldap_enabled: true
grafana_auth_ldap_config_file: /etc/grafana/ldap.toml
```

### Datasources Configuration

```yaml
grafana_additional_datasources:
  - name: "Production Prometheus"
    type: prometheus
    access: proxy
    url: http://prometheus-prod.example.com:9090
    isDefault: false
    editable: false
    jsonData:
      timeInterval: 30s

  - name: "MySQL Database"
    type: mysql
    access: proxy
    url: mysql-server.example.com:3306
    database: mydb
    user: grafana
    secureJsonData:
      password: "{{ mysql_password }}"
```

### Dashboard Import

```yaml
grafana_dashboards_import:
  - dashboard_id: 1860  # Node Exporter Full
    revision: 31
    datasource: Prometheus
    enabled: true
  - dashboard_id: 12974  # Loki Dashboard
    revision: 1
    datasource: Loki
    enabled: true
```

### Custom Dashboards

```yaml
grafana_dashboards_custom:
  - name: "My Custom Dashboard"
    file: files/dashboards/custom-dashboard.json
    folder: "Custom"
```

### Plugins

```yaml
grafana_plugins_install:
  - grafana-clock-panel
  - grafana-piechart-panel
  - grafana-worldmap-panel
```

### Loki Configuration

```yaml
loki_retention_enabled: true
loki_retention_period: 720h  # 30 days
loki_limits_ingestion_rate_mb: 8
loki_limits_ingestion_burst_size_mb: 16
```

### Tempo Configuration

```yaml
tempo_receivers_otlp_grpc_enabled: true
tempo_receivers_jaeger_grpc_enabled: true
tempo_receivers_zipkin_enabled: true
```

### Mimir Configuration

```yaml
mimir_target: all  # all, read, write, backend
mimir_storage_backend: filesystem
```

### Grafana Alloy Configuration

```yaml
alloy_prometheus_remote_write_enabled: true
alloy_prometheus_remote_write_url: http://mimir:9009/api/v1/push
alloy_loki_write_enabled: true
alloy_loki_write_url: http://loki:3100/loki/api/v1/push
alloy_tempo_write_enabled: true
alloy_tempo_write_url: http://tempo:4317
```

### SMTP Configuration

```yaml
grafana_smtp_enabled: true
grafana_smtp_host: smtp.gmail.com:587
grafana_smtp_user: your-email@gmail.com
grafana_smtp_from_address: grafana@example.com
grafana_smtp_from_name: Grafana Alerts
# grafana_smtp_password: defined in vault
```

### Firewall Configuration

```yaml
grafana_configure_firewall: true
grafana_firewall_zone: public  # For RedHat family

# Custom ports
grafana_firewall_ports:
  - 3000/tcp   # Grafana
  - 3100/tcp   # Loki
  - 3200/tcp   # Tempo
  - 9009/tcp   # Mimir
  - 12345/tcp  # Alloy
```

## Integration Examples

### Integration with Prometheus Stack

```yaml
# In prometheus_stack variables
prometheus_scrape_configs:
  - job_name: 'grafana'
    static_configs:
      - targets:
          - 'grafana-server:3000'

# In grafana variables
grafana_datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus-server:9090
    isDefault: true
```

### Integration with ELK Stack

```yaml
grafana_datasources:
  - name: Elasticsearch
    type: elasticsearch
    url: http://elasticsearch:9200
    database: "[logs-]YYYY.MM.DD"
    jsonData:
      timeField: "@timestamp"
      esVersion: "8.0.0"
```

### Complete Observability Stack

```yaml
# Deploy everything
grafana_install_server: true
grafana_install_loki: true
grafana_install_tempo: true
grafana_install_mimir: true
grafana_install_alloy: true

# Configure Alloy to collect everything
alloy_prometheus_remote_write_enabled: true
alloy_prometheus_remote_write_url: http://localhost:9009/api/v1/push
alloy_loki_write_enabled: true
alloy_loki_write_url: http://localhost:3100/loki/api/v1/push
alloy_tempo_write_enabled: true
alloy_tempo_write_url: http://localhost:4317
```

## Testing

### Ansible Version Compatibility Note

⚠️ **Known Issue**: Python 3.14.0 requires ansible-core >= 2.20.0, but version 2.19.3 is currently available. This prevents ansible-lint from running with Python 3.14.

**Workarounds until ansible-core 2.20.0 is released:**

1. **Use Python 3.13 or earlier** with ansible-lint
2. **Use yamllint** (syntax validated, only line-length warnings which are excluded in config):
   ```bash
   yamllint roles/grafana -d relaxed
   ```
3. **Use ansible-playbook syntax check** (currently passing):
   ```bash
   ansible-playbook playbooks/monitoring/grafana.yml --syntax-check
   ```

### Ansible Lint

Once ansible-core is compatible:

```bash
/Users/sidney/.local/share/mise/installs/python/3.14.0/bin/ansible-lint roles/grafana
```

Or with Python 3.13 or earlier:

```bash
# Install with compatible Python version
mise use python@3.13
pip install ansible-lint
ansible-lint roles/grafana
```

### Molecule Tests

Run the full Molecule test suite:

```bash
cd roles/grafana
molecule test
```

Run tests for specific scenario:

```bash
molecule test -s default
```

Run specific test stages:

```bash
molecule create
molecule converge
molecule verify
molecule destroy
```

### Test Platforms

The role is tested against:
- Ubuntu 22.04 (Jammy)
- Debian 12 (Bookworm)
- Rocky Linux 9

### Validation Status

✅ **Passed**:
- Playbook syntax check
- YAML syntax validation
- File structure verification
- All required files created

⏳ **Pending** (due to Python/ansible-core version incompatibility):
- Ansible-lint full validation
- Molecule end-to-end tests

## Troubleshooting

### Check Service Status

```bash
systemctl status grafana-server
systemctl status loki
systemctl status tempo
systemctl status mimir
systemctl status alloy
```

### View Logs

```bash
journalctl -u grafana-server -f
journalctl -u loki -f
journalctl -u tempo -f
journalctl -u mimir -f
journalctl -u alloy -f
```

### Test Endpoints

```bash
# Grafana
curl http://localhost:3000/api/health

# Loki
curl http://localhost:3100/ready

# Tempo
curl http://localhost:3200/ready

# Mimir
curl http://localhost:9009/ready

# Alloy
curl http://localhost:12345/-/ready
```

### Common Issues

#### Database Connection Failed
- Verify database is running
- Check database credentials in vault
- Ensure database user has proper permissions

#### Service Won't Start
- Check disk space
- Verify configuration file syntax
- Check service logs

#### Can't Access Grafana UI
- Verify firewall rules
- Check service is running
- Verify correct port binding

## Variables Reference

See [defaults/main.yml](defaults/main.yml) for a complete list of configurable variables.

### Component Control Variables
- `grafana_install_server` - Install Grafana server (default: true)
- `grafana_install_loki` - Install Loki (default: false)
- `grafana_install_tempo` - Install Tempo (default: false)
- `grafana_install_mimir` - Install Mimir (default: false)
- `grafana_install_alloy` - Install Grafana Alloy (default: false)

### Installation Variables
- `grafana_install_method` - Installation method: package, binary, docker (default: package)
- `grafana_version` - Version to install (default: latest)

### Database Variables
- `grafana_database_type` - Database type: sqlite3, postgres, mysql (default: postgres)
- `grafana_database_setup` - Auto-create database (default: false)

### Security Variables (Store in Vault)
- `grafana_security_admin_password` - Admin password (REQUIRED)
- `grafana_security_secret_key` - Secret key for cookies (REQUIRED)
- `grafana_database_password` - Database password (if not SQLite)

## Tags

The role supports the following tags:

- `always` - Always run (variable loading, validation)
- `setup` - System setup (users, repos)
- `install` - Component installation
- `config` - Configuration deployment
- `grafana` - Grafana-specific tasks
- `loki` - Loki-specific tasks
- `tempo` - Tempo-specific tasks
- `mimir` - Mimir-specific tasks
- `alloy` - Alloy-specific tasks
- `provisioning` - Datasources and dashboards provisioning
- `plugins` - Plugin installation
- `database` - Database setup
- `firewall` - Firewall configuration
- `verify` - Service verification

### Example Tag Usage

```bash
# Install only, skip configuration
ansible-playbook grafana.yml --tags install

# Configure only
ansible-playbook grafana.yml --tags config

# Install and configure Grafana server only
ansible-playbook grafana.yml --tags grafana

# Skip firewall configuration
ansible-playbook grafana.yml --skip-tags firewall
```

## License

MIT

## Author

Sidney - Home Lab Automation

## Contributing

Contributions are welcome! Please ensure:
1. All changes pass ansible-lint
2. Molecule tests pass for all platforms
3. Documentation is updated
4. Variables are documented in defaults/main.yml

## Support

For issues, questions, or contributions, please open an issue in the repository.
