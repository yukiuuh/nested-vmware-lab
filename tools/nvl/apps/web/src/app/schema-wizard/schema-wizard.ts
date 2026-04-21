import { Component, computed, EventEmitter, Input, Output, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ClarityModule } from '@clr/angular';
import { documentKind } from '@nvl/core';
import { copyTextToClipboard, selectAllCopyTarget } from '../copy-utils';
import { buildHostnameInventory, formatJson, validateEditorDocument } from '../editor-utils';
import { HostnameTableComponent } from '../hostname-table/hostname-table';

type BlueprintTemplate = 'nested_vcenter_storage' | 'provider_vcenter';
type VcenterPlacement = 'nested_vsphere' | 'provider_vsphere';
type RuntimeSourceType = 'http_ovf' | 'local_ovf';
type IsoSourceType = 'http_iso' | 'rclone_iso' | 'datastore_iso';
type InstallSourceType = RuntimeSourceType | IsoSourceType;

interface TemplateOption {
  id: BlueprintTemplate;
  label: string;
  description: string;
}

interface LabBlueprint {
  template: BlueprintTemplate;
  name: string;
  domain: string;
  vmAdminPassword: string;
  sshAuthorizedKeys: string[];
  ansiblePassword: string;
  ansiblePasswordEnv: string;
  ansiblePrivateKeyFile: string;
  ansiblePrivateKeyFileEnv: string;
  providerServer: string;
  providerServerEnv: string;
  providerUser: string;
  providerUserEnv: string;
  providerPassword: string;
  providerPasswordEnv: string;
  providerDatacenter: string;
  providerResourcePool: string;
  providerComputeHost: string;
  providerDatastore: string;
  wanNetwork: string;
  lanNetwork: string;
  managementNetwork: string;
  managementGateway: string;
  subnetMask: string;
  vlanStart: number;
  vlanCount: number;
  mtu: number;
  nameservers: string[];
  ntpServers: string[];
  unifiedOvaType: RuntimeSourceType;
  unifiedOvaUrl: string;
  unifiedOvaPath: string;
  esxiSourceType: IsoSourceType;
  esxiIsoUrl: string;
  esxiSourceDatastore: string;
  esxiSourcePath: string;
  vcsaSourceType: IsoSourceType;
  vcsaIsoUrl: string;
  vcsaSourceDatastore: string;
  vcsaSourcePath: string;
  esxiGroupName: string;
  esxiPrefix: string;
  esxiCount: number;
  esxiStartIp: string;
  esxiCpu: number;
  esxiMemoryGb: number;
  esxiNicCount: number;
  esxiDiskGb: number;
  includeStorage: boolean;
  storageKey: string;
  storageIp: string;
  storage1Ip: string;
  storage2Ip: string;
  storage1Vlan: number;
  storage2Vlan: number;
  storageCpu: number;
  storageMemoryGb: number;
  storageDiskGb: number;
  storageLunName: string;
  storageLunGb: number;
  storageDatastoreName: string;
  vcenterKey: string;
  vcenterHostname: string;
  vcenterIp: string;
  vcenterPlacement: VcenterPlacement;
  vcenterSize: string;
}

const TEMPLATE_OPTIONS: TemplateOption[] = [
  {
    id: 'nested_vcenter_storage',
    label: '1 ESXi Group + Nested vCenter + Storage',
    description:
      'Creates one ESXi group, a storage appliance, and a vCenter placed on the generated ESXi host.',
  },
  {
    id: 'provider_vcenter',
    label: '1 ESXi Group + Provider vCenter',
    description:
      'Creates one ESXi group and places vCenter directly on the provider vSphere target.',
  },
];

const UNIFIED_OVA_SOURCE_TYPES: RuntimeSourceType[] = ['http_ovf', 'local_ovf'];
const ISO_SOURCE_TYPES: IsoSourceType[] = ['http_iso', 'rclone_iso', 'datastore_iso'];

