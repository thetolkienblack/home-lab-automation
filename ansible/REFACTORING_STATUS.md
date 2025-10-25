# Ansible Refactoring Status

## ✅ Completed Tasks

### Security Fixes
- [x] **Encrypted vault file** - `inventories/group_vars/all/vault.yml` is now encrypted with ansible-vault
- [x] **Fixed duplicate host** - Removed duplicate `skynet` entry in `inventories/production.yml`
- [x] **Fixed empty host_vars files** - Added minimal YAML structure to all empty host_vars files
- [x] **Added .gitignore** - Created comprehensive gitignore for Ansible artifacts and sensitive files
- [x] **SSH agent support** - Added `scripts/setup-ssh-agent.sh` helper script
- [x] **Updated ansible.cfg** - Added SSH agent forwarding support with ForwardAgent=yes

### Configuration & Documentation
- [x] **ansible-lint configuration** - `.ansible-lint` with production profile
- [x] **yamllint configuration** - `.yamllint` for YAML formatting standards
- [x] **Pre-commit hooks** - `.pre-commit-config.yaml` for automated quality checks
- [x] **Comprehensive README** - `README.md` with full documentation

### Role Structure
- [x] **Created 6 roles** - All role directories initialized with ansible-galaxy
  - common (✅ Complete with tasks and defaults)
  - docker (⏳ Structure only)
  - security_hardening (⏳ Structure only)
  - tailscale (⏳ Structure only)
  - ntp (⏳ Structure only)
  - maintenance (⏳ Structure only)

## ⏳ Remaining Tasks

### Role Implementation
The following roles need to have their tasks, defaults, handlers, and templates populated by migrating code from the existing playbooks:

#### 1. Docker Role (`roles/docker/`)
**Source:** `playbooks/docker/install_docker.yml`

**Tasks to migrate:**
- Docker repository setup (Debian and RHEL)
- Docker package installation
- Docker daemon configuration
- Docker service management
- User group management
- Log rotation setup

**Files to create:**
- `tasks/main.yml` - Main task orchestration
- `tasks/debian.yml` - Debian-specific installation
- `tasks/rhel.yml` - RHEL-specific installation
- `defaults/main.yml` - Docker configuration variables
- `handlers/main.yml` - Docker service restart handlers
- `templates/daemon.json.j2` - Copy from `templates/virt/containers/`
- `templates/seccomp.json.j2` - Copy from `templates/virt/containers/`

#### 2. Security Hardening Role (`roles/security_hardening/`)
**Source:** `playbooks/security/system_hardening.yml`

**Tasks to migrate:**
- SSH configuration
- Firewall setup (UFW/firewalld)
- Fail2ban configuration
- Unattended upgrades
- Sysctl security parameters
- TCP wrappers
- Log rotation

**Files to create:**
- `tasks/main.yml`
- `tasks/ssh.yml`
- `tasks/firewall.yml`
- `tasks/fail2ban.yml`
- `defaults/main.yml`
- `handlers/main.yml`
- `templates/sshd_config.j2` - Copy from `templates/security/ssh/`
- `templates/jail.local.j2` - Copy from `templates/security/ssh/`

#### 3. Tailscale Role (`roles/tailscale/`)
**Source:** `playbooks/networking/tailscale_setup.yml`

**Tasks to migrate:**
- Repository setup
- Package installation
- Service configuration
- Authentication
- Network configuration

**Files to create:**
- `tasks/main.yml`
- `tasks/debian.yml`
- `tasks/rhel.yml`
- `defaults/main.yml`
- `handlers/main.yml`
- `templates/tailscale_daemon.j2` - Copy from `templates/system/networking/`

#### 4. NTP Role (`roles/ntp/`)
**Source:** `playbooks/system/ntp_timezone_config.yml`

**Tasks to migrate:**
- Timezone configuration
- NTP service installation (chronyd/timesyncd)
- NTP configuration
- Firewall rules for NTP

**Files to create:**
- `tasks/main.yml`
- `tasks/debian.yml` - systemd-timesyncd configuration
- `tasks/rhel.yml` - chronyd configuration
- `defaults/main.yml`
- `handlers/main.yml`
- `templates/chrony.conf.j2` - Copy from `templates/system/ntp/`
- `templates/timesyncd.conf.j2` - Copy from `templates/system/ntp/`

