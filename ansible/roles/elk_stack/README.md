# Ansible Role: elk_stack

Comprehensive Ansible role to install and configure the ELK Stack (Elasticsearch, Logstash, Kibana) version 8.x with support for both single-node and multi-node cluster deployments. Includes Prometheus, CheckMK, and Grafana monitoring integrations.

## Features

- **Version 8.x Support**: Latest Elasticsearch, Logstash, and Kibana
- **Flexible Deployment**: Single-node or multi-node cluster configurations
- **Independent Components**: Install components independently or together
- **Multi-OS Support**: Debian/Ubuntu and RedHat/Rocky Linux families
- **Security Configurable**: Enable/disable security features and SSL/TLS
- **Monitoring Integration**: Prometheus exporter, CheckMK plugins, Grafana dashboards
- **Fully Templated**: All configurations via Jinja2 templates
- **Production Ready**: Includes handlers, firewall rules, and health checks

## Requirements

### System Requirements

- **RAM**: Minimum 4GB (8GB recommended for production)
- **CPU**: Minimum 2 cores (4+ recommended)
- **Disk**: 20GB+ free space for data storage
- **OS**: Ubuntu 20.04+, Debian 11+, Rocky Linux 8+, RHEL 8+

### Ansible Requirements

- Ansible 2.12 or higher
- Collections:
  - `community.general >= 3.0.0`
  - `ansible.posix >= 1.3.0`

## Role Variables

### Component Installation

```yaml
elk_version: "8.11.3"                    # ELK Stack version
elk_install_elasticsearch: true          # Install Elasticsearch
elk_install_logstash: true               # Install Logstash
elk_install_kibana: true                 # Install Kibana
elk_deployment_mode: single              # Deployment mode: single or cluster
```

### Security Configuration

```yaml
elk_security_enabled: true               # Enable X-Pack security
elk_security_auto_generate_passwords: true
elk_ssl_enabled: true                    # Enable SSL/TLS
elk_ssl_verification_mode: "certificate" # SSL verification: full, certificate, none

# Custom passwords (if not auto-generated)
elk_elasticsearch_password: ""
elk_kibana_password: ""
elk_logstash_password: ""
```

### Elasticsearch Configuration

```yaml
elasticsearch_config_dir: "/etc/elasticsearch"
elasticsearch_data_dir: "/var/lib/elasticsearch"
elasticsearch_log_dir: "/var/log/elasticsearch"
elasticsearch_heap_size: "1g"

# Network
elasticsearch_network_host: "0.0.0.0"
elasticsearch_http_port: 9200
elasticsearch_transport_port: 9300

# Cluster
elasticsearch_cluster_name: "elk-cluster"
elasticsearch_node_name: "{{ ansible_hostname }}"
elasticsearch_node_master: true
elasticsearch_node_data: true
elasticsearch_node_ingest: true

# For multi-node clusters
elasticsearch_cluster_nodes: []
# Example:
#   - "node1.example.com:9300"
#   - "node2.example.com:9300"

elasticsearch_initial_master_nodes:
  - "{{ ansible_hostname }}"

# Index settings
elasticsearch_number_of_shards: 1
elasticsearch_number_of_replicas: 0
```

### Logstash Configuration

```yaml
logstash_config_dir: "/etc/logstash"
logstash_data_dir: "/var/lib/logstash"
logstash_log_dir: "/var/log/logstash"
logstash_heap_size: "512m"

# Network
logstash_http_host: "0.0.0.0"
logstash_http_port: 9600
logstash_beats_port: 5044
logstash_syslog_port: 5140

# Pipeline
logstash_pipeline_workers: "{{ ansible_processor_vcpus }}"
logstash_pipeline_batch_size: 125
logstash_pipeline_batch_delay: 50

# Elasticsearch output
logstash_elasticsearch_hosts:
  - "http://localhost:9200"
logstash_elasticsearch_user: "elastic"
```

### Kibana Configuration

```yaml
kibana_config_dir: "/etc/kibana"
kibana_data_dir: "/var/lib/kibana"
kibana_log_dir: "/var/log/kibana"

# Network
kibana_server_host: "0.0.0.0"
kibana_server_port: 5601
kibana_server_name: "{{ ansible_hostname }}"

# Elasticsearch connection
kibana_elasticsearch_hosts:
  - "http://localhost:9200"
kibana_elasticsearch_username: "kibana_system"
```

### Monitoring & Exporters

