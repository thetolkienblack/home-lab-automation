# Ansible Role: NFS

A comprehensive Ansible role for installing and configuring NFS (Network File System) servers and clients on Debian/Ubuntu and RedHat/Rocky Linux systems.

## Features

- **Dual Mode Support**: Configure systems as NFS server, client, or both
- **Multi-OS Support**: Compatible with Debian/Ubuntu and RedHat/Rocky Linux families
- **NFSv3 and NFSv4**: Support for both NFS versions with NFSv4 as default
- **Flexible Export Configuration**: Define multiple NFS exports with granular client permissions
- **Flexible Mount Configuration**: Define multiple NFS mounts with custom options
- **Firewall Integration**: Automatic firewall configuration (UFW for Debian, firewalld for RedHat)
- **Idempotent**: Safe to run multiple times without side effects
- **Production Ready**: Passes ansible-lint with production profile
- **Fully Tested**: Includes comprehensive Molecule tests

## Requirements

- Ansible 2.12 or higher
- Target systems running one of:
  - Ubuntu 20.04 (Focal), 22.04 (Jammy), 24.04 (Noble)
  - Debian 11 (Bullseye), 12 (Bookworm)
  - RHEL/Rocky Linux 8, 9

### Required Collections

```yaml
collections:
  - community.general (>=11.2.1)
  - ansible.posix (>=1.4.0)
```

Install with: `ansible-galaxy collection install -r requirements.yml`

## Role Variables

### Mode Configuration

```yaml
# NFS role mode: 'server', 'client', or 'both'
nfs_mode: 'both'

# NFS version to use (3 or 4)
nfs_version: 4
```

### NFS Server Configuration

```yaml
# Enable NFS server functionality
nfs_server_enabled: true

# NFS exports configuration
nfs_exports:
  - path: /srv/nfs/shared
    clients:
      - host: "192.168.1.0/24"
        options: "rw,sync,no_subtree_check,no_root_squash"
      - host: "10.0.0.0/8"
        options: "ro,sync,no_subtree_check"
    owner: root
    group: root
    mode: '0755'
    create: true  # Create directory if it doesn't exist
```

**Export Options Explained:**
- `rw` - Read-write access
- `ro` - Read-only access
- `sync` - Synchronous writes (safer but slower)
- `async` - Asynchronous writes (faster but less safe)
- `no_subtree_check` - Disable subtree checking (recommended)
- `no_root_squash` - Allow root on client to access as root on server
- `root_squash` - Map client root to nobody (default, more secure)
- `all_squash` - Map all users to nobody

### NFS Client Configuration

```yaml
# Enable NFS client functionality
nfs_client_enabled: true

# NFS mounts configuration
nfs_mounts:
  - path: /mnt/nfs/shared
    src: "192.168.1.100:/srv/nfs/shared"
    fstype: nfs4
    opts: "rw,sync,hard,intr"
    state: mounted  # Options: mounted, present, unmounted, absent
    owner: root
    group: root
    mode: '0755'
```

**Mount Options Explained:**
- `hard` - Retry indefinitely on failure (recommended for data integrity)
- `soft` - Fail after retransmit attempts (use with caution)
- `intr` - Allow interruption of NFS calls
- `timeo=600` - Timeout in deciseconds (60 seconds)
- `retrans=2` - Number of retransmissions before timeout

### Service Management

```yaml
# Service state and startup configuration
nfs_service_state: started
nfs_service_enabled: true
```

### Firewall Configuration

```yaml
# Enable firewall configuration
nfs_configure_firewall: true

# Firewall zones (RedHat/Rocky only)
nfs_firewall_zones:
  - public
```

### NFSv4 Specific Settings

```yaml
# NFSv4 domain for ID mapping
nfs_idmapd_domain: "{{ ansible_domain | default('localdomain') }}"
```

### Performance Tuning (Advanced)

```yaml
# Number of NFS server threads
nfs_server_threads: 8

# Enable UDP (not recommended for NFSv4)
nfs_enable_udp: false

# Enable NFSv3
nfs_enable_v3: false

# Enable NFSv4
nfs_enable_v4: true
```

## Dependencies

None. This role is self-contained.

