# deployment_v2

This directory is the new deployment entrypoint for the redesigned deployment model.

Status:

- `deployments/nested_vsphere` remains the current implementation
- `deployments/deployment_v2` is the parallel implementation target
- provider-neutral `Deployment` documents are the intended human-authored source
  of truth for new work
- `deployment.tfvars.json` is a generated vSphere Terraform provider spec, not
  a primary authoring format
- Terraform input uses `provider_config` instead of `provider` because `provider` is a reserved variable name
- `provider_config.server`, `provider_config.user`, and `provider_config.password` are optional; when omitted, the vSphere provider can read `VSPHERE_SERVER`, `VSPHERE_USER`, and `VSPHERE_PASSWORD` from the environment
- `name_prefix` controls the VM name prefix for this deployment; a random hex suffix is added automatically so multiple deployments can coexist in the same vSphere inventory
- `ssh_authorized_keys` injects SSH public keys into Router VMs via cloud-init

Current scope:

- accept the generated vSphere split-variable provider spec
- create Router VMs from `routers`
- create ESXi VMs from `esxi_groups` with Terraform-only inventory/lifecycle scope
- create storage service VMs from `storages`
- describe vCenter deployments from `vcenters` for Router-driven prepare
- expose structured outputs for future Terraform and Ansible integration
- avoid modifying the behavior of the legacy deployment entrypoint

Next steps:

1. add schema-aware validations for `deployment`
2. implement Router-driven ESXi PXE / kickstart workflow wiring
3. emit stable Ansible-oriented inventory outputs for Routers and ESXi hosts
4. expand vCenter placement and source support beyond the current provider-backed ISO flow
5. expand Router and ESXi placement support beyond `provider_vsphere`

Current implementation notes:

- Router creation currently supports `placement.kind = "provider_vsphere"` only
- Router placement overrides are not implemented yet; Router placement currently resolves from `provider_config`
- Router install media currently supports `install_sources` of type `http_ovf` or `local_ovf`
- Router definitions may use `source.install_source`; `template` is accepted as a compatibility alias during the transition
- Router EVPN-VXLAN gateway support is enabled by default for NSX Route Controller testing. Defaults use VLAN `1014`, underlay `10.0.14.1/24`, MTU `8000`, Router AS `200`, Route Controller AS `500`, Route Controller peers `["10.0.10.10"]`, and Red/Blue tenant VRFs with L3VNIs `50001` and `50002`; override these under `routers[*].evpn`, add multiple Route Controller floating IPs with `routers[*].evpn.bgp.route_controller_peers`, or set `routers[*].evpn.enabled = false`. Router images keep `linux-virtual` and install only the matching `linux-modules-extra-<kernel>` package required for VRF/VXLAN kernel modules.
- storage service creation currently supports `placement.kind = "provider_vsphere"` only
- storage placement overrides are not implemented yet; storage placement currently resolves from `provider_config`
- storage install media currently supports `install_sources` of type `http_ovf` or `local_ovf`
- each `storages` entry must reference an existing `router`; network defaults resolve from that router unless explicitly overridden on the storage object
- ESXi group creation currently supports `placement.kind = "provider_vsphere"` only
- ESXi placement overrides are not implemented yet; ESXi placement currently resolves from `provider_config`
- ESXi creation instantiates VMs in Terraform; current bootstrap preparation is handled by `playbooks/deployment_v2_prepare.yaml`
- ESXi install media currently validates `install_sources` of type `http_iso`, `rclone_iso`, or `datastore_iso`
- each `esxi_groups` entry must define `ntp_servers`; deployment_v2 prepare renders that list into the ESXi kickstart with `esxcli system ntp set`
- ESXi bootstrap is now described only by `install`; boot mode is derived internally from `install.method`
- use `install.kickstart.template`, not `install.pxe.ks_template`; the kickstart template is shared by both PXE and datastore ISO workflows
- optional `esxi_groups[*].vmkernel_adapters` declares post-install VMkernel networking for storage or other non-management traffic; each adapter defines `name`, `purpose`, `vswitch`, `portgroup`, either `uplink` or `active_uplinks`, `vlan`, `subnet`, and optional `mtu`, `standby_uplinks`, `unused_uplinks`, and `services`
- `output.ansible_inventory_seed` is a short-term Terraform-produced seed for downstream Ansible work; use `scripts/render_ansible_inventory.sh` to turn a saved seed file or Terraform output into an Ansible inventory JSON document
- rendered inventory now includes `deployment_v2_storages` and `deployment_v2_storage_<name>` groups for `storages`
- vCenter objects are currently metadata-only in Terraform; `playbooks/deployment_v2_prepare.yaml` deploys them from Router-mounted installer media
- vCenter prepare currently supports `placement.kind = "provider_vsphere"` and `placement.kind = "nested_vsphere"`
- vCenter install media currently validates `install_sources` of type `http_iso`, `rclone_iso`, or `datastore_iso`
- rendered inventory now includes `deployment_v2_vcenters` and `deployment_v2_vcenter_<name>` groups for `vcenters`
- provider-target and nested-ESXi-target vCenter deployment both run from the Router through the mounted VCSA CLI installer; Terraform does not invoke local `ovftool`
- `provider_vsphere` vCenter target selection is resolved at prepare time against live vCenter inventory, so the installer uses the canonical inventory path instead of a guessed host string
- vCenter prepare launches `provider_vsphere` vCenters asynchronously before ESXi verification, so provider-target VCSA deployment can overlap with nested ESXi bootstrap
- `nested_vsphere` vCenter placement targets a deployment_v2-managed ESXi host by `placement.esxi_group` and `placement.host`; it waits for ESXi readiness, not for a provider-target vCenter to complete
- `nested_vsphere` vCenter placement supports `placement.storage.mode = "existing_datastore"`, `"iscsi_datastore"`, or `"vsan_bootstrap"`; iSCSI datastore preparation and vSAN target-disk SSD preparation run before nested VCSA launch
- `placement.storage.mode = "iscsi_datastore"` must list `placement.storage.vmkernel_purposes`; those purposes select VMkernel adapters from the target ESXi group before software iSCSI discovery and VMFS creation
- prepare now treats "endpoint reachable" and "current deployment VM exists" as separate checks; if `10.0.0.100:443` responds but the expected `name_prefix-randomhex-<vcenter>` VM is missing, prepare fails as a stale-deployment conflict instead of silently skipping install
- `terraform destroy` now includes a best-effort cleanup hook for deployment_v2-managed VCSA VMs by exact VM name, so old deployment_v2 appliances do not remain orphaned in inventory when the Terraform state is torn down cleanly
- ESXi kickstart rendering now assumes VCF-style firstboot handling for all deployment_v2 hosts; `shape.vcf_mode` is kept only as compatibility metadata

