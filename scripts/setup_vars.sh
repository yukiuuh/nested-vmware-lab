#!/bin/bash

ROOT_DIR=/app
TEMPLATES_DIR=$ROOT_DIR/templates
SUPPORTED_MODES=("vsphere" "avi" "nsx")

while [ $# -gt 0 ]; do
  case $1 in
    -m) MODE=$2; shift 2;;
    -c) CONFIG=$2; shift 2;;
    --) shift; break ;;
  esac
done

if ! printf '%s\n' "${SUPPORTED_MODES[@]}" | grep -qx $MODE ; then
    echo "unsupported mode."
    exit 1
fi

echo
case $MODE in
  vsphere)
    gomplate -d config=$CONFIG --file $TEMPLATES_DIR/vsphere.tfvars.tpl ;;
  avi) 
    gomplate -d config=$CONFIG --file $TEMPLATES_DIR/vsphere.tfvars.tpl; gomplate -d config=$CONFIG --file $TEMPLATES_DIR/avi.tfvars.tpl ;;
  nsx) 
    gomplate -d config=$CONFIG --file $TEMPLATES_DIR/vsphere.tfvars.tpl ; gomplate -d config=$CONFIG --file $TEMPLATES_DIR/nsx.tfvars.tpl ;;
esac
