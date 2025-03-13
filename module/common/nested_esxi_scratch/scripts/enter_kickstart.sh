#!/bin/bash

govc vm.keystrokes -vm $VM_NAME -s " ks=${KS_URL} nameserver=${KS_NAMESERVER} ip=${KS_IP} netmask=${KS_NETMASK} gateway=${KS_GATEWAY} vlanid=${KS_VLAN} entropySources=1 disableHwrng=TRUE allowLegacyCPU=true"
govc vm.keystrokes -vm $VM_NAME -c 0x28 # ENTER