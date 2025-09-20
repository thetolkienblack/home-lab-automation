# Docker Compose Template Variables Reference

## Global Variables

### Top Level
- `compose_version` (string): Docker Compose file format version (default: "3.8")
- `services` (list): List of service definitions
- `networks` (list): List of network definitions
- `volumes` (list): List of volume definitions
- `secrets` (list): List of secret definitions
- `configs` (list): List of config definitions

## Service Variables

Each service in the `services` list can have the following variables:

### Basic Service Configuration
- `name` (string): Service name (used as key in compose file)
- `image` (string): Docker image to use
- `container_name` (string): Container name (defaults to service name)
- `hostname` (string): Container hostname
- `domainname` (string): Container domain name
- `platform` (string): Platform constraint (e.g., "linux/amd64")

### Build Configuration
- `build` (object):
  - `context` (string): Build context path
  - `dockerfile` (string): Dockerfile path
  - `args` (object): Build arguments (key-value pairs)
  - `target` (string): Build target stage

### Resource Management
- `cpu_limit` (string): CPU limit (e.g., "2.0", "500m")
- `memory_limit` (string): Memory limit (e.g., "1G", "512M")
- `memory_reservation` (string): Memory soft limit
- `cpu_reservation` (string): CPU reservation
- `pids_limit` (integer): PID limit
- `shm_size` (string): Shared memory size

### GPU Support
- `gpu_support` (string): GPU driver ("nvidia", "amd", "intel")
- `gpu_count` (string/integer): Number of GPUs ("all" or specific count)
- `gpu_capabilities` (list): GPU capabilities (default: ["gpu"])

### Advanced Deployment
- `deploy` (object):
  - `replicas` (integer): Number of replicas
  - `placement` (object):
    - `constraints` (list): Placement constraints
    - `preferences` (list): Placement preferences
  - `restart_policy` (object):
    - `condition` (string): "none", "on-failure", "any"
    - `delay` (string): Restart delay
    - `max_attempts` (integer): Maximum restart attempts
    - `window` (string): Restart window
  - `update_config` (object):
    - `parallelism` (integer): Update parallelism
    - `delay` (string): Update delay
    - `failure_action` (string): "pause", "continue", "rollback"
    - `monitor` (string): Monitor period
    - `max_failure_ratio` (float): Max failure ratio
    - `order` (string): "start-first", "stop-first"

### Security Configuration
- `security_opt` (list): Security options (e.g., ["no-new-privileges:true"])
- `cap_add` (list): Capabilities to add
- `cap_drop` (list): Capabilities to drop
- `privileged` (boolean): Run in privileged mode
- `read_only` (boolean): Read-only root filesystem
- `user` (string): User to run as (e.g., "1000:1000", "root")
- `group_add` (list): Additional groups

### Runtime Configuration
- `runtime` (string): Runtime to use (e.g., "nvidia", "runc")
- `init` (boolean): Use init process
- `pid` (string): PID namespace mode
- `ipc` (string): IPC namespace mode
- `uts` (string): UTS namespace mode
- `userns_mode` (string): User namespace mode

### System Configuration
- `sysctls` (object/list): Sysctl parameters
- `ulimits` (object): Ulimit settings
  - Each ulimit can be string or object with `soft` and `hard`
- `stdin_open` (boolean): Keep STDIN open
- `tty` (boolean): Allocate pseudo-TTY

### Network Configuration
- `ports` (list): Port mappings (e.g., ["80:80", "443:443/tcp"])
- `expose` (list): Expose ports without publishing
- `networks` (list/object): Networks to connect to
  - Simple format: list of network names
  - Advanced format: object with network configs:
    - `aliases` (list): Network aliases
    - `ipv4_address` (string): Static IPv4 address
    - `ipv6_address` (string): Static IPv6 address
    - `link_local_ips` (list): Link-local IPs
    - `priority` (integer): Network priority
- `network_mode` (string): Network mode ("host", "bridge", etc.)
- `mac_address` (string): MAC address

### Storage Configuration
- `volumes` (list): Volume mounts (e.g., ["/host:/container:ro"])
- `tmpfs` (list/object): tmpfs mounts
- `devices` (list): Device mappings (e.g., ["/dev/sda:/dev/xvda:rwm"])
- `device_cgroup_rules` (list): Device cgroup rules

### Environment Configuration
- `environment` (object/list): Environment variables
  - Object format: key-value pairs
  - List format: ["KEY=value"] strings
- `env_file` (string/list): Environment file(s)
- `working_dir` (string): Working directory

