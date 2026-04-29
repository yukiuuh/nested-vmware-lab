import { Ajv } from "ajv/dist/ajv.js";
import type { AnySchema, ErrorObject, ValidateFunction } from "ajv";
import { ansibleSeedSchema, deploymentSchema } from "./schema-data.js";

export { ansibleSeedSchema, deploymentSchema } from "./schema-data.js";

export const NVL_API_VERSION = "nvl.io/v1alpha1" as const;
export type NvlApiVersion = typeof NVL_API_VERSION;
export type NvlKind = "Deployment" | "AnsibleSeed";

export interface NvlDocument {
  apiVersion: NvlApiVersion;
  kind: NvlKind;
}

export interface Deployment extends NvlDocument {
  kind: "Deployment";
  name: string;
  providers: Record<string, unknown>;
  install_sources: Record<string, unknown>;
  routers: Record<string, unknown>;
  storages: Record<string, unknown>;
  esxi_groups: Record<string, unknown>;
  vcenters: Record<string, unknown>;
  credentials?: Record<string, unknown>;
  ssh_authorized_keys?: string[];
}

export type CapabilityValue = string | string[] | undefined;

export interface Capabilities {
  power_control?: CapabilityValue;
  boot_control?: CapabilityValue;
  console_input?: CapabilityValue;
  guest_exec?: CapabilityValue;
  file_transfer?: CapabilityValue;
  guest_verification?: CapabilityValue;
  esxi_install?: CapabilityValue;
  vcenter_deploy_target?: CapabilityValue;
  [key: string]: CapabilityValue;
}

export interface Lifecycle {
  owner?: string;
  provider?: string;
}

export interface ProviderRef {
  provider?: string;
  [key: string]: unknown;
}

export interface AnsibleSeed extends NvlDocument {
  kind: "AnsibleSeed";
  credentials: Record<string, unknown>;
  routers: Record<string, SeedRouter>;
  esxi_groups: Record<string, SeedEsxiGroup>;
  storages: Record<string, unknown>;
  vcenters: Record<string, unknown>;
  services?: Record<string, unknown>;
}

export interface SeedRouter {
  ansible?: SeedAnsibleConnection;
  capabilities?: Capabilities;
  lifecycle?: Lifecycle;
  provider_ref?: ProviderRef;
  runtime?: Record<string, unknown>;
  services?: Record<string, unknown>;
  [key: string]: unknown;
}

export interface SeedEsxiGroup {
  router?: string;
  install?: {
    method?: string;
    [key: string]: unknown;
  };
  capabilities?: Capabilities;
  lifecycle?: Lifecycle;
  provider_ref?: ProviderRef;
  hosts?: SeedEsxiHost[];
  [key: string]: unknown;
}

export interface SeedEsxiHost {
  hostname?: string;
  fqdn?: string;
  ip?: string;
  ansible?: SeedAnsibleConnection;
  capabilities?: Capabilities;
  lifecycle?: Lifecycle;
  provider_ref?: ProviderRef;
  observed?: {
    primary_mac_address?: string;
    mac_addresses?: string[];
    [key: string]: unknown;
  };
  primary_mac_address?: string;
  mac_addresses?: string[];
  [key: string]: unknown;
}

export interface SeedAnsibleConnection {
  host?: string;
  user?: string;
  password?: string;
  password_env?: string;
  private_key_file?: string;
  private_key_file_env?: string;
  ssh_common_args?: string;
  port?: number;
}

export interface ValidationResult {
  valid: boolean;
  apiVersion?: string;
  kind?: string;
  errors: ErrorObject[];
  messages: string[];
}

export interface CapabilityCheckResult {
  valid: boolean;
  errors: string[];
}

export interface VsphereTfvars {
  name_prefix: string;
  provider_config: Record<string, unknown>;
  ansible_connection?: Record<string, unknown>;
  install_sources: Record<string, unknown>;
  routers: Record<string, unknown>;
  esxi_groups: Record<string, unknown>;
  storages: Record<string, unknown>;
  vcenters: Record<string, unknown>;
  services: Record<string, unknown>;
  vm_admin_password?: unknown;
  ssh_authorized_keys?: string[];
}

export type ProviderKind = "vsphere" | "static" | "vcd";
export type ProviderAdapterStatus = "implemented" | "placeholder";

export interface ProviderAdapterSummary {
  kind: ProviderKind;
  status: ProviderAdapterStatus;
  canGenerateProviderSpec: boolean;
  canDiscoverObservedData: boolean;
  canProduceSeed: boolean;
  defaultEsxiCapabilities: Capabilities;
  notes: string[];
}

export interface StaticAnsibleSeedOptions {
  validateCapabilities?: boolean;
}

const providerAdapters: Record<ProviderKind, ProviderAdapterSummary> = {
  vsphere: {
    kind: "vsphere",
    status: "implemented",
    canGenerateProviderSpec: true,
    canDiscoverObservedData: true,
    canProduceSeed: true,
    defaultEsxiCapabilities: {
      power_control: "vsphere_api",
      boot_control: "vsphere_api",
      console_input: "vmware_sendkey",
      guest_exec: "vmware_tools",
      file_transfer: "guest_operations",
      guest_verification: "vmware_tools",
      esxi_install: ["pxe", "datastore_iso"],
      vcenter_deploy_target: ["vc", "esxi"],
    },
    notes: [
      "Generates deployment_v2 Terraform tfvars as a vSphere provider spec artifact.",
      "Normalizes Terraform ansible_inventory_seed output into AnsibleSeed.",
    ],
  },
  static: {
    kind: "static",
    status: "implemented",
    canGenerateProviderSpec: false,
    canDiscoverObservedData: false,
    canProduceSeed: true,
    defaultEsxiCapabilities: {
      power_control: "external",
      boot_control: "none",
      console_input: "none",
      guest_exec: "ssh",
      file_transfer: "scp",
      guest_verification: "ssh",
      esxi_install: ["pxe"],
      vcenter_deploy_target: ["esxi"],
    },
    notes: [
      "Produces AnsibleSeed from a Deployment plus an observed-data file.",
      "Assumes Router/NAS bootstrap is complete before deployment_v2 prepare runs.",
    ],
  },
  vcd: {
    kind: "vcd",
    status: "placeholder",
    canGenerateProviderSpec: false,
    canDiscoverObservedData: false,
    canProduceSeed: false,
    defaultEsxiCapabilities: {
      power_control: "vcd_api",
      boot_control: "vcd_api",
      console_input: "none",
      guest_exec: "ssh",
      file_transfer: "scp",
      guest_verification: "ssh",
      esxi_install: ["pxe"],
      vcenter_deploy_target: ["esxi"],
    },
    notes: [
      "Reserved for a future vCloud Director producer.",
      "The first supported ESXi install mode is expected to be Router PXE.",
    ],
  },
};

export function listProviderAdapters(): ProviderAdapterSummary[] {
  return Object.values(providerAdapters).map(cloneProviderAdapterSummary);
}