#### 5. Maintenance Role (`roles/maintenance/`)
**Source:** `playbooks/maintenance/system_maintenance.yml`

**Tasks to migrate:**
- Package updates
- System cleanup
- Disk space monitoring
- Memory/CPU reporting

**Files to create:**
- `tasks/main.yml`
- `tasks/updates.yml`
- `tasks/cleanup.yml`
- `defaults/main.yml`

### Molecule Testing
Each role should have Molecule tests configured:

```bash
cd roles/<role_name>
molecule init scenario
```

Then customize:
- `molecule/default/molecule.yml` - Test configuration
- `molecule/default/converge.yml` - Role application
- `molecule/default/verify.yml` - Test assertions

### Playbook Refactoring
Update existing playbooks to use roles instead of inline tasks:

**Example transformation:**

**Before:**
```yaml
---
- name: Install Docker
  hosts: all
  become: true
  tasks:
    - name: Install Docker packages
      ansible.builtin.package:
        name: docker-ce
        state: present
```

**After:**
```yaml
---
- name: Install Docker
  hosts: all
  become: true
  roles:
    - common
    - docker
```

**Playbooks to refactor:**
- ✅ `playbooks/maintenance/system_maintenance.yml` - Use common + maintenance roles
- ⏳ `playbooks/docker/install_docker.yml` - Use docker role
- ⏳ `playbooks/security/system_hardening.yml` - Use security_hardening role
- ⏳ `playbooks/networking/tailscale_setup.yml` - Use tailscale role
- ⏳ `playbooks/system/ntp_timezone_config.yml` - Use ntp role

## 📋 Quick Reference Commands

### Using SSH Agent
```bash
# Setup SSH agent
./scripts/setup-ssh-agent.sh

# Verify keys loaded
ssh-add -l
```

### Working with Vault
```bash
# View vault
ansible-vault view inventories/group_vars/all/vault.yml

# Edit vault
ansible-vault edit inventories/group_vars/all/vault.yml

# Encrypt new file
ansible-vault encrypt path/to/file.yml
```

### Testing Roles with Molecule
```bash
cd roles/docker
molecule create    # Create test instance
molecule converge  # Apply role
molecule verify    # Run tests
molecule destroy   # Cleanup
```

### Running Playbooks
```bash
# With vault password
ansible-playbook playbooks/docker/install_docker.yml --ask-vault-pass

# With tags
ansible-playbook playbooks/security/system_hardening.yml --tags ssh,firewall

# Check mode (dry run)
ansible-playbook playbooks/maintenance/system_maintenance.yml --check
```

### Linting
```bash
# Lint all playbooks and roles
ansible-lint

# Lint specific file
ansible-lint playbooks/docker/install_docker.yml

# YAML linting
yamllint .
```

## 🚀 Next Steps

1. **Complete Docker Role**
   ```bash
   # Start with docker role as it's commonly used
   cd roles/docker
   # Copy tasks from playbooks/docker/install_docker.yml
   # Add Molecule tests
   molecule init scenario
   ```

2. **Install Pre-commit Hooks**
   ```bash
   pre-commit install
   ```

3. **Test in Development Environment**
   ```bash
   ansible-playbook -i inventories/development.yml playbooks/maintenance/system_maintenance.yml
   ```

4. **Refactor One Playbook at a Time**
   - Migrate tasks to role
   - Update playbook to use role
   - Test thoroughly
   - Move to next playbook

5. **Add Molecule Tests**
   - Create test scenarios
   - Add verification tests
   - Run full test suite

## 📝 Notes

- The `common` role is complete and ready to use
- All existing playbooks are still functional
- Role migration should be done incrementally
- Test each role thoroughly before deploying to production
- Keep backups of working playbooks during migration

## 🔗 Resources

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Ansible Lint Rules](https://ansible-lint.readthedocs.io/rules/)

---

**Last Updated:** October 24, 2025
**Status:** Phase 1 Complete - Documentation and infrastructure ready for role implementation
