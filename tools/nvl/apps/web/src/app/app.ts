import { Component, computed, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ClarityModule } from '@clr/angular';
import {
  angleIcon,
  checkCircleIcon,
  ClarityIcons,
  clusterIcon,
  copyIcon,
  dashboardIcon,
  deployIcon,
  downloadIcon,
  eyeIcon,
  fileIcon,
  hostIcon,
  networkGlobeIcon,
  treeViewIcon,
  uploadIcon,
  wandIcon,
} from '@cds/core/icon';
import '@cds/core/icon/register.js';
import {
  checkSeedCapabilities,
  documentKind,
  generateStaticAnsibleSeed,
  generateVsphereTfvars,
} from '@nvl/core';
import {
  buildGraph,
  buildHostnameInventory,
  buildPreviewTrace,
  type EditorValidationIssue,
  explicitCredentialWarnings,
  formatJson,
  SAMPLE_DEPLOYMENT,
  SAMPLE_SEED,
  validateEditorDocument,
} from './editor-utils';
import { deploymentEditorSchema } from './deployment-editor-schema';
import { copyTextToClipboard, selectAllCopyTarget } from './copy-utils';
import { HostnameTableComponent } from './hostname-table/hostname-table';
import { SchemaFormComponent } from './schema-form/schema-form';
import { SchemaWizardComponent } from './schema-wizard/schema-wizard';

ClarityIcons.addIcons(
  angleIcon,
  checkCircleIcon,
  clusterIcon,
  copyIcon,
  dashboardIcon,
  deployIcon,
  downloadIcon,
  eyeIcon,
  fileIcon,
  hostIcon,
  networkGlobeIcon,
  treeViewIcon,
  uploadIcon,
  wandIcon,
);

type SampleName = 'deployment' | 'seed';
type PanelName = 'document' | 'hostnames' | 'validation' | 'graph' | 'preview';
type PreviewMode = 'document' | 'tfvars' | 'seed' | 'trace' | 'capabilities' | 'json';
type CopyTarget = 'document' | 'preview' | 'preview-command';

interface PreviewOption {
  mode: PreviewMode;
  label: string;
}

