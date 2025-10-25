# Proxmox VE Ansible Role

A comprehensive Ansible role for installing, configuring, and securing Proxmox Virtual Environment (VE) with support for clustering, storage backends, networking, backups, and security hardening.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Role Variables](#role-variables)
- [Dependencies](#dependencies)
- [Example Playbook](#example-playbook)
- [Usage](#usage)
- [Cluster Configuration](#cluster-configuration)
- [Storage Configuration](#storage-configuration)
- [Security Hardening](#security-hardening)
- [Testing](#testing)
- [License](#license)
- [Author](#author)

## Features

### Core Functionality
- ✅ Automated Proxmox VE installation (version 7.x, 8.x, 9.x)
- ✅ Repository configuration (no-subscription, enterprise, test)
- ✅ Kernel installation and IOMMU/PCI passthrough support
- ✅ Network configuration (bridges, VLANs, bonds, SDN)
- ✅ Storage backend configuration (NFS, CIFS, iSCSI, LVM, ZFS, Ceph)
- ✅ Cluster setup (create and join operations)
- ✅ High Availability (HA) configuration
- ✅ Backup scheduling and Proxmox Backup Server integration
- ✅ SSL/TLS certificate management (self-signed, ACME, custom)

### Security Features
- ✅ SSH hardening with key-based authentication
- ✅ Fail2ban integration for brute-force protection
- ✅ Proxmox firewall configuration with rules and IP sets
- ✅ System hardening with sysctl tuning
- ✅ AppArmor/SELinux support
- ✅ Audit logging for compliance
- ✅ Two-factor authentication (2FA) support
- ✅ Automatic security updates
- ✅ Password policy enforcement

### Management Features
- ✅ User and group management
- ✅ Access Control List (ACL) configuration
- ✅ API token generation
- ✅ Email notifications
- ✅ Remote syslog integration
- ✅ VM/CT template downloading
- ✅ Custom hooks and scripts

## Requirements

### System Requirements
- **OS**: Debian 11 (Bullseye), Debian 12 (Bookworm), or Ubuntu 20.04/22.04
- **Architecture**: x86_64 (AMD64)
- **RAM**: Minimum 2GB (4GB+ recommended)
- **Disk**: Minimum 10GB free space
- **CPU**: Hardware virtualization support (VT-x/AMD-V)
- **Network**: Static IP address recommended

### Ansible Requirements
- **Ansible**: 2.10 or higher
- **Python**: 3.6 or higher
- **Collections**:
  - `community.general` >= 11.2.1
  - `ansible.posix` >= 1.4.0

### Installation
```bash
ansible-galaxy collection install -r requirements.yml
```

## Role Variables

### General Configuration
```yaml
proxmox_version: "8.x"                      # Target Proxmox version
proxmox_subscription_type: "no-subscription" # no-subscription, enterprise, test
proxmox_hostname: "{{ ansible_hostname }}"
proxmox_domain: "{{ ansible_domain }}"
proxmox_fqdn: "{{ proxmox_hostname }}.{{ proxmox_domain }}"
```

### Cluster Configuration
```yaml
proxmox_cluster_enabled: false              # Enable cluster features
proxmox_cluster_create: false               # Create new cluster
proxmox_cluster_join: false                 # Join existing cluster
proxmox_cluster_name: "pve-cluster"
proxmox_cluster_master_node: ""             # IP/hostname of master node
proxmox_cluster_bindnet_addr: "{{ ansible_default_ipv4.address }}"
proxmox_cluster_link0_addr: "{{ ansible_default_ipv4.address }}"
proxmox_cluster_link1_addr: ""              # Optional redundant link
```

### Networking
```yaml
proxmox_network_configure: true
proxmox_network_bridges:
  - name: vmbr0
    type: bridge
    address: 192.168.1.100
    netmask: 255.255.255.0
    gateway: 192.168.1.1
    bridge_ports: eth0
    bridge_stp: "off"
    bridge_fd: 0
    comment: "Main bridge"
```

### Storage Backends
```yaml
proxmox_storage_backends:
  # NFS Storage
  - name: nfs-backup
    type: nfs
    server: 192.168.1.10
    export: /mnt/backup
    content: ["backup", "iso", "vztmpl"]
    maxfiles: 3

  # CIFS/SMB Storage
  - name: smb-storage
    type: cifs
    server: 192.168.1.20
    share: storage
    username: proxmox
    password: "{{ vault_smb_password }}"
    content: ["backup", "iso"]

  # ZFS Storage
  - name: zfs-pool
    type: zfspool
    pool: rpool/data
    content: ["images", "rootdir"]
    sparse: 1
```

### Security Settings
```yaml
proxmox_security_hardening: true
proxmox_ssh_port: 22
proxmox_ssh_permit_root_login: "prohibit-password"
proxmox_ssh_password_authentication: false
proxmox_fail2ban_enabled: true
proxmox_firewall_enabled: true
proxmox_sysctl_hardening: true
proxmox_audit_logging: true
```

### Firewall Rules
```yaml
proxmox_firewall_rules:
  - action: ACCEPT
    type: in
    proto: tcp
    dport: 22
    comment: "SSH access"
    enabled: 1
  - action: ACCEPT
    type: in
    proto: tcp
    dport: 8006
    comment: "Proxmox Web UI"
    enabled: 1
```

### Backup Configuration
```yaml
proxmox_backup_schedules:
  - vmid: "100"
    storage: local
    schedule: "0 2 * * *"  # Daily at 2 AM
    mode: snapshot
    compression: zstd
    retention:
      keep_last: 7
      keep_daily: 7
      keep_weekly: 4
      keep_monthly: 3
      keep_yearly: 1
```

### SSL/TLS Configuration
```yaml
proxmox_ssl_enabled: true
proxmox_ssl_certificate_source: "self-signed"  # self-signed, acme, custom
proxmox_ssl_acme_enabled: false
proxmox_ssl_acme_domain: "pve.example.com"
proxmox_ssl_acme_email: "admin@example.com"
```

For a complete list of variables, see [defaults/main.yml](defaults/main.yml).

## Dependencies

This role has no hard dependencies on other roles, but it works well with:
- `common` - Basic system setup
- `security_hardening` - Additional security measures
- `ntp` - Time synchronization

## Example Playbook

### Basic Installation
```yaml
---
- hosts: proxmox_nodes
  become: true
  roles:
    - role: proxmox
      vars:
        proxmox_subscription_type: "no-subscription"
        proxmox_security_hardening: true
```

### Cluster Setup
```yaml
---
# Create cluster on first node
- hosts: pve-node01
  become: true
  roles:
    - role: proxmox
      vars:
        proxmox_cluster_enabled: true
        proxmox_cluster_create: true
        proxmox_cluster_name: "homelab-cluster"

# Join cluster on other nodes
- hosts: pve-node02,pve-node03
  become: true
  serial: 1
  roles:
    - role: proxmox
      vars:
        proxmox_cluster_enabled: true
        proxmox_cluster_join: true
        proxmox_cluster_name: "homelab-cluster"
        proxmox_cluster_master_node: "192.168.1.101"
```

### Advanced Configuration
```yaml
---
- hosts: proxmox_nodes
  become: true
  roles:
    - role: proxmox
      vars:
        # Subscriptions
        proxmox_subscription_type: "no-subscription"
        proxmox_remove_subscription_notice: true

        # Security
        proxmox_security_hardening: true
        proxmox_fail2ban_enabled: true
        proxmox_firewall_enabled: true
        proxmox_ssh_password_authentication: false

        # SSL
        proxmox_ssl_enabled: true
        proxmox_ssl_certificate_source: "acme"
        proxmox_ssl_acme_enabled: true
        proxmox_ssl_acme_domain: "{{ ansible_fqdn }}"
        proxmox_ssl_acme_email: "admin@example.com"

        # Storage
        proxmox_storage_configure: true
        proxmox_storage_remove_local_lvm: true
        proxmox_storage_backends:
          - name: nfs-backup
            type: nfs
            server: 192.168.1.10
            export: /mnt/proxmox-backup
            content: ["backup", "iso", "vztmpl"]

        # Backups
        proxmox_backup_configure: true
        proxmox_backup_schedules:
          - vmid: "all"
            storage: nfs-backup
            schedule: "0 2 * * *"
            mode: snapshot
            compression: zstd
```

## Usage

### Installation
```bash
# Install the role
cd ansible
ansible-galaxy install -r requirements.yml

# Run the playbook
ansible-playbook playbooks/virtualization/proxmox_setup.yml

# Run with specific tags
ansible-playbook playbooks/virtualization/proxmox_setup.yml --tags proxmox_security

# Check mode (dry run)
ansible-playbook playbooks/virtualization/proxmox_setup.yml --check
```

### Available Tags
- `proxmox` - All Proxmox tasks
- `proxmox_preflight` - Preflight checks
- `proxmox_repository` - Repository configuration
- `proxmox_packages` - Package installation
- `proxmox_networking` - Network configuration
- `proxmox_storage` - Storage configuration
- `proxmox_cluster` - Cluster operations
- `proxmox_security` - Security hardening
- `proxmox_firewall` - Firewall configuration
- `proxmox_users` - User management
- `proxmox_ssl` - SSL/TLS configuration
- `proxmox_backup` - Backup configuration

## Cluster Configuration

### Creating a New Cluster
1. Run the role on the first node with `proxmox_cluster_create: true`
2. The cluster will be created with the specified name
3. Note the cluster join information

### Joining an Existing Cluster
1. Ensure the master node is accessible via SSH
2. Set `proxmox_cluster_join: true`
3. Specify `proxmox_cluster_master_node` (IP or hostname)
4. Run the role

### Cluster Requirements
- All nodes must have unique hostnames
- All nodes must resolve each other via DNS or `/etc/hosts`
- SSH key-based authentication between nodes
- Synchronized time (NTP)
- Network connectivity on cluster ports (5404-5405)

## Storage Configuration

### Supported Storage Types
- **dir** - Local directory
- **nfs** - Network File System
- **cifs** - CIFS/SMB shares
- **iscsi** - iSCSI targets
- **lvm** - Logical Volume Manager
- **lvmthin** - LVM thin provisioning
- **zfs** - ZFS filesystems
- **zfspool** - ZFS pools
- **rbd** - Ceph RADOS Block Device
- **cephfs** - Ceph Filesystem
- **glusterfs** - GlusterFS

### Storage Content Types
- `images` - VM disk images
- `rootdir` - Container root filesystems
- `vztmpl` - Container templates
- `backup` - Backup files
- `iso` - ISO images
- `snippets` - Snippets (cloud-init, hooks)

## Security Hardening

### Security Features Implemented
1. **SSH Hardening**
   - Key-based authentication
   - Disabled password authentication
   - Custom SSH port support
   - Root login restrictions

2. **Firewall**
   - Proxmox built-in firewall
   - Custom rules and IP sets
   - Security groups
   - Default deny policy

3. **Fail2ban**
   - Proxmox-specific filters
   - SSH protection
   - Configurable ban times

4. **System Hardening**
   - Sysctl tuning
   - Kernel parameter hardening
   - Disabled unnecessary services
   - AppArmor/SELinux enforcement

5. **Audit Logging**
   - Configuration change tracking
   - User activity logging
   - Security event monitoring

6. **Automatic Updates**
   - Security patches
   - Kernel updates
   - Configurable reboot schedules

## Testing

### Molecule Tests
```bash
# Install molecule
pip install molecule molecule-docker ansible-lint yamllint

# Run tests
cd ansible/roles/proxmox
molecule test

# Run specific scenarios
molecule converge        # Apply the role
molecule verify          # Run verification
molecule idempotence     # Test idempotence
```

### Ansible Lint
```bash
# Lint the role
cd ansible/roles/proxmox
ansible-lint

# Lint with specific rules
ansible-lint --strict
```

### Manual Testing
```bash
# Check syntax
ansible-playbook playbooks/virtualization/proxmox_setup.yml --syntax-check

# Dry run
ansible-playbook playbooks/virtualization/proxmox_setup.yml --check

# Run with verbosity
ansible-playbook playbooks/virtualization/proxmox_setup.yml -vvv
```

## Troubleshooting

### Common Issues

**Issue**: Cluster join fails
```bash
# Solution: Ensure SSH connectivity
ssh root@master-node pvecm status

# Check cluster ports are open
telnet master-node 5405
```

**Issue**: Proxmox web UI shows "no subscription" popup
```bash
# Solution: Set proxmox_remove_subscription_notice: true
```

**Issue**: Network configuration doesn't apply
```bash
# Solution: Reboot the system
proxmox_network_reboot_on_change: true
```

**Issue**: Storage backend not appearing
```bash
# Check storage configuration
pvesm status
cat /etc/pve/storage.cfg
```

## Best Practices

1. **Always use Ansible Vault for sensitive data**
   ```bash
   ansible-vault encrypt_string 'mypassword' --name 'vault_proxmox_password'
   ```

2. **Test in development first**
   - Use molecule tests
   - Run in check mode
   - Test on non-production nodes

3. **Use version control**
   - Track all configuration changes
   - Document customizations
   - Use git branches for testing

4. **Regular backups**
   - Configure automatic backups
   - Test restore procedures
   - Store backups off-site

5. **Monitor logs**
   - Enable audit logging
   - Configure remote syslog
   - Regular log reviews

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Ensure all tests pass
5. Submit a pull request

## License

MIT

## Author

Created by Sidney (via Claude Code)

## Support

For issues and questions:
- Create an issue in the repository
- Check the [Proxmox VE documentation](https://pve.proxmox.com/wiki/Main_Page)
- Review the molecule test scenarios

## Acknowledgments

- Proxmox VE team for the excellent virtualization platform
- Ansible community for the automation framework
- All contributors to this role