const BASE_BLUEPRINT: LabBlueprint = {
  template: 'nested_vcenter_storage',
  name: 'lab-a',
  domain: 'nested.lab',
  vmAdminPassword: 'VMware123!',
  sshAuthorizedKeys: [],
  ansiblePassword: '',
  ansiblePasswordEnv: '',
  ansiblePrivateKeyFile: '',
  ansiblePrivateKeyFileEnv: 'ANSIBLE_PRIVATE_KEY_FILE',
  providerServer: '',
  providerServerEnv: 'VSPHERE_SERVER',
  providerUser: '',
  providerUserEnv: 'VSPHERE_USER',
  providerPassword: '',
  providerPasswordEnv: 'VSPHERE_PASSWORD',
  providerDatacenter: 'Datacenter',
  providerResourcePool: 'Resources',
  providerComputeHost: 'esxi.example.local',
  providerDatastore: 'datastore1',
  wanNetwork: 'VM Network',
  lanNetwork: 'Nested-Trunk',
  managementNetwork: '10.0.0.0',
  managementGateway: '10.0.0.1',
  subnetMask: '255.255.255.0',
  vlanStart: 1001,
  vlanCount: 20,
  mtu: 8000,
  nameservers: ['10.0.0.1'],
  ntpServers: ['10.0.0.1'],
  unifiedOvaType: 'http_ovf',
  unifiedOvaUrl: 'https://repo.example.local/ova/router/nvl-unified.ova',
  unifiedOvaPath: '/path/to/nvl-unified.ova',
  esxiSourceType: 'http_iso',
  esxiIsoUrl: 'https://repo.example.local/iso/VMware-VMvisor-Installer-8.0U3.iso',
  esxiSourceDatastore: 'datastore1',
  esxiSourcePath: 'iso/VMware-VMvisor-Installer-8.0U3.iso',
  vcsaSourceType: 'http_iso',
  vcsaIsoUrl: 'https://repo.example.local/iso/VMware-VCSA-all-8.0U3.iso',
  vcsaSourceDatastore: 'datastore1',
  vcsaSourcePath: 'iso/VMware-VCSA-all-8.0U3.iso',
  esxiGroupName: 'management_a',
  esxiPrefix: 'esxi',
  esxiCount: 3,
  esxiStartIp: '10.0.0.101',
  esxiCpu: 8,
  esxiMemoryGb: 32,
  esxiNicCount: 8,
  esxiDiskGb: 32,
  includeStorage: true,
  storageKey: 'storage_a',
  storageIp: '10.0.0.10',
  storage1Ip: '10.0.4.10',
  storage2Ip: '10.0.5.10',
  storage1Vlan: 1004,
  storage2Vlan: 1005,
  storageCpu: 4,
  storageMemoryGb: 4,
  storageDiskGb: 200,
  storageLunName: 'lun01',
  storageLunGb: 200,
  storageDatastoreName: 'iscsi01',
  vcenterKey: 'vcsa_a',
  vcenterHostname: 'vcsa01',
  vcenterIp: '10.0.0.100',
  vcenterPlacement: 'nested_vsphere',
  vcenterSize: 'small',
};

@Component({
  selector: 'nvl-schema-wizard',
  imports: [ClarityModule, FormsModule, HostnameTableComponent],
  templateUrl: './schema-wizard.html',
  styleUrl: './schema-wizard.scss',
})
export class SchemaWizardComponent {
  @Output() applyDocument = new EventEmitter<unknown>();

  @Input() showLauncher = true;

  protected readonly open = signal(false);
  protected readonly templates = TEMPLATE_OPTIONS;
  protected readonly unifiedOvaSourceTypes = UNIFIED_OVA_SOURCE_TYPES;
  protected readonly isoSourceTypes = ISO_SOURCE_TYPES;
  protected readonly blueprint = signal<LabBlueprint>(defaultBlueprint('nested_vcenter_storage'));
  protected readonly copiedDraft = signal(false);

  private currentDocument: unknown = undefined;

  @Input() set document(value: unknown) {
    this.currentDocument = value;
  }

  protected readonly selectedTemplate = computed(() => {
    const template = this.blueprint().template;
    return TEMPLATE_OPTIONS.find((option) => option.id === template) ?? TEMPLATE_OPTIONS[0];
  });

