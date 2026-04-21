import {
  checkSeedCapabilities,
  documentKind,
  validateDocument,
} from '@nvl/core';

export interface GraphNode {
  id: string;
  label: string;
  kind: string;
}

export interface GraphEdge {
  from: string;
  to: string;
  label: string;
}

export interface HostnameEntry {
  kind: string;
  name: string;
  hostname: string;
  fqdn: string;
  ip: string;
  source: string;
}

export interface HostnameIssue {
  severity: 'error' | 'warning';
  message: string;
}

export interface HostnameInventory {
  entries: HostnameEntry[];
  issues: HostnameIssue[];
}

export interface EditorValidation {
  valid: boolean;
  kind: string;
  messages: string[];
}

export const SAMPLE_DEPLOYMENT = {
  apiVersion: 'nvl.io/v1alpha1',
  kind: 'Deployment',
  name: 'lab-a',
  credentials: {
    vm_admin_password: 'VMware123!',
    ansible: {
      private_key_file_env: 'ANSIBLE_PRIVATE_KEY_FILE',
    },
  },
  ssh_authorized_keys: [],
  providers: {
    primary: {
      kind: 'vsphere',
      credentials: {
        server_env: 'VSPHERE_SERVER',
        user_env: 'VSPHERE_USER',
        password_env: 'VSPHERE_PASSWORD',
      },
      placement_defaults: {
        datacenter: 'Datacenter',
        resource_pool: 'Resources',
        compute_host: 'esxi.example.local',
        datastore: 'datastore1',
        networks: {
          wan: 'VM Network',
          lan: 'Nested-Trunk',
        },
      },
    },
  },
  install_sources: {
    router_ova: {
      type: 'http_ovf',
      url: 'https://repo.example.local/ova/router/nvl-unified.ova',
    },
    esxi_8u3_installer: {
      type: 'http_iso',
      url: 'https://repo.example.local/iso/VMware-VMvisor-Installer-8.0U3.iso',
    },
  },
  routers: {
    router_a: {
      source: {
        install_source: 'router_ova',
      },
      placement: {
        kind: 'provider_vsphere',
      },
      networks: {
        wan: {
          network_name: 'VM Network',
          ip: null,
        },
        lan: {
          network_name: 'Nested-Trunk',
          domain_name: 'nested.lab',
          network: '10.0.0.0',
          gateway: '10.0.0.1',
        },
      },
    },
  },
  storages: {},
  esxi_groups: {
    management_a: {
      router: 'router_a',
      placement: {
        kind: 'provider_vsphere',
      },
      count: 1,
      hostname_prefix: 'esxi',
      starting_ip: '10.0.0.101',
      domain_name: 'nested.lab',
      install: {
        method: 'ansible_router_pxe',
        source: {
          install_source: 'esxi_8u3_installer',
        },
        kickstart: {
          template: 'esxi-8.0',
        },
      },
    },
  },
  vcenters: {},
};

export const SAMPLE_SEED = {
  apiVersion: 'nvl.io/v1alpha1',
  kind: 'AnsibleSeed',
  credentials: {
    vm_admin_password: 'VMware123!',
  },
  routers: {
    router_a: {
      name: 'lab-a-router_a',
      management_ip: '10.0.0.1',
      lifecycle: {
        owner: 'terraform',
        provider: 'vsphere',
      },
      capabilities: {
        guest_exec: 'ssh',
        file_transfer: 'scp',
      },
      provider_ref: {
        provider: 'vsphere',
        vm_name: 'lab-a-router_a',
      },
      networks: {
        lan: {
          domain_name: 'nested.lab',
          network: '10.0.0.0',
        },
      },
      services: {
        http: true,
        pxe: true,
      },
      runtime: {
        http_root: '/var/www/html',
        tftp_root: '/srv/tftp',
      },
      ansible: {
        host: '192.168.1.50',
        user: 'labadmin',
      },
    },
  },
  esxi_groups: {
    management_a: {
      router: 'router_a',
      lifecycle: {
        owner: 'terraform',
        provider: 'vsphere',
      },
      capabilities: {
        power_control: 'vsphere_api',
        boot_control: 'vsphere_api',
        console_input: 'vmware_sendkey',
        guest_verification: 'vmware_tools',
        esxi_install: ['pxe', 'datastore_iso'],
      },
      provider_ref: {
        provider: 'vsphere',
        datacenter: 'Datacenter',
      },
      install: {
        method: 'ansible_router_pxe',
      },
      hosts: [
        {
          name: 'lab-a-management_a-esxi01',
          hostname: 'esxi01',
          fqdn: 'esxi01.nested.lab',
          ip: '10.0.0.101',
          primary_mac_address: '00:50:56:aa:bb:01',
          observed: {
            primary_mac_address: '00:50:56:aa:bb:01',
            mac_addresses: ['00:50:56:aa:bb:01'],
          },
          ansible: {
            host: '10.0.0.101',
            user: 'root',
          },
        },
      ],
    },
  },
  storages: {},
  vcenters: {},
};

