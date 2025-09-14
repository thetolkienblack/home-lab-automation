#!/bin/bash

# Ansible Project Structure Generator - Clean Working Version
# Creates a comprehensive Ansible project structure for runbooks and host management
# Author: DevOps Engineer
# Version: 1.0

set -euo pipefail

# Default values
PROJECT_NAME=""
VAULT_PASSWORD_FILE=""
SSH_KEY_PATH=""
CREATE_VAULT_FILE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage
usage() {
    cat << EOF
Usage: $0 -n PROJECT_NAME [-v VAULT_PASSWORD_FILE] [-k SSH_KEY_PATH] [-c]

Options:
    -n, --name              Project name (required)
    -v, --vault-password    Path to vault password file (optional)
    -k, --ssh-key          Path to SSH private key (optional)
    -c, --create-vault     Create initial vault file with sample secrets
    -h, --help             Show this help message

Examples:
    $0 -n infrastructure-automation
    $0 -n my-ansible-project -v ~/.ansible_vault_pass -k ~/.ssh/ansible_key -c
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -v|--vault-password)
                VAULT_PASSWORD_FILE="$2"
                shift 2
                ;;
            -k|--ssh-key)
                SSH_KEY_PATH="$2"
                shift 2
                ;;
            -c|--create-vault)
                CREATE_VAULT_FILE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                usage
                exit 1
                ;;
        esac
    done

    if [[ -z "$PROJECT_NAME" ]]; then
        echo -e "${RED}Error: Project name is required${NC}"
        usage
        exit 1
    fi
}

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create directory structure
create_directories() {
    print_status "Creating directory structure for project: $PROJECT_NAME"
    
    # Main project directory
    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    
    # Core directories
    mkdir -p {inventories/{production,development},group_vars,host_vars}
    mkdir -p {roles,collections,library,filter_plugins,callback_plugins}
    mkdir -p {playbooks/{runbooks,maintenance,deployment,security},templates,files}
    mkdir -p {vault,logs,docs,scripts}
    
    # OS-specific variable directories
    mkdir -p group_vars/{all,debian,redhat,ubuntu,centos,rhel}
    mkdir -p host_vars/example
    
    # Runbook categories
    mkdir -p playbooks/runbooks/{system,security,monitoring,backup,network,application}
    mkdir -p playbooks/maintenance/{updates,cleanup,optimization}
    mkdir -p playbooks/deployment/{web,database,monitoring}
    mkdir -p playbooks/security/{hardening,compliance,audit}
    
    # Template directories by service
    mkdir -p templates/{ssh,firewall,monitoring,web,database,security}
    
    print_status "Directory structure created successfully"
}

