#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOYMENT_DIR="$ROOT_DIR/deployments/deployment_v2"
ANSIBLE_CONFIG_PATH="$ROOT_DIR/ansible.cfg"
INVENTORY_FILE=""
EXTRA_VARS_FILE=""
SHOW_VERIFICATION_ERRORS="false"
PLAYBOOK_PATH="$ROOT_DIR/playbooks/deployment_v2_prepare.yaml"
PRETTY="false"
DEFAULT_EXTRA_VARS_BASENAME="tfvars/prepare.vars.yaml"

usage() {
  cat <<EOF
Run the deployment_v2 preparation playbook from Terraform output.

Usage:
  $SCRIPT_NAME [options]

Options:
  --deployment-dir DIR   deployment_v2 Terraform working directory
                         default: $DEPLOYMENT_DIR
  --inventory-file FILE  write rendered inventory JSON to FILE and use it
                         default: temporary file
  --extra-vars FILE      Ansible extra-vars YAML/JSON file
                         default: auto-detect $DEPLOYMENT_DIR/$DEFAULT_EXTRA_VARS_BASENAME
  --pretty               pretty-print the generated inventory JSON
  --help                 show this help

Expected extra vars include:
  none for the current http_iso or rclone_iso flows

Template:
  cp $DEPLOYMENT_DIR/tfvars/prepare.vars.yaml.example \\
     $DEPLOYMENT_DIR/tfvars/prepare.vars.yaml
EOF
}

fail() {
  printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-dir)
      DEPLOYMENT_DIR="${2:-}"
      shift 2
      ;;
    --inventory-file)
      INVENTORY_FILE="${2:-}"
      shift 2
      ;;
    --extra-vars)
      EXTRA_VARS_FILE="${2:-}"
      shift 2
      ;;
    --pretty)
      PRETTY="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

require_cmd terraform
require_cmd ansible-playbook

[[ -d "$DEPLOYMENT_DIR" ]] || fail "deployment directory not found: $DEPLOYMENT_DIR"
[[ -f "$PLAYBOOK_PATH" ]] || fail "playbook not found: $PLAYBOOK_PATH"
[[ -f "$ANSIBLE_CONFIG_PATH" ]] || fail "ansible config not found: $ANSIBLE_CONFIG_PATH"

if [[ -z "$EXTRA_VARS_FILE" && -f "$DEPLOYMENT_DIR/$DEFAULT_EXTRA_VARS_BASENAME" ]]; then
  EXTRA_VARS_FILE="$DEPLOYMENT_DIR/$DEFAULT_EXTRA_VARS_BASENAME"
fi

if [[ -z "$INVENTORY_FILE" ]]; then
  INVENTORY_FILE="$(mktemp --suffix=.json)"
fi

RENDER_ARGS=(--deployment-dir "$DEPLOYMENT_DIR")
if [[ "$PRETTY" == "true" ]]; then
  RENDER_ARGS+=(--pretty)
fi

"$DEPLOYMENT_DIR/scripts/render_ansible_inventory.sh" "${RENDER_ARGS[@]}" > "$INVENTORY_FILE"

PLAYBOOK_ARGS=(-i "$INVENTORY_FILE" "$PLAYBOOK_PATH")
if [[ -n "$EXTRA_VARS_FILE" ]]; then
  [[ -f "$EXTRA_VARS_FILE" ]] || fail "extra vars file not found: $EXTRA_VARS_FILE (template: $DEPLOYMENT_DIR/tfvars/prepare.vars.yaml.example)"
  PLAYBOOK_ARGS+=(-e "@$EXTRA_VARS_FILE")
fi

ANSIBLE_CONFIG="$ANSIBLE_CONFIG_PATH" ansible-playbook "${PLAYBOOK_ARGS[@]}"