export function validateEditorDocument(value: unknown, hostnameIssues: HostnameIssue[] = []): EditorValidation {
  const schemaResult = validateDocument(value);
  const messages = [...schemaResult.messages];
  if (schemaResult.valid && schemaResult.kind === 'AnsibleSeed') {
    messages.push(...checkSeedCapabilities(value).errors);
  }
  messages.push(...hostnameIssues.filter((issue) => issue.severity === 'error').map((issue) => issue.message));

  return {
    valid: schemaResult.valid && messages.length === 0,
    kind: schemaResult.kind ?? '',
    messages,
  };
}

export function buildHostnameInventory(value: unknown): HostnameInventory {
  const document = asRecord(value);
  const entries: HostnameEntry[] = [];
  const issues: HostnameIssue[] = [];

  if (!document) {
    return { entries, issues };
  }

  const kind = documentKind(value);
  if (kind === 'Deployment') {
    collectDeploymentHostnames(document, entries, issues);
  }
  if (kind === 'AnsibleSeed') {
    collectSeedHostnames(document, entries);
  }

  addDuplicateHostnameIssues(entries, issues);
  addDnsLabelIssues(entries, issues);
  return { entries, issues };
}

export function buildGraph(value: unknown): { nodes: GraphNode[]; edges: GraphEdge[] } {
  const document = asRecord(value);
  const nodes: GraphNode[] = [];
  const edges: GraphEdge[] = [];

  for (const [id] of Object.entries(asRecord(document?.['routers']) ?? {})) {
    nodes.push({ id: `router:${id}`, label: id, kind: 'router' });
  }

  for (const [id, group] of Object.entries(asRecord(document?.['esxi_groups']) ?? {})) {
    nodes.push({ id: `esxi:${id}`, label: id, kind: 'esxi' });
    const router = coerceString(asRecord(group)?.['router']);
    if (router) {
      edges.push({ from: id, to: router, label: 'router' });
    }
  }

  for (const [id, storage] of Object.entries(asRecord(document?.['storages']) ?? {})) {
    nodes.push({ id: `storage:${id}`, label: id, kind: 'storage' });
    const router = coerceString(asRecord(storage)?.['router']);
    if (router) {
      edges.push({ from: id, to: router, label: 'router' });
    }
  }

  for (const [id, vcenter] of Object.entries(asRecord(document?.['vcenters']) ?? {})) {
    nodes.push({ id: `vcenter:${id}`, label: id, kind: 'vcenter' });
    const item = asRecord(vcenter);
    const router = coerceString(item?.['router']);
    if (router) {
      edges.push({ from: id, to: router, label: 'router' });
    }
    for (const group of stringArray(item?.['manages'])) {
      edges.push({ from: id, to: group, label: 'manages' });
    }
  }

  return { nodes, edges };
}

export function cloneJson<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

export function formatJson(value: unknown): string {
  return JSON.stringify(value, null, 2);
}