Ansible integration helpers:

- `AnsibleSeed` is the realized runtime contract for Ansible, not only an inventory source; it carries connection endpoints, provider references, observed MACs, capabilities, and provider-operation metadata needed by prepare tasks
- provider-specific specs such as vSphere `deployment.tfvars.json` are generated
  from `Deployment` documents and should not drift into a second hand-maintained
  configuration source
- `scripts/render_ansible_inventory.sh` renders a saved `AnsibleSeed` file, or the migration-mode Terraform `output.ansible_inventory_seed`, into dynamic inventory JSON for Ansible
- `scripts/render_ansible_inventory.sh` resolves missing vSphere-observed connection data before rendering inventory: Router provider-facing IPs are discovered from the router VM, and ESXi MAC addresses are discovered from host VM NICs when `provider_ref` and vSphere credentials are present
- for Terraform-managed vSphere labs, Terraform output is the source of truth for generated VM names, router DHCP/WAN IPs, and ESXi MAC addresses; static seed generation is only for externally provisioned or non-Terraform flows
- future vCD-backed labs must not assume direct controller connectivity to the Router; saved seeds should carry the external NAT IP separately from lab-internal Router addresses, with the first design assuming port-preserving NAT for SSH, HTTP, and proxy traffic
- future vCD support needs two seed producer paths: Terraform-managed vApps from Terraform output, and catalog/external vApps discovered by org, VDC, and vApp name through the vCD API; catalog vApp VM mapping should use embedded VM metadata rather than loose name matching, and ESXi host count should be discovered from the vApp contents
- future vCD catalog vApps should use vApp metadata `vapp.nat.vm` to identify the VM whose external IP becomes the Router-facing Ansible endpoint
- `provider_config` may carry `server_env`, `user_env`, `password_env`, and `datacenter_env`; saved seeds can keep those references, and inventory rendering hydrates `credentials.vsphere.server/user/password/datacenter` from the environment before Ansible runs
- `ssh_authorized_keys` injects public keys into Router and storage guests; `ansible_connection.private_key_file`, `ansible_connection.private_key_file_env`, `ansible_connection.password`, and `ansible_connection.password_env` control how the controller connects to those guests
- when no explicit Ansible SSH password is set, inventory rendering falls back to `credentials.vm_admin_password` for Router, storage, and nested ESXi SSH hosts
- `scripts/run_prepare.sh` renders inventory from `--seed-file` or Terraform output and runs `playbooks/deployment_v2_prepare.yaml`
- `playbooks/deployment_v2_prepare.yaml` consumes that inventory and prepares the current deployment_v2 bootstrap runtime on Router VMs for HTTP, PXE, and optional `rclone`
- `install.method = "ansible_router_pxe"` derives a PXE boot path from Router-hosted TFTP + HTTP assets
- `install.method = "ansible_vsphere_iso_boot"` derives a datastore-ISO boot path from a virtual CD/DVD plus VMware API key injection
- vCenter prepare runs the mounted VCSA CLI installer on the Router, using `ansible_inventory_seed.vcenters` as the deployment contract
- `placement.kind = "nested_vsphere"` targets a nested ESXi host by `placement.esxi_group` and `placement.host`; `placement.datastore` and `placement.network` are passed to the VCSA installer as ESXi target settings
- `placement.storage.mode = "iscsi_datastore"` creates VMkernel adapters, applies standard portgroup uplink policy, prepares software iSCSI, performs discovery, rescans storage, and creates or verifies the GPT-backed VMFS datastore on the target ESXi before VCSA deployment; matching LUNs with existing partitions are not overwritten
- `placement.storage.lun` references a deployment_v2 storage LUN by name; Terraform derives the ESXi-side LUN ID from that LUN's order in `storages[*].luns`, and Ansible selects the matching discovered iSCSI path dynamically on the ESXi host
- `storages[*].luns` is a list; the Web UI wizard can add or remove LUN rows and separately selects which LUN becomes the nested VCSA VMFS datastore through `placement.storage.lun`
- deployment_v2 storage LUN preflight requires ESXi to report a 512-byte logical block size; physical block size is logged for diagnostics but is not treated as a hard failure for deployment_v2-managed external iSCSI LUNs
- `iscsi_datastore` storage preparation runs over Router-proxied ESXi SSH rather than VMware Tools guest operations because `partedUtil`/VMFS raw device operations can fail under the VMware Tools execution context even when the same command works in an SSH root session; guest operations remain suitable for non-raw readiness checks, and a future API-module path should use `community.vmware.vmware_vswitch`, `vmware_portgroup`, `vmware_vmkernel`, `vmware_host_iscsi`, and `vmware_host_datastore` rather than `govc`
- Do not use VMware Tools guest operations (`vmware_vm_shell`) for ESXi raw storage mutations such as `partedUtil`, `vmkfstools -C`, or whole-device reads/writes under `/vmfs/devices/disks`; Guest Operations can run as `root`, but the process is created by VMware Tools rather than an SSH/ESXi Shell login session, and VMkernel raw device access can return `Operation not permitted` even when the same command succeeds over SSH
- Guest Operations are acceptable for non-raw ESXi readiness checks such as marker files, simple `esxcli storage filesystem list` verification, or other commands that do not open whole storage devices directly
- When investigating a suspected Guest Operations storage-context issue, compare the same command through SSH and through `vmware_vm_shell`: `id`, `ls -l /vmfs/devices/disks/<naa>`, `dd if=/vmfs/devices/disks/<naa> of=/dev/null bs=512 count=1`, and `partedUtil getptbl /vmfs/devices/disks/<naa>`; if only Guest Operations fails with `Operation not permitted`, keep the operation on Router-proxied SSH or move it to VMware API modules
- iSCSI `port_binding` is optional and defaults to `false`; when iSCSI VMkernel adapters share one standard vSwitch, model each storage portgroup with one active vmnic and put the other storage vmnic outside active/standby via `unused_uplinks` so ESXi port binding uses a single uplink per bound VMkernel adapter
- `placement.storage.mode = "vsan_bootstrap"` selects a `vCSA_with_cluster_on_ESXi`-compatible installer JSON with `VCSA_cluster` metadata after target-disk preparation; provide `placement.storage.vsan.datacenter`, `cluster`, exactly one `cache_disks` entry, and at least one `capacity_disks` entry; the referenced VCSA installer `url` or `path` must contain a detectable 7.0 U2 or later version such as `7.0.2` or `8.0.3`
- `vsan_bootstrap` validates the target ESXi version at runtime, requires ESXi 7.0 U2 or later, verifies the requested disks are present and not VMFS extents, and marks the cache/capacity disks as SSD through an ESXi SSH session before VCSA launch
- after VCSA deployment completes, `deployment_v2_register_esxi` registers hosts from each vCenter's `manages` ESXi groups into that vCenter; each ESXi group may be managed by only one vCenter and must be attached to the same Router as that vCenter
- for `vsan_bootstrap`, the VCSA CLI installer creates the datacenter/cluster and registers the bootstrap ESXi host; post-registration skips datacenter/cluster creation, registers only the remaining managed ESXi hosts, validates the deployed vCenter and managed ESXi hosts are 7.0 U2 or later, abandons the cluster Quickstart/HCI workflow, ensures vSAN is enabled with automatic disk claim disabled, claims one disk group per managed host from the configured cache/capacity disks, and creates or updates the `vSAN FTT0` storage policy by deriving it from an existing vSAN policy
- before ESXi registration, `deployment_v2_register_esxi` can configure vCenter
  Lifecycle Manager online depots from `vcenters[*].depots`,
  `vsphere_override_new_depots`, or
  `deployment_v2_register_esxi_override_new_depots`; each item may be
  `{location: "https://repo.example.local/vmw-depot-index.xml", description:
  "Local ESXi depot"}` or `[location, description]`
