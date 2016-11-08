#!/usr/bin/env bash

echo "Installing HAProxy..."
sudo apt-get install -y -q haproxy
sudo systemctl disable haproxy.service
