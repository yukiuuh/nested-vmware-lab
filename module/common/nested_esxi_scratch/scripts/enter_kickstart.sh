#!/bin/bash

govc vm.keystrokes -vm $VM_NAME -s " ks=${KS_URL} nameserver=${KS_NAMESERVER} ip=${KS_IP} netmask=${KS_NETMASK} gateway=${KS_GATEWAY} vlanid=${KS_VLAN} entropySources=${ENTROPY_SOURCE} disableHwrng=${DISABLE_HWRNG} allowLegacyCPU=true"
govc vm.keystrokes -vm $VM_NAME -c 0x28 # ENTER