export function getProviderAdapter(kind: string): ProviderAdapterSummary | undefined {
  if (kind === "vsphere" || kind === "static" || kind === "vcd") {
    return cloneProviderAdapterSummary(providerAdapters[kind]);
  }
  return undefined;
}

const schemas: Record<NvlKind, AnySchema> = {
  Deployment: deploymentSchema,
  AnsibleSeed: ansibleSeedSchema,
};

const ajv = new Ajv({ allErrors: true, strict: false });
const validators = new Map<NvlKind, ValidateFunction>();

function validatorFor(kind: NvlKind): ValidateFunction {
  const cached = validators.get(kind);
  if (cached) {
    return cached;
  }
  const validator = ajv.compile(schemas[kind]);
  validators.set(kind, validator);
  return validator;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function documentKind(document: unknown): NvlKind | undefined {
  if (!isRecord(document)) {
    return undefined;
  }
  if (document.apiVersion !== NVL_API_VERSION) {
    return undefined;
  }
  if (document.kind === "Deployment" || document.kind === "AnsibleSeed") {
    return document.kind;
  }
  return undefined;
}

export function validateDocument(document: unknown): ValidationResult {
  const apiVersion = isRecord(document) ? String(document.apiVersion ?? "") : undefined;
  const kindValue = isRecord(document) ? String(document.kind ?? "") : undefined;
  const kind = documentKind(document);

  if (!kind) {
    return {
      valid: false,
      apiVersion,
      kind: kindValue,
      errors: [],
      messages: [
        `unsupported document apiVersion/kind: ${apiVersion || "<missing>"}/${kindValue || "<missing>"}`,
      ],
    };
  }

  const validator = validatorFor(kind);
  const valid = validator(document) === true;
  const errors = [...(validator.errors ?? [])];
  const semanticMessages =
    valid && kind === "Deployment" ? deploymentSemanticValidationMessages(document as Deployment) : [];

  return {
    valid: valid && semanticMessages.length === 0,
    apiVersion,
    kind,
    errors,
    messages: [...formatValidationErrors(errors), ...semanticMessages],
  };
}

export function assertAnsibleSeed(document: unknown): AnsibleSeed {
  const result = validateDocument(document);
  if (!result.valid || result.kind !== "AnsibleSeed") {
    const messages = result.messages.length > 0 ? result.messages.join("; ") : "document is not an AnsibleSeed";
    throw new Error(messages);
  }
  return document as AnsibleSeed;
}

export function assertDeployment(document: unknown): Deployment {
  const result = validateDocument(document);
  if (!result.valid || result.kind !== "Deployment") {
    const messages = result.messages.length > 0 ? result.messages.join("; ") : "document is not a Deployment";
    throw new Error(messages);
  }
  return document as Deployment;
}

export function formatValidationErrors(errors: ErrorObject[]): string[] {
  return errors.map((error) => {
    const path = error.instancePath || "/";
    return `${path} ${error.message ?? "is invalid"}`;
  });
}

function deploymentSemanticValidationMessages(deployment: Deployment): string[] {
  return [
    ...deploymentVcenterDepotMessages(deployment),
    ...deploymentVsanBootstrapMessages(deployment),
  ];
}

function deploymentVcenterDepotMessages(deployment: Deployment): string[] {
  const messages: string[] = [];
  const installSources = asRecord(deployment.install_sources) ?? {};

  for (const [name, value] of Object.entries(deployment.vcenters ?? {})) {
    const vcenter = asRecord(value) ?? {};
    const sourceRef = vcenterSourceRef(vcenter);
    const source = sourceRef ? asRecord(installSources[sourceRef]) : undefined;
    if (!source || !vcsaSourceRequiresDepot(source)) {
      continue;
    }
    if (hasDepotEntries(vcenter.depots)) {
      continue;
    }
    messages.push(
      `vcenters.${name}.depots must define at least one vLCM online depot when the VCSA installer source is vCenter 9.0 or later`,
    );
  }

  return messages;
}

function deploymentVsanBootstrapMessages(deployment: Deployment): string[] {
  const messages: string[] = [];
  const installSources = asRecord(deployment.install_sources) ?? {};
  const esxiGroups = asRecord(deployment.esxi_groups) ?? {};

  for (const [name, value] of Object.entries(deployment.vcenters ?? {})) {
    const vcenter = asRecord(value) ?? {};
    const placement = asRecord(vcenter.placement) ?? {};
    const storage = asRecord(placement.storage) ?? {};
    if (storage.mode !== "vsan_bootstrap") {
      continue;
    }

    const sourceRef = vcenterSourceRef(vcenter);
    const source = sourceRef ? asRecord(installSources[sourceRef]) : undefined;
    const version = source ? detectVersionFromSource(source) : undefined;
    if (!version) {
      messages.push(
        `vcenters.${name}.placement.storage.mode=vsan_bootstrap requires a VCSA installer URL/path with a detectable 7.0 U2 or later version`,
      );
    } else if (!versionSupportsVsanBootstrap(version)) {
      messages.push(
        `vcenters.${name}.placement.storage.mode=vsan_bootstrap requires VCSA installer 7.0 U2 or later`,
      );
    }

    const vsan = asRecord(storage.vsan) ?? {};
    const cacheDisks = defaultStringArray(vsan.cache_disks, []);
    const capacityDisks = defaultStringArray(vsan.capacity_disks, []);
    if (cacheDisks.length !== 1) {
      messages.push(`vcenters.${name}.placement.storage.vsan.cache_disks must contain exactly one disk`);
    }
    if (capacityDisks.length === 0) {
      messages.push(`vcenters.${name}.placement.storage.vsan.capacity_disks must contain at least one disk`);
    }
    const overlap = cacheDisks.filter((disk) => capacityDisks.includes(disk));
    if (overlap.length > 0) {
      messages.push(
        `vcenters.${name}.placement.storage.vsan cache_disks and capacity_disks must not overlap: ${[
          ...new Set(overlap),
        ].join(", ")}`,
      );
    }
    const invalidMpxRuntimePaths = [...cacheDisks, ...capacityDisks].filter((disk) => disk.startsWith("mpx.vmhba"));
    if (invalidMpxRuntimePaths.length > 0) {
      messages.push(
        `vcenters.${name}.placement.storage.vsan disk selectors must be canonical naa.* device names or vmhba runtime paths; do not prefix vmhba paths with mpx: ${invalidMpxRuntimePaths.join(", ")}`,
      );
    }

    const esxiGroupName = stringOrUndefined(placement.esxi_group);
    const esxiGroup = esxiGroupName ? asRecord(esxiGroups[esxiGroupName]) : undefined;
    const shape = asRecord(esxiGroup?.shape) ?? {};
    const shapeDisks = Array.isArray(shape.disks) ? shape.disks : [];
    const requiredDiskCount = 1 + cacheDisks.length + capacityDisks.length;
    if (shapeDisks.length < requiredDiskCount) {
      messages.push(
        `vcenters.${name}.placement.storage.mode=vsan_bootstrap requires esxi_groups.${esxiGroupName ?? "<missing>"}.shape.disks to include boot disk plus requested cache/capacity disks`,
      );
    }
  }

  return messages;
}

function vcenterSourceRef(vcenter: Record<string, unknown>): string | undefined {
  const source = asRecord(vcenter.source);
  return stringOrUndefined(source?.install_source) ?? stringOrUndefined(vcenter.install_source);
}

function vcsaSourceRequiresDepot(source: Record<string, unknown>): boolean {
  const version = detectVersionFromSource(source);
  return version !== undefined && version.major >= 9;
}

function versionSupportsVsanBootstrap(version: { major: number; minor: number; patch: number }): boolean {
  return version.major > 7 || (version.major === 7 && (version.minor > 0 || version.patch >= 2));
}

function detectVersionFromSource(source: Record<string, unknown>): { major: number; minor: number; patch: number } | undefined {
  const text = [source.url, source.path]
    .map((value) => stringOrUndefined(value))
    .filter((value): value is string => value !== undefined)
    .map((value) => basename(value).toLowerCase())
    .join(" ");
  return detectVersion(text);
}

function detectVersion(text: string): { major: number; minor: number; patch: number } | undefined {
  const semver = text.match(/([0-9]+)\.([0-9]+)\.([0-9]+)/);
  if (semver) {
    return {
      major: Number(semver[1]),
      minor: Number(semver[2]),
      patch: Number(semver[3]),
    };
  }
  const update = text.match(/([0-9]+)\.([0-9]+)[._ -]*u([0-9]+)/i);
  if (update) {
    return {
      major: Number(update[1]),
      minor: Number(update[2]),
      patch: Number(update[3]),
    };
  }
  const majorMinor = text.match(/([0-9]+)\.([0-9]+)/);
  if (majorMinor) {
    return {
      major: Number(majorMinor[1]),
      minor: Number(majorMinor[2]),
      patch: 0,
    };
  }
  return undefined;
}

function basename(value: string): string {
  return value.split(/[\\/]/).at(-1) ?? value;
}

function hasDepotEntries(value: unknown): boolean {
  return Array.isArray(value) && value.length > 0;
}

export function checkSeedCapabilities(document: unknown): CapabilityCheckResult {
  const validation = validateDocument(document);
  if (!validation.valid || validation.kind !== "AnsibleSeed") {
    return {
      valid: false,
      errors: validation.messages.length > 0 ? validation.messages : ["document is not a valid AnsibleSeed"],
    };
  }

  const seed = document as AnsibleSeed;
  const errors: string[] = [];

  for (const [groupName, group] of Object.entries(seed.esxi_groups ?? {})) {
    const method = group.install?.method;
    if (!method) {
      continue;
    }

    const groupCapabilities = group.capabilities ?? {};

    if (method === "ansible_router_pxe") {
      checkRouterPxe(groupName, group, groupCapabilities, seed, errors);
    }

    if (method === "ansible_vsphere_iso_boot") {
      checkVsphereIsoBoot(groupName, groupCapabilities, errors);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

export function generateVsphereTfvars(document: unknown): VsphereTfvars {
  const deployment = assertDeployment(document);
  const primaryProvider = asRecord(deployment.providers.primary);

  if (primaryProvider?.kind !== "vsphere") {
    throw new Error("generate vsphere-tfvars requires providers.primary.kind=\"vsphere\"");
  }

  const placementDefaults = asRecord(primaryProvider.placement_defaults);
  const providerConfig = buildVsphereProviderConfig(primaryProvider, placementDefaults);
  const defaultNetworks = asRecord(providerConfig.default_networks) ?? {};

  const tfvars: VsphereTfvars = {
    name_prefix: deployment.name,
    provider_config: providerConfig,
    install_sources: mapNamedObjects(deployment.install_sources, (source) => normalizeInstallSourceTfvars(source)),
    routers: mapNamedObjects(deployment.routers, (router) => normalizeRouter(router, defaultNetworks)),
    esxi_groups: mapNamedObjects(deployment.esxi_groups, (group) => normalizeEsxiTfvarsGroup(group)),
    storages: mapNamedObjects(deployment.storages, (storage) => normalizeStorageTfvars(storage)),
    vcenters: mapNamedObjects(deployment.vcenters, (vcenter) => normalizeProviderPlacement(vcenter)),
    services: {},
  };

  const credentials = asRecord(deployment.credentials);
  if (credentials && "vm_admin_password" in credentials) {
    tfvars.vm_admin_password = credentials.vm_admin_password;
  }
  const ansibleConnection = asRecord(credentials?.ansible);
  if (ansibleConnection && Object.keys(ansibleConnection).length > 0) {
    tfvars.ansible_connection = ansibleConnection;
  }
  if (Array.isArray(deployment.ssh_authorized_keys)) {
    tfvars.ssh_authorized_keys = deployment.ssh_authorized_keys;
  }

  return tfvars;
}

export function normalizeTerraformAnsibleSeed(
  deploymentDocument: unknown,
  terraformSeedDocument: unknown,
): AnsibleSeed {
  const deployment = assertDeployment(deploymentDocument);
  if (!isRecord(terraformSeedDocument)) {
    throw new Error("Terraform ansible_inventory_seed output must be a JSON object");
  }

  const rawSeed = terraformSeedDocument as Record<string, unknown>;
  const seed: AnsibleSeed = {
    apiVersion: NVL_API_VERSION,
    kind: "AnsibleSeed",
    credentials: buildSeedCredentials(deployment, asRecord(rawSeed.credentials)),
    routers: normalizeRouters(asNamedRecord(rawSeed.routers), "terraform"),
    esxi_groups: normalizeEsxiGroups(asNamedRecord(rawSeed.esxi_groups), "terraform"),
    storages: normalizeStorages(asNamedRecord(rawSeed.storages), "terraform"),
    vcenters: normalizeVcenters(asNamedRecord(rawSeed.vcenters), "terraform"),
    services: asNamedRecord(rawSeed.services),
  };

  const validation = validateDocument(seed);
  if (!validation.valid) {
    throw new Error(`normalized Terraform seed is invalid: ${validation.messages.join("; ")}`);
  }

  const capabilityCheck = checkSeedCapabilities(seed);
  if (!capabilityCheck.valid) {
    throw new Error(`normalized Terraform seed has invalid capabilities: ${capabilityCheck.errors.join("; ")}`);
  }

  if (deployment.name.length === 0) {
    throw new Error("Deployment name must not be empty");
  }

  return seed;
}

export function generateStaticAnsibleSeed(
  deploymentDocument: unknown,
  observedDocument: unknown = {},
  options: StaticAnsibleSeedOptions = {},
): AnsibleSeed {
  const deployment = assertDeployment(deploymentDocument);
  const observed = asRecord(observedDocument) ?? {};

  const seed: AnsibleSeed = {
    apiVersion: NVL_API_VERSION,
    kind: "AnsibleSeed",
    credentials: buildSeedCredentials(deployment, asRecord(observed.credentials)),
    routers: mapNamedObjects(deployment.routers, (router, name) => {
      const observedRouter = asRecord(asRecord(observed.routers)?.[name]) ?? {};
      return buildStaticRouterSeed(deployment, name, router, observedRouter);
    }),
    esxi_groups: mapNamedObjects(deployment.esxi_groups, (group, name) => {
      const observedGroup = asRecord(asRecord(observed.esxi_groups)?.[name]) ?? {};
      return buildStaticEsxiGroupSeed(deployment, name, group, observedGroup);
    }),
    storages: mapNamedObjects(deployment.storages, (storage, name) => {
      const observedStorage = asRecord(asRecord(observed.storages)?.[name]) ?? {};
      return buildStaticRuntimeObject(deployment, name, storage, observedStorage);
    }),
    vcenters: mapNamedObjects(deployment.vcenters, (vcenter, name) => {
      const observedVcenter = asRecord(asRecord(observed.vcenters)?.[name]) ?? {};
      return buildStaticVcenterSeed(deployment, name, vcenter, observedVcenter);
    }),
    services: {
      ...(asRecord(observed.services) ?? {}),
    },
  };

  const validation = validateDocument(seed);
  if (!validation.valid) {
    throw new Error(`static seed is invalid: ${validation.messages.join("; ")}`);
  }

  if (options.validateCapabilities !== false) {
    const capabilityCheck = checkSeedCapabilities(seed);
    if (!capabilityCheck.valid) {
      throw new Error(`static seed has invalid capabilities: ${capabilityCheck.errors.join("; ")}`);
    }
  }

  return seed;
}

function checkRouterPxe(
  groupName: string,
  group: SeedEsxiGroup,
  capabilities: Capabilities,
  seed: AnsibleSeed,
  errors: string[],
): void {
  const routerName = group.router;
  const router = routerName ? seed.routers?.[routerName] : undefined;

  if (!routerName || !router) {
    errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires an existing router reference`);
  } else {
    const routerNetworks = asRecord(router.networks);
    const routerLan = asRecord(routerNetworks?.lan);

    if (!hasString(router.runtime?.http_root)) {
      errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires routers.${routerName}.runtime.http_root`);
    }
    if (!hasString(router.runtime?.tftp_root)) {
      errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires routers.${routerName}.runtime.tftp_root`);
    }
    if (router.services?.http !== true) {
      errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires routers.${routerName}.services.http=true`);
    }
    if (router.services?.pxe !== true) {
      errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires routers.${routerName}.services.pxe=true`);
    }
    if (!hasString(routerLan?.network)) {
      errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires routers.${routerName}.networks.lan.network`);
    }
    if (!hasString(routerLan?.domain_name)) {
      errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires routers.${routerName}.networks.lan.domain_name`);
    }
  }

  if (!hasCapability(capabilities, "power_control")) {
    errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires capabilities.power_control`);
  }

  if (!group.hosts || group.hosts.length === 0) {
    errors.push(`esxi_groups.${groupName}: ansible_router_pxe requires at least one ESXi host`);
  }

  for (const host of group.hosts ?? []) {
    if (!hasHostMac(host)) {
      const hostName = host.fqdn ?? host.hostname ?? "<unknown>";
      errors.push(`esxi_groups.${groupName}.hosts.${hostName}: ansible_router_pxe requires observed MAC addresses`);
    }
  }
}

