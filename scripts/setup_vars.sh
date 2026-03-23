#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${NVL_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
TEMPLATES_DIR="$ROOT_DIR/templates"
SUPPORTED_MODES=("vsphere" "avi" "nsx")
MODE=""
CONFIG=""

while [ $# -gt 0 ]; do
  case $1 in
    -m) MODE=$2; shift 2;;
    -c) CONFIG=$2; shift 2;;
    --) shift; break ;;
  esac
done

if [ -z "$MODE" ] || [ -z "$CONFIG" ]; then
    echo "usage: $(basename "$0") -c <config.yaml> -m <vsphere|avi|nsx>" >&2
    exit 1
fi

if ! printf '%s\n' "${SUPPORTED_MODES[@]}" | grep -qx "$MODE" ; then
    echo "unsupported mode."
    exit 1
fi

if [ ! -f "$CONFIG" ]; then
    echo "config file not found: $CONFIG" >&2
    exit 1
fi

if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "templates directory not found: $TEMPLATES_DIR" >&2
    exit 1
fi

echo
case $MODE in
  vsphere)
    gomplate -d "config=$CONFIG" --file "$TEMPLATES_DIR/vsphere.tfvars.tpl" ;;
  avi) 
    gomplate -d "config=$CONFIG" --file "$TEMPLATES_DIR/vsphere.tfvars.tpl"
    gomplate -d "config=$CONFIG" --file "$TEMPLATES_DIR/avi.tfvars.tpl" ;;
  nsx) 
    gomplate -d "config=$CONFIG" --file "$TEMPLATES_DIR/vsphere.tfvars.tpl"
    gomplate -d "config=$CONFIG" --file "$TEMPLATES_DIR/nsx.tfvars.tpl" ;;
esac
