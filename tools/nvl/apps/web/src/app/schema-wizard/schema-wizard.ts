import { Component, computed, EventEmitter, Input, Output, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ClarityModule } from '@clr/angular';
import { documentKind } from '@nvl/core';
import { copyTextToClipboard, selectAllCopyTarget } from '../copy-utils';
import { buildHostnameInventory, formatJson, validateEditorDocument } from '../editor-utils';
import { HostnameTableComponent } from '../hostname-table/hostname-table';

type BlueprintTemplate = 'nested_vcenter_storage' | 'provider_vcenter';
type VcenterPlacement = 'nested_vsphere' | 'provider_vsphere';
type VcenterStorageMode = 'existing_datastore' | 'iscsi_datastore' | 'vsan_bootstrap';
type RuntimeSourceType = 'http_ovf' | 'local_ovf';
type IsoSourceType = 'http_iso' | 'rclone_iso' | 'datastore_iso';
type InstallSourceType = RuntimeSourceType | IsoSourceType;

interface TemplateOption {
  id: BlueprintTemplate;
  label: string;
  description: string;
}

interface DepotEntry {
  location: string;
  description: string;
}

interface StorageLunEntry {
  name: string;
  sizeGb: number;
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
  vcenterDepots: DepotEntry[];
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
  storageLuns: StorageLunEntry[];
  vcenterStorageMode: VcenterStorageMode;
  vcenterStorageLun: string;
  storageDatastoreName: string;
  vsanDatastoreName: string;
  vsanDatacenter: string;
  vsanCluster: string;
  vsanCacheDisk: string;
  vsanCapacityDisks: string[];
  vsanCacheDiskGb: number;
  vsanCapacityDiskGb: number;
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
const VCENTER_STORAGE_MODES: VcenterStorageMode[] = [
  'existing_datastore',
  'iscsi_datastore',
  'vsan_bootstrap',
];

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
  vcenterDepots: [{ location: '', description: 'Local ESXi depot' }],
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
  storageLuns: [
    { name: 'lun01', sizeGb: 200 },
    { name: 'lun02', sizeGb: 200 },
    { name: 'lun03', sizeGb: 200 },
    { name: 'lun04', sizeGb: 200 },
  ],
  vcenterStorageMode: 'iscsi_datastore',
  vcenterStorageLun: 'lun01',
  storageDatastoreName: 'iscsi01',
  vsanDatastoreName: 'vsanDatastore',
  vsanDatacenter: 'Datacenter',
  vsanCluster: 'Cluster',
  vsanCacheDisk: 'vmhba0:C0:T1:L0',
  vsanCapacityDisks: ['vmhba0:C0:T2:L0'],
  vsanCacheDiskGb: 50,
  vsanCapacityDiskGb: 200,
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
  protected readonly vcenterStorageModes = VCENTER_STORAGE_MODES;
  protected readonly blueprint = signal<LabBlueprint>(defaultBlueprint('nested_vcenter_storage'));
  protected readonly copiedDraft = signal(false);
  protected readonly wizardSource = signal<'current' | 'template'>('template');

  private readonly currentDocument = signal<unknown>(undefined);

  @Input() set document(value: unknown) {
    this.currentDocument.set(value);
  }

  protected readonly selectedTemplate = computed(() => {
    const template = this.blueprint().template;
    return TEMPLATE_OPTIONS.find((option) => option.id === template) ?? TEMPLATE_OPTIONS[0];
  });
  protected readonly canImportCurrentDocument = computed(
    () => documentKind(this.currentDocument()) === 'Deployment',
  );

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
  protected readonly vcsaRequiresDepot = computed(() => vcsaSourceRequiresDepot(this.blueprint()));
  protected readonly isNestedVcenter = computed(
    () => this.blueprint().vcenterPlacement === 'nested_vsphere',
  );
  protected readonly selectedTemplateIndex = computed(() =>
    Math.max(
      0,
      TEMPLATE_OPTIONS.findIndex((option) => option.id === this.blueprint().template),
    ),
  );
  protected readonly wizardSourceLabel = computed(() =>
    this.wizardSource() === 'current' ? 'Editing current Deployment' : 'Using template defaults',
  );
  protected readonly commonPageIssues = computed(() => commonPageIssues(this.blueprint()));
  protected readonly esxiPageIssues = computed(() => esxiPageIssues(this.blueprint()));
  protected readonly vcenterPageIssues = computed(() => vcenterPageIssues(this.blueprint()));
  protected readonly hostnamePageIssues = computed(() =>
    this.hostnameInventory()
      .issues.filter((issue) => issue.severity === 'error')
      .map((issue) => issue.message),
  );
  protected readonly wizardIssues = computed(() => [
    ...this.commonPageIssues(),
    ...this.esxiPageIssues(),
    ...this.vcenterPageIssues(),
    ...this.hostnamePageIssues(),
  ]);
  protected readonly commonPageReady = computed(() => this.commonPageIssues().length === 0);
  protected readonly esxiPageReady = computed(() => this.esxiPageIssues().length === 0);
  protected readonly vcenterPageReady = computed(() => this.vcenterPageIssues().length === 0);
  protected readonly hostnamePageReady = computed(() => this.hostnamePageIssues().length === 0);
  protected readonly canApply = computed(
    () => this.wizardIssues().length === 0 && this.validation().valid,
  );

