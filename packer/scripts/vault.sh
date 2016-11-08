#!/usr/bin/env bash

set -e

echo "Fetching Vault..."
VAULT=0.6.2
cd /tmp
wget https://releases.hashicorp.com/vault/${VAULT}/vault_${VAULT}_linux_amd64.zip \
    --quiet \
    -O vault.zip

echo "Installing Vault..."
unzip -q vault.zip >/dev/null
chmod +x vault
sudo mv vault /usr/local/bin
sudo chmod 0755 /usr/local/bin/vault
sudo chown root:root /usr/local/bin/vault
sudo mkdir -p /etc/systemd/system/vault.d
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault



echo "Configuring Vault..."
sudo bash -c "cat >/etc/systemd/system/vault.d/config.json.tmp" << VAULTCONF

listener "atlas" {
  infrastructure = "{{ YOUR_ATLAS_USERNAME }}/vault-ent-test"
  token          = "{{ YOUR_ATLAS_TOKEN }}"
  node_id        = "{{ instance-id }}"
  tls_disable    = 1
}

backend "consul" {
  address = "127.0.0.1:8500"
  path = "vault"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

telemetry {
  statsite_address = "127.0.0.1:8125"
  disable_hostname = true
}

cluster_name = "test"
disable_mlock = true
VAULTCONF




echo "Configuring Vault sys policy..."
sudo bash -c "cat >/etc/systemd/system/vault.d/sys.hcl" << ACL
path "sys/capabilities-self" {
  capabilities = ["update"]
}
path "sys/mounts" {
  capabilities = ["read"]
}
ACL


echo "Configuring Vault environment..."
sudo bash -c "cat >/etc/profile.d/vault.sh" << VAULTENV
export VAULT_ADDR=http://127.0.0.1:8200
VAULTENV
sudo chmod 755 /etc/profile.d/vault.sh


echo "Installing Vault startup script..."
sudo bash -c "cat >/etc/systemd/system/vault.service" << 'VAULTSVC'
[Unit]
Description=vault agent
Requires=network-online.target
After=network-online.target consul.service

[Service]
EnvironmentFile=-/etc/default/vault
Restart=on-failure
ExecStart=/usr/local/bin/vault server $VAULT_FLAGS -config=/etc/systemd/system/vault.d/config.json
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
VAULTSVC
sudo chmod 0644 /etc/systemd/system/vault.service
