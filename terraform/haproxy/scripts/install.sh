#!/usr/bin/env bash
set -e

# Read from the file we created
CONSUL_JOIN=$(cat /tmp/consul-server-addr | tr -d '\n')

sudo bash -c "cat >/etc/default/consul" << EOF
CONSUL_FLAGS="\
-join=${CONSUL_JOIN} \
-data-dir=/opt/consul/data"
EOF

sudo chown root:root /etc/default/consul
sudo chmod 0644 /etc/default/consul

# register services and checks in consul
echo "Configuring HAProxy service registration and checks in Consul..."
sudo bash -c "cat >/etc/systemd/system/consul.d/haproxy.json" << HAPROXY
{"service": {
  "name": "haproxy",
  "tags": ["web"],
  "port": 80,
    "checks": [
      {
        "id": "GET",
        "script": "curl localhost >/dev/null 2>&1",
        "interval": "10s"
      },
      {
        "id": "HTTP-TCP",
        "name": "HTTP TCP on port 80",
        "tcp": "localhost:80",
        "interval": "10s",
        "timeout": "1s"
      },
        {
        "id": "OS service status",
        "script": "service haproxy status",
        "interval": "30s"
      }]
    }
}
HAPROXY

echo "Configuring system level Consul checks..."
sudo bash -c "cat >/etc/systemd/system/consul.d/system.json" << SYSTEM
{
    "checks": [
      {
        "id": "report CPU load",
        "name": "CPU Load",
        "script": "(printf '1m  5m  15m  cur/total  last-pid\n'; cat /proc/loadavg) | column -t",
        "interval": "60s"
      },
      {
        "id": "check RAM usage",
        "name": "RAM usage",
        "script": "free -m",
        "interval": "300s"
      },
      {
        "id": "test internet connectivity",
        "name": "ping",
        "script": "ping -c1 google.com >/dev/null",
        "interval": "30s"
      }]
}
SYSTEM


echo "Configuring HAProxy firewall rules..."
sudo iptables -I INPUT -s 0/0 -p tcp --dport 80 -j ACCEPT
sudo netfilter-persistent save
sudo netfilter-persistent reload



echo "Install Consul template configuration file for HAProxy..."
sudo bash -c "cat >/etc/systemd/system/consul-template.d/templates/haproxy.cfg.ctmpl" << HAPROXY
global
   log /dev/log local0
   log /dev/log local1 notice
   chroot /var/lib/haproxy
   stats socket /run/haproxy/admin.sock mode 660 level admin
   stats timeout 30s
   user haproxy
   group haproxy
   daemon

defaults
   log global
   mode http
   option httplog
   option dontlognull
   timeout connect 5000
   timeout client 50000
   timeout server 50000

frontend http_front
   bind *:80
   stats uri /haproxy?stats
   default_backend http_back

backend http_back
   balance roundrobin{{range service "nginx"}}
   server {{.Node}} {{.Address}}:{{.Port}} check{{end}}
HAPROXY

echo "Configuring Consul Template for HAProxy..."
sudo bash -c "cat >/etc/systemd/system/consul-template.d/consul-template.json" << EOF
consul = "127.0.0.1:8500"
template {
  source = "/etc/systemd/system/consul-template.d/templates/haproxy.cfg.ctmpl"
  destination = "/etc/haproxy/haproxy.cfg"
  command = "service haproxy reload"
  command_timeout = "30s"
  backup = true
}
EOF
