#!/bin/bash
set -e

# Clean apt
sudo apt-get -y autoremove
sudo apt-get -y autoclean
sudo rm -rf /var/lib/apt/lists/*

# Configure cloud-init for OVF datasource
sudo rm -f /etc/cloud/cloud.cfg.d/99-installer.cfg
sudo cloud-init clean --machine-id --seed
echo "disable_vmware_customization: false" | sudo tee /etc/cloud/cloud.cfg.d/99-vmware.cfg

# Reset cloud-init
sudo rm -rf /var/lib/cloud/*
sudo rm -rf /var/log/cloud-init*

sudo rm /etc/netplan/50-cloud-init.yaml
sudo rm -rf /var/log/journal/*
sudo truncate -s 0 /var/log/syslog /var/log/auth.log

sudo apt-get purge snapd -y
sudo rm -rf /snap /var/snap /var/lib/snapd

# Zero out free space to save space
sudo dd if=/dev/zero of=/EMPTY bs=1M || true
sudo rm -f /EMPTY