  protected readonly deployment = computed(() => buildBlueprintDeployment(this.blueprint()));
  protected readonly hostnameInventory = computed(() => buildHostnameInventory(this.deployment()));
  protected readonly validation = computed(() =>
    validateEditorDocument(this.deployment(), this.hostnameInventory().issues),
  );
  protected readonly draftJson = computed(() => formatJson(this.deployment()));
  protected readonly nestedHostTarget = computed(() => firstEsxiFqdn(this.blueprint()));
  protected readonly esxiInstallMethod = computed(() =>
    esxiInstallMethodForSource(this.blueprint().esxiSourceType),
  );

  public openWizard(): void {
    this.open.set(true);
  }

  protected loadTemplate(): void {
    this.blueprint.set(defaultBlueprint(this.blueprint().template));
    this.openWizard();
  }

  protected selectTemplate(value: unknown): void {
    const template = asTemplate(value);
    if (!template) {
      return;
    }
    this.blueprint.set(defaultBlueprint(template));
  }

  protected importCurrentDocument(): void {
    if (documentKind(this.currentDocument) !== 'Deployment') {
      return;
    }
    this.blueprint.set(inferBlueprint(this.currentDocument));
    this.openWizard();
  }

  protected updateBlueprint(key: keyof LabBlueprint, value: unknown): void {
    this.blueprint.update(
      (current) =>
        ({
          ...current,
          [key]: String(value ?? ''),
        }) as LabBlueprint,
    );
  }

  protected updateNumber(key: keyof LabBlueprint, value: unknown): void {
    const number = Number(value);
    if (!Number.isFinite(number)) {
      return;
    }
    this.blueprint.update(
      (current) =>
        ({
          ...current,
          [key]: Math.trunc(number),
        }) as LabBlueprint,
    );
  }

  protected updateBoolean(key: keyof LabBlueprint, value: unknown): void {
    this.blueprint.update(
      (current) =>
        ({
          ...current,
          [key]: value === true,
        }) as LabBlueprint,
    );
  }

  protected updatePlacement(value: unknown): void {
    const placement = value === 'nested_vsphere' ? 'nested_vsphere' : 'provider_vsphere';
    this.blueprint.update((current) => ({
      ...current,
      vcenterPlacement: placement,
    }));
  }

  protected installSourceTypeLabel(type: InstallSourceType): string {
    return {
      http_ovf: 'HTTP OVF / OVA',
      local_ovf: 'Local OVF / OVA',
      http_iso: 'HTTP ISO',
      rclone_iso: 'Rclone ISO',
      datastore_iso: 'Datastore ISO',
    }[type];
  }

  protected esxiInstallMethodLabel(method: string): string {
    return method === 'ansible_vsphere_iso_boot'
      ? 'ansible_vsphere_iso_boot'
      : 'ansible_router_pxe';
  }

  protected sourceUsesUrl(type: InstallSourceType): boolean {
    return type === 'http_ovf' || type === 'http_iso' || type === 'rclone_iso';
  }

  protected sourceUsesDatastore(type: InstallSourceType): boolean {
    return type === 'datastore_iso';
  }

  protected sourceUsesPath(type: InstallSourceType): boolean {
    return type === 'local_ovf' || type === 'datastore_iso';
  }

  protected listText(key: 'nameservers' | 'ntpServers' | 'sshAuthorizedKeys'): string {
    return this.blueprint()[key].join('\n');
  }

  protected updateStringList(
    key: 'nameservers' | 'ntpServers' | 'sshAuthorizedKeys',
    value: unknown,
  ): void {
    const items = String(value ?? '')
      .split('\n')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
    this.blueprint.update((current) => ({ ...current, [key]: items }));
  }

  protected apply(): void {
    this.applyDocument.emit(this.deployment());
  }

  protected copyDraftJson(): void {
    void copyTextToClipboard(this.draftJson()).then(() => {
      this.copiedDraft.set(true);
      window.setTimeout(() => this.copiedDraft.set(false), 1200);
    });
  }

  protected selectAllCopyTarget(event: KeyboardEvent): void {
    selectAllCopyTarget(event);
  }
}

function defaultBlueprint(template: BlueprintTemplate): LabBlueprint {
  const blueprint = cloneBlueprint({ ...BASE_BLUEPRINT, template });
  if (template === 'provider_vcenter') {
    return {
      ...blueprint,
      includeStorage: false,
      vcenterKey: 'provider_vc',
      vcenterHostname: 'provider-vc',
      vcenterIp: '10.0.0.60',
      vcenterPlacement: 'provider_vsphere',
    };
  }
  return blueprint;
}

