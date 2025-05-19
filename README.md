# Nested VMware Lab builder

## Description

Create nested vSphere( + AVI or NSX) lab using Terraform and Ansible

![overview](overview.svg)

## Requirments
 - vSphere 8.0
 - 2 portgroups
   - WAN(Management): DHCP, internet reachable
   - LAN(Nested): isolated, allow DHCP trafic, VLAN trunk network with Promiscuous or MAC Learning, MAC address changes, Forged transmit
 - Docker
 - Product binaries(installer iso, ova)

## Setup
1. Create LAN network
 - vSS: VLAN 4095, Promiscous, MAC address changes, Forged transmit
 - vDS: VLAN trunk, MAC Learning, MAC address changes, Forged transmit
 - NSX: VLAN 0-4094, MAC Learning, MAC address changes, allow DHCP trafic
2. Place product binaries
 - vCenter Server/ESXi: put ISO on datastore reachable from physical host
 - NSX/AVI: put ova on http server reachable from WAN network

## Usage
1. Start bootstrap container
```bash
docker run -v nested-vmware-lab-workspace:/app/workspace -u bootstrap  -it --rm ghcr.io/yukiuuh/nested-vmware-lab-bootstrap:0.0.1
```
2. Create working directory
```bash
cp -r ./deployments/nested_vsphere/ ./workspace/
```

3. Create config file
```bash
cd ./workspace/nested_vsphere
cp /app/examples/config.yaml ./
vim config.yaml # edit

setup_vars.sh -c ./config.yaml -m <vsphere|avi|nsx> > terraform.tfvars # generate tfvars file

vim terraform.tfvars # check or edit tfvars
```

4. Deploy
```bash
terraform plan # check tfvars 

terraform apply
```

5. Access to LAB
```bash
# 1. via SOCKS5 proxy(default ssh password: VMware123!)
ssh -D 127.0.0.1:<port number used for SOCKS5> -Nn -f labadmin@<router WAN IP>

# 2. via HTTP proxy(port 3128)
https_proxy=http://<router WAN IP>:3128

# 3. via RDP to WAN IP: you have to create RDP host(IP:10.0.0.2) in LAN network
```

6. Clean up
```bash
terraform destroy
```