function buildSeedCredentials(
  deployment: Deployment,
  observedCredentials: Record<string, unknown> | undefined,
): Record<string, unknown> {
  const deploymentCredentials = asRecord(deployment.credentials) ?? {};
  const realizedCredentials = observedCredentials ?? {};
  const vsphereCredentials = buildVsphereSeedCredentials(deployment);
  const deploymentVsphereCredentials = asRecord(deploymentCredentials.vsphere);
  const realizedVsphereCredentials = asRecord(realizedCredentials.vsphere);

  const credentials = mergeDefinedObjects(deploymentCredentials, realizedCredentials);

  if (vsphereCredentials || deploymentVsphereCredentials || realizedVsphereCredentials) {
    credentials.vsphere = mergeDefinedObjects(
      vsphereCredentials ?? {},
      deploymentVsphereCredentials ?? {},
      realizedVsphereCredentials ?? {},
    );
  }

  return credentials;
}

function buildVsphereSeedCredentials(deployment: Deployment): Record<string, unknown> | undefined {
  const provider = findProviderByKind(deployment, "vsphere");
  if (!provider) {
    return undefined;
  }

  const providerCredentials = asRecord(provider.credentials);
  const placementDefaults = asRecord(provider.placement_defaults);
  const credentials: Record<string, unknown> = {};

  copyIfString(providerCredentials, credentials, "server");
  copyIfString(providerCredentials, credentials, "server_env");
  copyIfString(providerCredentials, credentials, "user");
  copyIfString(providerCredentials, credentials, "user_env");
  copyIfString(providerCredentials, credentials, "password");
  copyIfString(providerCredentials, credentials, "password_env");
  copyIfString(providerCredentials, credentials, "datacenter");
  copyIfString(providerCredentials, credentials, "datacenter_env");
  if (!hasString(credentials.datacenter)) {
    copyIfString(placementDefaults, credentials, "datacenter");
  }
  if (typeof providerCredentials?.insecure === "boolean") {
    credentials.insecure = providerCredentials.insecure;
  }

  return Object.keys(credentials).length > 0 ? credentials : undefined;
}

