#!/bin/bash

MAX_RETRY=60
INTERVAL=1

for i in $(seq 1 $MAX_RETRY); do
    echo "wait for ESXi boot (retries $i / $MAX_RETRY)"
    govc vm.info $VM_NAME | grep poweredOn
    if [ $? -eq 0 ]; then
      break;
    fi
    sleep $INTERVAL && /bin/false
done

# wait for govc stability
sleep 5

govc vm.power -off -force $VM_NAME
govc device.boot -vm $VM_NAME -setup
govc vm.power -on $VM_NAME

sleep 5

govc vm.keystrokes -vm $VM_NAME -ls=true -c KEY_ENTER,KEY_SPACE,KEY_SPACE,KEY_SPACE,KEY_SPACE,KEY_SPACE,KEY_O