- vCenter 9.0 or later requires image-based ESXi lifecycle management, so
  deployment_v2 validation requires at least one `vcenters[*].depots` entry when
  the VCSA installer source version is detected as 9.0+
- registration creates or adopts the target datacenter and cluster before adding hosts; defaults are `Datacenter` and `Cluster`, while `vsan_bootstrap` uses its installer-created datacenter and cluster from existing placement metadata
- ESXi host registration uses the managed host FQDN as the vCenter add-host identifier, so Router DNS entries must match the rendered ESXi hostnames; `vsan_bootstrap` also passes the bootstrap ESXi FQDN, not its IP, to the VCSA CLI installer so the installer-created host entry is named consistently
- ESXi registration runs the VMware Ansible modules on the Router, not through the controller-side HTTP proxy; the role vendors controller `pyVmomi`/`pyVim` plus the vSAN Python SDK helpers into `/opt/nested-vmware-lab/python-vendor/vmware` so Router package repositories are not required
- ESXi boot uses TFTP-hosted `mboot.efi` and `boot.cfg`; HTTP is used only to publish kickstart files and the mounted ISO tree referenced by `prefix=`
- `http_iso` means a Router-managed HTTP ISO reference; deployment_v2 prepare downloads the ISO with `curl`/`get_url` into `/srv/install-sources/<source>/source.iso` and loop-mounts it into `/srv/install-sources/<source>/mounted`
- `rclone_iso` means a Router-managed HTTP ISO reference that is exposed via `rclone mount` under `/srv/install-sources/<source>/remote` and then loop-mounted directly from that remote path into `/srv/install-sources/<source>/mounted`
- `datastore_iso` means a vSphere datastore-backed ISO path; for ESXi, Terraform connects it directly to each host VM as a virtual CD/DVD, and for Router-driven VCSA deploys Terraform attaches it to the Router VM so prepare can mount the presented `/dev/srN` device into `/srv/install-sources/<source>/mounted`
- mounted ESXi ISOs are staged per install source into `tftp_root/<source>/...` and `http_root/iso/<source>/...`, so multiple installer ISOs can coexist without path collisions
- MAC-based PXE assignment needs each ESXi host MAC before Router runtime staging. Terraform-produced seeds already carry this from module outputs; saved/static seeds can omit it when `render_ansible_inventory.sh` can resolve the vSphere VM from `provider_ref.vm_name`, `provider_ref.vm_id`, or `name`
- `vm_admin_password` is now carried inside `ansible_inventory_seed.credentials.vm_admin_password`, so deployment_v2 prepare no longer needs an extra-vars root password for the normal `http_iso` flow
- deployment_v2 prepare/register tasks intentionally avoid `no_log`; these credentials belong to disposable lab vCenter/ESXi appliances, and visible module errors are required for troubleshooting failed deployments
- Ansible tasks should use maintained Ansible modules for vSphere operations when available; do not introduce `govc` calls from Ansible unless no suitable module exists for the operation
- provider API actions required during ESXi install, such as power, reset, reboot, boot preparation, or media operations, should be routed through a provider operation role keyed by seed `capabilities` and `provider_ref`; generic install roles should not grow provider-specific branches
- future vCD provider operations should use direct vCD REST API calls for vApp VM reset/reboot/power operations because maintained Ansible modules do not cover the required operations; prefer a helper command that owns auth/session/task polling and exposes JSON stdin/stdout to Ansible
- Router runtime services are now auto-derived from attached ESXi groups and vCenter install sources
- `router.execution.enable_pxe`, `router.execution.enable_http`, and `router.execution.enable_rclone` are optional compatibility overrides; they are no longer required in tfvars