function findProviderByKind(deployment: Deployment, kind: string): Record<string, unknown> | undefined {
  const primary = asRecord(deployment.providers.primary);
  if (stringOrUndefined(primary?.kind) === kind) {
    return primary;
  }
  return Object.values(deployment.providers)
    .map((provider) => asRecord(provider))
    .find((provider) => stringOrUndefined(provider?.kind) === kind);
}

function buildStaticRouterSeed(
  deployment: Deployment,
  name: string,
  router: Record<string, unknown>,
  observedRouter: Record<string, unknown>,
): SeedRouter {
  const providerKind = providerKindForObject(deployment, router);
  const networks = asRecord(router.networks) ?? {};
  const lan = asRecord(networks.lan) ?? {};
  const wan = asRecord(networks.wan) ?? {};
  const observedAnsible = asRecord(observedRouter.ansible) ?? {};
  const managementIp = defaultString(observedRouter.management_ip, lan.gateway, "10.0.0.1");
  const ansibleHost = defaultString(observedAnsible.host, observedRouter.wan_ip, wan.ip);
  const deploymentCredentials = asRecord(deployment.credentials);
  if (!hasString(ansibleHost) && providerKind === "static") {
    throw new Error(`routers.${name}: static seed requires observed ansible.host or wan_ip`);
  }

  return {
    ...router,
    ...observedRouter,
    name: defaultString(observedRouter.name, router.name, `${deployment.name}-${name}`),
    wan_ip: observedRouter.wan_ip ?? wan.ip ?? null,
    management_network: observedRouter.management_network ?? lan.network,
    management_ip: managementIp,
    lifecycle: mergeObject(observedRouter.lifecycle, {
      owner: "external",
      provider: providerKind,
    }),
    capabilities: mergeCapabilities(observedRouter.capabilities ?? router.capabilities, {
      guest_exec: "ssh",
      file_transfer: "scp",
    }),
    provider_ref: mergeObject(observedRouter.provider_ref, {
      provider: providerKind,
      vm_name: defaultString(observedRouter.name, router.name, `${deployment.name}-${name}`),
    }),
    networks,
    services: mergeObject(observedRouter.services, {
      http: true,
      pxe: true,
      rclone: false,
    }),
    runtime: mergeObject(observedRouter.runtime, {
      http_root: "/var/www/html",
      tftp_root: "/srv/tftp",
      ...(asRecord(router.execution) ?? {}),
    }),
    ansible: {
      ...(hasString(ansibleHost) ? { host: ansibleHost } : {}),
      user: defaultString(observedAnsible.user, "labadmin"),
      password: defaultString(observedAnsible.password, deploymentCredentials?.vm_admin_password),
      ...observedAnsible,
    },
  };
}