### Command and Execution
- `command` (string/list): Override default command
- `entrypoint` (string/list): Override default entrypoint

### Dependencies
- `depends_on` (list/object): Service dependencies
  - Simple format: list of service names
  - Advanced format: object with conditions:
    - `condition` (string): "service_started", "service_healthy", "service_completed_successfully"
    - `restart` (boolean): Restart dependent service
- `links` (list): Link to containers (legacy)
- `external_links` (list): Link to external containers

### Health Checks
- `healthcheck` (object):
  - `disable` (boolean): Disable health check
  - `test` (list): Health check command
  - `interval` (string): Check interval
  - `timeout` (string): Check timeout
  - `retries` (integer): Number of retries
  - `start_period` (string): Start period
  - `start_interval` (string): Start interval

### Restart and Stop Configuration
- `restart` (string): Restart policy ("no", "always", "on-failure", "unless-stopped")
- `stop_grace_period` (string): Grace period for stop
- `stop_signal` (string): Stop signal

### Labels and Metadata
- `labels` (object/list): Labels for the container
  - Object format: key-value pairs
  - List format: ["key=value"] strings

### Logging Configuration
- `logging` (object):
  - `driver` (string): Logging driver
  - `options` (object): Driver-specific options

### Extensions and Advanced
- `extends` (object): Extend another service
  - `file` (string): File containing service
  - `service` (string): Service name to extend
- `extra_hosts` (list): Extra host entries
- `dns` (string/list): Custom DNS servers
- `dns_search` (list): DNS search domains
- `dns_opt` (list): DNS options
- `cgroup_parent` (string): Parent cgroup
- `isolation` (string): Isolation technology
- `scale` (integer): Number of containers to run
- `profiles` (list): Profiles this service belongs to
- `pull_policy` (string): Pull policy ("always", "never", "missing", "build")

## Network Variables

Each network in the `networks` list:

- `name` (string): Network name
- `driver` (string): Network driver ("bridge", "overlay", etc.)
- `driver_opts` (object): Driver-specific options
- `attachable` (boolean): Enable manual container attachment
- `enable_ipv6` (boolean): Enable IPv6
- `ipam` (object): IP Address Management
  - `driver` (string): IPAM driver
  - `config` (list): IPAM configurations
    - `subnet` (string): Subnet CIDR
    - `ip_range` (string): IP range
    - `gateway` (string): Gateway IP
    - `aux_addresses` (object): Auxiliary addresses
  - `options` (object): IPAM options
- `internal` (boolean): Restrict external access
- `external` (boolean/object): Use external network
  - Boolean: true/false
  - Object: `name` (string) - external network name
- `labels` (object): Network labels

## Volume Variables

Each volume in the `volumes` list:

- `name` (string): Volume name
- `driver` (string): Volume driver
- `driver_opts` (object): Driver-specific options
- `external` (boolean/object): Use external volume
  - Boolean: true/false
  - Object: `name` (string) - external volume name
- `labels` (object): Volume labels

## Secret Variables

Each secret in the `secrets` list:

- `name` (string): Secret name
- `file` (string): Path to secret file
- `external` (boolean/object): Use external secret
- `labels` (object): Secret labels
- `driver` (string): Secret driver
- `driver_opts` (object): Driver-specific options
- `template_driver` (string): Template driver

## Config Variables

Each config in the `configs` list:

- `name` (string): Config name
- `file` (string): Path to config file
- `external` (boolean/object): Use external config
- `labels` (object): Config labels
- `template_driver` (string): Template driver

## Default Variables

These variables can be used to set defaults:

- `docker_defaults` (object):
  - `restart_policy` (string): Default restart policy
  - `stop_grace_period` (string): Default stop grace period
  - `security_opts` (list): Default security options
  - `capabilities` (object): Default capabilities

## Example Variable Structure

```yaml
compose_version: "3.8"

services:
  - name: webapp
    image: nginx:alpine
    container_name: my-webapp
    cpu_limit: "1.0"
    memory_limit: "512M"
    ports:
      - "80:80"
    environment:
      ENV: production
      DEBUG: false
    volumes:
      - "webapp_data:/var/www/html"
    networks:
      - webnet
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      traefik.enable: "true"
      traefik.http.routers.webapp.rule: "Host(`example.com`)"

networks:
  - name: webnet
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1

volumes:
  - name: webapp_data
    driver: local
```

This template covers every possible Docker Compose option and provides maximum flexibility for any containerized application stack.