import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import {
  checkSeedCapabilities,
  generateStaticAnsibleSeed,
  generateVsphereTfvars,
  listProviderAdapters,
  normalizeTerraformAnsibleSeed,
  validateDocument,
  type CapabilityCheckResult,
  type ValidationResult,
} from "@nvl/core";

interface CommandResult {
  exitCode: number;
}

function usage(): string {
  return `Usage:
  nvl validate <file>
  nvl check-capabilities <seed-file>
  nvl providers
  nvl generate vsphere-tfvars <deployment-file> [--output <file>] [--stdout]
  nvl seed from-terraform <deployment-file> --deployment-dir <dir> [--output <file>] [--stdout]
  nvl seed from-static <deployment-file> [--observed <file>] [--output <file>] [--stdout] [--strict-capabilities]

Commands:
  validate             Validate an NVL Deployment or AnsibleSeed document
  check-capabilities  Validate AnsibleSeed capability/method compatibility
  providers           List provider adapter capabilities
  generate            Generate provider-specific artifacts from a Deployment
  seed                Produce a realized AnsibleSeed from a producer`;
}

function readJsonFile(path: string): unknown {
  try {
    return JSON.parse(readFileSync(path, "utf8")) as unknown;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`failed to read JSON file ${path}: ${message}`);
  }
}

function printValidationErrors(path: string, result: ValidationResult): void {
  for (const message of result.messages) {
    console.error(`${path}: ${message}`);
  }
}

function validate(path: string): CommandResult {
  const document = readJsonFile(path);
  const result = validateDocument(document);

  if (!result.valid) {
    printValidationErrors(path, result);
    return { exitCode: 1 };
  }

  console.log(`${path}: valid ${result.apiVersion}/${result.kind}`);
  return { exitCode: 0 };
}

function printCapabilityErrors(path: string, result: CapabilityCheckResult): void {
  for (const error of result.errors) {
    console.error(`${path}: ${error}`);
  }
}

function checkCapabilities(path: string): CommandResult {
  const document = readJsonFile(path);
  const result = checkSeedCapabilities(document);

  if (!result.valid) {
    printCapabilityErrors(path, result);
    return { exitCode: 1 };
  }

  console.log(`${path}: capabilities valid`);
  return { exitCode: 0 };
}

function providersCommand(): CommandResult {
  console.log(JSON.stringify(listProviderAdapters(), null, 2));
  return { exitCode: 0 };
}

function generateVsphereTfvarsCommand(deploymentPath: string, args: string[]): CommandResult {
  const document = readJsonFile(deploymentPath);
  const tfvars = generateVsphereTfvars(document);
  const outputPath = optionValue(args, "--output")
    ?? join("generated", tfvars.name_prefix, "deployment.tfvars.json");

  writeOrPrintJson(tfvars, outputPath, args.includes("--stdout"));
  return { exitCode: 0 };
}

function seedFromTerraformCommand(deploymentPath: string, args: string[]): CommandResult {
  const deployment = readJsonFile(deploymentPath);
  const deploymentDir = optionValue(args, "--deployment-dir");
  if (!deploymentDir) {
    throw new Error(`seed from-terraform requires --deployment-dir <dir>\n\n${usage()}`);
  }

  const terraformOutput = execFileSync(
    "terraform",
    [`-chdir=${deploymentDir}`, "output", "-json", "ansible_inventory_seed"],
    { encoding: "utf8" },
  );
  const terraformSeed = JSON.parse(terraformOutput) as unknown;
  const seed = normalizeTerraformAnsibleSeed(deployment, terraformSeed);
  const outputPath = optionValue(args, "--output")
    ?? join("generated", seedName(deployment), "ansible-seed.json");

  writeOrPrintJson(seed, outputPath, args.includes("--stdout"));
  return { exitCode: 0 };
}

function seedFromStaticCommand(deploymentPath: string, args: string[]): CommandResult {
  const deployment = readJsonFile(deploymentPath);
  const observedPath = optionValue(args, "--observed");
  const observed = observedPath ? readJsonFile(observedPath) : {};
  const seed = generateStaticAnsibleSeed(deployment, observed, {
    validateCapabilities: args.includes("--strict-capabilities"),
  });
  const outputPath = optionValue(args, "--output")
    ?? join("generated", seedName(deployment), "ansible-seed.json");

  writeOrPrintJson(seed, outputPath, args.includes("--stdout"));
  return { exitCode: 0 };
}

function writeOrPrintJson(value: unknown, outputPath: string, stdout: boolean): void {
  const json = `${JSON.stringify(value, null, 2)}\n`;
  if (stdout) {
    process.stdout.write(json);
    return;
  }

  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, json, "utf8");
  console.log(`wrote ${outputPath}`);
}

function optionValue(args: string[], name: string): string | undefined {
  const index = args.indexOf(name);
  if (index === -1) {
    return undefined;
  }
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function seedName(document: unknown): string {
  if (typeof document === "object" && document !== null && "name" in document) {
    const name = (document as { name?: unknown }).name;
    if (typeof name === "string" && name.length > 0) {
      return name;
    }
  }
  return "deployment";
}

function requirePath(command: string, path: string | undefined): string {
  if (!path) {
    throw new Error(`${command} requires a file path\n\n${usage()}`);
  }
  return path;
}

export function main(argv: string[] = process.argv.slice(2)): CommandResult {
  const [command, path, file, ...rest] = argv;

  switch (command) {
    case "validate":
      return validate(requirePath(command, path));
    case "check-capabilities":
      return checkCapabilities(requirePath(command, path));
    case "providers":
      return providersCommand();
    case "generate":
      if (path !== "vsphere-tfvars") {
        throw new Error(`unknown generate target: ${path ?? "<missing>"}\n\n${usage()}`);
      }
      return generateVsphereTfvarsCommand(requirePath("generate vsphere-tfvars", file), rest);
    case "seed":
      if (path === "from-terraform") {
        return seedFromTerraformCommand(requirePath("seed from-terraform", file), rest);
      }
      if (path === "from-static") {
        return seedFromStaticCommand(requirePath("seed from-static", file), rest);
      }
      {
        throw new Error(`unknown seed producer: ${path ?? "<missing>"}\n\n${usage()}`);
      }
    case "--help":
    case "-h":
    case undefined:
      console.log(usage());
      return { exitCode: command === undefined ? 1 : 0 };
    default:
      throw new Error(`unknown command: ${command}\n\n${usage()}`);
  }
}

try {
  const result = main();
  process.exitCode = result.exitCode;
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