function buildStaticEsxiGroupSeed(
  deployment: Deployment,
  name: string,
  group: Record<string, unknown>,
  observedGroup: Record<string, unknown>,
): SeedEsxiGroup {
  const providerKind = providerKindForObject(deployment, group);
  const install = asRecord(group.install) ?? {};
  const routerName = defaultString(observedGroup.router, group.router);
  const defaultCapabilities = capabilitiesForProviderEsxiGroup(providerKind, group);
  const sourceRef = installSourceRef(install);
  const resolvedInstallSource = sourceRef ? asRecord(deployment.install_sources[sourceRef]) : undefined;

  return {
    ...group,
    ...observedGroup,
    router: routerName,
    lifecycle: mergeObject(observedGroup.lifecycle, {
      owner: "external",
      provider: providerKind,
    }),
    capabilities: mergeCapabilities(observedGroup.capabilities ?? group.capabilities, defaultCapabilities),
    provider_ref: mergeObject(observedGroup.provider_ref, {
      provider: providerKind,
    }),
    install: {
      ...install,
      ...(asRecord(observedGroup.install) ?? {}),
      source: resolvedInstallSource ?? asRecord(install.source),
      install_source: installSourceRef(install),
    },
    network: buildStaticEsxiNetwork(deployment, routerName, group, observedGroup),
    ntp_servers: defaultStringArray(observedGroup.ntp_servers ?? group.ntp_servers, ["10.0.0.1"]),
    hosts: buildStaticEsxiHosts(deployment, name, group, observedGroup, providerKind),
  };
}

function buildStaticEsxiNetwork(
  deployment: Deployment,
  routerName: string,
  group: Record<string, unknown>,
  observedGroup: Record<string, unknown>,
): Record<string, unknown> {
  const router = asRecord(deployment.routers[routerName]);
  const routerLan = asRecord(asRecord(router?.networks)?.lan) ?? {};
  const desiredNetwork = asRecord(group.network) ?? {};
  const observedNetwork = asRecord(observedGroup.network) ?? {};
  const gateway = defaultString(observedNetwork.gateway, desiredNetwork.gateway, group.gateway, routerLan.gateway, "10.0.0.1");

  return {
    network_name: defaultString(
      observedNetwork.network_name,
      desiredNetwork.network_name,
      group.network_name,
      routerLan.network_name,
      "Nested-Trunk",
    ),
    domain_name: defaultString(
      observedNetwork.domain_name,
      desiredNetwork.domain_name,
      group.domain_name,
      routerLan.domain_name,
      "nested.lab",
    ),
    gateway,
    nameservers: defaultStringArray(observedNetwork.nameservers ?? desiredNetwork.nameservers ?? group.nameservers, [gateway]),
    subnet_mask: defaultString(
      observedNetwork.subnet_mask,
      desiredNetwork.subnet_mask,
      group.subnet_mask,
      "255.255.255.0",
    ),
    ...desiredNetwork,
    ...observedNetwork,
  };
}

function routerDomainName(deployment: Deployment, routerName: string): string | undefined {
  const router = asRecord(deployment.routers[routerName]);
  return stringOrUndefined(asRecord(asRecord(router?.networks)?.lan)?.domain_name);
}

function buildStaticEsxiHosts(
  deployment: Deployment,
  groupName: string,
  group: Record<string, unknown>,
  observedGroup: Record<string, unknown>,
  providerKind: string,
): SeedEsxiHost[] {
  const observedHosts = Array.isArray(observedGroup.hosts)
    ? observedGroup.hosts.map((host) => asRecord(host) ?? {})
    : [];
  const count = defaultNumber(group.count, observedHosts.length);

  if (count < 1) {
    throw new Error(`esxi_groups.${groupName}: static seed requires count or observed hosts`);
  }

  const domainName = defaultString(group.domain_name, observedGroup.domain_name, "nested.lab");
  const hostnamePrefix = defaultString(group.hostname_prefix, "esxi");
  const startingIp = stringOrUndefined(group.starting_ip);
  const deploymentCredentials = asRecord(deployment.credentials);

  return Array.from({ length: count }, (_, index) => {
    const observedHost = observedHosts[index] ?? {};
    const hostname = defaultString(observedHost.hostname, `${hostnamePrefix}${String(index + 1).padStart(2, "0")}`);
    const fqdn = defaultString(observedHost.fqdn, `${hostname}.${domainName}`);
    const observedProviderRef = asRecord(observedHost.provider_ref) ?? {};
    const providerVmName = defaultString(
      observedHost.name,
      observedProviderRef.vm_name,
      `${deployment.name}-${groupName}-${hostname}`,
    );
    const ip = defaultString(
      observedHost.ip,
      observedHost.ansible && asRecord(observedHost.ansible)?.host,
      startingIp ? incrementIpv4(startingIp, index) : undefined,
    );
    if (!hasString(ip)) {
      throw new Error(`esxi_groups.${groupName}.hosts.${hostname}: static seed requires ip or starting_ip`);
    }

    const observed = mergeObject(observedHost.observed, {
      mac_addresses: asStringArray(observedHost.mac_addresses),
      primary_mac_address: stringOrUndefined(observedHost.primary_mac_address),
    });
    const ansible = asRecord(observedHost.ansible) ?? {};
    const primaryMac = stringOrUndefined(observedHost.primary_mac_address)
      ?? stringOrUndefined(observed.primary_mac_address);
    const macAddresses = asStringArray(observedHost.mac_addresses)
      ?? asStringArray(observed.mac_addresses)
      ?? (primaryMac ? [primaryMac] : undefined);

    return {
      ...observedHost,
      name: providerVmName,
      hostname,
      fqdn,
      ip,
      mac_addresses: macAddresses,
      primary_mac_address: primaryMac,
      observed,
      lifecycle: mergeObject(observedHost.lifecycle, {
        owner: "external",
        provider: providerKind,
      }),
      provider_ref: mergeObject(observedHost.provider_ref, {
        provider: providerKind,
        vm_name: providerVmName,
      }),
      ansible: {
        host: defaultString(ansible.host, ip),
        user: defaultString(ansible.user, "root"),
        password: defaultString(ansible.password, deploymentCredentials?.vm_admin_password),
        ...ansible,
      },
    };
  });
}

