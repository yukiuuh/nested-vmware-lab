# Nested VMware Lab builder

## Description

Create nested VCF / VVF / vSphere( + AVI or NSX) lab using Terraform and Ansible

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

## Default configuration example

### Login
| Component | Username | Password | 
| ---- |---- | ---- |
| ESX | root | VMware123! |
| VC | root,administrator@vsphere.local | VMware123! |
| AVI | admin | VMware123! |
| NSX | root,admin | VMware123!VMware123! |
| rouer | labadmin | VMware123! |
| storage | labadmin | VMware123! |
| kickstarter | root | VMware123! |

### Network
- DNS entries: [hosts.tftpl](module/router/templates/hosts.tftpl)

#### Segments
| Network | VLAN | Description | Comment | 
| ---- | ---- | ---- | ---- |
| 10.0.0.1/24 | 0 | Management| DHCP enabled 10.0.0.200 - 10.0.0.250 |
| 10.0.1.1/24 | 1001 | VM Management| for VCF |
| 10.0.2.1/24 | 1002 | vSAN| |
| 10.0.3.1/24 | 1003 | vMotion| |
| 10.0.4.1/24 | 1004 | iSCSI1| storage: 10.0.4.10 |
| 10.0.5.1/24 | 1005 | iSCSI2| storage: 10.0.5.10 |
| 10.0.6.1/24 | 1006 | frontend | for Avi |
| 10.0.7.1/24 | 1007| workload | for Avi |
| 10.0.8.1/24 | 1008 | ESXi vTEP | |
| 10.0.9.1/24 | 1009 | Edge vTEP | |
| 10.0.10.1/24 | 1010 | BGP Uplink1 | |
| 10.0.11.1/24 | 1011 | BGP Uplink2 | |
| 10.0.12.1/24 | 1012 | BGP Uplink3 | |
| 10.0.13.1/24 | 1013 | BGP Uplink4 | |

#### BGP
| Router ASN | Router Address | Edge ASN | Edge Uplink Address| 
| ---- | ---- | ---- | ---- |
| 200 | 10.0.10.1 | 300 | 10.0.10.2 - 10.0.10.9 |
| 200 | 10.0.11.1 | 300 | 10.0.11.2 - 10.0.11.9 |
| 200 | 10.0.12.1 | 400| 10.0.12.2 - 10.0.12.9 |
| 200 | 10.0.13.1 | 400| 10.0.13.2 - 10.0.13.9 |

## Tips

 - deploy VCF/VVF: [vcf9.tfvars.example](examples/vcf9.tfvars.example), [vcf5.tfvars.example](examples/vcf5.tfvars.example)

 - re-deploy ESXi hosts for VCF
```bash
terraform taint 'module.esxi_cluster.module.ks_server[0].module.kickstarter_photon.vsphere_virtual_machine.photon_with_cloudinit'
terraform taint 'module.esxi_cluster.module.nested_esxi_scratch["0"].vsphere_virtual_machine.nested_esxi'
terraform taint 'module.esxi_cluster.module.nested_esxi_scratch["1"].vsphere_virtual_machine.nested_esxi'
terraform taint 'module.esxi_cluster.module.nested_esxi_scratch["2"].vsphere_virtual_machine.nested_esxi'
terraform taint 'module.esxi_cluster.module.nested_esxi_scratch["3"].vsphere_virtual_machine.nested_esxi'
terraform taint 'module.esxi_cluster.module.nested_esxi_scratch["0"].terraform_data.kickstart_script'
terraform taint 'module.esxi_cluster.module.nested_esxi_scratch["1"].terraform_data.kickstart_script'
terraform taint 'module.esxi_cluster.module.nested_esxi_scratch["2"].terraform_data.kickstart_script'
terraform taint 'module.esxi_cluster.module.nested_esxi_scratch["3"].terraform_data.kickstart_script'
```