Prepare vars template:

```bash
cp deployments/deployment_v2/tfvars/prepare.vars.yaml.example \
  deployments/deployment_v2/tfvars/prepare.vars.yaml
```

For the current `http_iso`, `rclone_iso`, and `datastore_iso` flows, deployment_v2 prepare can still work from Terraform output as a migration convenience. The provider-neutral workflow should save or generate an `AnsibleSeed` file and pass it explicitly.

Minimal prepare example:

```bash
nix develop -c deployments/deployment_v2/scripts/run_prepare.sh
```

Saved-seed prepare example:

```bash
nix develop -c deployments/deployment_v2/scripts/run_prepare.sh \
  --seed-file examples/ansible-seed.v1alpha1.json
```

Example custom vLCM depot override in the prepare extra-vars file:

```yaml
vsphere_override_new_depots:
  - location: "https://repo.example.local/esxi/main/vmw-depot-index.xml"
    description: "Local ESXi depot"
```

For vCenter 9.0+ prefer keeping the depot in the Deployment document so
validation and generated seeds carry it:

```json
"vcenters": {
  "vcsa_a": {
    "depots": [
      {
        "location": "https://repo.example.local/esxi/main/vmw-depot-index.xml",
        "description": "Local ESXi depot"
      }
    ]
  }
}
```