## Example Playbooks

### Configure NFS Server Only

```yaml
---
- name: Setup NFS server
  hosts: nfs_servers
  become: true
  roles:
    - role: nfs
      vars:
        nfs_mode: server
        nfs_exports:
          - path: /srv/nfs/data
            clients:
              - host: "192.168.1.0/24"
                options: "rw,sync,no_subtree_check"
            create: true
          - path: /srv/nfs/backup
            clients:
              - host: "192.168.1.10"
                options: "rw,sync,no_root_squash"
              - host: "192.168.1.0/24"
                options: "ro,sync"
            owner: backup
            group: backup
            mode: '0750'
            create: true
```

### Configure NFS Client Only

```yaml
---
- name: Setup NFS client
  hosts: nfs_clients
  become: true
  roles:
    - role: nfs
      vars:
        nfs_mode: client
        nfs_mounts:
          - path: /mnt/data
            src: "nfs-server.example.com:/srv/nfs/data"
            fstype: nfs4
            opts: "rw,sync,hard,intr"
            state: mounted
          - path: /mnt/backup
            src: "192.168.1.100:/srv/nfs/backup"
            fstype: nfs4
            opts: "ro,sync,hard,intr"
            state: mounted
```

### Configure Both Server and Client

```yaml
---
- name: Setup NFS server and client
  hosts: nfs_hybrid
  become: true
  roles:
    - role: nfs
      vars:
        nfs_mode: both
        nfs_exports:
          - path: /srv/nfs/shared
            clients:
              - host: "*"
                options: "rw,sync,no_subtree_check"
            create: true
        nfs_mounts:
          - path: /mnt/remote
            src: "other-server.example.com:/srv/nfs/data"
            fstype: nfs4
            opts: "rw,sync,hard,intr"
            state: mounted
```

### Using with Inventory Groups

Create inventory groups in `inventories/production.yml`:

```yaml
all:
  children:
    nfs_servers:
      hosts:
        nfs-server-01:
          ansible_host: 192.168.1.100
    nfs_clients:
      hosts:
        web-server-01:
          ansible_host: 192.168.1.101
        web-server-02:
          ansible_host: 192.168.1.102

  vars:
    # Global NFS configuration
    nfs_version: 4
    nfs_configure_firewall: true
```

Configure group variables in `group_vars/nfs_servers/nfs.yml`:

```yaml
---
nfs_mode: server
nfs_exports:
  - path: /srv/nfs/websites
    clients:
      - host: "192.168.1.101"
        options: "rw,sync,no_subtree_check,no_root_squash"
      - host: "192.168.1.102"
        options: "rw,sync,no_subtree_check,no_root_squash"
    create: true
```

Configure group variables in `group_vars/nfs_clients/nfs.yml`:

```yaml
---
nfs_mode: client
nfs_mounts:
  - path: /var/www/html/shared
    src: "192.168.1.100:/srv/nfs/websites"
    fstype: nfs4
    opts: "rw,sync,hard,intr"
    state: mounted
```

Run the playbook:

```bash
ansible-playbook -i inventories/production.yml playbooks/storage/nfs.yml
```

## File Locations

### Configuration Files

- **Debian/Ubuntu:**
  - NFS exports: `/etc/exports`
  - NFS server config: `/etc/default/nfs-kernel-server`
  - NFSv4 idmapd: `/etc/idmapd.conf`

- **RedHat/Rocky:**
  - NFS exports: `/etc/exports`
  - NFS server config: `/etc/nfs.conf`
  - NFSv4 idmapd: `/etc/idmapd.conf`

### Service Names

- **Debian/Ubuntu:**
  - NFS server: `nfs-kernel-server`
  - NFSv4 idmapd: `nfs-idmapd`

- **RedHat/Rocky:**
  - NFS server: `nfs-server`
  - NFSv4 idmapd: `nfs-idmapd`
  - RPC bind: `rpcbind`

## Verification

### Verify NFS Server

```bash
# Check NFS server status
sudo systemctl status nfs-kernel-server  # Debian/Ubuntu
sudo systemctl status nfs-server         # RedHat/Rocky

# List active exports
sudo exportfs -v

# Check exported filesystems
sudo showmount -e localhost

# Check NFS statistics
nfsstat -s
```