function buildStaticRuntimeObject(
  deployment: Deployment,
  name: string,
  desired: Record<string, unknown>,
  observed: Record<string, unknown>,
): Record<string, unknown> {
  const providerKind = providerKindForObject(deployment, desired);
  return {
    ...desired,
    ...observed,
    lifecycle: mergeObject(observed.lifecycle, {
      owner: "external",
      provider: providerKind,
    }),
    capabilities: mergeCapabilities(observed.capabilities ?? desired.capabilities, {
      guest_exec: "ssh",
      file_transfer: "scp",
    }),
    provider_ref: mergeObject(observed.provider_ref, {
      provider: providerKind,
      vm_name: defaultString(observed.name, desired.name, `${deployment.name}-${name}`),
    }),
  };
}

function buildStaticVcenterSeed(
  deployment: Deployment,
  name: string,
  desired: Record<string, unknown>,
  observed: Record<string, unknown>,
): Record<string, unknown> {
  const providerKind = providerKindForObject(deployment, desired);
  const routerName = defaultString(observed.router, desired.router);
  const domainName = defaultString(
    observed.domain_name,
    desired.domain_name,
    routerDomainName(deployment, routerName),
    "nested.lab",
  );
  const hostname = defaultString(observed.hostname, desired.hostname, name);
  const fqdn = defaultString(observed.fqdn, desired.fqdn, `${hostname}.${domainName}`);
  const observedAnsible = asRecord(observed.ansible) ?? {};
  const desiredAnsible = asRecord(desired.ansible) ?? {};
  const ansibleHost = defaultString(
    observedAnsible.host,
    desiredAnsible.host,
    observed.ip,
    desired.ip,
    fqdn,
  );

  return {
    ...desired,
    ...observed,
    hostname,
    fqdn,
    lifecycle: mergeObject(observed.lifecycle, {
      owner: "external",
      provider: providerKind,
    }),
    capabilities: mergeCapabilities(observed.capabilities ?? desired.capabilities, {
      guest_exec: "ssh",
      file_transfer: "scp",
    }),
    provider_ref: mergeObject(observed.provider_ref, {
      provider: providerKind,
      vm_name: defaultString(observed.name, desired.name, `${deployment.name}-${name}`),
    }),
    ansible: {
      host: ansibleHost,
      user: defaultString(observedAnsible.user, desiredAnsible.user, "root"),
      ...desiredAnsible,
      ...observedAnsible,
    },
  };
}

function buildVsphereProviderConfig(
  provider: Record<string, unknown>,
  placementDefaults: Record<string, unknown> | undefined,
): Record<string, unknown> {
  const credentials = asRecord(provider.credentials);
  const networks = asRecord(placementDefaults?.networks);
  const providerConfig: Record<string, unknown> = {
    datacenter: requiredString(placementDefaults, "datacenter", "providers.primary.placement_defaults.datacenter"),
    resource_pool: requiredString(
      placementDefaults,
      "resource_pool",
      "providers.primary.placement_defaults.resource_pool",
    ),
    compute_host: requiredString(placementDefaults, "compute_host", "providers.primary.placement_defaults.compute_host"),
    datastore: requiredString(placementDefaults, "datastore", "providers.primary.placement_defaults.datastore"),
    default_networks: networks,
  };

  copyIfString(credentials, providerConfig, "server");
  copyIfString(credentials, providerConfig, "server_env");
  copyIfString(credentials, providerConfig, "user");
  copyIfString(credentials, providerConfig, "user_env");
  copyIfString(credentials, providerConfig, "password");
  copyIfString(credentials, providerConfig, "password_env");
  copyIfString(credentials, providerConfig, "datacenter_env");
  if (typeof credentials?.insecure === "boolean") {
    providerConfig.insecure = credentials.insecure;
  }

  return providerConfig;
}

function normalizeInstallSourceTfvars(source: Record<string, unknown>): Record<string, unknown> {
  const type = stringOrUndefined(source.type);
  const normalized = { ...source };

  if (type === "datastore_iso") {
    normalized.path = defaultString(source.path, source.url);
    delete normalized.url;
  }

  return normalized;
}

function normalizeRouter(
  router: Record<string, unknown>,
  defaultNetworks: Record<string, unknown>,
): Record<string, unknown> {
  const normalized = normalizeProviderPlacement(router);
  const networks = asRecord(normalized.networks) ?? {};
  const wan = asRecord(networks.wan) ?? {};
  const lan = asRecord(networks.lan) ?? {};

  normalized.networks = {
    ...networks,
    wan: {
      network_name: defaultString(wan.network_name, defaultNetworks.wan, "VM Network"),
      ip: wan.ip ?? null,
      subnet_mask: defaultString(wan.subnet_mask, undefined, "255.255.255.0"),
      gateway: defaultString(wan.gateway, undefined, "192.168.1.1"),
      nameservers: defaultStringArray(wan.nameservers, ["192.168.1.1", "8.8.8.8"]),
    },
    lan: {
      network_name: defaultString(lan.network_name, defaultNetworks.lan, "Nested-Trunk"),
      domain_name: defaultString(lan.domain_name, undefined, "nested.lab"),
      network: defaultString(lan.network, undefined, "10.0.0.0"),
      vlan_starts_with: defaultNumber(lan.vlan_starts_with, 1001),
      vlan_network_count: defaultNumber(lan.vlan_network_count, 20),
      mtu: defaultNumber(lan.mtu, 9000),
    },
  };

  normalized.execution = {
    http_root: "/var/www/html",
    tftp_root: "/srv/tftp",
    ...(asRecord(normalized.execution) ?? {}),
  };

  return normalized;
}

function normalizeEsxiTfvarsGroup(group: Record<string, unknown>): Record<string, unknown> {
  const normalized = normalizeProviderPlacement(group);
  const shape = asRecord(normalized.shape) ?? {};
  normalized.gateway = defaultString(normalized.gateway, "10.0.0.1");
  normalized.nameservers = defaultStringArray(normalized.nameservers, ["10.0.0.1"]);
  normalized.ntp_servers = defaultStringArray(normalized.ntp_servers, ["10.0.0.1"]);
  normalized.subnet_mask = defaultString(normalized.subnet_mask, "255.255.255.0");
  normalized.shape = {
    ...shape,
    num_cpus: defaultNumber(shape.num_cpus, normalized.num_cpus, 16),
    mem_gb: defaultNumber(shape.mem_gb, normalized.mem_gb, 32),
    nic_count: defaultNumber(shape.nic_count, normalized.nic_count, 8),
    tpm_enabled: typeof shape.tpm_enabled === "boolean" ? shape.tpm_enabled : false,
    nvme_enabled: typeof shape.nvme_enabled === "boolean" ? shape.nvme_enabled : false,
    disks: Array.isArray(shape.disks)
      ? shape.disks
      : [
        {
          label: "disk0",
          size_gb: 32,
          unit_number: 0,
        },
      ],
  };
  return normalized;
}

