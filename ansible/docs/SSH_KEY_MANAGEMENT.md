# SSH Key Management

The `security_hardening` role provides comprehensive SSH key management for any user on your systems.

## Features

- ✅ Configure SSH keys for **any user** (root, deploy, developers, etc.)
- ✅ Create users automatically if they don't exist
- ✅ Exclusive mode (removes all other keys) or additive mode
- ✅ Remove specific keys
- ✅ Backup existing keys before modification
- ✅ Secure storage in Ansible Vault
- ✅ Custom shells, groups, and home directories per user
- ✅ Tag-based execution (`--tags ssh_keys`)

## Configuration

### Simple Example - Single User

```yaml
# In inventories/group_vars/all/vault.yml
ssh_users:
  - user: root
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey admin@workstation"
```

### Complete Example - Multiple Users

```yaml
# In inventories/group_vars/all/vault.yml
ssh_users:
  # Root user
  - user: root
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdminKey admin@workstation"
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBackupKey backup@backup-server"
    exclusive: false  # Don't remove other existing keys

  # Deployment user (will be created if doesn't exist)
  - user: deploy
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICIDeployKey deploy@ci-cd"
    exclusive: false
    ensure_user: true  # Create user if missing
    shell: /bin/bash
    groups: [sudo, docker]

  # Developer user with exclusive keys
  - user: developer
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDevKey1 dev1@laptop"
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDevKey2 dev2@laptop"
    exclusive: true  # Remove ALL other keys for this user
    ensure_user: true
    shell: /bin/zsh
    groups: [developers, docker]
    remove_keys:  # Explicitly remove these keys if present
      - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABOldKey old@deprecated"

  # Monitoring user with custom home
  - user: monitoring
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMonitorKey monitoring@prometheus"
    exclusive: true
    ensure_user: true
    home: /opt/monitoring
    shell: /bin/sh
    groups: [monitoring]
```

### Host-Specific Configuration

```yaml
# In inventories/host_vars/webserver01.yml
ssh_users:
  - user: webadmin
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIWebKey webadmin@ops"
    ensure_user: true
    groups: [www-data, docker]
```

## Configuration Parameters

### Per-User Options

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `user` | ✅ Yes | - | Username (root or any other user) |
| `authorized_keys` | ✅ Yes | - | List of SSH public keys |
| `exclusive` | No | `false` | If true, removes all other keys |
| `ensure_user` | No | `true` | Create user if doesn't exist (ignored for root) |
| `shell` | No | `/bin/bash` | User's default shell |
| `groups` | No | `[]` | Additional groups for the user |
| `home` | No | auto | Custom home directory path |
| `remove_keys` | No | `[]` | List of keys to explicitly remove |

### Global Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ssh_backup_keys` | `false` | Backup existing authorized_keys before changes |

## Usage Examples

### 1. Deploy Keys to Root Only

```bash
# Edit vault
ansible-vault edit inventories/group_vars/all/vault.yml

# Add configuration
ssh_users:
  - user: root
    authorized_keys:
      - "ssh-ed25519 AAAAC3... your-key"

# Deploy
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh_keys
```

### 2. Create New User with SSH Access

```bash
# Configuration in vault
ssh_users:
  - user: newuser
    authorized_keys:
      - "ssh-ed25519 AAAAC3... newuser-key"
    ensure_user: true
    shell: /bin/bash
    groups: [sudo]

# Deploy
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh_keys
```

### 3. Replace All Keys (Exclusive Mode)

```bash
# ⚠️ WARNING: This removes ALL other keys!
ssh_users:
  - user: root
    authorized_keys:
      - "ssh-ed25519 AAAAC3... only-this-key"
    exclusive: true

# Deploy with backup enabled
ssh_backup_keys: true

# Run deployment
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh_keys
```

### 4. Remove Specific Old Keys

```bash
ssh_users:
  - user: deploy
    authorized_keys:
      - "ssh-ed25519 AAAAC3... new-key"
    remove_keys:
      - "ssh-rsa AAAAB3... old-key-to-remove"
      - "ssh-rsa AAAAB3... another-old-key"

# Deploy
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh_keys
```

### 5. Enable Backup Before Changes

```bash
# In group_vars/all/main.yml or vault
ssh_backup_keys: true

# This will create backups like:
# /root/.ssh/authorized_keys.backup.1729891234
# /home/deploy/.ssh/authorized_keys.backup.1729891234
```

## Security Best Practices

### 1. Always Use Ansible Vault

```bash
# Encrypt vault file
ansible-vault encrypt inventories/group_vars/all/vault.yml

# Edit encrypted vault
ansible-vault edit inventories/group_vars/all/vault.yml

# View encrypted vault
ansible-vault view inventories/group_vars/all/vault.yml
```