```yaml
# Prometheus Exporter
elk_install_prometheus_exporter: true
elk_prometheus_exporter_version: "1.7.0"
elk_prometheus_exporter_port: 9114

# CheckMK
elk_install_checkmk_agent: false
checkmk_agent_plugin_dir: "/usr/lib/check_mk_agent/plugins"

# Grafana
elk_install_grafana_dashboards: false
grafana_dashboard_dir: "/var/lib/grafana/dashboards"
```

### System Settings

```yaml
elk_install_java: true
elk_service_enabled: true
elk_service_state: started
elk_configure_firewall: false
```

## Dependencies

None. This role is self-contained.

## Example Playbooks

### Single Node - All Components

```yaml
---
- name: Deploy ELK Stack (Single Node)
  hosts: elk_server
  become: true

  roles:
    - role: elk_stack
      vars:
        elk_deployment_mode: single
        elk_install_elasticsearch: true
        elk_install_logstash: true
        elk_install_kibana: true
        elk_security_enabled: false  # Disable for testing
        elasticsearch_heap_size: "2g"
        logstash_heap_size: "1g"
```

### Elasticsearch Only (Cluster Mode)

```yaml
---
- name: Deploy Elasticsearch Cluster
  hosts: elasticsearch_nodes
  become: true

  roles:
    - role: elk_stack
      vars:
        elk_deployment_mode: cluster
        elk_install_elasticsearch: true
        elk_install_logstash: false
        elk_install_kibana: false
        elasticsearch_cluster_nodes:
          - "es-node1.local:9300"
          - "es-node2.local:9300"
          - "es-node3.local:9300"
        elasticsearch_initial_master_nodes:
          - "es-node1"
          - "es-node2"
          - "es-node3"
        elasticsearch_heap_size: "4g"
```

### Logstash Only (Connecting to Remote Elasticsearch)

```yaml
---
- name: Deploy Logstash Nodes
  hosts: logstash_servers
  become: true

  roles:
    - role: elk_stack
      vars:
        elk_install_elasticsearch: false
        elk_install_logstash: true
        elk_install_kibana: false
        logstash_elasticsearch_hosts:
          - "http://es-cluster.local:9200"
        logstash_heap_size: "2g"
```

### Kibana Only (Connecting to Remote Elasticsearch)

```yaml
---
- name: Deploy Kibana
  hosts: kibana_server
  become: true

  roles:
    - role: elk_stack
      vars:
        elk_install_elasticsearch: false
        elk_install_logstash: false
        elk_install_kibana: true
        kibana_elasticsearch_hosts:
          - "http://es-cluster.local:9200"
```

### Production Setup with Monitoring

```yaml
---
- name: Deploy ELK Stack with Full Monitoring
  hosts: elk_servers
  become: true

  pre_tasks:
    - name: Set vm.max_map_count for Elasticsearch
      ansible.posix.sysctl:
        name: vm.max_map_count
        value: "262144"
        state: present
        reload: true

  roles:
    - role: elk_stack
      vars:
        elk_deployment_mode: single
        elk_security_enabled: true
        elk_ssl_enabled: true

        # Components
        elk_install_elasticsearch: true
        elk_install_logstash: true
        elk_install_kibana: true

        # Monitoring
        elk_install_prometheus_exporter: true
        elk_install_checkmk_agent: true
        elk_install_grafana_dashboards: true

        # Performance tuning
        elasticsearch_heap_size: "4g"
        logstash_heap_size: "2g"

        # Firewall
        elk_configure_firewall: true
```

## Usage Guide

### Running the Playbook

1. **Create an inventory file** (`inventories/production.yml`):

```yaml
all:
  children:
    elk_servers:
      hosts:
        elk-node1:
          ansible_host: 192.168.1.100
```

2. **Create a playbook** (use the provided `playbooks/monitoring/elk_stack.yml`):

```bash
ansible-playbook -i inventories/production.yml playbooks/monitoring/elk_stack.yml
```

3. **Install only specific components**:

```bash
ansible-playbook -i inventories/production.yml playbooks/monitoring/elk_stack.yml \
  -e "elk_install_logstash=false elk_install_kibana=false"
```

### Accessing the Services

After deployment:

- **Elasticsearch**: `http://your-server:9200`
- **Kibana**: `http://your-server:5601`
- **Logstash API**: `http://your-server:9600`
- **Prometheus Metrics**: `http://your-server:9114/metrics`

### Testing Elasticsearch

```bash
# Check cluster health
curl http://localhost:9200/_cluster/health?pretty

# List indices
curl http://localhost:9200/_cat/indices?v

# Get node info
curl http://localhost:9200/_nodes?pretty
```

### Testing Logstash