Render a saved seed without running Ansible:

```bash
deployments/deployment_v2/scripts/render_ansible_inventory.sh \
  --seed-file examples/ansible-seed.v1alpha1.json \
  --pretty
```

`scripts/run_prepare.sh` automatically uses
`deployments/deployment_v2/tfvars/prepare.vars.yaml` when that file exists.
Provider discovery is enabled by default; pass `--provider-discovery-wait 5m`
if Router VMware Tools needs more time to report its provider-facing IP.
The current Web UI edits `Deployment` and `AnsibleSeed` documents and shows the
prepare command flow, but it does not edit `prepare.vars.yaml`; keep prepare
extra-vars such as `vsphere_override_new_depots` in that file until a dedicated
prepare configuration UI exists.

Provider-neutral schema and capability validation live in `tools/nvl`:

```bash
pnpm --dir tools/nvl install
pnpm --dir tools/nvl build
tools/nvl/packages/cli/bin/nvl validate examples/deployment.v1alpha1.json
tools/nvl/packages/cli/bin/nvl validate examples/deployment-static.v1alpha1.json
tools/nvl/packages/cli/bin/nvl validate examples/ansible-seed.v1alpha1.json
tools/nvl/packages/cli/bin/nvl check-capabilities examples/ansible-seed.v1alpha1.json
tools/nvl/packages/cli/bin/nvl providers
```

Generate the vSphere Terraform provider spec from the provider-neutral deployment:

```bash
tools/nvl/packages/cli/bin/nvl generate vsphere-tfvars \
  examples/deployment.v1alpha1.json
```

This writes `generated/<lab>/deployment.tfvars.json` by default. Treat that file
as generated input to Terraform; edit the source `Deployment` document instead
of hand-maintaining the generated provider spec. Use `--stdout` when piping or
redirecting the artifact manually.

Produce a versioned `AnsibleSeed` from a Terraform-managed deployment:

```bash
tools/nvl/packages/cli/bin/nvl seed from-terraform \
  examples/deployment.v1alpha1.json \
  --deployment-dir deployments/deployment_v2
```