function normalizeStorageTfvars(storage: Record<string, unknown>): Record<string, unknown> {
  const normalized = normalizeProviderPlacement(storage);
  normalized.gateway = defaultString(normalized.gateway, "10.0.0.1");
  normalized.nameservers = defaultStringArray(normalized.nameservers, ["10.0.0.1"]);
  normalized.domain_name = defaultString(normalized.domain_name, "nested.lab");
  normalized.subnet_mask = defaultString(normalized.subnet_mask, "255.255.255.0");
  normalized.storage1_ip = defaultString(normalized.storage1_ip, "10.0.4.10");
  normalized.storage2_ip = defaultString(normalized.storage2_ip, "10.0.5.10");
  normalized.storage1_vlan = defaultNumber(normalized.storage1_vlan, 1004);
  normalized.storage2_vlan = defaultNumber(normalized.storage2_vlan, 1005);
  normalized.mtu = defaultNumber(normalized.mtu, 9000);
  normalized.storage_subnet_mask = defaultString(normalized.storage_subnet_mask, "255.255.255.0");
  normalized.disk_size_gb = defaultNumber(normalized.disk_size_gb, 200);
  normalized.num_cpus = defaultNumber(normalized.num_cpus, 4);
  normalized.mem_gb = defaultNumber(normalized.mem_gb, 4);
  normalized.luns = Array.isArray(normalized.luns)
    ? normalized.luns
    : [
      {
        name: "lun01",
        size_gb: 100,
      },
    ];
  normalized.zfs_compression = defaultString(normalized.zfs_compression, "off");
  normalized.zfs_nfs_dedup = defaultString(normalized.zfs_nfs_dedup, "off");
  return normalized;
}

function normalizeProviderPlacement(value: Record<string, unknown>): Record<string, unknown> {
  const normalized: Record<string, unknown> = { ...value };
  const placement = asRecord(value.placement) ?? {};
  normalized.placement = {
    ...placement,
    kind: placement.kind ?? "provider_vsphere",
  };
  delete (normalized.placement as Record<string, unknown>).provider;
  return normalized;
}

function normalizeRouters(
  routers: Record<string, unknown>,
  defaultOwner: string,
): Record<string, SeedRouter> {
  return mapNamedObjects(routers, (router, name) => {
    const normalized: SeedRouter = {
      ...router,
      lifecycle: mergeObject(router.lifecycle, {
        owner: defaultOwner,
        provider: providerFromPlacement(router.placement),
      }),
      capabilities: mergeCapabilities(router.capabilities, {
        guest_exec: "ssh",
        file_transfer: "scp",
      }),
      provider_ref: mergeObject(router.provider_ref, {
        provider: providerFromPlacement(router.placement),
        vm_name: stringOrUndefined(router.name),
      }),
    };

    if (!normalized.provider_ref?.vm_name) {
      normalized.provider_ref = { ...normalized.provider_ref, vm_name: name };
    }

    return normalized;
  }) as Record<string, SeedRouter>;
}

function normalizeEsxiGroups(
  groups: Record<string, unknown>,
  defaultOwner: string,
): Record<string, SeedEsxiGroup> {
  return mapNamedObjects(groups, (group, groupName) => {
    const capabilities = capabilitiesForEsxiGroup(group);
    const normalizedHosts = (Array.isArray(group.hosts) ? group.hosts : []).map((host) => {
      const hostObject = asRecord(host) ?? {};
      const observed = mergeObject(hostObject.observed, {
        mac_addresses: asStringArray(hostObject.mac_addresses),
        primary_mac_address: stringOrUndefined(hostObject.primary_mac_address),
      });
      return {
        ...hostObject,
        lifecycle: mergeObject(hostObject.lifecycle, {
          owner: defaultOwner,
          provider: providerFromPlacement(group.placement),
        }),
        provider_ref: mergeObject(hostObject.provider_ref, {
          provider: providerFromPlacement(group.placement),
          vm_name: stringOrUndefined(hostObject.name),
        }),
        observed,
      };
    });

    return {
      ...group,
      lifecycle: mergeObject(group.lifecycle, {
        owner: defaultOwner,
        provider: providerFromPlacement(group.placement),
      }),
      capabilities: mergeCapabilities(group.capabilities, capabilities),
      provider_ref: mergeObject(group.provider_ref, {
        provider: providerFromPlacement(group.placement),
        datacenter: stringOrUndefined(asRecord(group.placement)?.datacenter),
        resource_pool: stringOrUndefined(asRecord(group.placement)?.resource_pool),
      }),
      hosts: normalizedHosts,
    };
  }) as Record<string, SeedEsxiGroup>;
}

function normalizeStorages(
  storages: Record<string, unknown>,
  defaultOwner: string,
): Record<string, unknown> {
  return mapNamedObjects(storages, (storage, name) => ({
    ...storage,
    lifecycle: mergeObject(storage.lifecycle, {
      owner: defaultOwner,
      provider: providerFromPlacement(storage.placement),
    }),
    capabilities: mergeCapabilities(storage.capabilities, {
      guest_exec: "ssh",
      file_transfer: "scp",
    }),
    provider_ref: mergeObject(storage.provider_ref, {
      provider: providerFromPlacement(storage.placement),
      vm_name: stringOrUndefined(storage.name) ?? name,
    }),
  }));
}

function normalizeVcenters(
  vcenters: Record<string, unknown>,
  defaultOwner: string,
): Record<string, unknown> {
  return mapNamedObjects(vcenters, (vcenter, name) => ({
    ...vcenter,
    lifecycle: mergeObject(vcenter.lifecycle, {
      owner: defaultOwner,
      provider: providerFromPlacement(vcenter.placement),
    }),
    capabilities: mergeCapabilities(vcenter.capabilities, {
      guest_exec: "ssh",
      file_transfer: "scp",
    }),
    provider_ref: mergeObject(vcenter.provider_ref, {
      provider: providerFromPlacement(vcenter.placement),
      vm_name: stringOrUndefined(vcenter.name) ?? name,
    }),
  }));
}

function capabilitiesForEsxiGroup(group: Record<string, unknown>): Capabilities {
  const install = asRecord(group.install);
  const source = asRecord(install?.source);
  const sourceType = stringOrUndefined(source?.type);
  const method = stringOrUndefined(install?.method);

  return {
    power_control: "vsphere_api",
    boot_control: "vsphere_api",
    console_input: "vmware_sendkey",
    guest_exec: "vmware_tools",
    file_transfer: "guest_operations",
    guest_verification: "vmware_tools",
    esxi_install: sourceType === "datastore_iso" || method === "ansible_vsphere_iso_boot"
      ? ["pxe", "datastore_iso"]
      : ["pxe"],
    vcenter_deploy_target: ["vc", "esxi"],
  };
}