function cloneBlueprint(value: LabBlueprint): LabBlueprint {
  return {
    ...value,
    nameservers: [...value.nameservers],
    ntpServers: [...value.ntpServers],
    sshAuthorizedKeys: [...value.sshAuthorizedKeys],
  };
}

function buildBlueprintDeployment(blueprint: LabBlueprint): Record<string, unknown> {
  const groupName = safeKey(blueprint.esxiGroupName, 'management_a');
  const storageKey = safeKey(blueprint.storageKey, 'storage_a');
  const vcenterKey = safeKey(blueprint.vcenterKey, 'vcsa_a');
  const provider = providerPlacement(blueprint);
  const nameservers =
    blueprint.nameservers.length > 0 ? blueprint.nameservers : [blueprint.managementGateway];
  const ntpServers = blueprint.ntpServers.length > 0 ? blueprint.ntpServers : nameservers;
  const esxiInstallMethod = esxiInstallMethodForSource(blueprint.esxiSourceType);

  return {
    apiVersion: 'nvl.io/v1alpha1',
    kind: 'Deployment',
    name: blueprint.name,
    credentials: {
      vm_admin_password: blueprint.vmAdminPassword,
      ansible: buildAnsibleConnectionCredentials(blueprint),
    },
    ssh_authorized_keys: blueprint.sshAuthorizedKeys,
    providers: {
      primary: {
        kind: 'vsphere',
        credentials: buildProviderCredentials(blueprint),
        placement_defaults: {
          datacenter: blueprint.providerDatacenter,
          resource_pool: blueprint.providerResourcePool,
          compute_host: blueprint.providerComputeHost,
          datastore: blueprint.providerDatastore,
          networks: {
            wan: blueprint.wanNetwork,
            lan: blueprint.lanNetwork,
          },
        },
      },
    },
    install_sources: {
      router_ova: buildInstallSource(
        blueprint.unifiedOvaType,
        blueprint.unifiedOvaUrl,
        '',
        blueprint.unifiedOvaPath,
      ),
      esxi_8u3_installer: buildInstallSource(
        blueprint.esxiSourceType,
        blueprint.esxiIsoUrl,
        blueprint.esxiSourceDatastore,
        blueprint.esxiSourcePath,
      ),
      vcsa_8u3_installer: buildInstallSource(
        blueprint.vcsaSourceType,
        blueprint.vcsaIsoUrl,
        blueprint.vcsaSourceDatastore,
        blueprint.vcsaSourcePath,
      ),
    },
    routers: {
      router_a: {
        source: {
          install_source: 'router_ova',
        },
        placement: provider,
        networks: {
          wan: {
            network_name: blueprint.wanNetwork,
            ip: null,
            subnet_mask: blueprint.subnetMask,
            nameservers,
          },
          lan: {
            network_name: blueprint.lanNetwork,
            domain_name: blueprint.domain,
            network: blueprint.managementNetwork,
            gateway: blueprint.managementGateway,
            vlan_starts_with: blueprint.vlanStart,
            vlan_network_count: blueprint.vlanCount,
            mtu: blueprint.mtu,
          },
        },
        execution: {
          enable_pxe: esxiInstallMethod === 'ansible_router_pxe',
          enable_http: true,
          enable_rclone:
            blueprint.esxiSourceType === 'rclone_iso' || blueprint.vcsaSourceType === 'rclone_iso',
          http_root: '/var/www/html',
          tftp_root: '/srv/tftp',
        },
      },
    },
    storages: blueprint.includeStorage
      ? {
          [storageKey]: {
            router: 'router_a',
            source: {
              install_source: 'router_ova',
            },
            placement: provider,
            ip: blueprint.storageIp,
            gateway: blueprint.managementGateway,
            nameservers,
            domain_name: blueprint.domain,
            subnet_mask: blueprint.subnetMask,
            storage1_ip: blueprint.storage1Ip,
            storage2_ip: blueprint.storage2Ip,
            storage1_vlan: blueprint.storage1Vlan,
            storage2_vlan: blueprint.storage2Vlan,
            mtu: blueprint.mtu,
            storage_subnet_mask: blueprint.subnetMask,
            disk_size_gb: Math.max(1, blueprint.storageDiskGb),
            num_cpus: Math.max(1, blueprint.storageCpu),
            mem_gb: Math.max(1, blueprint.storageMemoryGb),
            luns: [
              {
                name: safeKey(blueprint.storageLunName, 'lun01'),
                size_gb: Math.max(1, blueprint.storageLunGb),
              },
            ],
            zfs_compression: 'off',
            zfs_nfs_dedup: 'off',
          },
        }
      : {},
    esxi_groups: {
      [groupName]: {
        router: 'router_a',
        placement: provider,
        count: Math.max(1, blueprint.esxiCount),
        hostname_prefix: blueprint.esxiPrefix,
        starting_ip: blueprint.esxiStartIp,
        domain_name: blueprint.domain,
        gateway: blueprint.managementGateway,
        nameservers,
        ntp_servers: ntpServers,
        subnet_mask: blueprint.subnetMask,
        shape: {
          num_cpus: Math.max(1, blueprint.esxiCpu),
          mem_gb: Math.max(1, blueprint.esxiMemoryGb),
          nic_count: Math.max(1, blueprint.esxiNicCount),
          tpm_enabled: false,
          nvme_enabled: false,
          disks: [
            {
              label: 'disk0',
              size_gb: Math.max(1, blueprint.esxiDiskGb),
              unit_number: 0,
            },
          ],
        },
        vmkernel_adapters:
          blueprint.includeStorage && blueprint.vcenterPlacement === 'nested_vsphere'
            ? [
                {
                  name: 'vmk1',
                  purpose: 'iscsi_a',
                  vswitch: 'vSwitch1',
                  portgroup: 'Storage1',
                  uplink: 'vmnic2',
                  vlan: blueprint.storage1Vlan,
                  mtu: blueprint.mtu,
                  subnet: subnetFromIpv4(blueprint.storage1Ip),
                },
                {
                  name: 'vmk2',
                  purpose: 'iscsi_b',
                  vswitch: 'vSwitch2',
                  portgroup: 'Storage2',
                  uplink: 'vmnic3',
                  vlan: blueprint.storage2Vlan,
                  mtu: blueprint.mtu,
                  subnet: subnetFromIpv4(blueprint.storage2Ip),
                },
              ]
            : [],
        install: {
          method: esxiInstallMethod,
          source: {
            install_source: 'esxi_8u3_installer',
          },
          kickstart: {
            template: 'esxi-8.0',
          },
        },
        managed_by: [vcenterKey],
      },
    },
    vcenters: {
      [vcenterKey]: {
        router: 'router_a',
        placement: vcenterPlacement(blueprint, groupName),
        hostname: blueprint.vcenterHostname,
        ip: blueprint.vcenterIp,
        deployment_size: blueprint.vcenterSize,
        source: {
          install_source: 'vcsa_8u3_installer',
        },
        manages: [groupName],
        sso_domain_name: 'vsphere.local',
        nameservers,
        subnet_mask: blueprint.subnetMask,
      },
    },
  };
}

