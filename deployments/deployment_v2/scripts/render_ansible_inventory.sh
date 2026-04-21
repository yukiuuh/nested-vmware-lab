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
  --no-provider-discovery
                         do not resolve missing provider-observed values before rendering
  --provider-discovery-wait DURATION
                         wait duration for provider IP discovery
                         default: 2m
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
PROVIDER_DISCOVERY="true"
PROVIDER_DISCOVERY_WAIT="2m"

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
    --no-provider-discovery)
      PROVIDER_DISCOVERY="false"
      shift
      ;;
    --provider-discovery-wait)
      PROVIDER_DISCOVERY_WAIT="${2:-}"
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

env_value() {
  local name="$1"
  if [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    printf '%s' "${!name:-}"
  fi
}

normalize_govc_url() {
  local server="$1"
  if [[ "$server" =~ ^https?:// ]]; then
    printf '%s' "$server"
  else
    printf 'https://%s' "$server"
  fi
}

govc_url_to_server() {
  local url="$1"
  url="${url#http://}"
  url="${url#https://}"
  url="${url%%/*}"
  url="${url##*@}"
  printf '%s' "$url"
}

hydrate_vsphere_seed_credentials() {
  local server user password datacenter
  local server_env user_env password_env datacenter_env

  server="$(jq -r '.credentials.vsphere.server // empty' <<<"$SEED_JSON")"
  user="$(jq -r '.credentials.vsphere.user // empty' <<<"$SEED_JSON")"
  password="$(jq -r '.credentials.vsphere.password // empty' <<<"$SEED_JSON")"
  datacenter="$(jq -r '.credentials.vsphere.datacenter // empty' <<<"$SEED_JSON")"

  server_env="$(jq -r '.credentials.vsphere.server_env // empty' <<<"$SEED_JSON")"
  user_env="$(jq -r '.credentials.vsphere.user_env // empty' <<<"$SEED_JSON")"
  password_env="$(jq -r '.credentials.vsphere.password_env // empty' <<<"$SEED_JSON")"
  datacenter_env="$(jq -r '.credentials.vsphere.datacenter_env // empty' <<<"$SEED_JSON")"

  if [[ -z "$server" && -n "$server_env" ]]; then
    server="$(env_value "$server_env")"
  fi
  if [[ -z "$user" && -n "$user_env" ]]; then
    user="$(env_value "$user_env")"
  fi
  if [[ -z "$password" && -n "$password_env" ]]; then
    password="$(env_value "$password_env")"
  fi
  if [[ -z "$datacenter" && -n "$datacenter_env" ]]; then
    datacenter="$(env_value "$datacenter_env")"
  fi
  if [[ -z "$server" && -n "${VSPHERE_SERVER:-}" ]]; then
    server="$VSPHERE_SERVER"
  fi
  if [[ -z "$user" && -n "${VSPHERE_USER:-}" ]]; then
    user="$VSPHERE_USER"
  fi
  if [[ -z "$password" && -n "${VSPHERE_PASSWORD:-}" ]]; then
    password="$VSPHERE_PASSWORD"
  fi
  if [[ -z "$datacenter" && -n "${VSPHERE_DATACENTER:-}" ]]; then
    datacenter="$VSPHERE_DATACENTER"
  fi
  if [[ -z "$server" && -n "${GOVC_URL:-}" ]]; then
    server="$(govc_url_to_server "$GOVC_URL")"
  fi
  if [[ -z "$user" && -n "${GOVC_USERNAME:-}" ]]; then
    user="$GOVC_USERNAME"
  fi
  if [[ -z "$password" && -n "${GOVC_PASSWORD:-}" ]]; then
    password="$GOVC_PASSWORD"
  fi
  if [[ -z "$datacenter" && -n "${GOVC_DATACENTER:-}" ]]; then
    datacenter="$GOVC_DATACENTER"
  fi

  SEED_JSON="$(
    jq \
      --arg server "$server" \
      --arg user "$user" \
      --arg password "$password" \
      --arg datacenter "$datacenter" \
      '
        def set_nonempty($path; $value):
          if $value != "" then setpath($path; $value) else . end;

        .credentials = (.credentials // {})
        | .credentials.vsphere = (.credentials.vsphere // {})
        | set_nonempty(["credentials", "vsphere", "server"]; $server)
        | set_nonempty(["credentials", "vsphere", "user"]; $user)
        | set_nonempty(["credentials", "vsphere", "password"]; $password)
        | set_nonempty(["credentials", "vsphere", "datacenter"]; $datacenter)
        | .vcenters = (
            (.vcenters // {})
            | with_entries(
                if (.value.placement.kind // "") == "provider_vsphere" then
                  .value.target = (.value.target // {})
                  | .value = (
                      .value
                      | if $server != "" and ((.target.hostname // "") == "") then
                          .target.hostname = $server
                        else . end
                      | if $user != "" and ((.target.username // "") == "") then
                          .target.username = $user
                        else . end
                      | if $password != "" and ((.target.password // "") == "") then
                          .target.password = $password
                        else . end
                      | if $datacenter != "" and ((.target.datacenter // "") == "") then
                          .target.datacenter = $datacenter
                        else . end
                    )
                else . end
              )
          )
      ' <<<"$SEED_JSON"
  )"
}

load_vsphere_govc_env() {
  local server user password datacenter insecure
  local server_env user_env password_env datacenter_env

  server="$(jq -r '.credentials.vsphere.server // empty' <<<"$SEED_JSON")"
  user="$(jq -r '.credentials.vsphere.user // empty' <<<"$SEED_JSON")"
  password="$(jq -r '.credentials.vsphere.password // empty' <<<"$SEED_JSON")"
  datacenter="$(jq -r '.credentials.vsphere.datacenter // empty' <<<"$SEED_JSON")"
  insecure="$(jq -r 'if .credentials.vsphere.insecure == false then "0" else (.credentials.vsphere.insecure // "1" | tostring) end' <<<"$SEED_JSON")"

  server_env="$(jq -r '.credentials.vsphere.server_env // empty' <<<"$SEED_JSON")"
  user_env="$(jq -r '.credentials.vsphere.user_env // empty' <<<"$SEED_JSON")"
  password_env="$(jq -r '.credentials.vsphere.password_env // empty' <<<"$SEED_JSON")"
  datacenter_env="$(jq -r '.credentials.vsphere.datacenter_env // empty' <<<"$SEED_JSON")"

  if [[ -z "$server" && -n "$server_env" ]]; then
    server="$(env_value "$server_env")"
  fi
  if [[ -z "$user" && -n "$user_env" ]]; then
    user="$(env_value "$user_env")"
  fi
  if [[ -z "$password" && -n "$password_env" ]]; then
    password="$(env_value "$password_env")"
  fi
  if [[ -z "$datacenter" && -n "$datacenter_env" ]]; then
    datacenter="$(env_value "$datacenter_env")"
  fi
  if [[ -z "$server" && -n "${VSPHERE_SERVER:-}" ]]; then
    server="$VSPHERE_SERVER"
  fi
  if [[ -z "$user" && -n "${VSPHERE_USER:-}" ]]; then
    user="$VSPHERE_USER"
  fi
  if [[ -z "$password" && -n "${VSPHERE_PASSWORD:-}" ]]; then
    password="$VSPHERE_PASSWORD"
  fi
  if [[ -z "$datacenter" && -n "${VSPHERE_DATACENTER:-}" ]]; then
    datacenter="$VSPHERE_DATACENTER"
  fi

  if [[ -n "$server" ]]; then
    export GOVC_URL
    GOVC_URL="$(normalize_govc_url "$server")"
  fi
  if [[ -n "$user" ]]; then
    export GOVC_USERNAME="$user"
  fi
  if [[ -n "$password" ]]; then
    export GOVC_PASSWORD="$password"
  fi
  if [[ -n "$datacenter" ]]; then
    export GOVC_DATACENTER="$datacenter"
  fi
  if [[ -n "$insecure" ]]; then
    export GOVC_INSECURE="$insecure"
  fi
}

ensure_vsphere_discovery_ready() {
  require_cmd govc
  load_vsphere_govc_env
  [[ -n "${GOVC_URL:-}" ]] || fail "vSphere provider discovery requires credentials.vsphere.server, credentials.vsphere.server_env, or GOVC_URL"
  [[ -n "${GOVC_USERNAME:-}" ]] || fail "vSphere provider discovery requires credentials.vsphere.user, credentials.vsphere.user_env, or GOVC_USERNAME"
  [[ -n "${GOVC_PASSWORD:-}" ]] || fail "vSphere provider discovery requires credentials.vsphere.password, credentials.vsphere.password_env, or GOVC_PASSWORD"
}

normalize_vsphere_vm_ref() {
  local ref="$1"
  if [[ "$ref" == vm-* ]]; then
    printf 'VirtualMachine:%s' "$ref"
  else
    printf '%s' "$ref"
  fi
}

first_ipv4_from_text() {
  local text="$1"
  local exclude="$2"
  local candidate

  text="${text//,/ }"
  for candidate in $text; do
    if [[ "$candidate" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] \
      && [[ "$candidate" != 169.254.* ]] \
      && [[ "$candidate" != "$exclude" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
}

discover_vsphere_vm_ipv4() {
  local vm_ref="$1"
  local network_name="$2"
  local exclude_ip="$3"
  local normalized_ref ip ip_output

  normalized_ref="$(normalize_vsphere_vm_ref "$vm_ref")"

  if [[ -n "$network_name" ]]; then
    ip="$(
      govc vm.info -json "$normalized_ref" \
        | jq -r --arg network "$network_name" --arg exclude "$exclude_ip" '
            [
              .virtualMachines[]?.guest.net[]?
              | select((.network // "") == $network)
              | .ipConfig.ipAddress[]?.ipAddress
              | select(test("^([0-9]{1,3}\\.){3}[0-9]{1,3}$"))
              | select(. != $exclude)
              | select(startswith("169.254.") | not)
            ][0] // empty
          '
    )" || ip=""
    if [[ -n "$ip" ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
  fi

  ip_output="$(govc vm.ip -a -v4 -wait="$PROVIDER_DISCOVERY_WAIT" "$normalized_ref" 2>/dev/null || true)"
  first_ipv4_from_text "$ip_output" "$exclude_ip"
}

discover_vsphere_vm_macs() {
  local vm_ref="$1"
  local normalized_ref

  normalized_ref="$(normalize_vsphere_vm_ref "$vm_ref")"
  govc device.info -vm "$normalized_ref" -json 'ethernet-*' \
    | jq -r '.devices[]? | .macAddress? // empty | ascii_downcase' \
    | sort -u
}

set_router_wan_ip() {
  local router_name="$1"
  local ip="$2"

  SEED_JSON="$(
    jq \
      --arg router "$router_name" \
      --arg ip "$ip" \
      '
        .routers[$router].wan_ip = $ip
        | .routers[$router].ansible = ((.routers[$router].ansible // {}) + {host: $ip})
      ' <<<"$SEED_JSON"
  )"
}

set_esxi_host_macs() {
  local group_name="$1"
  local host_index="$2"
  local macs_json="$3"

  SEED_JSON="$(
    jq \
      --arg group "$group_name" \
      --argjson index "$host_index" \
      --argjson macs "$macs_json" \
      '
        .esxi_groups[$group].hosts[$index].mac_addresses = $macs
        | .esxi_groups[$group].hosts[$index].primary_mac_address = $macs[0]
        | .esxi_groups[$group].hosts[$index].observed = (.esxi_groups[$group].hosts[$index].observed // {})
        | .esxi_groups[$group].hosts[$index].observed.mac_addresses = $macs
        | .esxi_groups[$group].hosts[$index].observed.primary_mac_address = $macs[0]
      ' <<<"$SEED_JSON"
  )"
}

normalize_existing_esxi_host_mac() {
  local group_name="$1"
  local host_index="$2"
  local primary_mac="$3"

  SEED_JSON="$(
    jq \
      --arg group "$group_name" \
      --argjson index "$host_index" \
      --arg mac "$primary_mac" \
      '
        .esxi_groups[$group].hosts[$index].mac_addresses = (
          .esxi_groups[$group].hosts[$index].mac_addresses // [$mac]
        )
        | .esxi_groups[$group].hosts[$index].observed = (.esxi_groups[$group].hosts[$index].observed // {})
        | .esxi_groups[$group].hosts[$index].observed.primary_mac_address = $mac
        | .esxi_groups[$group].hosts[$index].observed.mac_addresses = (
          .esxi_groups[$group].hosts[$index].observed.mac_addresses
          // .esxi_groups[$group].hosts[$index].mac_addresses
        )
      ' <<<"$SEED_JSON"
  )"
}

resolve_vsphere_routers() {
  local router_name provider vm_ref network_name management_ip ansible_host wan_ip
  local discovered_ip row

  while IFS= read -r row; do
    router_name="$(jq -r '.[0]' <<<"$row")"
    provider="$(jq -r '.[1]' <<<"$row")"
    vm_ref="$(jq -r '.[2]' <<<"$row")"
    network_name="$(jq -r '.[3]' <<<"$row")"
    management_ip="$(jq -r '.[4]' <<<"$row")"
    ansible_host="$(jq -r '.[5]' <<<"$row")"
    wan_ip="$(jq -r '.[6]' <<<"$row")"

    [[ "$provider" == "vsphere" ]] || continue

    if [[ -z "$wan_ip" && -n "$ansible_host" && "$ansible_host" != "$management_ip" ]]; then
      set_router_wan_ip "$router_name" "$ansible_host"
      continue
    fi

    if [[ -n "$wan_ip" && -n "$ansible_host" && "$ansible_host" != "$management_ip" ]]; then
      continue
    fi

    [[ -n "$vm_ref" ]] || fail "routers.${router_name}: vSphere provider discovery requires provider_ref.vm_name, provider_ref.vm_id, or name"
    ensure_vsphere_discovery_ready

    discovered_ip="$(discover_vsphere_vm_ipv4 "$vm_ref" "$network_name" "$management_ip")"
    [[ -n "$discovered_ip" ]] || fail "routers.${router_name}: unable to resolve provider-facing vSphere IP for VM ${vm_ref}"
    set_router_wan_ip "$router_name" "$discovered_ip"
  done < <(
    jq -r '
      (.routers // {})
      | to_entries[]
      | [
          .key,
          (.value.provider_ref.provider // .value.lifecycle.provider // ""),
          (
            .value.provider_ref.inventory_path
            // .value.provider_ref.vm_id
            // .value.provider_ref.provider_vm_id
            // .value.observed.provider_vm_id
            // .value.provider_ref.vm_name
            // .value.name
            // .key
          ),
          (.value.networks.wan.network_name // .value.networks.wan.network // ""),
          (.value.management_ip // .value.networks.lan.gateway // ""),
          (.value.ansible.host // ""),
          (.value.wan_ip // "")
        ]
      | @json
    ' <<<"$SEED_JSON"
  )
}

resolve_vsphere_esxi_macs() {
  local group_name host_index install_method provider vm_ref mac_count primary_mac
  local macs_json row
  local -a macs

  while IFS= read -r row; do
    group_name="$(jq -r '.[0]' <<<"$row")"
    host_index="$(jq -r '.[1]' <<<"$row")"
    install_method="$(jq -r '.[2]' <<<"$row")"
    provider="$(jq -r '.[3]' <<<"$row")"
    vm_ref="$(jq -r '.[4]' <<<"$row")"
    mac_count="$(jq -r '.[5]' <<<"$row")"
    primary_mac="$(jq -r '.[6]' <<<"$row")"

    [[ "$install_method" == "ansible_router_pxe" ]] || continue
    [[ "$provider" == "vsphere" ]] || continue

    if [[ "$mac_count" != "0" && -n "$primary_mac" ]]; then
      continue
    fi

    if [[ -n "$primary_mac" ]]; then
      normalize_existing_esxi_host_mac "$group_name" "$host_index" "$primary_mac"
      continue
    fi

    [[ -n "$vm_ref" ]] || fail "esxi_groups.${group_name}.hosts[${host_index}]: vSphere MAC discovery requires provider_ref.vm_name, provider_ref.vm_id, or name"
    ensure_vsphere_discovery_ready

    mapfile -t macs < <(discover_vsphere_vm_macs "$vm_ref" || true)
    [[ "${#macs[@]}" -gt 0 ]] || fail "esxi_groups.${group_name}.hosts[${host_index}]: unable to resolve vSphere MAC addresses for VM ${vm_ref}"
    macs_json="$(printf '%s\n' "${macs[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')"
    set_esxi_host_macs "$group_name" "$host_index" "$macs_json"
  done < <(
    jq -r '
      (.esxi_groups // {})
      | to_entries[] as $group
      | ($group.value.hosts // [])
      | to_entries[]
      | [
          $group.key,
          (.key | tostring),
          ($group.value.install.method // ""),
          (
            .value.provider_ref.provider
            // $group.value.provider_ref.provider
            // .value.lifecycle.provider
            // $group.value.lifecycle.provider
            // ""
          ),
          (
            .value.provider_ref.inventory_path
            // .value.provider_ref.vm_id
            // .value.provider_ref.provider_vm_id
            // .value.observed.provider_vm_id
            // .value.provider_ref.vm_name
            // .value.name
            // .value.fqdn
            // .value.hostname
            // ""
          ),
          ((.value.mac_addresses // []) | length | tostring),
          (.value.primary_mac_address // .value.observed.primary_mac_address // "")
        ]
      | @json
    ' <<<"$SEED_JSON"
  )
}

resolve_provider_observations() {
  resolve_vsphere_routers
  resolve_vsphere_esxi_macs
}

validate_inventory_seed_observations() {
  local errors

  errors="$(
    jq -r '
      [
        (
          (.routers // {})
          | to_entries[]
          | select((.value.ansible.host // "") == "")
          | "routers.\(.key): ansible.host is required"
        ),
        (
          (.esxi_groups // {})
          | to_entries[] as $group
          | select(($group.value.install.method // "") == "ansible_router_pxe")
          | ($group.value.hosts // [])
          | to_entries[]
          | select(
              (((.value.mac_addresses // []) | length) == 0)
              and ((.value.primary_mac_address // .value.observed.primary_mac_address // "") == "")
            )
          | "esxi_groups.\($group.key).hosts[\(.key)]: ansible_router_pxe requires provider-resolved MAC addresses"
        )
      ]
      | .[]
    ' <<<"$SEED_JSON"
  )"

  if [[ -n "$errors" ]]; then
    fail "seed is missing required inventory observations before inventory rendering:
$errors"
  fi
}

validate_inventory_seed_credentials() {
  local errors

  errors="$(
    jq -r '
      def provider_name:
        .provider_ref.provider
        // .lifecycle.provider
        // .placement.provider
        // "";
      def placement_kind:
        .placement.kind // "";
      def is_vsphere_backed:
        provider_name == "vsphere"
        or placement_kind == "provider_vsphere"
        or placement_kind == "nested_vsphere";
      def uses_vsphere:
        any((.routers // {})[]?; is_vsphere_backed)
        or any((.storages // {})[]?; is_vsphere_backed)
        or any((.vcenters // {})[]?; is_vsphere_backed)
        or any((.esxi_groups // {})[]?; is_vsphere_backed or (.install.method // "") == "ansible_vsphere_iso_boot");

      if uses_vsphere then
        [
          if (.credentials.vsphere.server // "") == "" then "credentials.vsphere.server" else empty end,
          if (.credentials.vsphere.user // "") == "" then "credentials.vsphere.user" else empty end,
          if (.credentials.vsphere.password // "") == "" then "credentials.vsphere.password" else empty end,
          if (.credentials.vsphere.datacenter // "") == "" then "credentials.vsphere.datacenter" else empty end
        ][]
      else
        empty
      end
    ' <<<"$SEED_JSON"
  )"

  if [[ -n "$errors" ]]; then
    fail "seed is missing vSphere credentials required by Ansible inventory rendering:
$errors
Set credentials.vsphere.* directly, set the referenced *_env variables, or export VSPHERE_SERVER/VSPHERE_USER/VSPHERE_PASSWORD/VSPHERE_DATACENTER."
  fi
}

if [[ -n "$SEED_FILE" ]]; then
  [[ -r "$SEED_FILE" ]] || fail "seed file not readable: $SEED_FILE"
  SEED_JSON="$(cat "$SEED_FILE")"
else
  require_cmd terraform
  [[ -d "$DEPLOYMENT_DIR" ]] || fail "deployment directory not found: $DEPLOYMENT_DIR"
  SEED_JSON="$(terraform -chdir="$DEPLOYMENT_DIR" output -json ansible_inventory_seed)"
fi

hydrate_vsphere_seed_credentials
validate_inventory_seed_credentials
if [[ "$PROVIDER_DISCOVERY" == "true" ]]; then
  resolve_provider_observations
fi
validate_inventory_seed_observations

jq -n "${JQ_FORMAT_FLAGS[@]}" \
  --argjson seed "$SEED_JSON" \
  '
  $seed as $seed
  | ($seed.routers // {}) as $routers
  | ($seed.esxi_groups // {}) as $esxi_groups
  | ($seed.storages // {}) as $storages
  | ($seed.vcenters // {}) as $vcenters
  | ($seed.credentials.ansible // {}) as $ansible_defaults
  | (
    def env_value($name):
      if ($name // "") == "" then null else env[$name] // null end;
    def first_nonempty($values):
      ($values | map(select(. != null and . != "")) | .[0] // null);
    def optional_value($key; $value):
      if ($value // "") == "" then {} else {($key): $value} end;
    def ansible_hostvars($ansible; $kind):
      (
        first_nonempty([
          $ansible.password,
          env_value($ansible.password_env),
          $ansible_defaults.password,
          env_value($ansible_defaults.password_env),
          (
            if ($kind == "router" or $kind == "storage" or $kind == "esxi_host") then
              $seed.credentials.vm_admin_password
            else
              null
            end
          )
        ]) // null
      ) as $password
      | (
        first_nonempty([
          $ansible.private_key_file,
          env_value($ansible.private_key_file_env),
          $ansible_defaults.private_key_file,
          env_value($ansible_defaults.private_key_file_env),
          env.ANSIBLE_PRIVATE_KEY_FILE
        ]) // null
      ) as $private_key_file
      | (
        first_nonempty([
          $ansible.ssh_common_args,
          $ansible_defaults.ssh_common_args,
          env.NVL_ANSIBLE_SSH_COMMON_ARGS
        ]) // null
      ) as $ssh_common_args
      | {
          ansible_host: $ansible.host,
          ansible_user: first_nonempty([$ansible.user, $ansible_defaults.user])
        }
        + optional_value("ansible_password"; $password)
        + optional_value("ansible_ssh_private_key_file"; $private_key_file)
        + optional_value("ansible_ssh_common_args"; $ssh_common_args)
        + optional_value("ansible_port"; $ansible.port);
    (
      reduce ($routers | to_entries[]) as $router ({};
        . + {
          ($router.key): (
            ansible_hostvars($router.value.ansible; "router") + {
            deployment_v2_kind: "router",
            deployment_v2_name: $router.key,
            deployment_v2_router: $router.value
            }
          )
        }
      )
      +
      reduce ($storages | to_entries[]) as $storage ({};
        . + {
          ($storage.key): (
            ansible_hostvars($storage.value.ansible; "storage") + {
            deployment_v2_kind: "storage",
            deployment_v2_name: $storage.key,
            deployment_v2_storage: $storage.value
            }
          )
        }
      )
      +
      reduce ($vcenters | to_entries[]) as $vcenter ({};
        . + {
          ($vcenter.value.fqdn): (
            ansible_hostvars($vcenter.value.ansible; "vcenter") + {
            deployment_v2_kind: "vcenter",
            deployment_v2_name: $vcenter.key,
            deployment_v2_vcenter: $vcenter.value
            }
          )
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
              value: (
                ansible_hostvars(.value.ansible; "esxi_host") + {
                deployment_v2_kind: "esxi_host",
                deployment_v2_name: .value.hostname,
                deployment_v2_esxi_group: $group.key,
                deployment_v2_esxi_host: .value,
                deployment_v2_esxi_group_config: $group.value
                }
              )
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
  )
'