function collectDeploymentHostnames(
  document: Record<string, unknown>,
  entries: HostnameEntry[],
  issues: HostnameIssue[],
): void {
  const routerDomains = new Map<string, string>();
  const routers = asRecord(document['routers']) ?? {};

  for (const [name, value] of Object.entries(routers)) {
    const router = asRecord(value) ?? {};
    const lan = asRecord(asRecord(router['networks'])?.['lan']) ?? {};
    const domainName = defaultString(lan['domain_name'], 'localdomain');
    const gateway = coerceString(lan['gateway']);
    routerDomains.set(name, domainName);
    entries.push({
      kind: 'Router',
      name,
      hostname: 'router',
      fqdn: withDomain('router', domainName),
      ip: gateway,
      source: `routers.${name}`,
    });
  }

  const groups = asRecord(document['esxi_groups']) ?? {};
  for (const [name, value] of Object.entries(groups)) {
    const group = asRecord(value) ?? {};
    const routerName = coerceString(group['router']);
    const domainName = defaultString(group['domain_name'], routerDomains.get(routerName), 'localdomain');
    const prefix = defaultString(group['hostname_prefix'], name);
    const count = Math.max(0, Math.trunc(numberValue(group['count'], 0)));
    const startingIp = coerceString(group['starting_ip']);

    for (let index = 0; index < count; index += 1) {
      const hostname = `${prefix}${String(index + 1).padStart(2, '0')}`;
      entries.push({
        kind: 'ESXi',
        name: `${name}/${index + 1}`,
        hostname,
        fqdn: withDomain(hostname, domainName),
        ip: incrementIpv4(startingIp, index),
        source: `esxi_groups.${name}[${index}]`,
      });
    }
  }

  const storages = asRecord(document['storages']) ?? {};
  for (const [name, value] of Object.entries(storages)) {
    const storage = asRecord(value) ?? {};
    const routerName = coerceString(storage['router']);
    const domainName = defaultString(storage['domain_name'], routerDomains.get(routerName), 'localdomain');
    entries.push({
      kind: 'Storage',
      name,
      hostname: 'storage',
      fqdn: withDomain('storage', domainName),
      ip: coerceString(storage['ip']),
      source: `storages.${name}`,
    });
  }

  const vcenters = asRecord(document['vcenters']) ?? {};
  for (const [name, value] of Object.entries(vcenters)) {
    const vcenter = asRecord(value) ?? {};
    const routerName = coerceString(vcenter['router']);
    const domainName = routerDomains.get(routerName) ?? 'localdomain';
    const hostname = defaultString(vcenter['hostname'], name);
    entries.push({
      kind: 'vCenter',
      name,
      hostname,
      fqdn: withDomain(hostname, domainName),
      ip: coerceString(vcenter['ip']),
      source: `vcenters.${name}`,
    });

    const placement = asRecord(vcenter['placement']) ?? {};
    if (placement['kind'] === 'nested_vsphere') {
      addNestedVcenterPlacementIssue(name, placement, entries, issues);
    }
  }
}

function addNestedVcenterPlacementIssue(
  vcenterName: string,
  placement: Record<string, unknown>,
  entries: HostnameEntry[],
  issues: HostnameIssue[],
): void {
  const groupName = coerceString(placement['esxi_group']);
  const hostRef = coerceString(placement['host']);
  if (!groupName || !hostRef) {
    issues.push({
      severity: 'error',
      message: `vcenters.${vcenterName}.placement must set esxi_group and host for nested_vsphere`,
    });
    return;
  }

  const candidates = entries.filter((entry) => entry.kind === 'ESXi' && entry.source.startsWith(`esxi_groups.${groupName}[`));
  if (candidates.length === 0) {
    issues.push({
      severity: 'error',
      message: `vcenters.${vcenterName}.placement.esxi_group does not match an ESXi group: ${groupName}`,
    });
    return;
  }

  if (!candidates.some((entry) => matchesHostRef(entry, hostRef))) {
    issues.push({
      severity: 'error',
      message: `vcenters.${vcenterName}.placement.host does not match a rendered host in ${groupName}: ${hostRef}`,
    });
  }
}

