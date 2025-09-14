# Ansible Infrastructure Project

This Ansible project provides a comprehensive framework for managing infrastructure with security-first approach.

## Quick Start

### 1. Install Dependencies
```bash
ansible-galaxy install -r requirements.yml
```

### 2. Configure Ansible Vault
```bash
# Create vault password file
echo "your-vault-password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Encrypt sensitive variables
ansible-vault encrypt group_vars/all/vault.yml
```

### 3. Update Inventory
Edit the inventory files in `inventories/` to match your infrastructure.

### 4. Deploy
```bash
# Run the main site playbook
ansible-playbook site.yml

# Test connectivity first
ansible all -m ping
```

## Project Structure

- `inventories/` - Environment-specific host definitions
- `group_vars/` - Group-specific variables
- `host_vars/` - Host-specific variables  
- `playbooks/` - Organized playbooks and runbooks
- `templates/` - Jinja2 configuration templates
- `roles/` - Custom Ansible roles
- `vault/` - Encrypted secrets management

## Security Features

- SSH key authentication only
- Ansible Vault for secrets
- Security hardening playbooks
- Firewall configuration
- Fail2ban integration
- Automatic security updates