# Create ansible.cfg
create_ansible_config() {
    print_status "Creating ansible.cfg configuration file"
    
    # Set default paths
    local vault_file="~/.ansible_vault_pass"
    local ssh_key="~/.ssh/ansible_key"
    
    # Use provided paths if available
    if [[ -n "$VAULT_PASSWORD_FILE" ]]; then
        vault_file="$VAULT_PASSWORD_FILE"
    fi
    
    if [[ -n "$SSH_KEY_PATH" ]]; then
        ssh_key="$SSH_KEY_PATH"
    fi
    
    cat > ansible.cfg << EOF
[defaults]
# Basic Configuration
inventory = inventories/production/hosts.yml
remote_user = ansible
host_key_checking = False
timeout = 30
forks = 10
gather_facts = True
gathering = smart
fact_caching = jsonfile
fact_caching_connection = .facts_cache
fact_caching_timeout = 86400

# Security Settings
private_key_file = $ssh_key
vault_password_file = $vault_file

# Logging
log_path = logs/ansible.log
display_skipped_hosts = False
display_ok_hosts = True

# Plugins and Collections
collections_paths = ./collections:~/.ansible/collections:/usr/share/ansible/collections
roles_path = ./roles:~/.ansible/roles:/usr/share/ansible/roles
library = ./library
filter_plugins = ./filter_plugins
callback_plugins = ./callback_plugins

# Performance
pipelining = True
control_path_dir = /tmp/.ansible-cp
control_path = %(directory)s/%%h-%%p-%%r

# Callback plugins
stdout_callback = yaml
bin_ansible_callbacks = True

# SSH Configuration
[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r

# Privilege Escalation
[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

# Galaxy Configuration
[galaxy]
server_list = community_galaxy

[galaxy_server.community_galaxy]
url = https://galaxy.ansible.com/
EOF
}

# Create inventory files
create_inventories() {
    print_status "Creating inventory files"
    
    # Production inventory
    cat > inventories/production/hosts.yml << 'EOF'
---
all:
  children:
    webservers:
      hosts:
        web01.example.com:
          ansible_host: 192.168.1.10
          ansible_user: ansible
        web02.example.com:
          ansible_host: 192.168.1.11
          ansible_user: ansible
      vars:
        http_port: 80
        https_port: 443
        
    databases:
      hosts:
        db01.example.com:
          ansible_host: 192.168.1.20
          ansible_user: ansible
          mysql_port: 3306
        db02.example.com:
          ansible_host: 192.168.1.21
          ansible_user: ansible
          mysql_port: 3306
      vars:
        database_backup_retention: 30
        
    monitoring:
      hosts:
        monitor01.example.com:
          ansible_host: 192.168.1.30
          ansible_user: ansible
      vars:
        grafana_port: 3000
        prometheus_port: 9090
        
    debian:
      children:
        webservers:
        databases:
      vars:
        ansible_python_interpreter: /usr/bin/python3
        package_manager: apt
        
    rhel:
      hosts:
        rhel01.example.com:
          ansible_host: 192.168.1.40
          ansible_user: ansible
      vars:
        ansible_python_interpreter: /usr/bin/python3
        package_manager: yum
EOF
    
    # Development inventory - create with different IP range
    cat > inventories/development/hosts.yml << 'EOF'
---
all:
  children:
    webservers:
      hosts:
        web01.example.com:
          ansible_host: 192.168.3.10
          ansible_user: ansible
        web02.example.com:
          ansible_host: 192.168.3.11
          ansible_user: ansible
      vars:
        http_port: 80
        https_port: 443
        
    databases:
      hosts:
        db01.example.com:
          ansible_host: 192.168.3.20
          ansible_user: ansible
          mysql_port: 3306
        db02.example.com:
          ansible_host: 192.168.3.21
          ansible_user: ansible
          mysql_port: 3306
      vars:
        database_backup_retention: 30
        
    monitoring:
      hosts:
        monitor01.example.com:
          ansible_host: 192.168.3.30
          ansible_user: ansible
      vars:
        grafana_port: 3000
        prometheus_port: 9090
        
    debian:
      children:
        webservers:
        databases:
      vars:
        ansible_python_interpreter: /usr/bin/python3
        package_manager: apt
        
    rhel:
      hosts:
        rhel01.example.com:
          ansible_host: 192.168.3.40
          ansible_user: ansible
      vars:
        ansible_python_interpreter: /usr/bin/python3
        package_manager: yum
EOF
}

# Create group variables
create_group_vars() {
    print_status "Creating group variables"
    
    # All group variables
    cat > group_vars/all/main.yml << 'EOF'
---
# Global Variables
timezone: "UTC"
ntp_servers:
  - pool.ntp.org
  - time.google.com

# SSH Configuration
ssh_port: 22
ssh_permit_root_login: false
ssh_password_authentication: false
ssh_max_auth_tries: 3

# Firewall Settings
firewall_enabled: true
fail2ban_enabled: true

# Security Settings
automatic_security_updates: true
unattended_upgrades: true

# Monitoring
monitoring_enabled: true
log_retention_days: 30

# Common packages
common_packages:
  - curl
  - wget
  - vim
  - htop
  - tree
  - unzip
  - git
EOF

    # Debian-specific variables
    cat > group_vars/debian/main.yml << 'EOF'
---
# Debian/Ubuntu specific variables
package_manager: apt
service_manager: systemctl

# Package repositories
security_repo: "deb http://security.debian.org/debian-security"
updates_repo: "deb http://deb.debian.org/debian"

# System packages
debian_packages:
  - apt-transport-https
  - ca-certificates
  - software-properties-common
  - python3-pip
  
# Services
ssh_service_name: ssh
firewall_service_name: ufw
EOF

    # RedHat-specific variables  
    cat > group_vars/redhat/main.yml << 'EOF'
---
# RedHat/CentOS specific variables
package_manager: yum
service_manager: systemctl

# EPEL repository
epel_enabled: true

# System packages
rhel_packages:
  - epel-release
  - python3-pip
  - yum-utils
  - device-mapper-persistent-data
  - lvm2

# Services
ssh_service_name: sshd
firewall_service_name: firewalld
EOF

    # Create encrypted vault file for sensitive data
    if [[ "$CREATE_VAULT_FILE" == true ]]; then
        print_status "Creating sample vault file (you'll need to encrypt it manually)"
        cat > group_vars/all/vault.yml << 'EOF'
---
# Encrypted variables (use ansible-vault encrypt to secure)
# Example: ansible-vault encrypt group_vars/all/vault.yml

# Database credentials
vault_mysql_root_password: "super_secure_password_123"
vault_mysql_app_password: "app_secure_password_456"

# API Keys
vault_monitoring_api_key: "your_monitoring_api_key_here"
vault_backup_encryption_key: "backup_encryption_key_here"

# SSH Keys (for deployment)
vault_deploy_ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  # Your private key content here
  -----END OPENSSH PRIVATE KEY-----

# Certificates
vault_ssl_certificate: |
  -----BEGIN CERTIFICATE-----
  # Your SSL certificate here
  -----END CERTIFICATE-----

vault_ssl_private_key: |
  -----BEGIN PRIVATE KEY-----
  # Your SSL private key here
  -----END PRIVATE KEY-----
EOF
        print_warning "Remember to encrypt vault.yml with: ansible-vault encrypt group_vars/all/vault.yml"
    fi
}

# Create requirements files
create_requirements() {
    print_status "Creating requirements files"
    
    # Ansible Galaxy requirements
    cat > requirements.yml << 'EOF'
---
# Ansible Galaxy Requirements
# Install with: ansible-galaxy install -r requirements.yml

# Community Collections
collections:
  - name: community.general
    version: ">=6.0.0"
  - name: ansible.posix
    version: ">=1.4.0"
  - name: community.crypto
    version: ">=2.0.0"
  - name: community.docker
    version: ">=3.0.0"
  - name: community.mysql
    version: ">=3.0.0"
  - name: community.postgresql
    version: ">=2.0.0"
  - name: community.grafana
    version: ">=1.0.0"
  - name: prometheus.prometheus
    version: ">=0.1.0"

# Community Roles
roles:
  - name: geerlingguy.security
    version: "2.0.1"
  - name: geerlingguy.firewall
    version: "2.6.0"
  - name: geerlingguy.docker
    version: "6.1.0"
  - name: geerlingguy.mysql
    version: "4.3.4"
  - name: geerlingguy.nginx
    version: "3.1.4"
  - name: dev-sec.os-hardening
    version: "7.10.0"
  - name: dev-sec.ssh-hardening
    version: "9.8.0"
  - name: cloudalchemy.prometheus
    version: "2.17.0"
  - name: cloudalchemy.grafana
    version: "0.22.3"
EOF
}

# Create basic documentation
create_documentation() {
    print_status "Creating project documentation"
    
    cat > README.md << 'EOF'
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
EOF
}

# Create basic playbooks
create_basic_playbooks() {
    print_status "Creating basic playbooks"
    
    # Main site playbook
    cat > site.yml << 'EOF'
---
# Main Site Playbook
- name: "Apply common configuration to all hosts"
  hosts: all
  become: true
  gather_facts: true
  
  tasks:
    - name: "Install common packages"
      package:
        name: "{{ common_packages }}"
        state: present
        
    - name: "Configure timezone"
      timezone:
        name: "{{ timezone }}"
        
    - name: "Ensure SSH is configured securely"
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
        backup: true
      loop:
        - { regexp: '^PasswordAuthentication', line: 'PasswordAuthentication no' }
        - { regexp: '^PermitRootLogin', line: 'PermitRootLogin no' }
        - { regexp: '^Port', line: 'Port {{ ssh_port }}' }
      notify: restart_ssh
      
  handlers:
    - name: restart_ssh
      service:
        name: "{{ ssh_service_name | default('ssh') }}"
        state: restarted
EOF

    # Basic system maintenance runbook
    cat > playbooks/runbooks/system/system_maintenance.yml << 'EOF'
---
# System Maintenance Runbook
- name: "System Maintenance"
  hosts: all
  become: true
  gather_facts: true
  
  tasks:
    - name: "Update package cache"
      package:
        update_cache: true
      
    - name: "Upgrade all packages (Debian/Ubuntu)"
      apt:
        upgrade: dist
        autoremove: true
        autoclean: true
      when: ansible_os_family == "Debian"
      
    - name: "Update all packages (RedHat/CentOS)"
      yum:
        name: "*"
        state: latest
        update_cache: true
      when: ansible_os_family == "RedHat"
        
    - name: "Check disk space"
      command: df -h
      register: disk_usage
      
    - name: "Display disk usage"
      debug:
        msg: "{{ disk_usage.stdout_lines }}"
EOF
}

# Main function
main() {
    print_status "Starting Ansible project generator"
    
    parse_args "$@"
    
    create_directories
    create_ansible_config
    create_inventories
    create_group_vars
    create_requirements
    create_documentation
    create_basic_playbooks
    
    print_status "Project structure created successfully!"
    echo ""
    print_status "Project Summary:"
    echo -e "${BLUE}Project Name:${NC} $PROJECT_NAME"
    echo -e "${BLUE}Location:${NC} $(pwd)/$PROJECT_NAME"
    echo -e "${BLUE}Vault Password File:${NC} ${VAULT_PASSWORD_FILE:-~/.ansible_vault_pass}"
    echo -e "${BLUE}SSH Key Path:${NC} ${SSH_KEY_PATH:-~/.ssh/ansible_key}"
    echo ""
    
    print_status "Next Steps:"
    echo "1. cd $PROJECT_NAME"
    echo "2. Review and customize inventory files in inventories/"
    echo "3. Update group_vars/ for your environment"
    echo "4. Install dependencies: ansible-galaxy install -r requirements.yml"
    echo "5. Test connectivity: ansible all -m ping"
    echo "6. Deploy: ansible-playbook site.yml"
    echo ""
    
    if [[ "$CREATE_VAULT_FILE" == true ]]; then
        print_warning "Don't forget to encrypt the vault file:"
        echo "ansible-vault encrypt $PROJECT_NAME/group_vars/all/vault.yml"
        echo ""
    fi
    
    print_status "Happy automating! 🚀"
}

# Run the main function with all arguments
main "$@"