  public openWizard(): void {
    if (this.importCurrentDeployment()) {
      this.wizardSource.set('current');
    }
    this.open.set(true);
  }

  protected loadTemplate(): void {
    this.blueprint.set(defaultBlueprint(this.blueprint().template));
    this.wizardSource.set('template');
    this.open.set(true);
  }

  protected selectTemplate(value: unknown): void {
    const template = asTemplate(value);
    if (!template) {
      return;
    }
    this.blueprint.set(defaultBlueprint(template));
    this.wizardSource.set('template');
  }

  protected selectAdjacentTemplate(offset: number): void {
    const nextIndex =
      (this.selectedTemplateIndex() + offset + TEMPLATE_OPTIONS.length) % TEMPLATE_OPTIONS.length;
    this.selectTemplate(TEMPLATE_OPTIONS[nextIndex].id);
  }

  protected importCurrentDocument(): void {
    if (this.importCurrentDeployment()) {
      this.wizardSource.set('current');
    }
    this.open.set(true);
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

  protected addDepot(): void {
    this.blueprint.update((current) => ({
      ...current,
      vcenterDepots: [...current.vcenterDepots, { location: '', description: 'Local ESXi depot' }],
    }));
  }

  protected removeDepot(index: number): void {
    this.blueprint.update((current) => ({
      ...current,
      vcenterDepots:
        current.vcenterDepots.length > 1
          ? current.vcenterDepots.filter((_, itemIndex) => itemIndex !== index)
          : [{ location: '', description: 'Local ESXi depot' }],
    }));
  }

  protected updateDepot(index: number, key: keyof DepotEntry, value: unknown): void {
    this.blueprint.update((current) => ({
      ...current,
      vcenterDepots: current.vcenterDepots.map((depot, itemIndex) =>
        itemIndex === index ? { ...depot, [key]: String(value ?? '') } : depot,
      ),
    }));
  }

  protected addStorageLun(): void {
    this.blueprint.update((current) => ({
      ...current,
      storageLuns: [
        ...current.storageLuns,
        { name: nextStorageLunName(current.storageLuns), sizeGb: 200 },
      ],
    }));
  }

  protected removeStorageLun(index: number): void {
    this.blueprint.update((current) => {
      const storageLuns =
        current.storageLuns.length > 1
          ? current.storageLuns.filter((_, itemIndex) => itemIndex !== index)
          : [{ name: 'lun01', sizeGb: 200 }];
      const selectedNames = storageLuns.map((lun) => lun.name.trim());
      return {
        ...current,
      storageLuns,
      vcenterStorageLun: selectedNames.includes(current.vcenterStorageLun.trim())
        ? current.vcenterStorageLun
          : storageLuns[0]?.name || 'lun01',
      };
    });
  }

  protected updateStorageLun(
    index: number,
    key: keyof StorageLunEntry,
    value: unknown,
  ): void {
    this.blueprint.update((current) => {
      const previousName = current.storageLuns[index]?.name;
      const storageLuns = current.storageLuns.map((lun, itemIndex) => {
        if (itemIndex !== index) {
          return lun;
        }
        if (key === 'sizeGb') {
          const number = Number(value);
          return Number.isFinite(number) ? { ...lun, sizeGb: Math.trunc(number) } : lun;
        }
        return { ...lun, name: String(value ?? '') };
      });
      const nextName = storageLuns[index]?.name;
      return {
        ...current,
        storageLuns,
        vcenterStorageLun:
          previousName && current.vcenterStorageLun === previousName && nextName
            ? nextName
            : current.vcenterStorageLun,
      };
    });
  }

  protected updatePlacement(value: unknown): void {
    const placement = value === 'nested_vsphere' ? 'nested_vsphere' : 'provider_vsphere';
    this.blueprint.update((current) => ({
      ...current,
      vcenterPlacement: placement,
      includeStorage: placement === 'nested_vsphere' && current.vcenterStorageMode === 'iscsi_datastore',
    }));
  }

  protected updateStorageMode(value: unknown): void {
    const mode = asVcenterStorageMode(value);
    this.blueprint.update((current) => ({
      ...current,
      vcenterStorageMode: mode,
      includeStorage: mode === 'iscsi_datastore',
      storageDatastoreName:
        mode === 'vsan_bootstrap'
          ? current.vsanDatastoreName || 'vsanDatastore'
          : current.storageDatastoreName,
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

  protected listText(
    key: 'nameservers' | 'ntpServers' | 'sshAuthorizedKeys' | 'vsanCapacityDisks',
  ): string {
    return this.blueprint()[key].join('\n');
  }

  protected updateStringList(
    key: 'nameservers' | 'ntpServers' | 'sshAuthorizedKeys' | 'vsanCapacityDisks',
    value: unknown,
  ): void {
    const items = String(value ?? '')
      .split('\n')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
    this.blueprint.update((current) => ({ ...current, [key]: items }));
  }

  protected apply(): void {
    if (!this.canApply()) {
      return;
    }
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

  private importCurrentDeployment(): boolean {
    const currentDocument = this.currentDocument();
    if (documentKind(currentDocument) !== 'Deployment') {
      return false;
    }
    this.blueprint.set(inferBlueprint(currentDocument));
    return true;
  }
}

function commonPageIssues(blueprint: LabBlueprint): string[] {
  return [
    ...requiredTextIssue('Deployment Name', blueprint.name),
    ...dnsLabelIssue('Deployment Name', blueprint.name),
    ...requiredTextIssue('DNS Domain', blueprint.domain),
    ...dnsNameIssue('DNS Domain', blueprint.domain),
    ...requiredTextIssue('Admin Password', blueprint.vmAdminPassword),
    ...requiredTextIssue('Datacenter', blueprint.providerDatacenter),
    ...requiredTextIssue('Resource Pool', blueprint.providerResourcePool),
    ...requiredTextIssue('Compute Host', blueprint.providerComputeHost),
    ...requiredTextIssue('Datastore', blueprint.providerDatastore),
    ...requiredTextIssue('WAN Network', blueprint.wanNetwork),
    ...requiredTextIssue('LAN / Trunk Network', blueprint.lanNetwork),
    ...requiredTextIssue('Management Network', blueprint.managementNetwork),
    ...ipv4Issue('Management Network', blueprint.managementNetwork),
    ...requiredTextIssue('Gateway', blueprint.managementGateway),
    ...ipv4Issue('Gateway', blueprint.managementGateway),
    ...requiredTextIssue('Subnet Mask', blueprint.subnetMask),
    ...ipv4Issue('Subnet Mask', blueprint.subnetMask),
    ...integerRangeIssue('VLAN Start', blueprint.vlanStart, 1, 4094),
    ...integerRangeIssue('VLAN Count', blueprint.vlanCount, 1, 4094),
    ...integerRangeIssue('MTU', blueprint.mtu, 576, 9000),
    ...runtimeSourceIssues('Unified OVA', blueprint.unifiedOvaType, {
      url: blueprint.unifiedOvaUrl,
      path: blueprint.unifiedOvaPath,
    }),
  ];
}

function esxiPageIssues(blueprint: LabBlueprint): string[] {
  return [
    ...requiredTextIssue('Group Key', blueprint.esxiGroupName),
    ...keyIssue('Group Key', blueprint.esxiGroupName),
    ...requiredTextIssue('Hostname Prefix', blueprint.esxiPrefix),
    ...dnsLabelIssue('Hostname Prefix', blueprint.esxiPrefix),
    ...integerRangeIssue('Count', blueprint.esxiCount, 1),
    ...requiredTextIssue('Starting IP', blueprint.esxiStartIp),
    ...ipv4Issue('Starting IP', blueprint.esxiStartIp),
    ...isoSourceIssues('ESXi Source', blueprint.esxiSourceType, {
      url: blueprint.esxiIsoUrl,
      datastore: blueprint.esxiSourceDatastore,
      path: blueprint.esxiSourcePath,
    }),
    ...integerRangeIssue('CPUs', blueprint.esxiCpu, 1),
    ...integerRangeIssue('Memory GB', blueprint.esxiMemoryGb, 1),
    ...integerRangeIssue('NIC Count', blueprint.esxiNicCount, 1),
    ...integerRangeIssue('Boot Disk GB', blueprint.esxiDiskGb, 1),
  ];
}

function vcenterPageIssues(blueprint: LabBlueprint): string[] {
  const iscsiStorageIssues =
    blueprint.vcenterPlacement === 'nested_vsphere' && blueprint.vcenterStorageMode === 'iscsi_datastore'
    ? [
        ...requiredTextIssue('Storage Key', blueprint.storageKey),
        ...keyIssue('Storage Key', blueprint.storageKey),
        ...requiredTextIssue('Storage Management IP', blueprint.storageIp),
        ...ipv4Issue('Storage Management IP', blueprint.storageIp),
        ...requiredTextIssue('Storage Network 1 IP', blueprint.storage1Ip),
        ...ipv4Issue('Storage Network 1 IP', blueprint.storage1Ip),
        ...requiredTextIssue('Storage Network 2 IP', blueprint.storage2Ip),
        ...ipv4Issue('Storage Network 2 IP', blueprint.storage2Ip),
        ...integerRangeIssue('Storage VLAN 1', blueprint.storage1Vlan, 1, 4094),
        ...integerRangeIssue('Storage VLAN 2', blueprint.storage2Vlan, 1, 4094),
        ...integerRangeIssue('Storage CPUs', blueprint.storageCpu, 1),
        ...integerRangeIssue('Storage Memory GB', blueprint.storageMemoryGb, 1),
        ...integerRangeIssue('Storage Appliance Disk GB', blueprint.storageDiskGb, 1),
        ...storageLunIssues(blueprint.storageLuns),
        ...requiredTextIssue('vCenter Datastore LUN', blueprint.vcenterStorageLun),
        ...(blueprint.vcenterStorageLun.trim()
        && !blueprint.storageLuns.some(
          (lun) => lun.name.trim() === blueprint.vcenterStorageLun.trim(),
        )
          ? ['vCenter Datastore LUN must reference one of the defined LUN names.']
          : []),
        ...requiredTextIssue('Nested VCSA Datastore Name', blueprint.storageDatastoreName),
      ]
    : [];
  const existingDatastoreIssues =
    blueprint.vcenterPlacement === 'nested_vsphere'
    && blueprint.vcenterStorageMode === 'existing_datastore'
      ? [...requiredTextIssue('Nested VCSA Datastore Name', blueprint.storageDatastoreName)]
      : [];
  const vsanIssues =
    blueprint.vcenterPlacement === 'nested_vsphere' && blueprint.vcenterStorageMode === 'vsan_bootstrap'
      ? [
          ...requiredTextIssue('vSAN Datastore Name', blueprint.vsanDatastoreName),
          ...requiredTextIssue('vSAN Datacenter', blueprint.vsanDatacenter),
          ...requiredTextIssue('vSAN Cluster', blueprint.vsanCluster),
          ...requiredTextIssue('vSAN Cache Disk', blueprint.vsanCacheDisk),
          ...integerRangeIssue('vSAN Cache Disk GB', blueprint.vsanCacheDiskGb, 1),
          ...integerRangeIssue('vSAN Capacity Disk GB', blueprint.vsanCapacityDiskGb, 1),
          ...vsanCapacityDiskIssues(blueprint),
        ]
      : [];

  return [
    ...requiredTextIssue('vCenter Key', blueprint.vcenterKey),
    ...keyIssue('vCenter Key', blueprint.vcenterKey),
    ...requiredTextIssue('Hostname', blueprint.vcenterHostname),
    ...dnsLabelIssue('Hostname', blueprint.vcenterHostname),
    ...requiredTextIssue('IP', blueprint.vcenterIp),
    ...ipv4Issue('IP', blueprint.vcenterIp),
    ...isoSourceIssues('VCSA Source', blueprint.vcsaSourceType, {
      url: blueprint.vcsaIsoUrl,
      datastore: blueprint.vcsaSourceDatastore,
      path: blueprint.vcsaSourcePath,
    }),
    ...vcenterDepotIssues(blueprint),
    ...iscsiStorageIssues,
    ...existingDatastoreIssues,
    ...vsanIssues,
  ];
}

function storageLunIssues(luns: StorageLunEntry[]): string[] {
  if (luns.length === 0) {
    return ['At least one storage LUN is required when a storage appliance is created.'];
  }
  const issues = luns.flatMap((lun, index) => [
    ...requiredTextIssue(`LUN ${index + 1} Name`, lun.name),
    ...keyIssue(`LUN ${index + 1} Name`, lun.name),
    ...integerRangeIssue(`LUN ${index + 1} Size GB`, lun.sizeGb, 1),
  ]);
  const names = luns.map((lun) => lun.name.trim()).filter((name) => name.length > 0);
  const duplicateNames = names.filter((name, index) => names.indexOf(name) !== index);
  if (duplicateNames.length > 0) {
    issues.push(`LUN names must be unique: ${[...new Set(duplicateNames)].join(', ')}.`);
  }
  return issues;
}

function vcenterDepotIssues(blueprint: LabBlueprint): string[] {
  const activeDepots = blueprint.vcenterDepots.filter(depotHasAnyValue);
  const required = vcsaSourceRequiresDepot(blueprint);
  if (!required && activeDepots.length === 0) {
    return [];
  }
  if (required && activeDepots.length === 0) {
    return ['At least one vLCM depot is required for vCenter 9.0+.'];
  }
  return activeDepots.flatMap((depot, index) => [
    ...sourceUrlIssues(`vLCM Depot ${index + 1} Location`, depot.location, true),
    ...requiredTextIssue(`vLCM Depot ${index + 1} Description`, depot.description),
  ]);
}

function vsanCapacityDiskIssues(blueprint: LabBlueprint): string[] {
  const capacityDisks = blueprint.vsanCapacityDisks
    .map((disk) => disk.trim())
    .filter((disk) => disk.length > 0);
  const issues =
    capacityDisks.length === 0 ? ['At least one vSAN capacity disk is required.'] : [];
  const duplicates = capacityDisks.filter((disk, index) => capacityDisks.indexOf(disk) !== index);
  if (duplicates.length > 0) {
    issues.push(`vSAN capacity disks must be unique: ${[...new Set(duplicates)].join(', ')}.`);
  }
  if (blueprint.vsanCacheDisk.trim() && capacityDisks.includes(blueprint.vsanCacheDisk.trim())) {
    issues.push('vSAN cache disk must not also be listed as a capacity disk.');
  }
  return issues;
}

function depotHasAnyValue(depot: DepotEntry): boolean {
  return (
    depot.location.trim().length > 0
    || (
      depot.description.trim().length > 0
      && depot.description.trim() !== 'Local ESXi depot'
    )
  );
}

function runtimeSourceIssues(
  label: string,
  type: RuntimeSourceType,
  values: { url: string; path: string },
): string[] {
  if (type === 'http_ovf') {
    return sourceUrlIssues(`${label} URL`, values.url, true);
  }
  return requiredTextIssue(`${label} Path`, values.path);
}

function isoSourceIssues(
  label: string,
  type: IsoSourceType,
  values: { url: string; datastore: string; path: string },
): string[] {
  if (type === 'http_iso') {
    return sourceUrlIssues(`${label} URL`, values.url, true);
  }
  if (type === 'rclone_iso') {
    return requiredTextIssue(`${label} Rclone Remote`, values.url);
  }
  return [
    ...requiredTextIssue(`${label} Datastore`, values.datastore),
    ...requiredTextIssue(`${label} Path`, values.path),
  ];
}

function requiredTextIssue(label: string, value: string): string[] {
  return value.trim() ? [] : [`${label} is required.`];
}

function sourceUrlIssues(label: string, value: string, requireHttp: boolean): string[] {
  const required = requiredTextIssue(label, value);
  if (required.length > 0) {
    return required;
  }
  if (requireHttp && !/^https?:\/\/\S+$/i.test(value.trim())) {
    return [`${label} must be an HTTP(S) URL.`];
  }
  return [];
}

function dnsLabelIssue(label: string, value: string): string[] {
  if (!value.trim() || /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/i.test(value.trim())) {
    return [];
  }
  return [`${label} must be a DNS-safe label.`];
}

function dnsNameIssue(label: string, value: string): string[] {
  const text = value.trim();
  if (!text) {
    return [];
  }
  const labels = text.split('.');
  return labels.length > 0 && labels.every((part) => dnsLabelIssue(label, part).length === 0)
    ? []
    : [`${label} must be a valid DNS name.`];
}

function keyIssue(label: string, value: string): string[] {
  if (!value.trim() || /^[A-Za-z0-9_][A-Za-z0-9_-]*$/.test(value.trim())) {
    return [];
  }
  return [`${label} must use letters, numbers, underscores, or dashes.`];
}

function ipv4Issue(label: string, value: string): string[] {
  const text = value.trim();
  if (!text) {
    return [];
  }
  const octets = text.split('.');
  const valid =
    octets.length === 4 &&
    octets.every((part) => {
      if (!/^\d+$/.test(part)) {
        return false;
      }
      const number = Number(part);
      return number >= 0 && number <= 255;
    });
  return valid ? [] : [`${label} must be an IPv4 address.`];
}

function integerRangeIssue(
  label: string,
  value: number,
  minimum: number,
  maximum?: number,
): string[] {
  if (!Number.isInteger(value) || value < minimum || (maximum !== undefined && value > maximum)) {
    return [
      maximum === undefined
        ? `${label} must be ${minimum} or greater.`
        : `${label} must be between ${minimum} and ${maximum}.`,
    ];
  }
  return [];
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
    vcenterDepots: value.vcenterDepots.map((depot) => ({ ...depot })),
    storageLuns: value.storageLuns.map((lun) => ({ ...lun })),
    vsanCapacityDisks: [...value.vsanCapacityDisks],
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
  const storageLuns = normalizedStorageLuns(blueprint.storageLuns);
  const useIscsiStorage =
    blueprint.vcenterPlacement === 'nested_vsphere'
    && blueprint.vcenterStorageMode === 'iscsi_datastore';

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
      esxi_installer: buildInstallSource(
        blueprint.esxiSourceType,
        blueprint.esxiIsoUrl,
        blueprint.esxiSourceDatastore,
        blueprint.esxiSourcePath,
      ),
      vcsa_installer: buildInstallSource(
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
    storages: useIscsiStorage
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
            luns: storageLuns.map((lun) => ({
              name: lun.name,
              size_gb: lun.sizeGb,
            })),
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
          disks: esxiDisks(blueprint),
        },
        vmkernel_adapters: nestedVmkernelAdapters(blueprint),
        install: {
          method: esxiInstallMethod,
          source: {
            install_source: 'esxi_installer',
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
          install_source: 'vcsa_installer',
        },
        manages: [groupName],
        ...vcenterDepotConfig(blueprint),
        sso_domain_name: 'vsphere.local',
        nameservers,
        subnet_mask: blueprint.subnetMask,
      },
    },
  };
}

function vcenterDepotConfig(blueprint: LabBlueprint): Record<string, unknown> {
  const depots = blueprint.vcenterDepots
    .filter((depot) => depot.location.trim().length > 0)
    .map((depot) => ({
      location: depot.location.trim(),
      description: depot.description.trim() || 'Local ESXi depot',
    }));
  if (depots.length === 0) {
    return {};
  }
  return { depots };
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
    const storageLuns = normalizedStorageLuns(blueprint.storageLuns);
    const selectedLun = selectedStorageLun(blueprint, storageLuns);
    const datastoreName =
      blueprint.vcenterStorageMode === 'vsan_bootstrap'
        ? safeKey(blueprint.vsanDatastoreName, 'vsanDatastore')
        : safeKey(blueprint.storageDatastoreName, 'datastore1');
    const placement: Record<string, unknown> = {
      kind: 'nested_vsphere',
      esxi_group: groupName,
      host: firstEsxiFqdn(blueprint),
      datastore: datastoreName,
      network: 'VM Network',
    };
    if (blueprint.vcenterStorageMode === 'iscsi_datastore') {
      placement['storage'] = {
        mode: 'iscsi_datastore',
        storage: safeKey(blueprint.storageKey, 'storage_a'),
        lun: selectedLun.name,
        vmkernel_purposes: ['iscsi_a', 'iscsi_b'],
        port_binding: false,
      };
    } else if (blueprint.vcenterStorageMode === 'vsan_bootstrap') {
      placement['storage'] = {
        mode: 'vsan_bootstrap',
        vsan: {
          datastore_name: datastoreName,
          datacenter: safeKey(blueprint.vsanDatacenter, 'Datacenter'),
          cluster: safeKey(blueprint.vsanCluster, 'Cluster'),
          cache_disks: [safeKey(blueprint.vsanCacheDisk, 'vmhba0:C0:T1:L0')],
          capacity_disks: normalizedVsanCapacityDisks(blueprint),
          compression_only: false,
          deduplication_and_compression: false,
          enable_vlcm: false,
        },
      };
    } else {
      placement['storage'] = {
        mode: 'existing_datastore',
      };
    }
    return placement;
  }
  return providerPlacement(blueprint);
}

function esxiDisks(blueprint: LabBlueprint): Array<Record<string, unknown>> {
  const disks: Array<Record<string, unknown>> = [
    {
      label: 'disk0',
      size_gb: Math.max(1, blueprint.esxiDiskGb),
      unit_number: 0,
    },
  ];
  if (blueprint.vcenterPlacement !== 'nested_vsphere' || blueprint.vcenterStorageMode !== 'vsan_bootstrap') {
    return disks;
  }
  disks.push({
    label: 'vsan-cache0',
    size_gb: Math.max(1, blueprint.vsanCacheDiskGb),
    unit_number: 1,
  });
  normalizedVsanCapacityDisks(blueprint).forEach((_, index) => {
    disks.push({
      label: `vsan-capacity${index}`,
      size_gb: Math.max(1, blueprint.vsanCapacityDiskGb),
      unit_number: index + 2,
    });
  });
  return disks;
}

function nestedVmkernelAdapters(blueprint: LabBlueprint): Array<Record<string, unknown>> {
  if (blueprint.vcenterPlacement !== 'nested_vsphere') {
    return [];
  }
  const storageAdapters =
    blueprint.vcenterStorageMode === 'iscsi_datastore'
      ? [
          {
            name: 'vmk1',
            purpose: 'iscsi_a',
            vswitch: 'vSwitch1',
            portgroup: 'Storage1',
            active_uplinks: ['vmnic2'],
            unused_uplinks: ['vmnic3'],
            vlan: blueprint.storage1Vlan,
            mtu: blueprint.mtu,
            subnet: subnetFromIpv4(blueprint.storage1Ip),
          },
          {
            name: 'vmk2',
            purpose: 'iscsi_b',
            vswitch: 'vSwitch1',
            portgroup: 'Storage2',
            active_uplinks: ['vmnic3'],
            unused_uplinks: ['vmnic2'],
            vlan: blueprint.storage2Vlan,
            mtu: blueprint.mtu,
            subnet: subnetFromIpv4(blueprint.storage2Ip),
          },
        ]
      : [];
  return [
    ...storageAdapters,
    {
      name: storageAdapters.length > 0 ? 'vmk3' : 'vmk1',
      purpose: 'vmotion',
      vswitch: 'vSwitch1',
      portgroup: 'vMotion',
      active_uplinks: ['vmnic2', 'vmnic3'],
      vlan: blueprint.storage2Vlan + 1,
      mtu: blueprint.mtu,
      subnet: subnetNearIpv4(blueprint.storage1Ip, 2),
    },
    {
      name: storageAdapters.length > 0 ? 'vmk4' : 'vmk2',
      purpose: 'vsan',
      vswitch: 'vSwitch1',
      portgroup: 'vSAN',
      active_uplinks: ['vmnic2', 'vmnic3'],
      vlan: blueprint.storage2Vlan + 2,
      mtu: blueprint.mtu,
      subnet: subnetNearIpv4(blueprint.storage1Ip, 3),
    },
  ];
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
  const esxiSource = asRecord(installSources['esxi_installer']) ?? {};
  const vcsaSource = asRecord(installSources['vcsa_installer']) ?? {};
  const groups = asRecord(root['esxi_groups']) ?? {};
  const [groupKey, group] = firstRecordEntry(groups) ?? ['', {}];
  const shape = asRecord(group['shape']) ?? {};
  const disks = Array.isArray(shape['disks']) ? shape['disks'] : [];
  const firstDisk = asRecord(disks[0]) ?? {};
  const storages = asRecord(root['storages']) ?? {};
  const [storageKey, storage] = firstRecordEntry(storages) ?? ['', {}];
  const storageLuns = Array.isArray(storage['luns']) ? storage['luns'] : [];
  const vcenters = asRecord(root['vcenters']) ?? {};
  const [vcenterKey, vcenter] = firstRecordEntry(vcenters) ?? ['', {}];
  const placement = asRecord(vcenter['placement']) ?? {};
  const placementStorage = asRecord(placement['storage']) ?? {};
  const placementVsan = asRecord(placementStorage['vsan']) ?? {};
  const vcenterDepots = Array.isArray(vcenter['depots']) ? vcenter['depots'] : [];
  const blueprintStorageLuns = storageLunEntries(storageLuns, blueprint.storageLuns);
  const storageMode = asVcenterStorageMode(placementStorage['mode']);

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
    vcenterDepots: depotEntries(vcenterDepots, blueprint.vcenterDepots),
    esxiGroupName: groupKey || blueprint.esxiGroupName,
    esxiPrefix: stringValue(group['hostname_prefix'], blueprint.esxiPrefix),
    esxiCount: numberValue(group['count'], blueprint.esxiCount),
    esxiStartIp: stringValue(group['starting_ip'], blueprint.esxiStartIp),
    esxiCpu: numberValue(shape['num_cpus'], blueprint.esxiCpu),
    esxiMemoryGb: numberValue(shape['mem_gb'], blueprint.esxiMemoryGb),
    esxiNicCount: numberValue(shape['nic_count'], blueprint.esxiNicCount),
    esxiDiskGb: numberValue(firstDisk['size_gb'], blueprint.esxiDiskGb),
    includeStorage: storageMode === 'iscsi_datastore' && Object.keys(storages).length > 0,
    storageKey: storageKey || blueprint.storageKey,
    storageIp: stringValue(storage['ip'], blueprint.storageIp),
    storage1Ip: stringValue(storage['storage1_ip'], blueprint.storage1Ip),
    storage2Ip: stringValue(storage['storage2_ip'], blueprint.storage2Ip),
    storage1Vlan: numberValue(storage['storage1_vlan'], blueprint.storage1Vlan),
    storage2Vlan: numberValue(storage['storage2_vlan'], blueprint.storage2Vlan),
    storageCpu: numberValue(storage['num_cpus'], blueprint.storageCpu),
    storageMemoryGb: numberValue(storage['mem_gb'], blueprint.storageMemoryGb),
    storageDiskGb: numberValue(storage['disk_size_gb'], blueprint.storageDiskGb),
    storageLuns: blueprintStorageLuns,
    vcenterStorageMode: storageMode,
    vcenterStorageLun: stringValue(
      placementStorage['lun'],
      blueprintStorageLuns[0]?.name,
      blueprint.vcenterStorageLun,
    ),
    storageDatastoreName: stringValue(placement['datastore'], blueprint.storageDatastoreName),
    vsanDatastoreName: stringValue(
      placementVsan['datastore_name'],
      placement['datastore'],
      blueprint.vsanDatastoreName,
    ),
    vsanDatacenter: stringValue(placementVsan['datacenter'], blueprint.vsanDatacenter),
    vsanCluster: stringValue(placementVsan['cluster'], blueprint.vsanCluster),
    vsanCacheDisk: stringArray(placementVsan['cache_disks'], [blueprint.vsanCacheDisk])[0] ?? blueprint.vsanCacheDisk,
    vsanCapacityDisks: stringArray(placementVsan['capacity_disks'], blueprint.vsanCapacityDisks),
    vsanCacheDiskGb: numberValue(diskSizeByUnit(disks, 1), blueprint.vsanCacheDiskGb),
    vsanCapacityDiskGb: numberValue(diskSizeByUnit(disks, 2), blueprint.vsanCapacityDiskGb),
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

function asVcenterStorageMode(value: unknown): VcenterStorageMode {
  return VCENTER_STORAGE_MODES.includes(value as VcenterStorageMode)
    ? (value as VcenterStorageMode)
    : 'existing_datastore';
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

function vcsaSourceRequiresDepot(blueprint: LabBlueprint): boolean {
  const text = [
    blueprint.vcsaSourceType === 'datastore_iso' ? blueprint.vcsaSourcePath : blueprint.vcsaIsoUrl,
  ]
    .map((value) => basename(value).toLowerCase())
    .join(' ');
  const version = detectVersion(text);
  return version !== undefined && version.major >= 9;
}

function detectVersion(text: string): { major: number; minor: number; patch: number } | undefined {
  const semver = text.match(/([0-9]+)\.([0-9]+)\.([0-9]+)/);
  if (semver) {
    return { major: Number(semver[1]), minor: Number(semver[2]), patch: Number(semver[3]) };
  }
  const update = text.match(/([0-9]+)\.([0-9]+)[._ -]*u([0-9]+)/i);
  if (update) {
    return { major: Number(update[1]), minor: Number(update[2]), patch: Number(update[3]) };
  }
  const majorMinor = text.match(/([0-9]+)\.([0-9]+)/);
  if (majorMinor) {
    return { major: Number(majorMinor[1]), minor: Number(majorMinor[2]), patch: 0 };
  }
  return undefined;
}

function basename(value: string): string {
  return value.split(/[\\/]/).at(-1) ?? value;
}

function subnetFromIpv4(value: string): string {
  const parts = value.split('.');
  if (parts.length !== 4 || parts.some((part) => !/^\d+$/.test(part))) {
    return '10.0.4.0/24';
  }
  return `${parts[0]}.${parts[1]}.${parts[2]}.0/24`;
}

function subnetNearIpv4(value: string, thirdOctetOffset: number): string {
  const parts = value.split('.');
  if (parts.length !== 4 || parts.some((part) => !/^\d+$/.test(part))) {
    return `10.0.${4 + thirdOctetOffset}.0/24`;
  }
  const thirdOctet = Math.min(254, Math.max(0, Number(parts[2]) + thirdOctetOffset));
  return `${parts[0]}.${parts[1]}.${thirdOctet}.0/24`;
}

function normalizedStorageLuns(luns: StorageLunEntry[]): StorageLunEntry[] {
  const entries = luns
    .map((lun) => ({
      name: safeKey(lun.name, ''),
      sizeGb: Math.max(1, lun.sizeGb),
    }))
    .filter((lun) => lun.name.length > 0);
  return entries.length > 0 ? entries : [{ name: 'lun01', sizeGb: 200 }];
}

function selectedStorageLun(
  blueprint: LabBlueprint,
  storageLuns = normalizedStorageLuns(blueprint.storageLuns),
): StorageLunEntry {
  const selectedName = blueprint.vcenterStorageLun.trim();
  return (
    storageLuns.find((lun) => lun.name === selectedName)
    ?? storageLuns[0]
    ?? { name: 'lun01', sizeGb: 200 }
  );
}

function normalizedVsanCapacityDisks(blueprint: LabBlueprint): string[] {
  const disks = blueprint.vsanCapacityDisks
    .map((disk) => disk.trim())
    .filter((disk) => disk.length > 0);
  return disks.length > 0 ? disks : ['vmhba0:C0:T2:L0'];
}

function diskSizeByUnit(disks: unknown[], unitNumber: number): unknown {
  const disk = disks.map(asRecord).find((entry) => entry?.['unit_number'] === unitNumber);
  return disk?.['size_gb'];
}

function nextStorageLunName(luns: StorageLunEntry[]): string {
  const names = new Set(luns.map((lun) => lun.name));
  for (let index = luns.length + 1; index < luns.length + 100; index += 1) {
    const name = `lun${String(index).padStart(2, '0')}`;
    if (!names.has(name)) {
      return name;
    }
  }
  return `lun${String(luns.length + 1).padStart(2, '0')}`;
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

function depotEntries(value: unknown[], fallback: DepotEntry[]): DepotEntry[] {
  const entries = value
    .map((item) => asRecord(item))
    .filter((item): item is Record<string, unknown> => item !== undefined)
    .map((item) => ({
      location: stringValue(item['location'], item['url']),
      description: stringValue(item['description'], 'Local ESXi depot'),
    }));
  return entries.length > 0 ? entries : fallback.map((depot) => ({ ...depot }));
}

function storageLunEntries(value: unknown[], fallback: StorageLunEntry[]): StorageLunEntry[] {
  const entries = value
    .map((item) => asRecord(item))
    .filter((item): item is Record<string, unknown> => item !== undefined)
    .map((item) => ({
      name: stringValue(item['name']),
      sizeGb: numberValue(item['size_gb'], 200),
    }))
    .filter((lun) => lun.name.length > 0);
  return entries.length > 0 ? entries : fallback.map((lun) => ({ ...lun }));
}