This writes `generated/<lab>/ansible-seed.json` by default and normalizes the
Terraform output with lifecycle metadata, provider references, realized
capabilities, and observed MAC addresses.
When provider credentials are supplied through `server_env`, `user_env`, or
`password_env`, the saved seed keeps the environment-variable references. The
inventory renderer resolves them into concrete Ansible module credentials at
runtime, so the normal prepare path remains:

```bash
deployments/deployment_v2/scripts/run_prepare.sh \
  --deployment-dir deployments/deployment_v2
```

Produce a versioned `AnsibleSeed` from an externally provisioned lab without
Terraform state:

```bash
tools/nvl/packages/cli/bin/nvl seed from-static \
  examples/deployment-static.v1alpha1.json \
  --observed examples/observed-static.v1alpha1.json
```

The static seed producer is the first provider-adapter boundary for flows where
Router and NAS bootstrap is already complete before `deployment_v2_prepare`
runs. For vSphere-backed labs, observed Router WAN IPs and ESXi MAC addresses
do not need to be written by hand when the seed includes vSphere credentials
and `provider_ref` VM identifiers; `scripts/render_ansible_inventory.sh`
resolves those values before Ansible connects to the Router or stages PXE.
Use `--strict-capabilities` with `nvl seed from-static` only when you want seed
generation itself to fail before provider discovery.

The initial configuration editor shell is available in the same workspace:

```bash
pnpm --dir tools/nvl --filter web build
pnpm --dir tools/nvl --filter web test
pnpm --dir tools/nvl --filter web exec ng serve --host 127.0.0.1 --port 4200
```

The editor imports `@nvl/core` for schema validation and preview generation. To
create a vSAN bootstrap Deployment from the UI, open the Deployment Design
Wizard, choose nested vCenter placement, set Storage Mode to `vSAN Bootstrap`,
and fill in the vSAN datastore, datacenter, cluster, cache disk, and capacity
disk fields. The generated JSON includes `placement.storage.mode =
"vsan_bootstrap"`, the VCSA installer `VCSA_cluster` metadata, vSAN VMkernel
adapter defaults, and the extra nested ESXi disks needed by the selected cache
and capacity disk names.
Use either a canonical ESXi device name visible under `/vmfs/devices/disks`,
such as `naa.*`, or an explicit runtime path such as `vmhba0:C0:T1:L0`.
deployment_v2 resolves runtime paths to canonical device names with
`esxcfg-mpath` before rendering the VCSA installer JSON. If vSAN disks were
added to an already-created nested ESXi VM, recreate that ESXi VM before
preparing vSAN because the nested ESXi Terraform module intentionally ignores
disk drift on existing VMs.

Current scope of `deployment_v2_prepare`:

- Router-hosted ESXi PXE / kickstart bootstrap
- vSphere datastore ISO bootstrap for ESXi via virtual CD/DVD and EFI boot option injection
- ESXi post-install verification through vSphere guest operations
- Router-hosted VCSA deployment from mounted `http_iso`, `rclone_iso`, or `datastore_iso` install sources

VMkernel adapter schema:

```json
{
  "storages": {
    "storage_a": {
      "luns": [
        { "name": "lun01", "size_gb": 200 },
        { "name": "lun02", "size_gb": 200 },
        { "name": "lun03", "size_gb": 200 },
        { "name": "lun04", "size_gb": 200 }
      ]
    }
  },
  "esxi_groups": {
    "management_a": {
      "vmkernel_adapters": [
        {
          "name": "vmk1",
          "purpose": "iscsi_a",
          "vswitch": "vSwitch1",
          "portgroup": "Storage1",
          "active_uplinks": ["vmnic2"],
          "unused_uplinks": ["vmnic3"],
          "vlan": 1004,
          "mtu": 8000,
          "subnet": "10.0.4.0/24"
        },
        {
          "name": "vmk2",
          "purpose": "iscsi_b",
          "vswitch": "vSwitch1",
          "portgroup": "Storage2",
          "active_uplinks": ["vmnic3"],
          "unused_uplinks": ["vmnic2"],
          "vlan": 1005,
          "mtu": 8000,
          "subnet": "10.0.5.0/24"
        },
        {
          "name": "vmk3",
          "purpose": "vmotion",
          "vswitch": "vSwitch1",
          "portgroup": "vMotion",
          "active_uplinks": ["vmnic2", "vmnic3"],
          "vlan": 1006,
          "mtu": 8000,
          "subnet": "10.0.6.0/24"
        },
        {
          "name": "vmk4",
          "purpose": "vsan",
          "vswitch": "vSwitch1",
          "portgroup": "vSAN",
          "active_uplinks": ["vmnic2", "vmnic3"],
          "vlan": 1007,
          "mtu": 8000,
          "subnet": "10.0.7.0/24"
        }
      ]
    }
  },
  "vcenters": {
    "vcsa_a": {
      "placement": {
        "kind": "nested_vsphere",
        "storage": {
          "mode": "iscsi_datastore",
          "storage": "storage_a",
          "lun": "lun01",
          "vmkernel_purposes": ["iscsi_a", "iscsi_b"],
          "port_binding": false
        }
      }
    }
  }
}
```

