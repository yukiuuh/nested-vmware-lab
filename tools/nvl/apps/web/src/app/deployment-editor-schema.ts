import type { JsonSchema } from './schema-form/schema-form';

const sourceRef = {
  type: 'object',
  title: 'Source',
  description: 'References an install source defined in install_sources.',
  properties: {
    install_source: {
      type: 'string',
      title: 'Install Source',
      description: 'Key of the OVA, ISO, or template source to use.',
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const providerPlacement = {
  type: 'object',
  title: 'Placement',
  description:
    'Controls whether the component is placed on the provider vSphere or on a nested ESXi/vSphere target.',
  required: ['kind'],
  properties: {
    kind: {
      type: 'string',
      title: 'Kind',
      description:
        'provider_vsphere deploys directly to the provider. nested_vsphere targets an ESXi host created by this lab.',
      enum: ['provider_vsphere', 'nested_vsphere'],
      default: 'provider_vsphere',
    },
    provider: { type: 'string', title: 'Provider', description: 'Provider key, usually primary.' },
    datacenter: {
      type: 'string',
      title: 'Datacenter',
      description: 'Target vSphere datacenter name.',
    },
    resource_pool: {
      type: 'string',
      title: 'Resource Pool',
      description: 'Target resource pool or cluster resource pool.',
    },
    host: {
      type: 'string',
      title: 'Host',
      description:
        'Target provider host, nested ESXi hostname, FQDN, or IP depending on placement kind.',
    },
    datastore: {
      type: 'string',
      title: 'Datastore',
      description: 'Datastore used for the deployed VM.',
    },
    network: {
      type: 'string',
      title: 'Network',
      description: 'Port group or network name used by the deployed VM.',
    },
    esxi_group: {
      type: 'string',
      title: 'ESXi Group',
      description: 'Nested ESXi group used when kind is nested_vsphere.',
    },
    storage: {
      type: 'object',
      title: 'Nested vCenter Storage',
      description:
        'Storage preparation mode for nested-ESXi-target vCenter deployment.',
      required: ['mode'],
      properties: {
        mode: {
          type: 'string',
          title: 'Mode',
          description:
            'existing_datastore uses an existing datastore, iscsi_datastore prepares VMFS on iSCSI, and vsan_bootstrap creates vSAN through the VCSA installer.',
          enum: ['existing_datastore', 'iscsi_datastore', 'vsan_bootstrap'],
          default: 'existing_datastore',
        },
        storage: {
          type: 'string',
          title: 'Storage Appliance',
          description: 'Storage object key used by iscsi_datastore.',
        },
        lun: {
          type: 'string',
          title: 'LUN',
          description: 'LUN name used by iscsi_datastore.',
        },
        vmkernel_purposes: {
          type: 'array',
          title: 'VMkernel Purposes',
          description: 'VMkernel adapter purpose keys used by iscsi_datastore.',
          items: { type: 'string' },
          default: ['iscsi_a', 'iscsi_b'],
        },
        port_binding: {
          type: 'boolean',
          title: 'Port Binding',
          description: 'Enable ESXi iSCSI port binding for iscsi_datastore.',
          default: false,
        },
        vsan: {
          type: 'object',
          title: 'vSAN Bootstrap',
          description: 'VCSA installer vSAN bootstrap settings.',
          required: ['datastore_name', 'datacenter', 'cluster', 'cache_disks', 'capacity_disks'],
          properties: {
            datastore_name: {
              type: 'string',
              title: 'Datastore Name',
              description: 'vSAN datastore name.',
              default: 'vsanDatastore',
            },
            datacenter: {
              type: 'string',
              title: 'Datacenter',
              description: 'Datacenter created or adopted by the VCSA installer.',
              default: 'Datacenter',
            },
            cluster: {
              type: 'string',
              title: 'Cluster',
              description: 'Cluster created or adopted by the VCSA installer.',
              default: 'Cluster',
            },
            cache_disks: {
              type: 'array',
              title: 'Cache Disks',
              description:
                'Canonical naa.* ESXi disk names or vmhba runtime paths for vSAN cache. deployment_v2 currently supports one cache disk.',
              items: { type: 'string' },
              default: ['vmhba0:C0:T1:L0'],
            },
            capacity_disks: {
              type: 'array',
              title: 'Capacity Disks',
              description: 'Canonical naa.* ESXi disk names or vmhba runtime paths for vSAN capacity.',
              items: { type: 'string' },
              default: ['vmhba0:C0:T2:L0'],
            },
            compression_only: {
              type: 'boolean',
              title: 'Compression Only',
              default: false,
            },
            deduplication_and_compression: {
              type: 'boolean',
              title: 'Deduplication And Compression',
              default: false,
            },
            enable_vlcm: {
              type: 'boolean',
              title: 'Enable vLCM',
              default: false,
            },
          },
          additionalProperties: true,
        },
      },
      additionalProperties: true,
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const stringArray = {
  type: 'array',
  items: { type: 'string' },
} satisfies JsonSchema;

const vmkernelAdapter = {
  type: 'object',
  title: 'VMkernel Adapter',
  description:
    'ESXi VMkernel adapter, standard vSwitch portgroup, uplink policy, and optional VMkernel service tags.',
  required: ['name', 'purpose', 'vswitch', 'portgroup', 'vlan', 'subnet'],
  properties: {
    name: {
      type: 'string',
      title: 'Name',
      description: 'VMkernel interface name such as vmk1.',
      default: 'vmk1',
    },
    purpose: {
      type: 'string',
      title: 'Purpose',
      description: 'Stable purpose key. vmotion and vsan automatically enable matching VMkernel tags.',
      default: 'iscsi_a',
    },
    vswitch: {
      type: 'string',
      title: 'vSwitch',
      description: 'Standard vSwitch to create or reuse.',
      default: 'vSwitch1',
    },
    portgroup: {
      type: 'string',
      title: 'Portgroup',
      description: 'Standard portgroup for this VMkernel adapter.',
      default: 'Storage1',
    },
    uplink: {
      type: 'string',
      title: 'Legacy Active Uplink',
      description: 'Backward-compatible single active vmnic. Prefer active_uplinks for new configs.',
    },
    active_uplinks: {
      ...stringArray,
      title: 'Active Uplinks',
      description:
        'vmnic names active for this portgroup. For iSCSI port binding, use exactly one active uplink.',
      default: ['vmnic2'],
    },
    standby_uplinks: {
      ...stringArray,
      title: 'Standby Uplinks',
      description: 'Optional standby vmnic names for this portgroup.',
    },
    unused_uplinks: {
      ...stringArray,
      title: 'Unused Uplinks',
      description:
        'vmnic names attached to the vSwitch but intentionally omitted from this portgroup active/standby policy.',
    },
    vlan: {
      type: 'integer',
      title: 'VLAN',
      description: 'VLAN ID for the portgroup.',
      minimum: 0,
      maximum: 4094,
      default: 1004,
    },
    mtu: {
      type: 'integer',
      title: 'MTU',
      description: 'VMkernel interface and vSwitch MTU.',
      minimum: 576,
      maximum: 9000,
      default: 9000,
    },
    subnet: {
      type: 'string',
      title: 'Subnet',
      description: 'IPv4 CIDR used to derive per-host VMkernel IPs when ip is omitted.',
      default: '10.0.4.0/24',
    },
    ip: {
      type: 'string',
      title: 'Static IP',
      description: 'Optional static IP. Leave empty for per-host derived addresses.',
    },
    ip_offset_from_management: {
      type: 'boolean',
      title: 'Derive IP From Management Offset',
      description: 'Derive the host portion from each ESXi management IP.',
      default: true,
    },
    services: {
      type: 'array',
      title: 'Services',
      description: 'Optional VMkernel service tags. Supported values are vmotion and vsan.',
      items: {
        type: 'string',
        enum: ['vmotion', 'vsan'],
      },
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const freeform = {
  type: 'object',
  additionalProperties: true,
} satisfies JsonSchema;

const storageLun = {
  type: 'object',
  title: 'Storage LUN',
  description: 'iSCSI LUN exposed by the storage appliance.',
  required: ['name', 'size_gb'],
  properties: {
    name: {
      type: 'string',
      title: 'Name',
      description: 'LUN name referenced by vCenter nested storage placement.',
      default: 'lun01',
    },
    size_gb: {
      type: 'integer',
      title: 'Size GB',
      description: 'LUN size in GiB.',
      default: 200,
      minimum: 1,
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const installSource = {
  type: 'object',
  title: 'Install Source',
  description: 'Reusable media source such as the unified OVA, ESXi ISO, or VCSA ISO.',
  required: ['type'],
  properties: {
    type: {
      type: 'string',
      title: 'Type',
      description: 'How the installer or image is retrieved.',
      enum: ['http_ovf', 'local_ovf', 'http_iso', 'rclone_iso', 'datastore_iso'],
      default: 'http_iso',
    },
    url: {
      type: 'string',
      title: 'URL',
      description:
        'Required when type is http_ovf, http_iso, or rclone_iso. For rclone_iso, use the rclone remote URI.',
    },
    datastore: {
      type: 'string',
      title: 'Datastore',
      description: 'Required when type is datastore_iso.',
    },
    path: {
      type: 'string',
      title: 'Path',
      description: 'Required when type is local_ovf or datastore_iso.',
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const provider = {
  type: 'object',
  title: 'Provider',
  description:
    'External infrastructure provider used to create routers, ESXi hosts, and optional provider-side vCenter VMs.',
  required: ['kind'],
  properties: {
    kind: {
      type: 'string',
      title: 'Kind',
      description: 'Provider adapter type.',
      enum: ['vsphere', 'static', 'vcd'],
      default: 'vsphere',
    },
    credentials: {
      type: 'object',
      title: 'Credentials',
      description:
        'Use either literal vSphere credentials or *_env fields for Terraform and Ansible runtime variables.',
      properties: {
        server: {
          type: 'string',
          title: 'Server',
          description: 'Literal vSphere endpoint written to provider_config.server.',
        },
        server_env: {
          type: 'string',
          title: 'Server Env',
          description: 'Environment variable that provides the vSphere endpoint at runtime.',
        },
        user: {
          type: 'string',
          title: 'User',
          description: 'vSphere user written to provider_config.user.',
        },
        user_env: {
          type: 'string',
          title: 'User Env',
          description: 'Environment variable that provides the vSphere user at runtime.',
        },
        password: {
          type: 'string',
          title: 'Password',
          description:
            'Explicit provider password. Prefer password_env for shared files and avoid committing real secrets.',
        },
        password_env: {
          type: 'string',
          title: 'Password Env',
          description: 'Environment variable that provides the vSphere password at runtime.',
        },
        datacenter_env: {
          type: 'string',
          title: 'Datacenter Env',
          description: 'Environment variable passed through to provider discovery tooling.',
        },
        insecure: {
          type: 'boolean',
          title: 'Allow Unverified SSL',
          description: 'Allow unverified vSphere TLS certificates for lab environments.',
          default: true,
        },
      },
      additionalProperties: true,
    },
    placement_defaults: {
      type: 'object',
      title: 'Placement Defaults',
      description: 'Default provider-side placement values reused by generated components.',
      properties: {
        datacenter: {
          type: 'string',
          title: 'Datacenter',
          description: 'Provider vSphere datacenter.',
          default: 'Datacenter',
        },
        resource_pool: {
          type: 'string',
          title: 'Resource Pool',
          description: 'Provider resource pool for lab VMs.',
          default: 'Resources',
        },
        compute_host: {
          type: 'string',
          title: 'Compute Host',
          description: 'Provider ESXi host or cluster target.',
        },
        datastore: {
          type: 'string',
          title: 'Datastore',
          description: 'Provider datastore for lab VMs.',
          default: 'datastore1',
        },
        networks: {
          type: 'object',
          title: 'Networks',
          description: 'Provider network names used by the router WAN and nested trunk LAN.',
          properties: {
            wan: {
              type: 'string',
              title: 'WAN',
              description: 'Uplink network for the router.',
              default: 'VM Network',
            },
            lan: {
              type: 'string',
              title: 'LAN',
              description: 'Trunk or internal network for nested lab traffic.',
              default: 'Nested-Trunk',
            },
          },
          additionalProperties: true,
        },
      },
      additionalProperties: true,
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const router = {
  type: 'object',
  title: 'Router',
  description:
    'Router and services VM for the lab management network, DHCP/PXE flow, and installer serving.',
  required: ['source', 'placement', 'networks'],
  properties: {
    source: sourceRef,
    placement: providerPlacement,
    networks: {
      type: 'object',
      title: 'Networks',
      description: 'WAN and lab LAN definitions for the router VM.',
      required: ['lan'],
      properties: {
        wan: {
          type: 'object',
          title: 'WAN',
          description: 'External or provider-facing router network.',
          properties: {
            network_name: {
              type: 'string',
              title: 'Network Name',
              description: 'Provider port group connected to the router WAN NIC.',
              default: 'VM Network',
            },
            ip: {
              type: 'string',
              title: 'IP',
              description: 'Optional static WAN IP. Leave empty when DHCP is used.',
            },
            subnet_mask: {
              type: 'string',
              title: 'Subnet Mask',
              description: 'WAN subnet mask for static addressing.',
              default: '255.255.255.0',
            },
            gateway: {
              type: 'string',
              title: 'Gateway',
              description: 'WAN gateway for static addressing.',
            },
            nameservers: {
              ...stringArray,
              title: 'Nameservers',
              description: 'DNS resolvers for router WAN/static configuration.',
            },
          },
          additionalProperties: true,
        },
        lan: {
          type: 'object',
          title: 'LAN',
          description:
            'Shared lab management network. Wizard-generated ESXi, storage, and vCenter settings inherit this.',
          required: ['domain_name', 'network', 'gateway'],
          properties: {
            network_name: {
              type: 'string',
              title: 'Network Name',
              description: 'Provider port group or trunk used by the router LAN NIC.',
              default: 'Nested-Trunk',
            },
            domain_name: {
              type: 'string',
              title: 'Domain',
              description: 'DNS domain applied to lab-managed hostnames.',
              default: 'nested.lab',
            },
            network: {
              type: 'string',
              title: 'Network',
              description: 'Lab management subnet network address.',
              default: '10.0.0.0',
            },
            gateway: {
              type: 'string',
              title: 'Gateway',
              description: 'Router LAN IP and default gateway for lab nodes.',
              default: '10.0.0.1',
            },
            vlan_starts_with: {
              type: 'integer',
              title: 'VLAN Start',
              description: 'First VLAN ID reserved for additional nested networks.',
              default: 1001,
              minimum: 1,
              maximum: 4094,
            },
            vlan_network_count: {
              type: 'integer',
              title: 'VLAN Count',
              description: 'Number of VLAN-backed lab networks to allocate.',
              default: 20,
              minimum: 1,
              maximum: 4094,
            },
            mtu: {
              type: 'integer',
              title: 'MTU',
              description: 'MTU configured for lab-side networking.',
              default: 8000,
              minimum: 576,
              maximum: 9000,
            },
          },
          additionalProperties: true,
        },
      },
      additionalProperties: true,
    },
    execution: {
      type: 'object',
      title: 'Execution',
      description: 'Router filesystem paths used for generated HTTP and TFTP assets.',
      properties: {
        http_root: {
          type: 'string',
          title: 'HTTP Root',
          description: 'Directory served by the router web service.',
          default: '/var/www/html',
        },
        tftp_root: {
          type: 'string',
          title: 'TFTP Root',
          description: 'Directory used for PXE/TFTP boot assets.',
          default: '/srv/tftp',
        },
      },
      additionalProperties: true,
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const esxiGroup = {
  type: 'object',
  title: 'ESXi Group',
  description:
    'A homogeneous set of nested ESXi hosts rendered from a count, hostname prefix, and VM shape.',
  required: [
    'router',
    'placement',
    'count',
    'hostname_prefix',
    'starting_ip',
    'domain_name',
    'install',
  ],
  properties: {
    router: {
      type: 'string',
      title: 'Router',
      description: 'Router key that provides management networking and PXE services.',
    },
    placement: providerPlacement,
    count: {
      type: 'integer',
      title: 'Count',
      description: 'Number of ESXi hosts generated in this group.',
      default: 1,
      minimum: 1,
    },
    hostname_prefix: {
      type: 'string',
      title: 'Hostname Prefix',
      description: 'Prefix used to generate esxi01, esxi02, and later hostnames.',
      default: 'esxi',
    },
    starting_ip: {
      type: 'string',
      title: 'Starting IP',
      description: 'First ESXi management IP. Later hosts increment from this address.',
      default: '10.0.0.101',
    },
    domain_name: {
      type: 'string',
      title: 'Domain',
      description: 'DNS domain for generated ESXi FQDNs.',
      default: 'nested.lab',
    },
    gateway: {
      type: 'string',
      title: 'Gateway',
      description: 'Default gateway for ESXi management networking.',
      default: '10.0.0.1',
    },
    nameservers: {
      ...stringArray,
      title: 'Nameservers',
      description: 'DNS resolvers configured on ESXi hosts.',
    },
    ntp_servers: {
      ...stringArray,
      title: 'NTP Servers',
      description: 'NTP servers configured on ESXi hosts.',
    },
    subnet_mask: {
      type: 'string',
      title: 'Subnet Mask',
      description: 'ESXi management subnet mask.',
      default: '255.255.255.0',
    },
    shape: {
      type: 'object',
      title: 'Shape',
      description: 'VM hardware shape shared by every ESXi host in this group.',
      properties: {
        num_cpus: {
          type: 'integer',
          title: 'CPUs',
          description: 'vCPU count per nested ESXi VM.',
          default: 16,
          minimum: 1,
        },
        mem_gb: {
          type: 'integer',
          title: 'Memory GB',
          description: 'Memory size per nested ESXi VM.',
          default: 32,
          minimum: 1,
        },
        nic_count: {
          type: 'integer',
          title: 'NICs',
          description: 'Number of virtual NICs per ESXi VM.',
          default: 8,
          minimum: 1,
        },
        tpm_enabled: {
          type: 'boolean',
          title: 'TPM Enabled',
          description: 'Attach a virtual TPM to each ESXi VM.',
          default: false,
        },
        nvme_enabled: {
          type: 'boolean',
          title: 'NVMe Enabled',
          description: 'Use NVMe devices where supported by the deployment flow.',
          default: false,
        },
        disks: {
          type: 'array',
          title: 'Disks',
          description: 'Disk definitions attached to each ESXi VM.',
          items: freeform,
          default: [{ label: 'disk0', size_gb: 32, unit_number: 0 }],
        },
      },
      additionalProperties: true,
    },
    vmkernel_adapters: {
      type: 'array',
      title: 'VMkernel Adapters',
      description:
        'Optional ESXi VMkernel adapter definitions used by nested vCenter storage, vMotion, and vSAN preparation.',
      items: vmkernelAdapter,
    },
    install: {
      type: 'object',
      title: 'Install',
      description: 'Installation method and media for the ESXi group.',
      required: ['method', 'source'],
      properties: {
        method: {
          type: 'string',
          title: 'Method',
          description: 'PXE through the lab router or provider ISO boot.',
          enum: ['ansible_router_pxe', 'ansible_vsphere_iso_boot'],
          default: 'ansible_router_pxe',
        },
        source: sourceRef,
        kickstart: {
          type: 'object',
          title: 'Kickstart',
          description: 'Kickstart template settings used for unattended ESXi installation.',
          properties: {
            template: {
              type: 'string',
              title: 'Template',
              description: 'Kickstart template name.',
              default: 'esxi-8.0',
            },
          },
          additionalProperties: true,
        },
      },
      additionalProperties: true,
    },
    managed_by: {
      ...stringArray,
      title: 'Managed By',
      description: 'vCenter keys expected to manage this ESXi group.',
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const storage = {
  type: 'object',
  title: 'Storage',
  description: 'Storage appliance or service VM attached to the lab management network.',
  required: ['router', 'source', 'placement', 'ip'],
  properties: {
    router: {
      type: 'string',
      title: 'Router',
      description: 'Router key that provides management networking for the storage VM.',
    },
    source: sourceRef,
    placement: providerPlacement,
    ip: { type: 'string', title: 'IP', description: 'Management IP for the storage appliance.' },
    gateway: {
      type: 'string',
      title: 'Gateway',
      description: 'Default gateway on the lab management network.',
    },
    nameservers: {
      ...stringArray,
      title: 'Nameservers',
      description: 'DNS resolvers configured on the storage appliance.',
    },
    domain_name: {
      type: 'string',
      title: 'Domain',
      description: 'DNS domain for the storage appliance hostname.',
    },
    subnet_mask: { type: 'string', title: 'Subnet Mask', description: 'Management subnet mask.' },
    storage1_ip: {
      type: 'string',
      title: 'Storage Network 1 IP',
      description: 'First storage service IP, typically used by iSCSI path A.',
      default: '10.0.4.10',
    },
    storage2_ip: {
      type: 'string',
      title: 'Storage Network 2 IP',
      description: 'Second storage service IP, typically used by iSCSI path B.',
      default: '10.0.5.10',
    },
    storage1_vlan: {
      type: 'integer',
      title: 'Storage VLAN 1',
      description: 'VLAN for the first storage network.',
      default: 1004,
      minimum: 1,
      maximum: 4094,
    },
    storage2_vlan: {
      type: 'integer',
      title: 'Storage VLAN 2',
      description: 'VLAN for the second storage network.',
      default: 1005,
      minimum: 1,
      maximum: 4094,
    },
    mtu: {
      type: 'integer',
      title: 'MTU',
      description: 'Storage network MTU.',
      default: 8000,
      minimum: 576,
      maximum: 9000,
    },
    storage_subnet_mask: {
      type: 'string',
      title: 'Storage Subnet Mask',
      description: 'Subnet mask for storage service networks.',
      default: '255.255.255.0',
    },
    disk_size_gb: {
      type: 'integer',
      title: 'Storage Appliance Disk GB',
      description: 'Backing disk size for the storage appliance.',
      default: 200,
      minimum: 1,
    },
    num_cpus: {
      type: 'integer',
      title: 'CPUs',
      description: 'vCPU count for the storage appliance.',
      default: 4,
      minimum: 1,
    },
    mem_gb: {
      type: 'integer',
      title: 'Memory GB',
      description: 'Memory size for the storage appliance.',
      default: 4,
      minimum: 1,
    },
    luns: {
      type: 'array',
      title: 'LUNs',
      description: 'iSCSI LUNs exposed by the storage appliance.',
      items: storageLun,
      default: [
        { name: 'lun01', size_gb: 200 },
        { name: 'lun02', size_gb: 200 },
        { name: 'lun03', size_gb: 200 },
        { name: 'lun04', size_gb: 200 },
      ],
    },
    zfs_compression: {
      type: 'string',
      title: 'ZFS Compression',
      description: 'ZFS compression mode for storage datasets.',
      default: 'off',
    },
    zfs_nfs_dedup: {
      type: 'string',
      title: 'ZFS NFS Dedup',
      description: 'ZFS dedup mode for NFS datasets.',
      default: 'off',
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

const vcenter = {
  type: 'object',
  title: 'vCenter Server',
  description: 'vCenter Server Appliance definition and the ESXi groups it should manage.',
  required: ['router', 'placement', 'hostname', 'ip', 'source', 'manages'],
  properties: {
    router: {
      type: 'string',
      title: 'Router',
      description: 'Router key that provides management networking for vCenter.',
    },
    placement: providerPlacement,
    hostname: {
      type: 'string',
      title: 'Hostname',
      description: 'vCenter hostname without the DNS domain.',
      default: 'vcsa01',
    },
    ip: {
      type: 'string',
      title: 'IP',
      description: 'vCenter management IP on the lab network.',
      default: '10.0.0.10',
    },
    deployment_size: {
      type: 'string',
      title: 'Deployment Size',
      description: 'VCSA deployment size profile.',
      enum: ['tiny', 'small', 'medium', 'large', 'xlarge'],
      default: 'small',
    },
    source: sourceRef,
    manages: {
      ...stringArray,
      title: 'Manages',
      description: 'ESXi group keys that this vCenter should own.',
    },
    depots: {
      type: 'array',
      title: 'vLCM Online Depots',
      description:
        'vCenter Lifecycle Manager online depots. Required for vCenter 9.0+ image-based ESXi management.',
      items: {
        type: 'object',
        title: 'Depot',
        required: ['location', 'description'],
        properties: {
          location: {
            type: 'string',
            title: 'Location',
            description: 'Depot index URL, such as https://repo.example.local/vmw-depot-index.xml.',
          },
          description: {
            type: 'string',
            title: 'Description',
            description: 'vCenter depot description.',
          },
        },
        additionalProperties: true,
      },
    },
    sso_domain_name: {
      type: 'string',
      title: 'SSO Domain',
      description: 'VCSA SSO domain.',
      default: 'vsphere.local',
    },
    nameservers: {
      ...stringArray,
      title: 'Nameservers',
      description: 'DNS resolvers configured on vCenter.',
    },
    subnet_mask: {
      type: 'string',
      title: 'Subnet Mask',
      description: 'vCenter management subnet mask.',
    },
  },
  additionalProperties: true,
} satisfies JsonSchema;

export const deploymentEditorSchema = {
  $schema: 'http://json-schema.org/draft-07/schema#',
  $id: 'https://nvl.io/schemas/deployment.v1alpha1.schema.json',
  type: 'object',
  title: 'NVL Deployment',
  description:
    'Declarative description of providers, install media, routers, ESXi groups, storage appliances, and vCenter Servers.',
  additionalProperties: false,
  required: [
    'apiVersion',
    'kind',
    'name',
    'providers',
    'install_sources',
    'routers',
    'storages',
    'esxi_groups',
    'vcenters',
  ],
  properties: {
    apiVersion: {
      const: 'nvl.io/v1alpha1',
      title: 'API Version',
      description: 'NVL document API version.',
    },
    kind: { const: 'Deployment', title: 'Kind', description: 'Document kind.' },
    name: {
      type: 'string',
      title: 'Deployment Name',
      description: 'Short, DNS-safe lab name used as a prefix in generated infrastructure.',
      minLength: 1,
      pattern: '^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$',
      default: 'lab-a',
    },
    providers: {
      type: 'object',
      title: 'Providers',
      description:
        'Named provider definitions. The primary provider is required for the standard vSphere flow.',
      required: ['primary'],
      additionalProperties: provider,
    },
    install_sources: {
      type: 'object',
      title: 'Install Sources',
      description:
        'Named installer and image sources referenced by routers, ESXi groups, storage, and vCenter definitions.',
      additionalProperties: installSource,
    },
    routers: {
      type: 'object',
      title: 'Routers',
      description: 'Router/service VMs that define lab management networks.',
      additionalProperties: router,
    },
    storages: {
      type: 'object',
      title: 'Storage Appliances',
      description: 'Optional storage components used by the nested lab.',
      additionalProperties: storage,
    },
    esxi_groups: {
      type: 'object',
      title: 'ESXi Groups',
      description: 'Nested ESXi host groups generated from shared shape and hostname settings.',
      additionalProperties: esxiGroup,
    },
    vcenters: {
      type: 'object',
      title: 'vCenter Servers',
      description: 'vCenter Server Appliances and the groups they manage.',
      additionalProperties: vcenter,
    },
    credentials: {
      type: 'object',
      title: 'Credentials',
      description: 'Deployment-level credentials. Keep real secrets out of committed files.',
      properties: {
        vm_admin_password: {
          type: 'string',
          title: 'Admin Password',
          description: 'Router labadmin and nested ESXi root password used by deployment_v2.',
        },
        ansible: {
          type: 'object',
          title: 'Ansible Connection',
          description: 'Controller-side SSH defaults used when rendering Ansible inventory.',
          properties: {
            password: {
              type: 'string',
              title: 'Password',
              description:
                'Explicit SSH password for Ansible. Prefer password_env for shared files.',
            },
            password_env: {
              type: 'string',
              title: 'Password Env',
              description: 'Environment variable that provides the Ansible SSH password.',
            },
            private_key_file: {
              type: 'string',
              title: 'Private Key File',
              description: 'Controller-side private key path used by Ansible SSH.',
            },
            private_key_file_env: {
              type: 'string',
              title: 'Private Key Env',
              description:
                'Environment variable that provides the controller-side private key path.',
            },
            ssh_common_args: {
              type: 'string',
              title: 'SSH Args',
              description: 'Optional extra SSH args for Ansible connections.',
            },
          },
          additionalProperties: true,
        },
      },
      additionalProperties: true,
    },
    ssh_authorized_keys: {
      type: 'array',
      title: 'SSH Authorized Keys',
      description: 'Public SSH keys injected into generated lab VMs where supported.',
      items: { type: 'string' },
    },
    metadata: {
      ...freeform,
      title: 'Metadata',
      description: 'Free-form labels and notes for tooling.',
    },
  },
} satisfies JsonSchema;
