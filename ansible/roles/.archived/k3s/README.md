# Ansible Role: k3s

This role installs and configures [k3s](https://k3s.io/) - Lightweight Kubernetes with optional Calico CNI on Debian and RHEL-based systems.

## Requirements

- Ansible >= 2.15
- Supported OS:
  - Ubuntu 20.04+
  - Debian 11+
  - RHEL/Rocky Linux 8+
- Minimum 512MB RAM (1GB+ recommended)
- Minimum 1 CPU core (2+ recommended)

## Role Variables

### Installation Mode

```yaml
# Installation mode: 'server', 'agent', or 'combined'
k3s_mode: combined

# k3s version
k3s_version: v1.28.5+k3s1
```

### Server Configuration

```yaml
# Server settings
k3s_server_enabled: true
k3s_server_host: "{{ ansible_default_ipv4.address }}"
k3s_server_port: 6443
```

### Agent Configuration

```yaml
# Agent settings (required for agent mode)
k3s_agent_enabled: false
k3s_server_url: "https://server-ip:6443"
k3s_server_token: "your-server-token"
```

### CNI Configuration

```yaml
# CNI selection: 'calico' or 'flannel'
k3s_cni: calico

# Calico version and settings
calico_version: v3.27.0
calico_ipv4_pool_cidr: 10.42.0.0/16
calico_encapsulation: VXLAN  # VXLAN, IPIP, IPIPCrossSubnet, VXLANCrossSubnet, None
```

### Network Configuration

```yaml
# Cluster networking
k3s_cluster_cidr: 10.42.0.0/16
k3s_service_cidr: 10.43.0.0/16
```

### Components

```yaml
# Disable default k3s components
k3s_disable_components:
  - traefik
  - servicelb
```

### Firewall

```yaml
# Firewall configuration
k3s_configure_firewall: false
k3s_firewall_zone: public
```

## Dependencies

- `community.general` collection
- `ansible.posix` collection

Install collections:

```bash
ansible-galaxy collection install community.general ansible.posix
```

## Example Playbook

### Single Server with Calico

```yaml
---
- hosts: k3s_servers
  become: true
  roles:
    - role: k3s
      vars:
        k3s_mode: server
        k3s_cni: calico
        k3s_configure_kubectl: true
```

### Server + Agent (Combined)

```yaml
---
- hosts: k3s_nodes
  become: true
  roles:
    - role: k3s
      vars:
        k3s_mode: combined
        k3s_cni: calico
```

### Multi-Node Cluster

```yaml
---
# First, set up the server
- hosts: k3s_master
  become: true
  roles:
    - role: k3s
      vars:
        k3s_mode: server
        k3s_cni: calico

# Then, join agents
- hosts: k3s_workers
  become: true
  roles:
    - role: k3s
      vars:
        k3s_mode: agent
        k3s_server_url: "https://{{ hostvars[groups['k3s_master'][0]]['ansible_default_ipv4']['address'] }}:6443"
        k3s_server_token: "{{ hostvars[groups['k3s_master'][0]]['k3s_server_token'] }}"
```

### With Flannel (Default CNI)

```yaml
---
- hosts: k3s_servers
  become: true
  roles:
    - role: k3s
      vars:
        k3s_mode: server
        k3s_cni: flannel
```

## Accessing the Cluster

After installation, access the cluster using:

```bash
# Using k3s directly
sudo k3s kubectl get nodes

# Using kubectl (if configured)
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes

# Or from user's home directory
kubectl get nodes  # Uses ~/.kube/config
```

## Firewall Ports

### Server Ports

- 6443/tcp - Kubernetes API server
- 10250/tcp - Kubelet metrics
- 2379-2380/tcp - etcd

### Agent Ports

- 10250/tcp - Kubelet metrics

### Calico Ports

- 179/tcp - BGP
- 4789/udp - VXLAN overlay

## Testing

This role includes Molecule tests:

```bash
cd roles/k3s
molecule test

# Run specific scenarios
molecule converge
molecule verify
molecule destroy
```

## Uninstalling k3s

k3s includes uninstall scripts:

```bash
# Server
sudo /usr/local/bin/k3s-uninstall.sh

# Agent
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

## License

MIT

## Author Information

Created for home lab Kubernetes deployments and learning.