function buildProviderCredentials(blueprint: LabBlueprint): Record<string, unknown> {
  return compactObject({
    server: blueprint.providerServer,
    server_env: blueprint.providerServerEnv,
    user: blueprint.providerUser,
    user_env: blueprint.providerUserEnv,
    password: blueprint.providerPassword,
    password_env: blueprint.providerPasswordEnv,
  });
}

function buildAnsibleConnectionCredentials(blueprint: LabBlueprint): Record<string, unknown> {
  return compactObject({
    password: blueprint.ansiblePassword,
    password_env: blueprint.ansiblePasswordEnv,
    private_key_file: blueprint.ansiblePrivateKeyFile,
    private_key_file_env: blueprint.ansiblePrivateKeyFileEnv,
  });
}

function providerPlacement(blueprint: LabBlueprint): Record<string, unknown> {
  return {
    kind: 'provider_vsphere',
    provider: 'primary',
    datacenter: blueprint.providerDatacenter,
    resource_pool: blueprint.providerResourcePool,
    host: blueprint.providerComputeHost,
    datastore: blueprint.providerDatastore,
    network: blueprint.lanNetwork,
  };
}

function buildInstallSource(
  type: InstallSourceType,
  url: string,
  datastore: string,
  path: string,
): Record<string, unknown> {
  if (type === 'datastore_iso') {
    return {
      type,
      datastore,
      path,
    };
  }
  if (type === 'local_ovf') {
    return {
      type,
      path,
    };
  }
  return {
    type,
    url,
  };
}

