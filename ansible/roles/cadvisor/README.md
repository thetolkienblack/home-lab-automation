# Ansible Role: cAdvisor

This role installs and configures [cAdvisor](https://github.com/google/cadvisor) (Container Advisor) for monitoring container resource usage and performance metrics on Debian and RHEL-based systems.

## Requirements

- Ansible >= 2.15
- Docker (if using Docker installation method)
- Supported OS:
  - Ubuntu 20.04+
  - Debian 11+
  - RHEL/Rocky Linux 8+

## Role Variables

### Installation Settings

```yaml
# Installation method: 'docker' or 'binary'
cadvisor_install_method: docker

# cAdvisor version
cadvisor_version: v0.47.0

# Docker image
cadvisor_docker_image: gcr.io/cadvisor/cadvisor
cadvisor_docker_container_name: cadvisor
cadvisor_docker_restart_policy: unless-stopped
```

### Network Settings

```yaml
# Network configuration
cadvisor_port: 8080
cadvisor_bind_address: "0.0.0.0"
```

### Storage Settings

```yaml
# Storage and performance settings
cadvisor_storage_duration: 2m0s
cadvisor_housekeeping_interval: 10s
```

### Firewall Settings

```yaml
# Firewall configuration
cadvisor_configure_firewall: false
cadvisor_firewall_zone: public
```

### Binary Installation Settings

```yaml
# Binary installation (alternative to Docker)
cadvisor_binary_path: /usr/local/bin/cadvisor
cadvisor_user: cadvisor
cadvisor_group: cadvisor
cadvisor_create_user: true
```

## Dependencies

- `community.docker` collection (for Docker installation method)
- `community.general` collection (for firewall management)
- `ansible.posix` collection (for RHEL firewall)

Install collections:

```bash
ansible-galaxy collection install community.docker community.general ansible.posix
```

## Example Playbook

### Docker Installation (Recommended)

```yaml
---
- hosts: monitoring_servers
  become: true
  roles:
    - role: cadvisor
      vars:
        cadvisor_install_method: docker
        cadvisor_port: 8080
        cadvisor_configure_firewall: true
```

### Binary Installation

```yaml
---
- hosts: monitoring_servers
  become: true
  roles:
    - role: cadvisor
      vars:
        cadvisor_install_method: binary
        cadvisor_port: 8080
        cadvisor_create_user: true
```

### Custom Configuration

```yaml
---
- hosts: monitoring_servers
  become: true
  roles:
    - role: cadvisor
      vars:
        cadvisor_install_method: docker
        cadvisor_port: 9090
        cadvisor_bind_address: "127.0.0.1"
        cadvisor_storage_duration: 5m0s
        cadvisor_housekeeping_interval: 5s
        cadvisor_configure_firewall: true
        cadvisor_docker_privileged: false
```

## Accessing cAdvisor

After installation, cAdvisor will be accessible at:

- Web UI: `http://<server-ip>:8080/`
- Metrics: `http://<server-ip>:8080/metrics`
- API: `http://<server-ip>:8080/api/v1.3/machine`

## Testing

This role includes Molecule tests for both Debian and RHEL-based systems.

```bash
# Run tests
cd roles/cadvisor
molecule test

# Run specific scenario
molecule converge
molecule verify
```

## License

MIT

## Author Information

Created for home lab automation and monitoring infrastructure.