When `ip` is omitted on a VMkernel adapter, Terraform derives the per-host VMK IP by reusing the management host octet inside the adapter `subnet`; for example management `10.0.0.101` and subnet `10.0.4.0/24` becomes `10.0.4.101`. Explicit `ip` is intended only for single-host ESXi groups.

vSAN bootstrap storage mode example:

```json
{
  "vcenters": {
    "vcsa_vsan": {
      "placement": {
        "kind": "nested_vsphere",
        "esxi_group": "management_a",
        "host": "nest01.nested.lab",
        "datastore": "vsanDatastore",
        "network": "VM Network",
        "storage": {
          "mode": "vsan_bootstrap",
          "vsan": {
            "datastore_name": "vsanDatastore",
            "datacenter": "Datacenter",
            "cluster": "Cluster",
            "cache_disks": ["vmhba0:C0:T1:L0"],
            "capacity_disks": ["vmhba0:C0:T2:L0"]
          }
        }
      },
      "source": {
        "install_source": "vcsa_8u3_installer"
      },
      "manages": ["management_a"]
    }
  }
}
```

The same disk selectors must be valid on each managed ESXi host for post-registration disk group claim. The current implementation supports one cache disk group per host.

Implementation status as of 2026-04-27:

- ESXi install is working through both Router-driven PXE and vSphere datastore-ISO boot paths
- VCSA install is working from Router-mounted `datastore_iso` media for both 8.0 and 7.0 media sets
- `placement.kind = "nested_vsphere"` is implemented for `vcenters`; nested VCSAs target deployment_v2-managed ESXi hosts by `placement.esxi_group` and `placement.host`
- 7.0 VCSA did not require a separate kickstart or installer branch; the working issue found during validation was stale VCSA detection and cleanup, not 7.0-specific installer behavior
- vCenter orchestration is dependency-aware per Router: provider-target vCenters launch asynchronously before ESXi verification, nested-ESXi-target vCenters launch after nested ESXi readiness, and nested vCenters do not depend on provider-target vCenter completion
- nested-ESXi-target vCenter storage readiness is modeled before VCSA launch; `iscsi_datastore` prepares a deployment_v2 storage LUN as VMFS, while `vsan_bootstrap` validates ESXi 7.0 U2+, marks requested disks as SSD, and passes `VCSA_cluster` metadata to the VCSA CLI installer
- `vsan_bootstrap` is restricted to VCSA installer media at 7.0 U2 or later by parsing the referenced install source `url` or `path`, then validates the deployed vCenter and managed ESXi host versions at runtime
- multiple vCenters are modeled and validated; the example now exercises one provider-target vCenter plus one nested-ESXi-target vCenter in the same Router scope
- baseline managed ESXi registration is implemented after VCSA deployment; `vsan_bootstrap` additionally skips Quickstart, claims disk groups on managed hosts, and creates the `vSAN FTT0` policy

Planned expansion of `deployment_v2_prepare`:

- real deployment validation for the dependency-aware multi-vCenter scheduler under provider-target and nested-ESXi-target mixes
- real deployment validation for `iscsi_datastore` and `vsan_bootstrap` nested-ESXi-target storage readiness
- real deployment validation for managed ESXi registration driven by `vcenters[*].manages`
- post-registration vCenter initialization, including cluster HA/DRS policy and distributed switch/vmkernel networking
- nested vSphere guest provisioning workflows beyond ESXi PXE
