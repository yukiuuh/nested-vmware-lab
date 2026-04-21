import { Component, computed, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ClarityModule } from '@clr/angular';
import {
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
type PreviewMode = 'document' | 'tfvars' | 'seed' | 'capabilities' | 'json';
type CopyTarget = 'document' | 'preview';

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
  protected readonly previewMode = signal<PreviewMode>('tfvars');
  protected readonly copiedTarget = signal<CopyTarget | ''>('');

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
      return { valid: false, kind: '', messages: [parsed.error] };
    }
    return validateEditorDocument(parsed.value, this.hostnameInventory().issues);
  });
  protected readonly graph = computed(() => buildGraph(this.parsed().value));
  protected readonly isDeploymentDocument = computed(
    () => documentKind(this.parsed().value) === 'Deployment',
  );

  protected readonly previewOptions = computed<PreviewOption[]>(() => {
    const kind = documentKind(this.parsed().value);
    if (kind === 'Deployment') {
      return [
        { mode: 'document', label: 'Deployment JSON' },
        { mode: 'tfvars', label: 'Terraform tfvars' },
        {
          mode: 'seed',
          label: deploymentUsesVsphere(this.parsed().value)
            ? 'Terraform AnsibleSeed'
            : 'Static AnsibleSeed',
        },
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

  protected loadSample(sample: SampleName): void {
    this.activeDocument.set(sample);
    this.documentText.set(formatJson(sample === 'deployment' ? SAMPLE_DEPLOYMENT : SAMPLE_SEED));
  }

  protected applyGeneratedDocument(document: unknown): void {
    this.activeDocument.set('deployment');
    this.documentText.set(formatJson(document));
    this.activePanel.set('document');
  }

  protected updateDocumentFromForm(document: unknown): void {
    this.activeDocument.set('deployment');
    this.documentText.set(formatJson(document));
  }

  protected formatDocument(): void {
    const parsed = this.parsed();
    if (parsed.error || parsed.value === undefined) {
      return;
    }
    this.documentText.set(formatJson(parsed.value));
  }

  protected loadFile(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) {
      return;
    }

    void file.text().then((text) => {
      this.documentText.set(text);
      input.value = '';
    });
  }

  protected downloadDocument(): void {
    const blob = new Blob([this.documentText()], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    const kind = documentKind(this.parsed().value)?.toLowerCase() ?? 'document';
    link.href = url;
    link.download = `nvl-${kind}.json`;
    link.click();
    URL.revokeObjectURL(url);
  }

  protected copyDocument(): void {
    this.copyText(this.documentText(), 'document');
  }

  protected copyPreview(): void {
    this.copyText(this.preview(), 'preview');
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
}

function terraformSeedProducerPreview(value: unknown): Record<string, unknown> {
  const document = asRecord(value) ?? {};
  const name = typeof document['name'] === 'string' ? document['name'] : 'deployment';
  return {
    kind: 'TerraformAnsibleSeedProducer',
    deployment: name,
    source_of_truth: 'terraform output -json ansible_inventory_seed',
    reason: [
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

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}