function vcenterPlacement(blueprint: LabBlueprint, groupName: string): Record<string, unknown> {
  if (blueprint.vcenterPlacement === 'nested_vsphere') {
    const placement: Record<string, unknown> = {
      kind: 'nested_vsphere',
      esxi_group: groupName,
      host: firstEsxiFqdn(blueprint),
      datastore:
        blueprint.includeStorage && safeKey(blueprint.storageDatastoreName, '')
          ? blueprint.storageDatastoreName
          : 'datastore1',
      network: 'VM Network',
    };
    if (blueprint.includeStorage) {
      placement['storage'] = {
        mode: 'iscsi_datastore',
        storage: safeKey(blueprint.storageKey, 'storage_a'),
        lun: safeKey(blueprint.storageLunName, 'lun01'),
        vmkernel_purposes: ['iscsi_a', 'iscsi_b'],
        port_binding: false,
      };
    }
    return placement;
  }
  return providerPlacement(blueprint);
}

function firstEsxiFqdn(blueprint: LabBlueprint): string {
  return `${blueprint.esxiPrefix}01.${blueprint.domain}`;
}

function inferBlueprint(document: unknown): LabBlueprint {
  const blueprint = defaultBlueprint('nested_vcenter_storage');
  const root = asRecord(document) ?? {};
  const deploymentCredentials = asRecord(root['credentials']) ?? {};
  const ansibleCredentials = asRecord(deploymentCredentials['ansible']) ?? {};
  const providers = asRecord(root['providers']) ?? {};
  const primary = asRecord(providers['primary']) ?? {};
  const credentials = asRecord(primary['credentials']) ?? {};
  const placementDefaults = asRecord(primary['placement_defaults']) ?? {};
  const networks = asRecord(placementDefaults['networks']) ?? {};
  const routers = asRecord(root['routers']) ?? {};
  const router = firstRecordValue(routers) ?? {};
  const lan = asRecord(asRecord(router['networks'])?.['lan']) ?? {};
  const installSources = asRecord(root['install_sources']) ?? {};
  const unifiedSource = asRecord(installSources['router_ova']) ?? {};
  const esxiSource = asRecord(installSources['esxi_8u3_installer']) ?? {};
  const vcsaSource = asRecord(installSources['vcsa_8u3_installer']) ?? {};
  const groups = asRecord(root['esxi_groups']) ?? {};
  const [groupKey, group] = firstRecordEntry(groups) ?? ['', {}];
  const shape = asRecord(group['shape']) ?? {};
  const disks = Array.isArray(shape['disks']) ? shape['disks'] : [];
  const firstDisk = asRecord(disks[0]) ?? {};
  const storages = asRecord(root['storages']) ?? {};
  const [storageKey, storage] = firstRecordEntry(storages) ?? ['', {}];
  const storageLuns = Array.isArray(storage['luns']) ? storage['luns'] : [];
  const firstStorageLun = asRecord(storageLuns[0]) ?? {};
  const vcenters = asRecord(root['vcenters']) ?? {};
  const [vcenterKey, vcenter] = firstRecordEntry(vcenters) ?? ['', {}];
  const placement = asRecord(vcenter['placement']) ?? {};
  const placementStorage = asRecord(placement['storage']) ?? {};

  return {
    ...blueprint,
    template:
      placement['kind'] === 'provider_vsphere' ? 'provider_vcenter' : 'nested_vcenter_storage',
    name: stringValue(root['name'], blueprint.name),
    domain: stringValue(group['domain_name'], lan['domain_name'], blueprint.domain),
    vmAdminPassword: stringValue(
      deploymentCredentials['vm_admin_password'],
      blueprint.vmAdminPassword,
    ),
    sshAuthorizedKeys: stringArray(root['ssh_authorized_keys'], blueprint.sshAuthorizedKeys),
    ansiblePassword: stringValue(ansibleCredentials['password'], blueprint.ansiblePassword),
    ansiblePasswordEnv: stringValue(
      ansibleCredentials['password_env'],
      blueprint.ansiblePasswordEnv,
    ),
    ansiblePrivateKeyFile: stringValue(
      ansibleCredentials['private_key_file'],
      blueprint.ansiblePrivateKeyFile,
    ),
    ansiblePrivateKeyFileEnv: stringValue(
      ansibleCredentials['private_key_file_env'],
      blueprint.ansiblePrivateKeyFileEnv,
    ),
    providerServer: stringValue(credentials['server'], blueprint.providerServer),
    providerServerEnv: stringValue(credentials['server_env'], blueprint.providerServerEnv),
    providerUser: stringValue(credentials['user'], blueprint.providerUser),
    providerUserEnv: stringValue(credentials['user_env'], blueprint.providerUserEnv),
    providerPassword: stringValue(credentials['password'], blueprint.providerPassword),
    providerPasswordEnv: stringValue(credentials['password_env'], blueprint.providerPasswordEnv),
    providerDatacenter: stringValue(placementDefaults['datacenter'], blueprint.providerDatacenter),
    providerResourcePool: stringValue(
      placementDefaults['resource_pool'],
      blueprint.providerResourcePool,
    ),
    providerComputeHost: stringValue(
      placementDefaults['compute_host'],
      blueprint.providerComputeHost,
    ),
    providerDatastore: stringValue(placementDefaults['datastore'], blueprint.providerDatastore),
    wanNetwork: stringValue(networks['wan'], blueprint.wanNetwork),
    lanNetwork: stringValue(networks['lan'], lan['network_name'], blueprint.lanNetwork),
    managementNetwork: stringValue(lan['network'], blueprint.managementNetwork),
    managementGateway: stringValue(group['gateway'], lan['gateway'], blueprint.managementGateway),
    subnetMask: stringValue(group['subnet_mask'], blueprint.subnetMask),
    vlanStart: numberValue(lan['vlan_starts_with'], blueprint.vlanStart),
    vlanCount: numberValue(lan['vlan_network_count'], blueprint.vlanCount),
    mtu: numberValue(lan['mtu'], blueprint.mtu),
    nameservers: stringArray(group['nameservers'], blueprint.nameservers),
    ntpServers: stringArray(group['ntp_servers'], blueprint.ntpServers),
    unifiedOvaType: runtimeSourceType(unifiedSource['type'], blueprint.unifiedOvaType),
    unifiedOvaUrl: stringValue(unifiedSource['url'], blueprint.unifiedOvaUrl),
    unifiedOvaPath: stringValue(unifiedSource['path'], blueprint.unifiedOvaPath),
    esxiSourceType: isoSourceType(esxiSource['type'], blueprint.esxiSourceType),
    esxiIsoUrl: stringValue(esxiSource['url'], blueprint.esxiIsoUrl),
    esxiSourceDatastore: stringValue(esxiSource['datastore'], blueprint.esxiSourceDatastore),
    esxiSourcePath: stringValue(esxiSource['path'], blueprint.esxiSourcePath),
    vcsaSourceType: isoSourceType(vcsaSource['type'], blueprint.vcsaSourceType),
    vcsaIsoUrl: stringValue(vcsaSource['url'], blueprint.vcsaIsoUrl),
    vcsaSourceDatastore: stringValue(vcsaSource['datastore'], blueprint.vcsaSourceDatastore),
    vcsaSourcePath: stringValue(vcsaSource['path'], blueprint.vcsaSourcePath),
    esxiGroupName: groupKey || blueprint.esxiGroupName,
    esxiPrefix: stringValue(group['hostname_prefix'], blueprint.esxiPrefix),
    esxiCount: numberValue(group['count'], blueprint.esxiCount),
    esxiStartIp: stringValue(group['starting_ip'], blueprint.esxiStartIp),
    esxiCpu: numberValue(shape['num_cpus'], blueprint.esxiCpu),
    esxiMemoryGb: numberValue(shape['mem_gb'], blueprint.esxiMemoryGb),
    esxiNicCount: numberValue(shape['nic_count'], blueprint.esxiNicCount),
    esxiDiskGb: numberValue(firstDisk['size_gb'], blueprint.esxiDiskGb),
    includeStorage: Object.keys(storages).length > 0,
    storageKey: storageKey || blueprint.storageKey,
    storageIp: stringValue(storage['ip'], blueprint.storageIp),
    storage1Ip: stringValue(storage['storage1_ip'], blueprint.storage1Ip),
    storage2Ip: stringValue(storage['storage2_ip'], blueprint.storage2Ip),
    storage1Vlan: numberValue(storage['storage1_vlan'], blueprint.storage1Vlan),
    storage2Vlan: numberValue(storage['storage2_vlan'], blueprint.storage2Vlan),
    storageCpu: numberValue(storage['num_cpus'], blueprint.storageCpu),
    storageMemoryGb: numberValue(storage['mem_gb'], blueprint.storageMemoryGb),
    storageDiskGb: numberValue(storage['disk_size_gb'], blueprint.storageDiskGb),
    storageLunName: stringValue(
      firstStorageLun['name'],
      placementStorage['lun'],
      blueprint.storageLunName,
    ),
    storageLunGb: numberValue(firstStorageLun['size_gb'], blueprint.storageLunGb),
    storageDatastoreName: stringValue(placement['datastore'], blueprint.storageDatastoreName),
    vcenterKey: vcenterKey || blueprint.vcenterKey,
    vcenterHostname: stringValue(vcenter['hostname'], blueprint.vcenterHostname),
    vcenterIp: stringValue(vcenter['ip'], blueprint.vcenterIp),
    vcenterPlacement:
      placement['kind'] === 'provider_vsphere' ? 'provider_vsphere' : 'nested_vsphere',
    vcenterSize: stringValue(vcenter['deployment_size'], blueprint.vcenterSize),
  };
}