### 2. Use ED25519 Keys (Recommended)

```bash
# Generate modern SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key
cat ~/.ssh/id_ed25519.pub
```

### 3. Test Before Production

```bash
# Dry-run mode
ansible-playbook -i inventories/development.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh_keys \
  --check

# Apply to single dev host
ansible-playbook -i inventories/development.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh_keys \
  --limit dev-host-01
```

### 4. Enable Backups for Exclusive Mode

```yaml
# When using exclusive mode, ALWAYS enable backups
ssh_backup_keys: true

ssh_users:
  - user: root
    authorized_keys:
      - "ssh-ed25519 AAAAC3... only-key"
    exclusive: true  # ⚠️ Removes all other keys!
```

## Migration from Old Playbooks

### Migrating from `update_ssh_keys.yml`

**Old format:**
```yaml
ssh_users:
  - name: deploy
    authorized_keys:
      - "ssh-ed25519 AAAAC3... key1"
```

**New format:**
```yaml
ssh_users:
  - user: deploy  # Changed from 'name' to 'user'
    authorized_keys:
      - "ssh-ed25519 AAAAC3... key1"
```

### Migration Script

```bash
# 1. Backup current configuration
ansible all -i inventories/production.yml \
  -m shell -a "cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.migration.backup"

# 2. Extract current keys
ansible all -i inventories/production.yml \
  -m shell -a "cat /root/.ssh/authorized_keys"

# 3. Update vault with new format
ansible-vault edit inventories/group_vars/all/vault.yml

# 4. Deploy with backup enabled
ansible-playbook -i inventories/production.yml \
  playbooks/security/system_hardening_role.yml \
  --tags ssh_keys \
  -e "ssh_backup_keys=true"
```

## Verification

```bash
# Check deployed keys for root
ansible all -i inventories/production.yml \
  -m shell -a "cat /root/.ssh/authorized_keys"

# Check deployed keys for specific user
ansible all -i inventories/production.yml \
  -m shell -a "cat /home/deploy/.ssh/authorized_keys" \
  -b

# Test SSH access
ssh -i ~/.ssh/id_ed25519 root@hostname
ssh -i ~/.ssh/id_ed25519 deploy@hostname
```

## Troubleshooting

### Keys Not Working

1. **Check file permissions:**
   ```bash
   ansible all -i inventories/production.yml \
     -m shell -a "ls -la /root/.ssh/" -b
   # Should be: drwx------ (700) for directory
   # Should be: -rw------- (600) for authorized_keys
   ```

2. **Check key format:**
   ```bash
   # Public keys should start with:
   ssh-ed25519 AAAAC3...
   ssh-rsa AAAAB3...
   # NOT with extra quotes or line breaks
   ```

3. **View SSH daemon logs:**
   ```bash
   tail -f /var/log/auth.log  # Debian/Ubuntu
   tail -f /var/log/secure    # RHEL/CentOS
   ```

### Locked Out After Exclusive Mode

If you set `exclusive: true` and locked yourself out:

1. Use console access (physical or hosting provider dashboard)
2. Manually restore from backup:
   ```bash
   ls -la /root/.ssh/authorized_keys.backup.*
   cp /root/.ssh/authorized_keys.backup.NEWEST /root/.ssh/authorized_keys
   chmod 600 /root/.ssh/authorized_keys
   ```

### User Creation Failed

```bash
# Check if user exists
ansible all -i inventories/production.yml \
  -m shell -a "id deploy"

# Manually create user if needed
ansible all -i inventories/production.yml \
  -m user -a "name=deploy shell=/bin/bash groups=sudo" -b
```

## Complete Working Example

```yaml
# inventories/group_vars/all/vault.yml
---
# SSH user configuration
ssh_backup_keys: true

ssh_users:
  # System administrator
  - user: root
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdminKey1 admin1@workstation"
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdminKey2 admin2@workstation"
    exclusive: false

  # CI/CD deployment user
  - user: deploy
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICIDeployKey deploy@jenkins"
    exclusive: true
    ensure_user: true
    shell: /bin/bash
    groups: [sudo, docker]

  # Development team
  - user: devteam
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDev1 dev1@laptop"
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDev2 dev2@laptop"
    exclusive: false
    ensure_user: true
    groups: [developers]
    remove_keys:
      - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABOldDev old-dev@retired"
```

---

**Last Updated**: October 25, 2025
**Role**: security_hardening
**Tags**: ssh, ssh_keys, ssh_users, ssh_backup, ssh_remove
