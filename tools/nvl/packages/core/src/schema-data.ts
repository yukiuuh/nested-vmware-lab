import type { AnySchema } from "ajv";

const namedMap = {
  type: "object",
  additionalProperties: {
    type: "object",
    additionalProperties: true,
  },
} as const;

const capabilities = {
  type: "object",
  additionalProperties: {
    anyOf: [
      { type: "string" },
      {
        type: "array",
        items: { type: "string" },
      },
    ],
  },
} as const;

const lifecycle = {
  type: "object",
  additionalProperties: true,
  properties: {
    owner: { type: "string" },
    provider: { type: "string" },
  },
} as const;

const providerRef = {
  type: "object",
  additionalProperties: true,
  properties: {
    provider: { type: "string" },
  },
} as const;

const observed = {
  type: "object",
  additionalProperties: true,
  properties: {
    primary_mac_address: { type: "string" },
    mac_addresses: {
      type: "array",
      items: { type: "string" },
    },
    provider_vm_id: { type: "string" },
  },
} as const;

const ansibleConnection = {
  type: "object",
  additionalProperties: true,
  required: ["host", "user"],
  properties: {
    host: { type: "string", minLength: 1 },
    user: { type: "string", minLength: 1 },
    password: { type: "string" },
    password_env: { type: "string" },
    private_key_file: { type: "string" },
    private_key_file_env: { type: "string" },
    ssh_common_args: { type: "string" },
    port: { type: "integer", minimum: 1, maximum: 65535 },
  },
} as const;

const discoverableAnsibleConnection = {
  type: "object",
  additionalProperties: true,
  required: ["user"],
  properties: {
    host: { type: "string", minLength: 1 },
    user: { type: "string", minLength: 1 },
    password: { type: "string" },
    password_env: { type: "string" },
    private_key_file: { type: "string" },
    private_key_file_env: { type: "string" },
    ssh_common_args: { type: "string" },
    port: { type: "integer", minimum: 1, maximum: 65535 },
  },
} as const;

export const deploymentSchema = {
  $schema: "http://json-schema.org/draft-07/schema#",
  $id: "https://nvl.io/schemas/deployment.v1alpha1.schema.json",
  type: "object",
  additionalProperties: false,
  required: [
    "apiVersion",
    "kind",
    "name",
    "providers",
    "install_sources",
    "routers",
    "storages",
    "esxi_groups",
    "vcenters",
  ],
  properties: {
    apiVersion: { const: "nvl.io/v1alpha1" },
    kind: { const: "Deployment" },
    name: {
      type: "string",
      minLength: 1,
      pattern: "^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$",
    },
    providers: {
      type: "object",
      required: ["primary"],
      additionalProperties: {
        type: "object",
        required: ["kind"],
        additionalProperties: true,
        properties: {
          kind: {
            type: "string",
            enum: ["vsphere", "static", "vcd"],
          },
          credentials: {
            type: "object",
            additionalProperties: true,
          },
          placement_defaults: {
            type: "object",
            additionalProperties: true,
          },
        },
      },
    },
    install_sources: namedMap,
    routers: namedMap,
    storages: namedMap,
    esxi_groups: namedMap,
    vcenters: namedMap,
    credentials: {
      type: "object",
      additionalProperties: true,
    },
    ssh_authorized_keys: {
      type: "array",
      items: { type: "string" },
    },
    metadata: {
      type: "object",
      additionalProperties: true,
    },
  },
} satisfies AnySchema;

export const ansibleSeedSchema = {
  $schema: "http://json-schema.org/draft-07/schema#",
  $id: "https://nvl.io/schemas/ansible-seed.v1alpha1.schema.json",
  type: "object",
  additionalProperties: true,
  required: [
    "apiVersion",
    "kind",
    "credentials",
    "routers",
    "esxi_groups",
    "storages",
    "vcenters",
  ],
  properties: {
    apiVersion: { const: "nvl.io/v1alpha1" },
    kind: { const: "AnsibleSeed" },
    credentials: {
      type: "object",
      additionalProperties: true,
    },
    routers: {
      type: "object",
      additionalProperties: {
        type: "object",
        additionalProperties: true,
        required: ["ansible"],
        properties: {
          ansible: discoverableAnsibleConnection,
          capabilities,
          lifecycle,
          provider_ref: providerRef,
          runtime: {
            type: "object",
            additionalProperties: true,
          },
          services: {
            type: "object",
            additionalProperties: true,
          },
        },
      },
    },
    esxi_groups: {
      type: "object",
      additionalProperties: {
        type: "object",
        additionalProperties: true,
        required: ["router", "install", "hosts"],
        properties: {
          router: { type: "string", minLength: 1 },
          install: {
            type: "object",
            additionalProperties: true,
            required: ["method"],
            properties: {
              method: {
                type: "string",
                enum: ["ansible_router_pxe", "ansible_vsphere_iso_boot"],
              },
            },
          },
          capabilities,
          lifecycle,
          provider_ref: providerRef,
          hosts: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: true,
              required: ["hostname", "fqdn", "ip", "ansible"],
              properties: {
                hostname: { type: "string", minLength: 1 },
                fqdn: { type: "string", minLength: 1 },
                ip: { type: "string", minLength: 1 },
                ansible: ansibleConnection,
                capabilities,
                lifecycle,
                provider_ref: providerRef,
                observed,
                primary_mac_address: { type: "string" },
                mac_addresses: {
                  type: "array",
                  items: { type: "string" },
                },
              },
            },
          },
        },
      },
    },
    storages: {
      type: "object",
      additionalProperties: {
        type: "object",
        additionalProperties: true,
        properties: {
          ansible: ansibleConnection,
          capabilities,
          lifecycle,
          provider_ref: providerRef,
          observed,
        },
      },
    },
    vcenters: {
      type: "object",
      additionalProperties: {
        type: "object",
        additionalProperties: true,
        required: ["fqdn", "ansible"],
        properties: {
          fqdn: { type: "string", minLength: 1 },
          ansible: ansibleConnection,
          capabilities,
          lifecycle,
          provider_ref: providerRef,
          observed,
        },
      },
    },
    services: {
      type: "object",
      additionalProperties: true,
    },
  },
} satisfies AnySchema;
