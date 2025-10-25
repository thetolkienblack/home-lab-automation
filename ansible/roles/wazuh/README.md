# Ansible Role: Wazuh

Comprehensive Ansible role for installing and configuring Wazuh SIEM (Security Information and Event Management) including Manager, Indexer, Dashboard, and Agent with Docker monitoring and Trivy vulnerability integration.

## Requirements

- Ansible >= 2.15
- Docker (automatically installed via dependency)
- Trivy (automatically installed via dependency)
- Supported OS:
  - Ubuntu 20.04+
  - Debian 11+
  - RHEL/Rocky Linux 8+

## Dependencies

This role depends on:
- `docker` - Automatically installs Docker for container monitoring
- `trivy` - Automatically installs Trivy for vulnerability scanning integration

## Role Variables

### Installation Mode

```yaml
# Installation mode: 'all-in-one', 'distributed', 'manager', 'indexer', 'dashboard', 'agent'
wazuh_install_mode: all-in-one

# Or granular control
wazuh_install_manager: true
wazuh_install_indexer: true
wazuh_install_dashboard: true
wazuh_install_agent: false
```

### Wazuh Manager

```yaml
wazuh_manager_email_notification: true
wazuh_manager_email_to: "admin@example.com"
wazuh_manager_vulnerability_detection: true
wazuh_manager_active_response: true
```

### Wazuh Indexer

```yaml
wazuh_indexer_cluster_type: single-node  # or 'cluster'
wazuh_indexer_heap_size_min: 1g
wazuh_indexer_heap_size_max: 1g
```

### Wazuh Dashboard

```yaml
wazuh_dashboard_port: 443
wazuh_dashboard_username: admin
wazuh_dashboard_password: "SecurePassword123!"
wazuh_dashboard_ssl_enabled: true
```

### Wazuh Agent

```yaml
wazuh_agent_manager_ip: "192.168.1.100"
wazuh_agent_auth_method: password  # or 'certificate'
wazuh_agent_auth_password: "your-password"
```

### Docker Monitoring

```yaml
wazuh_monitor_docker: true
wazuh_docker_monitor_containers: true
wazuh_docker_monitor_events: true
wazuh_docker_fim_enabled: true
```

### Trivy Integration

```yaml
wazuh_trivy_integration: true
wazuh_trivy_scan_schedule: "0 */6 * * *"  # Every 6 hours
wazuh_trivy_severity_levels:
  - CRITICAL
  - HIGH
  - MEDIUM
```

## Example Playbooks

### All-in-One Installation

```yaml
---
- hosts: wazuh_server
  become: true
  roles:
    - role: wazuh
      vars:
        wazuh_install_mode: all-in-one
        wazuh_dashboard_password: "ChangeMe123!"
```

### Agent Only Installation

```yaml
---
- hosts: monitored_servers
  become: true
  roles:
    - role: wazuh
      vars:
        wazuh_install_mode: agent
        wazuh_agent_manager_ip: "192.168.1.100"
        wazuh_agent_auth_password: "agent-password"
        wazuh_monitor_docker: true
        wazuh_trivy_integration: true
```

### Distributed Installation

```yaml
---
# Indexer nodes
- hosts: wazuh_indexer
  become: true
  roles:
    - role: wazuh
      vars:
        wazuh_install_mode: indexer
        wazuh_indexer_cluster_type: cluster

# Manager node
- hosts: wazuh_manager
  become: true
  roles:
    - role: wazuh
      vars:
        wazuh_install_mode: manager

# Dashboard node
- hosts: wazuh_dashboard
  become: true
  roles:
    - role: wazuh
      vars:
        wazuh_install_mode: dashboard
```

## Features

### Comprehensive Monitoring

- **File Integrity Monitoring (FIM)**: Monitor critical system directories
- **Rootcheck**: Detect rootkits and system anomalies
- **Security Configuration Assessment (SCA)**: CIS benchmarks compliance
- **Log Analysis**: Real-time log monitoring and analysis
- **Vulnerability Detection**: Integrated CVE scanning

### Docker Monitoring

- Container lifecycle monitoring (start/stop/die events)
- Docker daemon log collection
- Container file integrity monitoring
- Docker socket security monitoring
- Container resource usage tracking

### Trivy Integration

- Automated vulnerability scanning of running containers
- Scheduled scans every 6 hours (configurable)
- Real-time reporting to Wazuh
- Severity-based alerting (CRITICAL, HIGH, MEDIUM)
- Integration with Wazuh rules engine

### Security Features

- SSL/TLS encryption with self-signed certificates
- Password or certificate-based agent authentication
- Active response for threat mitigation
- Email notifications for critical alerts
- Package version locking to prevent unwanted updates

## Accessing Wazuh

After installation:

**Dashboard**: `https://<server-ip>:443`
**API**: `https://<server-ip>:55000`
**Manager**: Port 1514 (agents), Port 1515 (enrollment)

Default credentials (change immediately):
- Username: `admin`
- Password: Value of `wazuh_dashboard_password`

## File Locations

- Configuration: `/var/ossec/etc/ossec.conf`
- Logs: `/var/ossec/logs/`
- Rules: `/var/ossec/etc/rules/`
- SSL Certificates: `/etc/wazuh-certificates/`

## Troubleshooting

### Check Service Status

```bash
systemctl status wazuh-manager
systemctl status wazuh-indexer
systemctl status wazuh-dashboard
systemctl status wazuh-agent
```

### View Logs

```bash
tail -f /var/ossec/logs/ossec.log
tail -f /var/log/wazuh-indexer/wazuh-cluster.log
```

### Test Agent Connection

```bash
/var/ossec/bin/agent_control -l
```

### Verify Docker Monitoring

```bash
docker ps
tail -f /var/ossec/logs/ossec.log | grep docker
```

### Check Trivy Integration

```bash
cat /var/log/trivy-wazuh.log
```

## License

MIT

## Author

Created for comprehensive security monitoring in home lab and production environments.