### Verify NFS Client

```bash
# Check mounted NFS shares
mount | grep nfs

# Verify mount point is accessible
df -h /mnt/nfs/shared

# Test read/write access
touch /mnt/nfs/shared/test.txt
ls -la /mnt/nfs/shared/test.txt
rm /mnt/nfs/shared/test.txt

# Check NFS statistics
nfsstat -c
```

### Verify Firewall

```bash
# Debian/Ubuntu
sudo ufw status | grep -E "(2049|111)"

# RedHat/Rocky
sudo firewall-cmd --list-services
sudo firewall-cmd --list-ports
```

## Testing

This role includes comprehensive Molecule tests for automated validation.

### Run Molecule Tests

```bash
# Install molecule and dependencies
pip install molecule molecule-docker docker

# Run full test suite
cd roles/nfs
molecule test

# Run individual test stages
molecule create      # Create test containers
molecule converge    # Apply the role
molecule verify      # Run verification tests
molecule destroy     # Clean up
```

### Test Platforms

The role is tested on:
- Ubuntu 22.04
- Debian 12

## Troubleshooting

### NFS Server Issues

**Problem:** Exports not showing up
```bash
# Reload exports
sudo exportfs -ra

# Check for errors in syslog
sudo tail -f /var/log/syslog  # Debian/Ubuntu
sudo tail -f /var/log/messages  # RedHat/Rocky
```

**Problem:** Permission denied on client
```bash
# Check export options
sudo exportfs -v

# Verify directory permissions on server
ls -la /srv/nfs/shared

# Check client IP is allowed
sudo cat /etc/exports
```

### NFS Client Issues

**Problem:** Mount hangs
```bash
# Check network connectivity
ping nfs-server-hostname

# Check if NFS server is reachable
showmount -e nfs-server-hostname

# Try manual mount with debug
sudo mount -t nfs4 -v nfs-server:/srv/nfs/shared /mnt/test
```

**Problem:** Stale file handle
```bash
# Unmount (may need force)
sudo umount -f /mnt/nfs/shared

# Remount
sudo mount /mnt/nfs/shared
```

### Network Issues

**Problem:** Connection refused
```bash
# Check firewall on server
sudo systemctl status ufw        # Debian/Ubuntu
sudo systemctl status firewalld  # RedHat/Rocky

# Verify NFS ports are open
sudo netstat -tulpn | grep -E "(2049|111)"
```

### NFSv4 ID Mapping Issues

**Problem:** Files owned by nobody:nogroup
```bash
# Check idmapd is running
sudo systemctl status nfs-idmapd

# Verify domain matches
grep Domain /etc/idmapd.conf

# Restart idmapd
sudo systemctl restart nfs-idmapd
```

## Security Considerations

1. **Network Security:**
   - Use firewall rules to restrict access to trusted networks
   - Consider using VPN or private network for NFS traffic
   - NFS doesn't encrypt data in transit (use Kerberos for encryption)

2. **Export Options:**
   - Avoid `no_root_squash` unless absolutely necessary
   - Use `ro` (read-only) when write access isn't needed
   - Be specific with client IP ranges instead of using `*`

3. **File Permissions:**
   - Set appropriate ownership and permissions on export directories
   - Consider using `all_squash` for shared directories

4. **SELinux (RedHat/Rocky):**
   - Ensure proper SELinux contexts for NFS directories
   - Use `setsebool -P nfs_export_all_rw on` if needed

## Performance Tips

1. **Use NFSv4:** Better performance and security than NFSv3
2. **Increase threads:** Adjust `nfs_server_threads` for high-traffic servers
3. **Use async carefully:** Only use `async` mount option for non-critical data
4. **Network tuning:** Ensure jumbo frames are enabled on 10G+ networks
5. **Use hard mounts:** Prefer `hard` over `soft` mounts for data integrity

## License

MIT

## Author Information

Created by Sidney for home lab automation.

## Contributing

Issues and pull requests are welcome. Please ensure:
- All changes pass `ansible-lint` with production profile
- Molecule tests pass
- Documentation is updated
