# Deprecated Playbooks

These playbooks have been refactored into reusable roles located in `roles/`.

## ⚠️ Do Not Use These Playbooks

All functionality has been migrated to role-based playbooks with improved:
- ✅ Modularity and reusability
- ✅ Testing with Molecule
- ✅ Better organization
- ✅ Tag-based execution
- ✅ Enhanced features

## Migration Guide

### Old → New Playbook Mappings

| Old Playbook | New Playbook | Role(s) Used |
|--------------|--------------|--------------|
| `install_docker.yml` | `playbooks/docker/install_docker_role.yml` | common, docker |
| `system_maintenance.yml` | `playbooks/maintenance/system_maintenance_role.yml` | common, maintenance |
| `ntp_timezone_config.yml` | `playbooks/system/ntp_timezone_config_role.yml` | common, ntp |
| `tailscale_setup.yml` | `playbooks/networking/tailscale_setup_role.yml` | common, tailscale |
| `system_hardening.yml` | `playbooks/security/system_hardening_role.yml` | common, security_hardening |
| `update_ssh_keys.yml` | Use `system_hardening_role.yml --tags ssh_keys` | security_hardening |

### Usage Examples

**Old way:**
```bash
ansible-playbook -i inventories/production.yml playbooks/docker/install_docker.yml
```

**New way:**
```bash
ansible-playbook -i inventories/production.yml playbooks/docker/install_docker_role.yml
```

## New Features in Role-Based Playbooks

### SSH Key Management (replaces `update_ssh_keys.yml`)

Now uses improved `ssh_users` configuration:

```yaml
# Old format (deprecated)
ssh_users:
  - name: deploy
    authorized_keys: [...]

# New format (current)
ssh_users:
  - user: deploy  # Works for root and any other user
    authorized_keys: [...]
    ensure_user: true
    shell: /bin/bash
    groups: [sudo, docker]
```

See `docs/SSH_KEY_MANAGEMENT.md` for complete documentation.

### Tag-Based Execution

All new playbooks support granular tag-based execution:

```bash
# Only update packages
ansible-playbook playbooks/maintenance/system_maintenance_role.yml --tags updates

# Only configure SSH
ansible-playbook playbooks/security/system_hardening_role.yml --tags ssh

# Only deploy SSH keys
ansible-playbook playbooks/security/system_hardening_role.yml --tags ssh_keys
```

### Testing with Molecule

All roles now have Molecule test suites:

```bash
cd roles/docker
molecule test

cd roles/security_hardening
molecule test
```

## Documentation

- **Quick Start**: `docs/QUICK_START.md`
- **SSH Key Management**: `docs/SSH_KEY_MANAGEMENT.md`
- **Implementation Progress**: `IMPLEMENTATION_PROGRESS.md`
- **Refactoring Status**: `REFACTORING_STATUS.md`

## Removal Timeline

These deprecated playbooks will be **removed** in a future release once all production systems have migrated to role-based playbooks.

**Migration deadline**: None set yet - use at your own pace

---

**Deprecated**: October 25, 2025
**Reason**: Refactored into modular roles for better maintainability and reusability
