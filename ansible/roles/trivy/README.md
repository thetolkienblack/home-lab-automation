# Ansible Role: Trivy

This role installs and configures [Trivy](https://trivy.dev/) - A comprehensive vulnerability scanner for containers and other artifacts, configured to run daily scans with report generation.

## Requirements

- Ansible >= 2.15
- Docker installed and running (automatically installed via dependency)
- Supported OS:
  - Ubuntu 20.04+
  - Debian 11+
  - RHEL/Rocky Linux 8+

## Dependencies

This role depends on the `docker` role, which will be automatically executed before Trivy installation. The docker role ensures Docker is installed and running on the target system.

## Role Variables

### Installation Settings

```yaml
# Installation method: 'repository' (recommended) or 'binary'
trivy_install_method: repository

# Trivy version (leave empty for latest)
trivy_version: ""
```

### Directory Configuration

```yaml
# Cache and data directories
trivy_cache_dir: /var/lib/trivy/cache
trivy_data_dir: /var/lib/trivy/db
trivy_reports_dir: /var/log/trivy
trivy_config_dir: /etc/trivy
```

### Scan Configuration

```yaml
# Enable daily automated scans
trivy_enable_daily_scans: true
trivy_scan_schedule: "0 2 * * *"  # Daily at 2 AM

# Scan running containers
trivy_scan_running_containers: true

# Scan specific Docker images
trivy_docker_images_to_scan:
  - nginx:latest
  - alpine:latest

# Scan filesystem paths
trivy_scan_filesystem: false
trivy_filesystem_paths:
  - /opt/application
```

### Report Settings

```yaml
# Report format: json, table, sarif, cyclonedx, spdx
trivy_report_format: json

# Report retention in days
trivy_report_retention_days: 30

# Severity levels to report
trivy_severity_levels:
  - CRITICAL
  - HIGH
  - MEDIUM
  - LOW
```

### Vulnerability Types

```yaml
# Types of vulnerabilities to scan
trivy_vuln_types:
  - os
  - library
```

## Dependencies

None - Trivy is installed from official repositories or binary releases.

## Example Playbook

### Basic Installation

```yaml
---
- hosts: docker_hosts
  become: true
  roles:
    - role: trivy
      vars:
        trivy_enable_daily_scans: true
        trivy_scan_running_containers: true
```

### Scan Specific Images

```yaml
---
- hosts: docker_hosts
  become: true
  roles:
    - role: trivy
      vars:
        trivy_enable_daily_scans: true
        trivy_docker_images_to_scan:
          - nginx:latest
          - postgres:15
          - redis:alpine
        trivy_severity_levels:
          - CRITICAL
          - HIGH
```

### Custom Schedule and Retention

```yaml
---
- hosts: docker_hosts
  become: true
  roles:
    - role: trivy
      vars:
        trivy_enable_daily_scans: true
        trivy_scan_schedule: "0 3 * * *"  # 3 AM daily
        trivy_report_retention_days: 60
        trivy_report_format: json
```

### Filesystem Scanning

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: trivy
      vars:
        trivy_scan_running_containers: true
        trivy_scan_filesystem: true
        trivy_filesystem_paths:
          - /opt/application
          - /var/www/html
```

## Daily Scans

The role automatically configures:

1. **Daily Scan Script** (`/usr/local/bin/trivy-scan.sh`)
   - Scans running containers (if enabled)
   - Scans specified Docker images
   - Scans filesystem paths (if enabled)
   - Generates timestamped reports

2. **Cron Job**
   - Runs daily at configured time (default: 2 AM)
   - Logs output to `/var/log/trivy/scan.log`

3. **Report Cleanup**
   - Automatically removes reports older than retention period
   - Runs daily at 3 AM
   - Keeps last 10 cleanup logs

## Reports

Reports are stored in `/var/log/trivy/` with filenames like:

- `container_<name>_<timestamp>.json` - Container scan reports
- `image_<name>_<timestamp>.json` - Image scan reports
- `filesystem_<path>_<timestamp>.json` - Filesystem scan reports
- `scan_<timestamp>.log` - Scan execution logs

## Manual Scanning

### Scan a Docker Image

```bash
trivy image nginx:latest
```

### Scan a Running Container

```bash
trivy image $(docker inspect --format='{{.Config.Image}}' container_name)
```

### Scan Filesystem

```bash
trivy fs /path/to/directory
```

### Run the Daily Scan Manually

```bash
/usr/local/bin/trivy-scan.sh
```

## Testing

This role includes Molecule tests:

```bash
cd roles/trivy
molecule test

# Run specific scenarios
molecule converge
molecule verify
molecule destroy
```

## Trivy Database

The role automatically:
- Downloads the Trivy vulnerability database
- Updates the database during installation
- Caches the database in `/var/lib/trivy/db`

To manually update the database:

```bash
trivy image --download-db-only
```

## Troubleshooting

### Check Trivy Version

```bash
trivy --version
```

### View Scan Logs

```bash
tail -f /var/log/trivy/scan.log
```

### Check Cron Jobs

```bash
crontab -l
```

### Manual Test Scan

```bash
trivy image --severity HIGH,CRITICAL alpine:latest
```

### Check Docker Access

```bash
docker ps
```

## License

MIT

## Author Information

Created for automated vulnerability scanning in home lab and production environments.