function capabilitiesForProviderEsxiGroup(providerKind: string, group: Record<string, unknown>): Capabilities {
  if (providerKind === "vsphere") {
    return capabilitiesForEsxiGroup(group);
  }
  if (providerKind === "vcd") {
    return providerAdapters.vcd.defaultEsxiCapabilities;
  }
  return providerAdapters.static.defaultEsxiCapabilities;
}

function checkVsphereIsoBoot(groupName: string, capabilities: Capabilities, errors: string[]): void {
  if (!capabilityEquals(capabilities, "boot_control", "vsphere_api")) {
    errors.push(
      `esxi_groups.${groupName}: ansible_vsphere_iso_boot requires capabilities.boot_control="vsphere_api"`,
    );
  }
  if (!capabilityEquals(capabilities, "console_input", "vmware_sendkey")) {
    errors.push(
      `esxi_groups.${groupName}: ansible_vsphere_iso_boot requires capabilities.console_input="vmware_sendkey"`,
    );
  }
}

function providerKindForObject(deployment: Deployment, value: Record<string, unknown>): string {
  const placement = asRecord(value.placement);
  const providerName = stringOrUndefined(placement?.provider) ?? "primary";
  const provider = asRecord(deployment.providers[providerName]);
  return stringOrUndefined(provider?.kind) ?? "static";
}

function installSourceRef(install: Record<string, unknown>): string | undefined {
  const source = asRecord(install.source);
  return stringOrUndefined(source?.install_source) ?? stringOrUndefined(install.install_source);
}

function incrementIpv4(address: string, offset: number): string {
  const parts = address.split(".").map((part) => Number(part));
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) {
    throw new Error(`invalid IPv4 address: ${address}`);
  }
  const value = parts.reduce((acc, part) => (acc * 256) + part, 0) + offset;
  if (value < 0 || value > 0xffffffff) {
    throw new Error(`IPv4 address overflow from ${address} + ${offset}`);
  }
  return [
    (value >>> 24) & 255,
    (value >>> 16) & 255,
    (value >>> 8) & 255,
    value & 255,
  ].join(".");
}

function cloneProviderAdapterSummary(adapter: ProviderAdapterSummary): ProviderAdapterSummary {
  return {
    ...adapter,
    defaultEsxiCapabilities: {
      ...adapter.defaultEsxiCapabilities,
      esxi_install: Array.isArray(adapter.defaultEsxiCapabilities.esxi_install)
        ? [...adapter.defaultEsxiCapabilities.esxi_install]
        : adapter.defaultEsxiCapabilities.esxi_install,
      vcenter_deploy_target: Array.isArray(adapter.defaultEsxiCapabilities.vcenter_deploy_target)
        ? [...adapter.defaultEsxiCapabilities.vcenter_deploy_target]
        : adapter.defaultEsxiCapabilities.vcenter_deploy_target,
    },
    notes: [...adapter.notes],
  };
}

function mapNamedObjects<T>(
  values: Record<string, unknown>,
  mapper: (value: Record<string, unknown>, name: string) => T,
): Record<string, T> {
  return Object.fromEntries(
    Object.entries(values).map(([name, value]) => [name, mapper(asRecord(value) ?? {}, name)]),
  );
}

function asNamedRecord(value: unknown): Record<string, unknown> {
  return asRecord(value) ?? {};
}

function requiredString(
  values: Record<string, unknown> | undefined,
  key: string,
  path: string,
): string {
  const value = values?.[key];
  if (!hasString(value)) {
    throw new Error(`${path} is required for vSphere tfvars generation`);
  }
  return value;
}

function copyIfString(
  source: Record<string, unknown> | undefined,
  target: Record<string, unknown>,
  key: string,
): void {
  const value = source?.[key];
  if (hasString(value)) {
    target[key] = value;
  }
}

function defaultString(...values: unknown[]): string {
  for (const value of values) {
    if (hasString(value)) {
      return value;
    }
  }
  return "";
}

function defaultStringArray(value: unknown, fallback: string[]): string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string") ? value : fallback;
}

function defaultNumber(...values: unknown[]): number {
  const fallback = values[values.length - 1];
  for (const value of values) {
    const number =
      typeof value === "number"
        ? value
        : typeof value === "string" && value.trim() !== ""
          ? Number(value)
          : NaN;
    if (Number.isFinite(number)) {
      return number;
    }
  }
  return typeof fallback === "number" ? fallback : 0;
}

function mergeObject(
  value: unknown,
  defaults: Record<string, unknown>,
): Record<string, unknown> {
  return {
    ...defaults,
    ...(asRecord(value) ?? {}),
  };
}

function mergeDefinedObjects(...values: Record<string, unknown>[]): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const value of values) {
    for (const [key, item] of Object.entries(value)) {
      if (item !== undefined && item !== null && !(typeof item === "string" && item.length === 0)) {
        result[key] = item;
      }
    }
  }
  return result;
}

function mergeCapabilities(value: unknown, defaults: Capabilities): Capabilities {
  const existing = asRecord(value) ?? {};
  const capabilities: Capabilities = { ...defaults };
  for (const [key, capabilityValue] of Object.entries(existing)) {
    if (
      typeof capabilityValue === "string"
      || (
        Array.isArray(capabilityValue)
        && capabilityValue.every((item) => typeof item === "string")
      )
    ) {
      capabilities[key] = capabilityValue;
    }
  }
  return capabilities;
}

function providerFromPlacement(placement: unknown): string {
  const placementObject = asRecord(placement);
  const kind = stringOrUndefined(placementObject?.kind);
  if (kind === "nested_vsphere" || kind === "provider_vsphere") {
    return "vsphere";
  }
  return stringOrUndefined(placementObject?.provider) ?? "vsphere";
}

function stringOrUndefined(value: unknown): string | undefined {
  return hasString(value) ? value : undefined;
}

function asStringArray(value: unknown): string[] | undefined {
  return Array.isArray(value) && value.every((item) => typeof item === "string") ? value : undefined;
}

function hasString(value: unknown): value is string {
  return typeof value === "string" && value.length > 0;
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return isRecord(value) ? value : undefined;
}

function hasCapability(capabilities: Capabilities, key: string): boolean {
  const value = capabilities[key];
  if (Array.isArray(value)) {
    return value.length > 0;
  }
  return typeof value === "string" && value.length > 0 && value !== "none";
}

function capabilityEquals(capabilities: Capabilities, key: string, expected: string): boolean {
  const value = capabilities[key];
  return Array.isArray(value) ? value.includes(expected) : value === expected;
}

function hasHostMac(host: SeedEsxiHost): boolean {
  return (
    hasString(host.primary_mac_address)
    || hasString(host.observed?.primary_mac_address)
    || (Array.isArray(host.mac_addresses) && host.mac_addresses.length > 0)
    || (Array.isArray(host.observed?.mac_addresses) && host.observed.mac_addresses.length > 0)
  );
}