```bash
# Check Logstash API
curl http://localhost:9600/?pretty

# Check pipeline stats
curl http://localhost:9600/_node/stats/pipelines?pretty

# Send test data via Beats
echo "test message" | nc localhost 5044
```

### Testing Kibana

Open your browser and navigate to `http://your-server:5601`

### Prometheus Integration

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'elasticsearch'
    static_configs:
      - targets: ['elk-server:9114']
```

## Multi-Node Cluster Setup

For a production 3-node Elasticsearch cluster:

```yaml
---
- name: Deploy Elasticsearch 3-Node Cluster
  hosts: es_cluster
  become: true

  pre_tasks:
    - name: Set vm.max_map_count
      ansible.posix.sysctl:
        name: vm.max_map_count
        value: "262144"
        state: present
        reload: true

  roles:
    - role: elk_stack
      vars:
        elk_deployment_mode: cluster
        elk_install_elasticsearch: true
        elk_install_logstash: false
        elk_install_kibana: false

        elasticsearch_cluster_name: "production-cluster"
        elasticsearch_cluster_nodes:
          - "es-node1.local:9300"
          - "es-node2.local:9300"
          - "es-node3.local:9300"

        elasticsearch_initial_master_nodes:
          - "es-node1"
          - "es-node2"
          - "es-node3"

        elasticsearch_heap_size: "8g"
        elasticsearch_number_of_replicas: 1
```

## Customizing Logstash Pipelines

The role includes default pipelines for Beats and Syslog. To add custom pipelines:

1. Update the `logstash_pipelines` variable:

```yaml
logstash_pipelines:
  - pipeline.id: "beats"
    path.config: "/etc/logstash/conf.d/beats.conf"
  - pipeline.id: "custom"
    path.config: "/etc/logstash/conf.d/custom.conf"
```

2. Create custom pipeline templates in `templates/logstash-custom.conf.j2`

## Troubleshooting

### Elasticsearch won't start

```bash
# Check logs
sudo journalctl -u elasticsearch -f

# Verify vm.max_map_count
sysctl vm.max_map_count

# Check disk space
df -h /var/lib/elasticsearch
```

### Logstash pipeline errors

```bash
# Check Logstash logs
sudo journalctl -u logstash -f

# Validate pipeline config
sudo -u logstash /usr/share/logstash/bin/logstash --config.test_and_exit \
  -f /etc/logstash/conf.d/beats.conf
```

### Kibana can't connect to Elasticsearch

```bash
# Check Kibana logs
sudo journalctl -u kibana -f

# Verify Elasticsearch is accessible
curl http://localhost:9200

# Check Kibana config
cat /etc/kibana/kibana.yml
```

## Testing

### Running Molecule Tests

```bash
# Install molecule
pip install molecule molecule-docker

# Run full test suite
cd roles/elk_stack
molecule test

# Test on specific platform
molecule test --scenario-name default
```

### Running Ansible Lint

```bash
ansible-lint roles/elk_stack
```

## Security Considerations

### Production Deployments

For production:

1. **Enable Security**:
   ```yaml
   elk_security_enabled: true
   elk_ssl_enabled: true
   ```

2. **Use Strong Passwords**:
   ```yaml
   elk_elasticsearch_password: "{{ vault_elasticsearch_password }}"
   ```

3. **Configure Firewall**:
   ```yaml
   elk_configure_firewall: true
   ```

4. **Use SSL Certificates**: Place valid certificates in `{{ elk_ssl_certificate_path }}`

5. **Restrict Network Access**:
   ```yaml
   elasticsearch_network_host: "{{ ansible_default_ipv4.address }}"
   ```

## Performance Tuning

### Memory Settings

- **Elasticsearch**: Set heap to 50% of RAM, max 31GB
- **Logstash**: Set heap to 25% of RAM
- **Kibana**: No heap tuning required

```yaml
elasticsearch_heap_size: "16g"  # For 32GB RAM server
logstash_heap_size: "4g"        # For 16GB RAM server
```

### Index Management

```yaml
elasticsearch_number_of_shards: 1     # Single node
elasticsearch_number_of_replicas: 0   # Single node

# For 3-node cluster:
elasticsearch_number_of_shards: 3
elasticsearch_number_of_replicas: 1
```

## License

MIT

## Author Information

Created by Sidney for home lab automation.

## Contributing

Issues and pull requests welcome!

## Changelog

### Version 1.0.0 (2024)
- Initial release
- ELK Stack 8.x support
- Single and cluster mode
- Prometheus, CheckMK, Grafana integration
- Debian and RedHat family support
- Comprehensive molecule tests