@Component({
  selector: 'app-root',
  imports: [
    ClarityModule,
    FormsModule,
    HostnameTableComponent,
    SchemaFormComponent,
    SchemaWizardComponent,
  ],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {
  protected navCollapsed = false;
  protected readonly documentSchema = deploymentEditorSchema;
  protected readonly activePanel = signal<PanelName>('document');
  protected readonly activeDocument = signal<SampleName>('deployment');
  protected readonly documentText = signal(formatJson(SAMPLE_DEPLOYMENT));
  protected readonly cleanDocumentText = signal(this.documentText());
  protected readonly previewMode = signal<PreviewMode>('tfvars');
  protected readonly copiedTarget = signal<CopyTarget | ''>('');
  protected readonly fileLoadError = signal('');

  protected readonly parsed = computed(() => {
    try {
      return { value: JSON.parse(this.documentText()) as unknown, error: '' };
    } catch (error) {
      return { value: undefined, error: error instanceof Error ? error.message : String(error) };
    }
  });

  protected readonly hostnameInventory = computed(() =>
    buildHostnameInventory(this.parsed().value),
  );
  protected readonly validation = computed(() => {
    const parsed = this.parsed();
    if (parsed.error) {
      return {
        valid: false,
        kind: '',
        issues: [{ message: parsed.error, source: 'parse' as const }],
        messages: [parsed.error],
      };
    }
    return validateEditorDocument(parsed.value, this.hostnameInventory().issues);
  });
  protected readonly graph = computed(() => buildGraph(this.parsed().value));
  protected readonly isDeploymentDocument = computed(
    () => documentKind(this.parsed().value) === 'Deployment',
  );
  protected readonly dirty = computed(() => this.documentText() !== this.cleanDocumentText());
  protected readonly credentialWarnings = computed(() =>
    explicitCredentialWarnings(this.parsed().value),
  );
  protected readonly hasCredentialWarnings = computed(() => this.credentialWarnings().length > 0);

  protected readonly previewOptions = computed<PreviewOption[]>(() => {
    const kind = documentKind(this.parsed().value);
    if (kind === 'Deployment') {
      return [
        { mode: 'document', label: 'Deployment JSON' },
        { mode: 'tfvars', label: 'Terraform tfvars' },
        {
          mode: 'seed',
          label: deploymentUsesVsphere(this.parsed().value)
            ? 'Terraform Seed Producer'
            : 'Static AnsibleSeed',
        },
        { mode: 'trace', label: 'Source Trace' },
      ];
    }
    if (kind === 'AnsibleSeed') {
      return [
        { mode: 'json', label: 'AnsibleSeed JSON' },
        { mode: 'capabilities', label: 'Capability Check' },
      ];
    }
    return [{ mode: 'json', label: 'JSON' }];
  });

  protected readonly effectivePreviewMode = computed(() => {
    const mode = this.previewMode();
    const options = this.previewOptions();
    return options.some((option) => option.mode === mode) ? mode : options[0].mode;
  });

  protected readonly previewLabel = computed(() => {
    const mode = this.effectivePreviewMode();
    return this.previewOptions().find((option) => option.mode === mode)?.label ?? 'JSON';
  });

  protected readonly preview = computed(() => {
    const parsed = this.parsed();
    if (parsed.error) {
      return parsed.error;
    }

    try {
      const kind = documentKind(parsed.value);
      const mode = this.effectivePreviewMode();
      if (kind === 'Deployment') {
        if (mode === 'tfvars') {
          return formatJson(generateVsphereTfvars(parsed.value));
        }
        if (mode === 'seed') {
          if (deploymentUsesVsphere(parsed.value)) {
            return formatJson(terraformSeedProducerPreview(parsed.value));
          }
          return formatJson(
            generateStaticAnsibleSeed(parsed.value, {}, { validateCapabilities: false }),
          );
        }
        if (mode === 'trace') {
          return formatJson(buildPreviewTrace(parsed.value));
        }
        return formatJson(parsed.value);
      }
      if (kind === 'AnsibleSeed' && mode === 'capabilities') {
        return formatJson(checkSeedCapabilities(parsed.value));
      }
      return formatJson(parsed.value);
    } catch (error) {
      return error instanceof Error ? error.message : String(error);
    }
  });

  protected readonly previewDownloadName = computed(() => {
    const mode = this.effectivePreviewMode();
    const name = deploymentName(this.parsed().value);
    if (mode === 'tfvars') {
      return 'deployment.tfvars.json';
    }
    if (mode === 'seed') {
      if (deploymentUsesVsphere(this.parsed().value)) {
        return `${name}-terraform-seed-producer.json`;
      }
      return `${name}-ansible-seed.json`;
    }
    if (mode === 'capabilities') {
      return `${name}-capability-check.json`;
    }
    if (mode === 'trace') {
      return `${name}-source-trace.json`;
    }
    return `${name}-${mode}.json`;
  });

  protected readonly previewCommand = computed(() => {
    const value = this.parsed().value;
    if (documentKind(value) !== 'Deployment') {
      return '';
    }

    const name = deploymentName(value);
    const mode = this.effectivePreviewMode();
    if (mode === 'tfvars') {
      return 'nix develop -c tools/nvl/packages/cli/bin/nvl generate vsphere-tfvars deployment.json --output deployments/deployment_v2/tfvars/deployment.tfvars.json';
    }
    if (mode === 'seed') {
      if (deploymentUsesVsphere(value)) {
        return `nix develop -c tools/nvl/packages/cli/bin/nvl seed from-terraform deployment.json --deployment-dir deployments/deployment_v2 --output generated/${name}/ansible-seed.json`;
      }
      return `nix develop -c tools/nvl/packages/cli/bin/nvl seed from-static deployment.json --output generated/${name}/ansible-seed.json`;
    }
    return '';
  });

  protected updateDocumentText(value: string): void {
    this.documentText.set(value);
    this.fileLoadError.set('');
  }

  protected loadSample(sample: SampleName): void {
    if (!this.confirmReplaceDocument(`load the ${sample} sample`)) {
      return;
    }
    const text = formatJson(sample === 'deployment' ? SAMPLE_DEPLOYMENT : SAMPLE_SEED);
    this.activeDocument.set(sample);
    this.documentText.set(text);
    this.cleanDocumentText.set(text);
    this.fileLoadError.set('');
  }

  protected applyGeneratedDocument(document: unknown): void {
    if (!this.confirmReplaceDocument('apply the wizard output')) {
      return;
    }
    this.activeDocument.set('deployment');
    this.documentText.set(formatJson(document));
    this.previewMode.set('tfvars');
    this.activePanel.set('preview');
    this.fileLoadError.set('');
  }

  protected updateDocumentFromForm(document: unknown): void {
    this.activeDocument.set('deployment');
    this.documentText.set(formatJson(document));
    this.fileLoadError.set('');
  }

  protected formatDocument(): void {
    const parsed = this.parsed();
    if (parsed.error || parsed.value === undefined) {
      return;
    }
    this.updateDocumentText(formatJson(parsed.value));
  }

  protected loadFile(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) {
      return;
    }

    if (!this.confirmReplaceDocument('load a JSON file')) {
      input.value = '';
      return;
    }

    if (!isJsonFile(file)) {
      this.fileLoadError.set('Choose a .json file.');
      input.value = '';
      return;
    }

    void file
      .text()
      .then((text) => {
        try {
          const parsed = JSON.parse(text) as unknown;
          const formatted = formatJson(parsed);
          this.activeDocument.set(documentKind(parsed) === 'AnsibleSeed' ? 'seed' : 'deployment');
          this.documentText.set(formatted);
          this.cleanDocumentText.set(formatted);
          this.fileLoadError.set('');
        } catch (error) {
          this.fileLoadError.set(
            `Could not load JSON: ${error instanceof Error ? error.message : String(error)}`,
          );
        } finally {
          input.value = '';
        }
      })
      .catch((error) => {
        this.fileLoadError.set(
          `Could not read file: ${error instanceof Error ? error.message : String(error)}`,
        );
        input.value = '';
      });
  }

  protected downloadDocument(): void {
    const kind = documentKind(this.parsed().value)?.toLowerCase() ?? 'document';
    this.downloadText(this.documentText(), `nvl-${kind}.json`);
    this.cleanDocumentText.set(this.documentText());
  }

  protected copyDocument(): void {
    this.copyText(this.documentText(), 'document');
  }

  protected copyPreview(): void {
    this.copyText(this.preview(), 'preview');
  }

  protected downloadPreview(): void {
    this.downloadText(this.preview(), this.previewDownloadName());
  }

  protected copyPreviewCommand(): void {
    const command = this.previewCommand();
    if (command) {
      this.copyText(command, 'preview-command');
    }
  }

  protected validationIssueActionLabel(issue: EditorValidationIssue): string {
    return issue.path && this.isDeploymentDocument() ? 'Go to field' : 'Go to JSON';
  }

  protected goToValidationIssue(issue: EditorValidationIssue): void {
    if (issue.path && this.isDeploymentDocument()) {
      this.focusDocumentField(issue.path);
      return;
    }
    this.focusJsonDocument();
  }

  protected selectAllCopyTarget(event: KeyboardEvent): void {
    selectAllCopyTarget(event);
  }

  private copyText(text: string, target: CopyTarget): void {
    void copyTextToClipboard(text).then(() => {
      this.copiedTarget.set(target);
      window.setTimeout(() => {
        if (this.copiedTarget() === target) {
          this.copiedTarget.set('');
        }
      }, 1200);
    });
  }

  private confirmReplaceDocument(action: string): boolean {
    if (!this.dirty()) {
      return true;
    }
    return window.confirm(`Current JSON has unsaved changes. Continue and ${action}?`);
  }

  private downloadText(text: string, filename: string): void {
    const blob = new Blob([text], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
  }

  private focusDocumentField(path: string): void {
    this.activePanel.set('document');
    window.dispatchEvent(new CustomEvent('nvl-schema-form:reveal-path', { detail: { path } }));
    window.setTimeout(() => {
      const target = findSchemaPathElement(path);
      if (!target) {
        this.focusJsonDocument();
        return;
      }

      target.scrollIntoView({ block: 'center', behavior: 'smooth' });
      target.classList.add('schema-jump-highlight');
      window.setTimeout(() => target.classList.remove('schema-jump-highlight'), 1800);

      const focusTarget = target.matches('input, select, textarea, button')
        ? target
        : target.querySelector('input, select, textarea, button');
      if (focusTarget instanceof HTMLElement) {
        focusTarget.focus({ preventScroll: true });
      }
    }, 0);
  }

  private focusJsonDocument(): void {
    this.activePanel.set('document');
    window.setTimeout(() => {
      const target = document.getElementById('nvl-json-document');
      if (target instanceof HTMLTextAreaElement) {
        target.focus();
      }
    }, 0);
  }
}

function terraformSeedProducerPreview(value: unknown): Record<string, unknown> {
  const document = asRecord(value) ?? {};
  const name = typeof document['name'] === 'string' ? document['name'] : 'deployment';
  return {
    kind: 'TerraformAnsibleSeedProducer',
    deployment: name,
    produces_kind: 'AnsibleSeed',
    preview_artifact: 'producer_commands',
    source_of_truth: 'terraform output -json ansible_inventory_seed',
    reason: [
      'The Deployment document alone cannot realize a vSphere AnsibleSeed',
      'vSphere VM names include the Terraform deployment suffix',
      'Router provider-facing IP is assigned at runtime',
      'PXE MAC addresses are provider/runtime observations',
    ],
    commands: {
      generate_tfvars:
        'tools/nvl/packages/cli/bin/nvl generate vsphere-tfvars <deployment-file> --output deployments/deployment_v2/tfvars/deployment.tfvars.json',
      produce_seed:
        'tools/nvl/packages/cli/bin/nvl seed from-terraform <deployment-file> --deployment-dir deployments/deployment_v2 --output generated/' +
        name +
        '/ansible-seed.json',
      render_inventory:
        'deployments/deployment_v2/scripts/render_ansible_inventory.sh --deployment-dir deployments/deployment_v2 --pretty',
      prepare_extra_vars:
        'optional runtime override: set vsphere_override_new_depots in deployments/deployment_v2/tfvars/prepare.vars.yaml; for vCenter 9.0+ prefer vcenters.<name>.depots in the Deployment document',
      run_prepare:
        'deployments/deployment_v2/scripts/run_prepare.sh --deployment-dir deployments/deployment_v2',
    },
  };
}

function deploymentUsesVsphere(value: unknown): boolean {
  const document = asRecord(value);
  const providers = asRecord(document?.['providers']) ?? {};
  return Object.values(providers).some((provider) => asRecord(provider)?.['kind'] === 'vsphere');
}

function deploymentName(value: unknown): string {
  const document = asRecord(value);
  const name = document?.['name'];
  return typeof name === 'string' && name.trim() ? name.trim() : 'deployment';
}

function isJsonFile(file: File): boolean {
  return file.name.toLowerCase().endsWith('.json') || file.type === 'application/json';
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function findSchemaPathElement(path: string): HTMLElement | undefined {
  const candidates = pathCandidates(path);
  const elements = Array.from(document.querySelectorAll<HTMLElement>('[data-schema-path]'));
  for (const candidate of candidates) {
    const element = elements.find((item) => item.dataset['schemaPath'] === candidate);
    if (element) {
      return element;
    }
  }
  return undefined;
}

function pathCandidates(path: string): string[] {
  const normalized = normalizePath(path);
  const candidates: string[] = [];
  let current = normalized;
  while (current) {
    candidates.push(current);
    current = current.includes('.') ? current.slice(0, current.lastIndexOf('.')) : '';
  }
  return candidates;
}

function normalizePath(path: string): string {
  return path.replace(/\[(\d+)\]/g, '.$1').replace(/^\.+|\.+$/g, '');
}
