#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'EOF'
Create an SSO user for deployment_v2 and assign the vSphere permissions it
needs to run the full deployment flow.

This script assumes:
- `govc` is already installed
- `GOVC_URL` / `GOVC_USERNAME` / `GOVC_PASSWORD` point to a vCenter account that
  can create SSO users and assign permissions

The script intentionally uses built-in roles rather than a fragile hand-written
privilege list:
- `ReadOnly` on `/` with propagation enabled for inventory traversal
- `Admin` on `/` without propagation for global vCenter services such as tags,
  storage policies, and content libraries
- `Admin` on the target datacenter with propagation enabled for VM, network,
  datastore, and cluster operations inside the lab scope

Usage:
  create_deployment_v2_user.sh --username USER --password PASS --datacenter DC [options]

Options:
  --username USER                 SSO user name without domain suffix
  --password PASS                 SSO user password
  --datacenter DC                 Lab datacenter name
  --sso-domain DOMAIN             SSO domain name (default: vsphere.local)
  --root-readonly-role ROLE       Role for `/` inventory traversal (default: ReadOnly)
  --root-global-role ROLE         Role for `/` global services (default: Admin)
  --datacenter-role ROLE          Role for `/<datacenter>` (default: Admin)
  --root-global-propagate BOOL    Propagate root global role (default: false)
  --datacenter-propagate BOOL     Propagate datacenter role (default: true)
  --principal PRINCIPAL           Override the principal to bind permissions to
  --dry-run                       Print the govc commands without executing them
  --help                          Show this help

Examples:
  export GOVC_URL='https://administrator@vsphere.local:***@vcsa.nested.lab/sdk'
  export GOVC_INSECURE=1
  create_deployment_v2_user.sh \
    --username terraform-v2 \
    --password 'ChangeMe123!' \
    --datacenter Datacenter

Notes:
  - `govc sso.user.create` expects the bare username, not `user@domain`
  - permission assignment usually targets `user@domain`
EOF
}

log() {
  printf '[%s] %s\n' "$SCRIPT_NAME" "$*"
}

fail() {
  printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

normalize_bool() {
  case "${1,,}" in
    true|yes|1) printf 'true\n' ;;
    false|no|0) printf 'false\n' ;;
    *) fail "invalid boolean value: $1" ;;
  esac
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'DRY-RUN:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

user_exists() {
  govc sso.user.ls "${SSO_DOMAIN}" 2>/dev/null | grep -Eq "^(${PRINCIPAL}|${USERNAME})$"
}

permission_exists() {
  local entity_path="$1"
  local role_name="$2"
  local propagate="$3"
  local expected_prop

  if [[ "$propagate" == "true" ]]; then
    expected_prop="true"
  else
    expected_prop="false"
  fi

  govc permissions.ls "${entity_path}" 2>/dev/null \
    | awk -v principal="${PRINCIPAL}" -v role="${role_name}" -v prop="${expected_prop}" '
        $1 == principal && $2 == role && $3 == prop { found = 1 }
        END { exit found ? 0 : 1 }
      '
}

ensure_permission() {
  local entity_path="$1"
  local role_name="$2"
  local propagate="$3"

  if permission_exists "${entity_path}" "${role_name}" "${propagate}"; then
    log "permission already present: principal=${PRINCIPAL} role=${role_name} path=${entity_path} propagate=${propagate}"
    return 0
  fi

  log "assigning role=${role_name} path=${entity_path} propagate=${propagate}"
  run_cmd govc permissions.set -principal "${PRINCIPAL}" -role "${role_name}" -propagate="${propagate}" "${entity_path}"
}

USERNAME=""
PASSWORD=""
DATACENTER=""
SSO_DOMAIN="vsphere.local"
ROOT_READONLY_ROLE="ReadOnly"
ROOT_GLOBAL_ROLE="Admin"
DATACENTER_ROLE="Admin"
ROOT_GLOBAL_PROPAGATE="false"
DATACENTER_PROPAGATE="true"
PRINCIPAL=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username)
      USERNAME="${2:-}"
      shift 2
      ;;
    --password)
      PASSWORD="${2:-}"
      shift 2
      ;;
    --datacenter)
      DATACENTER="${2:-}"
      shift 2
      ;;
    --sso-domain)
      SSO_DOMAIN="${2:-}"
      shift 2
      ;;
    --root-readonly-role)
      ROOT_READONLY_ROLE="${2:-}"
      shift 2
      ;;
    --root-global-role)
      ROOT_GLOBAL_ROLE="${2:-}"
      shift 2
      ;;
    --datacenter-role)
      DATACENTER_ROLE="${2:-}"
      shift 2
      ;;
    --root-global-propagate)
      ROOT_GLOBAL_PROPAGATE="$(normalize_bool "${2:-}")"
      shift 2
      ;;
    --datacenter-propagate)
      DATACENTER_PROPAGATE="$(normalize_bool "${2:-}")"
      shift 2
      ;;
    --principal)
      PRINCIPAL="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
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

require_cmd govc

[[ -n "${USERNAME}" ]] || fail "--username is required"
[[ -n "${PASSWORD}" ]] || fail "--password is required"
[[ -n "${DATACENTER}" ]] || fail "--datacenter is required"
[[ -n "${GOVC_URL:-}" ]] || fail "GOVC_URL must be set"

PRINCIPAL="${PRINCIPAL:-${USERNAME}@${SSO_DOMAIN}}"
DATACENTER_PATH="/${DATACENTER}"

log "target principal: ${PRINCIPAL}"
log "target datacenter: ${DATACENTER_PATH}"

if [[ "${DRY_RUN}" == "false" ]]; then
  govc datacenter.info "${DATACENTER_PATH}" >/dev/null 2>&1 || fail "datacenter not found: ${DATACENTER_PATH}"
fi

if user_exists; then
  log "SSO user already exists: ${PRINCIPAL}"
else
  log "creating SSO user: ${USERNAME} in ${SSO_DOMAIN}"
  run_cmd govc sso.user.create -p "${PASSWORD}" "${USERNAME}"
fi

ensure_permission "/" "${ROOT_READONLY_ROLE}" "true"
ensure_permission "/" "${ROOT_GLOBAL_ROLE}" "${ROOT_GLOBAL_PROPAGATE}"
ensure_permission "${DATACENTER_PATH}" "${DATACENTER_ROLE}" "${DATACENTER_PROPAGATE}"

cat <<EOF

Principal created or verified: ${PRINCIPAL}

Assigned permissions:
- / -> ${ROOT_READONLY_ROLE} (propagate=true)
- / -> ${ROOT_GLOBAL_ROLE} (propagate=${ROOT_GLOBAL_PROPAGATE})
- ${DATACENTER_PATH} -> ${DATACENTER_ROLE} (propagate=${DATACENTER_PROPAGATE})

Use this principal for deployment_v2, for example:
  export VSPHERE_USER='${PRINCIPAL}'
  export VSPHERE_PASSWORD='${PASSWORD}'

If your lab needs full root-level inheritance, rerun with:
  --root-global-propagate true
EOF
