#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'EOF'
Render an Ansible inventory JSON document from deployment_v2 Terraform output.

Input modes:
- read `terraform output -json ansible_inventory_seed` from a deployment_v2 directory
- read a previously-saved JSON seed file

Usage:
  render_ansible_inventory.sh [options]

Options:
  --deployment-dir DIR   deployment_v2 working directory
                         default: current working directory
  --seed-file FILE       read ansible_inventory_seed JSON from FILE instead of terraform output
  --pretty               pretty-print JSON output
  --help                 show this help

Examples:
  render_ansible_inventory.sh --deployment-dir ./deployments/deployment_v2 --pretty
  terraform -chdir=deployments/deployment_v2 output -json ansible_inventory_seed > /tmp/seed.json
  render_ansible_inventory.sh --seed-file /tmp/seed.json --pretty
EOF
}

fail() {
  printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

DEPLOYMENT_DIR="$(pwd)"
SEED_FILE=""
JQ_FORMAT_FLAGS=("-c")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-dir)
      DEPLOYMENT_DIR="${2:-}"
      shift 2
      ;;
    --seed-file)
      SEED_FILE="${2:-}"
      shift 2
      ;;
    --pretty)
      JQ_FORMAT_FLAGS=()
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

require_cmd jq

if [[ -n "$SEED_FILE" ]]; then
  [[ -f "$SEED_FILE" ]] || fail "seed file not found: $SEED_FILE"
  SEED_JSON="$(cat "$SEED_FILE")"
else
  require_cmd terraform
  [[ -d "$DEPLOYMENT_DIR" ]] || fail "deployment directory not found: $DEPLOYMENT_DIR"
  SEED_JSON="$(terraform -chdir="$DEPLOYMENT_DIR" output -json ansible_inventory_seed)"
fi

jq -n "${JQ_FORMAT_FLAGS[@]}" \
  --argjson seed "$SEED_JSON" \
  '
  $seed as $seed
  | ($seed.routers // {}) as $routers
  | ($seed.esxi_groups // {}) as $esxi_groups
  | ($seed.storages // {}) as $storages
  | ($seed.vcenters // {}) as $vcenters
  | (
      reduce ($routers | to_entries[]) as $router ({};
        . + {
          ($router.key): {
            ansible_host: $router.value.ansible.host,
            ansible_user: $router.value.ansible.user,
            deployment_v2_kind: "router",
            deployment_v2_name: $router.key,
            deployment_v2_router: $router.value
          }
        }
      )
      +
      reduce ($storages | to_entries[]) as $storage ({};
        . + {
          ($storage.key): {
            ansible_host: $storage.value.ansible.host,
            ansible_user: $storage.value.ansible.user,
            deployment_v2_kind: "storage",
            deployment_v2_name: $storage.key,
            deployment_v2_storage: $storage.value
          }
        }
      )
      +
      reduce ($vcenters | to_entries[]) as $vcenter ({};
        . + {
          ($vcenter.value.fqdn): {
            ansible_host: $vcenter.value.ansible.host,
            ansible_user: $vcenter.value.ansible.user,
            deployment_v2_kind: "vcenter",
            deployment_v2_name: $vcenter.key,
            deployment_v2_vcenter: $vcenter.value
          }
        }
      )
      +
      reduce (
        [
          $esxi_groups
          | to_entries[]
          | . as $group
          | ($group.value.hosts // [])
          | to_entries[]
          | {
              alias: .value.fqdn,
              value: {
                ansible_host: .value.ansible.host,
                ansible_user: .value.ansible.user,
                deployment_v2_kind: "esxi_host",
                deployment_v2_name: .value.hostname,
                deployment_v2_esxi_group: $group.key,
                deployment_v2_esxi_host: .value,
                deployment_v2_esxi_group_config: $group.value
              }
            }
        ][]
      ) as $host ({};
        . + { ($host.alias): $host.value }
      )
    ) as $hostvars
  | (
      ["deployment_v2_routers", "deployment_v2_storages", "deployment_v2_esxi", "deployment_v2_vcenters"]
      + ($routers | keys | map("deployment_v2_router_" + .))
      + ($storages | keys | map("deployment_v2_storage_" + .))
      + ($esxi_groups | keys | map("deployment_v2_esxi_group_" + .))
      + ($vcenters | keys | map("deployment_v2_vcenter_" + .))
    ) as $all_children
  | {
      all: {
        children: ($all_children | map({key: ., value: {}}) | from_entries),
        vars: {
          deployment_v2: $seed
        }
      },
      deployment_v2_routers: {
        hosts: ($routers | keys | map({key: ., value: $hostvars[.]}) | from_entries)
      },
      deployment_v2_storages: {
        hosts: ($storages | keys | map({key: ., value: $hostvars[.]}) | from_entries)
      },
      deployment_v2_vcenters: {
        hosts: ($vcenters | to_entries | map({key: .value.fqdn, value: $hostvars[.value.fqdn]}) | from_entries)
      },
      deployment_v2_esxi: {
        children: (($esxi_groups | keys | map("deployment_v2_esxi_group_" + .)) | map({key: ., value: {}}) | from_entries)
      }
    }
    +
    (
      reduce ($routers | to_entries[]) as $router ({};
        . + {
          ("deployment_v2_router_" + $router.key): {
            hosts: { ($router.key): $hostvars[$router.key] },
            vars: {
              deployment_v2_router_name: $router.key,
              deployment_v2_router: $router.value
            }
          }
        }
      )
    )
    +
    (
      reduce ($storages | to_entries[]) as $storage ({};
        . + {
          ("deployment_v2_storage_" + $storage.key): {
            hosts: { ($storage.key): $hostvars[$storage.key] },
            vars: {
              deployment_v2_storage_name: $storage.key,
              deployment_v2_storage: $storage.value
            }
          }
        }
      )
    )
    +
    (
      reduce ($vcenters | to_entries[]) as $vcenter ({};
        . + {
          ("deployment_v2_vcenter_" + $vcenter.key): {
            hosts: { ($vcenter.value.fqdn): $hostvars[$vcenter.value.fqdn] },
            vars: {
              deployment_v2_vcenter_name: $vcenter.key,
              deployment_v2_vcenter: $vcenter.value
            }
          }
        }
      )
    )
    +
    (
      reduce ($esxi_groups | to_entries[]) as $group ({};
        . + {
          ("deployment_v2_esxi_group_" + $group.key): {
            hosts: ((($group.value.hosts // []) | map(.fqdn)) | map({key: ., value: $hostvars[.]}) | from_entries),
            vars: {
              deployment_v2_esxi_group_name: $group.key,
              deployment_v2_esxi_group: $group.value
            }
          }
        }
      )
    )
'