function asTemplate(value: unknown): BlueprintTemplate | undefined {
  return value === 'nested_vcenter_storage' || value === 'provider_vcenter' ? value : undefined;
}

function runtimeSourceType(value: unknown, fallback: RuntimeSourceType): RuntimeSourceType {
  return value === 'http_ovf' || value === 'local_ovf' ? value : fallback;
}

function isoSourceType(value: unknown, fallback: IsoSourceType): IsoSourceType {
  return value === 'http_iso' || value === 'rclone_iso' || value === 'datastore_iso'
    ? value
    : fallback;
}

function esxiInstallMethodForSource(sourceType: IsoSourceType): string {
  return sourceType === 'datastore_iso' ? 'ansible_vsphere_iso_boot' : 'ansible_router_pxe';
}

function subnetFromIpv4(value: string): string {
  const parts = value.split('.');
  if (parts.length !== 4 || parts.some((part) => !/^\d+$/.test(part))) {
    return '10.0.4.0/24';
  }
  return `${parts[0]}.${parts[1]}.${parts[2]}.0/24`;
}

function safeKey(value: string, fallback: string): string {
  return value.trim() || fallback;
}

function firstRecordValue(record: Record<string, unknown>): Record<string, unknown> | undefined {
  return asRecord(Object.values(record)[0]);
}

function firstRecordEntry(
  record: Record<string, unknown>,
): [string, Record<string, unknown>] | undefined {
  const [key, value] = Object.entries(record)[0] ?? [];
  const entry = asRecord(value);
  return key && entry ? [key, entry] : undefined;
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function compactObject(value: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(value).filter(([, entryValue]) => {
      if (typeof entryValue === 'string') {
        return entryValue.trim().length > 0;
      }
      return entryValue !== undefined && entryValue !== null;
    }),
  );
}

function stringValue(...values: unknown[]): string {
  for (const value of values) {
    if (typeof value === 'string' && value.length > 0) {
      return value;
    }
  }
  return '';
}

function numberValue(value: unknown, fallback: number): number {
  const number =
    typeof value === 'number'
      ? value
      : typeof value === 'string' && value.trim() !== ''
        ? Number(value)
        : NaN;
  return Number.isFinite(number) ? Math.trunc(number) : fallback;
}

function stringArray(value: unknown, fallback: string[]): string[] {
  return Array.isArray(value) && value.every((item) => typeof item === 'string')
    ? [...value]
    : [...fallback];
}
