# deployment_v2

This directory is the new deployment entrypoint for the redesigned deployment model.

Status:

- `deployments/nested_vsphere` remains the current implementation
- `deployments/deployment_v2` is the parallel implementation target
- input is expected as split top-level variables in `deployment.tfvars.json`
- Terraform input uses `provider_config` instead of `provider` because `provider` is a reserved variable name
- `provider_config.server`, `provider_config.user`, and `provider_config.password` are optional; when omitted, the vSphere provider can read `VSPHERE_SERVER`, `VSPHERE_USER`, and `VSPHERE_PASSWORD` from the environment
- `name_prefix` controls the VM name prefix for this deployment; a random hex suffix is added automatically so multiple deployments can coexist in the same vSphere inventory
- `ssh_authorized_keys` injects SSH public keys into Router VMs via cloud-init

Current scope:

- accept the new split-variable model
- create Router VMs from `routers`
- create ESXi VMs from `esxi_groups` with Terraform-only inventory/lifecycle scope
- create storage service VMs from `storages`
- expose structured outputs for future Terraform and Ansible integration
- avoid modifying the behavior of the legacy deployment entrypoint

Next steps:

1. add schema-aware validations for `deployment`
2. implement Router-driven ESXi PXE / kickstart workflow wiring
3. emit stable Ansible-oriented inventory outputs for Routers and ESXi hosts
4. implement vCenter creation from `deployment.vcenters`
5. expand Router and ESXi placement support beyond `provider_vsphere`

Current implementation notes:

- Router creation currently supports `placement.kind = "provider_vsphere"` only
- Router placement overrides are not implemented yet; Router placement currently resolves from `provider_config`
- Router install media currently supports `install_sources` of type `http_ovf` or `local_ovf`
- Router definitions may use `source.install_source`; `template` is accepted as a compatibility alias during the transition
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
- `output.ansible_inventory_seed` is the contract for downstream Ansible work; use `scripts/render_ansible_inventory.sh` to turn it into an Ansible inventory JSON document
- rendered inventory now includes `deployment_v2_storages` and `deployment_v2_storage_<name>` groups for `storages`
- ESXi kickstart rendering now assumes VCF-style firstboot handling for all deployment_v2 hosts; `shape.vcf_mode` is kept only as compatibility metadata

Ansible integration helpers:

- `scripts/render_ansible_inventory.sh` renders `output.ansible_inventory_seed` into dynamic inventory JSON for Ansible
- `scripts/run_prepare.sh` renders inventory and runs `playbooks/deployment_v2_prepare.yaml`
- `playbooks/deployment_v2_prepare.yaml` consumes that inventory and prepares the current deployment_v2 bootstrap runtime on Router VMs for HTTP, PXE, and optional `rclone`
- `install.method = "ansible_router_pxe"` derives a PXE boot path from Router-hosted TFTP + HTTP assets
- `install.method = "ansible_vsphere_iso_boot"` derives a datastore-ISO boot path from a virtual CD/DVD plus VMware API key injection
- ESXi boot uses TFTP-hosted `mboot.efi` and `boot.cfg`; HTTP is used only to publish kickstart files and the mounted ISO tree referenced by `prefix=`
- `http_iso` means a Router-managed HTTP ISO reference; deployment_v2 prepare downloads the ISO with `curl`/`get_url` into `/srv/install-sources/<source>/source.iso` and loop-mounts it into `/srv/install-sources/<source>/mounted`
- `rclone_iso` means a Router-managed HTTP ISO reference that is exposed via `rclone mount` under `/srv/install-sources/<source>/remote` and then loop-mounted into `/srv/install-sources/<source>/mounted`
- `datastore_iso` means a vSphere datastore-backed ISO path that Terraform connects directly to each ESXi VM as a virtual CD/DVD; deployment_v2 prepare still renders host-specific kickstart files on the Router, then uses Ansible VMware modules to enter EFI setup and inject `ks=` arguments for each host
- mounted ESXi ISOs are staged per install source into `tftp_root/<source>/...` and `http_root/iso/<source>/...`, so multiple installer ISOs can coexist without path collisions
- MAC-based PXE assignment expects `primary_mac_address` to be present in `terraform output -json ansible_inventory_seed`; refresh or apply Terraform before rendering inventory after output shape changes
- `vm_admin_password` is now carried inside `ansible_inventory_seed.credentials.vm_admin_password`, so deployment_v2 prepare no longer needs an extra-vars root password for the normal `http_iso` flow
- Routers serving `rclone_iso` sources must keep `router.execution.enable_rclone = true`
- Routers serving `datastore_iso` ESXi installs must keep `router.execution.enable_http = true`, because kickstart files are still published from the Router over HTTP

Prepare vars template:

```bash
cp deployments/deployment_v2/tfvars/prepare.vars.yaml.example \
  deployments/deployment_v2/tfvars/prepare.vars.yaml
```

For the current `http_iso`, `rclone_iso`, and `datastore_iso` flows, deployment_v2 prepare now works from Terraform output alone.

Minimal prepare example:

```bash
nix develop -c deployments/deployment_v2/scripts/run_prepare.sh
```

`scripts/run_prepare.sh` automatically uses
`deployments/deployment_v2/tfvars/prepare.vars.yaml` when that file exists.

Current scope of `deployment_v2_prepare`:

- Router-hosted ESXi PXE / kickstart bootstrap
- vSphere datastore ISO bootstrap for ESXi via virtual CD/DVD and EFI boot option injection
- ESXi post-install verification through vSphere guest operations

Planned expansion of `deployment_v2_prepare`:

- vCenter Server deployment preparation and verification
- nested vSphere guest provisioning workflows beyond ESXi PXE