function collectSeedHostnames(document: Record<string, unknown>, entries: HostnameEntry[]): void {
  const routerDomains = new Map<string, string>();
  const routers = asRecord(document['routers']) ?? {};

  for (const [name, value] of Object.entries(routers)) {
    const router = asRecord(value) ?? {};
    const lan = asRecord(asRecord(router['networks'])?.['lan']) ?? {};
    const domainName = defaultString(lan['domain_name'], 'localdomain');
    const hostname = defaultString(router['hostname'], 'router');
    routerDomains.set(name, domainName);
    entries.push({
      kind: 'Router',
      name,
      hostname,
      fqdn: withDomain(hostname, domainName),
      ip: defaultString(router['management_ip'], asRecord(router['ansible'])?.['host']),
      source: `routers.${name}`,
    });
  }

  const groups = asRecord(document['esxi_groups']) ?? {};
  for (const [groupName, value] of Object.entries(groups)) {
    const group = asRecord(value) ?? {};
    const routerName = coerceString(group['router']);
    const domainName = routerDomains.get(routerName) ?? 'localdomain';
    const hosts = Array.isArray(group['hosts']) ? group['hosts'] : [];
    hosts.forEach((hostValue, index) => {
      const host = asRecord(hostValue) ?? {};
      const fqdn = coerceString(host['fqdn']);
      const hostname = defaultString(host['hostname'], firstLabel(fqdn), `host${index + 1}`);
      entries.push({
        kind: 'ESXi',
        name: `${groupName}/${index + 1}`,
        hostname,
        fqdn: defaultString(fqdn, withDomain(hostname, domainName)),
        ip: coerceString(host['ip']),
        source: `esxi_groups.${groupName}.hosts[${index}]`,
      });
    });
  }

  const storages = asRecord(document['storages']) ?? {};
  for (const [name, value] of Object.entries(storages)) {
    const storage = asRecord(value) ?? {};
    const fqdn = coerceString(storage['fqdn']);
    const hostname = defaultString(storage['hostname'], firstLabel(fqdn), name);
    entries.push({
      kind: 'Storage',
      name,
      hostname,
      fqdn: defaultString(fqdn, hostname),
      ip: defaultString(storage['ip'], asRecord(storage['ansible'])?.['host']),
      source: `storages.${name}`,
    });
  }

  const vcenters = asRecord(document['vcenters']) ?? {};
  for (const [name, value] of Object.entries(vcenters)) {
    const vcenter = asRecord(value) ?? {};
    const fqdn = coerceString(vcenter['fqdn']);
    const hostname = defaultString(vcenter['hostname'], firstLabel(fqdn), name);
    entries.push({
      kind: 'vCenter',
      name,
      hostname,
      fqdn: defaultString(fqdn, hostname),
      ip: defaultString(vcenter['ip'], asRecord(vcenter['ansible'])?.['host']),
      source: `vcenters.${name}`,
    });
  }
}

function addDuplicateHostnameIssues(entries: HostnameEntry[], issues: HostnameIssue[]): void {
  const byFqdn = new Map<string, HostnameEntry[]>();
  for (const entry of entries) {
    if (!entry.fqdn) {
      continue;
    }
    const key = entry.fqdn.toLowerCase();
    byFqdn.set(key, [...(byFqdn.get(key) ?? []), entry]);
  }

  for (const [fqdn, duplicates] of byFqdn.entries()) {
    if (duplicates.length < 2) {
      continue;
    }
    issues.push({
      severity: 'error',
      message: `duplicate hostname ${fqdn}: ${duplicates.map((entry) => entry.source).join(', ')}`,
    });
  }
}

function addDnsLabelIssues(entries: HostnameEntry[], issues: HostnameIssue[]): void {
  for (const entry of entries) {
    if (entry.hostname && !/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/i.test(entry.hostname)) {
      issues.push({
        severity: 'warning',
        message: `${entry.source} hostname is not a DNS label: ${entry.hostname}`,
      });
    }
  }
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : undefined;
}

function coerceString(value: unknown): string {
  return typeof value === 'string' ? value : typeof value === 'number' || typeof value === 'boolean' ? String(value) : '';
}

function defaultString(...values: unknown[]): string {
  for (const value of values) {
    const text = coerceString(value);
    if (text.length > 0) {
      return text;
    }
  }
  return '';
}

function numberValue(value: unknown, fallback: number): number {
  const number = typeof value === 'number' ? value : typeof value === 'string' && value.trim() !== '' ? Number(value) : NaN;
  return Number.isFinite(number) ? number : fallback;
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value) && value.every((item) => typeof item === 'string') ? value : [];
}

function firstLabel(fqdn: string): string {
  return fqdn.split('.')[0] ?? '';
}

function withDomain(hostname: string, domainName: string): string {
  return domainName ? `${hostname}.${domainName}` : hostname;
}

function incrementIpv4(ip: string, offset: number): string {
  const octets = ip.split('.').map((part) => Number(part));
  if (octets.length !== 4 || octets.some((octet) => !Number.isInteger(octet) || octet < 0 || octet > 255)) {
    return offset === 0 ? ip : '';
  }

  const value = (((octets[0] * 256 + octets[1]) * 256 + octets[2]) * 256 + octets[3]) + offset;
  if (value < 0 || value > 0xffffffff) {
    return '';
  }

  return [
    Math.floor(value / 256 ** 3) % 256,
    Math.floor(value / 256 ** 2) % 256,
    Math.floor(value / 256) % 256,
    value % 256,
  ].join('.');
}

function matchesHostRef(entry: HostnameEntry, hostRef: string): boolean {
  const normalized = hostRef.toLowerCase();
  return [entry.hostname, entry.fqdn, entry.ip].some((value) => value.toLowerCase() === normalized);
}
