import { CommonModule } from '@angular/common';
import {
  Component,
  ElementRef,
  EventEmitter,
  HostListener,
  Input,
  Output,
  signal,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ClarityModule } from '@clr/angular';
import { cloneJson, formatJson } from '../editor-utils';

export interface JsonSchema {
  $schema?: string;
  $id?: string;
  title?: string;
  description?: string;
  default?: unknown;
  type?: string | string[];
  const?: unknown;
  enum?: unknown[];
  properties?: Record<string, JsonSchema>;
  required?: string[];
  items?: JsonSchema;
  additionalProperties?: JsonSchema | boolean;
  minLength?: number;
  minimum?: number;
  maximum?: number;
  pattern?: string;
}

export interface SchemaUiField {
  path: string;
  label?: string;
  widget?: SchemaWidget;
  description?: string;
  order?: number;
  wide?: boolean;
  entryPrefix?: string;
}

export interface SchemaFormUi {
  fields?: SchemaUiField[];
  order?: string[];
}

type SchemaWidget =
  | 'array-json'
  | 'array-object'
  | 'array-string'
  | 'checkbox'
  | 'freeform-map'
  | 'json'
  | 'map'
  | 'number'
  | 'object'
  | 'readonly'
  | 'select'
  | 'text';

interface SchemaField {
  path: string;
  key: string;
  label: string;
  schema: JsonSchema;
  widget: SchemaWidget;
  required: boolean;
  description: string;
  order: number;
  wide: boolean;
  entryPrefix: string;
}

interface MapEntry {
  key: string;
  path: string;
  value: unknown;
}

@Component({
  selector: 'nvl-schema-form',
  imports: [ClarityModule, CommonModule, FormsModule],
  templateUrl: './schema-form.html',
  styleUrl: './schema-form.scss',
})
export class SchemaFormComponent {
  @Input({ required: true }) schema!: JsonSchema;
  @Input({ required: true }) model!: unknown;
  @Input() ui: SchemaFormUi = {};
  @Output() modelChange = new EventEmitter<unknown>();

  protected readonly jsonErrors = signal<Record<string, string>>({});
  protected readonly newEntryNames = signal<Record<string, string>>({});
  protected readonly newFreeformKeys = signal<Record<string, string>>({});
  protected readonly collapsedSections = signal<Record<string, boolean>>({});

  public constructor(private readonly elementRef: ElementRef<HTMLElement>) {}

  @HostListener('window:nvl-schema-form:reveal-path', ['$event'])
  protected revealPath(event: Event): void {
    const path = (event as CustomEvent<{ path?: string }>).detail?.path;
    if (path) {
      this.expandPath(path);
    }
  }

  protected sectionNavigation(): SchemaField[] {
    return this.fieldsFor(this.schema, '').filter((field) =>
      ['array-json', 'array-object', 'freeform-map', 'map', 'object'].includes(field.widget),
    );
  }

  protected goToSection(path: string): void {
    this.expandPath(path);
    const target = this.findPathElement(path);
    if (!target) {
      return;
    }

    target.scrollIntoView({ block: 'start', behavior: 'smooth' });
    target.classList.add('schema-jump-highlight');
    window.setTimeout(() => target.classList.remove('schema-jump-highlight'), 1800);

    const focusTarget = target.querySelector('input, select, textarea, button');
    if (focusTarget instanceof HTMLElement) {
      focusTarget.focus({ preventScroll: true });
    }
  }

  protected isSectionCollapsed(path: string): boolean {
    return this.collapsedSections()[path] === true;
  }

  protected setSectionOpen(path: string, open: boolean): void {
    this.collapsedSections.update((current) => ({
      ...current,
      [path]: !open,
    }));
  }

  protected sectionIssueCount(field: SchemaField): number {
    let count = this.fieldErrors(field).length;
    if (field.widget === 'object') {
      count += this.countErrorsForNode(field.schema, field.path);
    }
    if (field.widget === 'map') {
      for (const entry of this.mapEntries(field)) {
        count += this.countErrorsForNode(this.mapValueSchema(field), entry.path);
      }
    }
    if (field.widget === 'array-object') {
      for (const entry of this.arrayEntries(field)) {
        count += this.countErrorsForNode(this.arrayItemSchema(field), entry.path);
      }
    }
    return count;
  }

  protected mapEntryIssueCount(field: SchemaField, path: string): number {
    return this.countErrorsForNode(this.mapValueSchema(field), path);
  }

  protected arrayEntryIssueCount(field: SchemaField, path: string): number {
    return this.countErrorsForNode(this.arrayItemSchema(field), path);
  }

  protected issueCountLabel(count: number): string {
    return `${count} ${count === 1 ? 'issue' : 'issues'}`;
  }

  protected fieldsFor(schema: JsonSchema, basePath: string): SchemaField[] {
    const properties = schema.properties ?? {};
    const uiFields = new Map((this.ui.fields ?? []).map((field) => [field.path, field]));
    const required = new Set(schema.required ?? []);
    const order = this.ui.order ?? Object.keys(properties);

    return Object.entries(properties)
      .map(([key, propertySchema]) => {
        const path = joinPath(basePath, key);
        const uiField = uiFields.get(path) ?? uiFields.get(key);
        return {
          path,
          key,
          label: uiField?.label ?? propertySchema.title ?? labelFromPath(key),
          schema: propertySchema,
          widget: uiField?.widget ?? widgetForSchema(propertySchema),
          required: required.has(key),
          description: uiField?.description ?? propertySchema.description ?? '',
          order: uiField?.order ?? order.indexOf(key),
          wide: uiField?.wide ?? isWideFieldPath(path, key),
          entryPrefix: uiField?.entryPrefix ?? entryPrefixForPath(path),
        };
      })
      .sort((a, b) => normalizedOrder(a.order) - normalizedOrder(b.order));
  }

  protected fieldValue(field: SchemaField): unknown {
    return valueAtPath(this.model, field.path);
  }

  protected textValue(field: SchemaField): string {
    const value = this.displayValue(field);
    return typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean'
      ? String(value)
      : '';
  }

  protected checkedValue(field: SchemaField): boolean {
    return this.displayValue(field) === true;
  }

  protected jsonValue(field: SchemaField): string {
    const value = this.displayValue(field);
    return formatJson(value ?? defaultValueForSchema(field.schema));
  }

  protected stringListValue(field: SchemaField): string {
    const value = this.displayValue(field);
    return Array.isArray(value) ? value.join('\n') : '';
  }

  protected mapEntries(field: SchemaField): MapEntry[] {
    const value = this.fieldValue(field);
    const record = isRecord(value) ? value : {};
    return Object.entries(record).map(([key, entryValue]) => ({
      key,
      path: joinPath(field.path, key),
      value: entryValue,
    }));
  }

  protected arrayEntries(field: SchemaField): MapEntry[] {
    const value = this.fieldValue(field);
    const items = Array.isArray(value) ? value : [];
    return items.map((entryValue, index) => ({
      key: String(index),
      path: joinPath(field.path, String(index)),
      value: entryValue,
    }));
  }

  protected arrayItemSchema(field: SchemaField): JsonSchema {
    return field.schema.items ?? {};
  }

  protected arrayEntryLabel(index: string): string {
    return `#${Number(index) + 1}`;
  }

  protected helperText(field: SchemaField, fallback = ''): string {
    return [field.description, fallback, this.defaultHelperText(field)]
      .filter((part) => part.length > 0)
      .join(' ');
  }

  protected hasHelperText(field: SchemaField, fallback = ''): boolean {
    return this.helperText(field, fallback).length > 0;
  }

  protected hasFieldErrors(field: SchemaField): boolean {
    return this.fieldErrors(field).length > 0;
  }

  protected fieldErrorText(field: SchemaField): string {
    return this.fieldErrors(field).join(' ');
  }

  protected fieldInputId(field: SchemaField): string {
    return `schema-field-${pathId(field.path)}`;
  }

  protected fieldHelperId(field: SchemaField): string {
    return `schema-field-${pathId(field.path)}-helper`;
  }

  protected fieldErrorId(field: SchemaField): string {
    return `schema-field-${pathId(field.path)}-error`;
  }

  protected fieldDescribedBy(field: SchemaField, fallback = ''): string {
    const ids: string[] = [];
    if (this.hasHelperText(field, fallback)) {
      ids.push(this.fieldHelperId(field));
    }
    if (this.hasFieldErrors(field)) {
      ids.push(this.fieldErrorId(field));
    }
    return ids.join(' ');
  }

  protected isWideField(field: SchemaField): boolean {
    return field.wide;
  }

  protected removeMapEntryLabel(field: SchemaField, key: string): string {
    return `Remove ${field.label} entry ${key}`;
  }

  protected removeArrayItemLabel(field: SchemaField, index: string): string {
    return `Remove ${field.label} ${this.arrayEntryLabel(index)}`;
  }

  protected addArrayItem(field: SchemaField): void {
    const value = this.fieldValue(field);
    const items = Array.isArray(value) ? [...value] : [];
    items.push(defaultValueForSchema(this.arrayItemSchema(field)));
    this.emitPathUpdate(field.path, items);
  }

  protected removeArrayItem(field: SchemaField, index: string): void {
    const value = this.fieldValue(field);
    if (!Array.isArray(value)) {
      return;
    }
    const items = [...value];
    items.splice(Number(index), 1);
    this.emitPathUpdate(field.path, items);
  }

  protected mapValueSchema(field: SchemaField): JsonSchema {
    return isSchema(field.schema.additionalProperties) ? field.schema.additionalProperties : {};
  }

  protected newEntryName(path: string): string {
    return (
      this.newEntryNames()[path] ??
      nextEntryName(this.fieldValue({ path } as SchemaField), entryPrefixForPath(path))
    );
  }

  protected updateNewEntryName(path: string, value: unknown): void {
    this.newEntryNames.update((current) => ({ ...current, [path]: sanitizeKey(value) }));
  }

  protected addMapEntry(field: SchemaField): void {
    const key = this.newEntryName(field.path);
    if (!key) {
      return;
    }
    const value = this.fieldValue(field);
    const record = isRecord(value) ? { ...value } : {};
    if (key in record) {
      return;
    }
    record[key] = defaultValueForSchema(this.mapValueSchema(field));
    this.emitPathUpdate(field.path, record);
    this.newEntryNames.update((current) => ({
      ...current,
      [field.path]: nextEntryName(record, field.entryPrefix),
    }));
  }

  protected removeMapEntry(field: SchemaField, key: string): void {
    const value = this.fieldValue(field);
    if (!isRecord(value)) {
      return;
    }
    const record = { ...value };
    delete record[key];
    this.emitPathUpdate(field.path, record);
  }

  protected freeformEntries(field: SchemaField): MapEntry[] {
    const value = this.fieldValue(field);
    const record = isRecord(value) ? value : {};
    return Object.entries(record).map(([key, entryValue]) => ({
      key,
      path: joinPath(field.path, key),
      value: entryValue,
    }));
  }

  protected freeformTextValue(entry: MapEntry): string {
    return typeof entry.value === 'string' ||
      typeof entry.value === 'number' ||
      typeof entry.value === 'boolean'
      ? String(entry.value)
      : formatJson(entry.value ?? '');
  }

  protected newFreeformKey(path: string): string {
    return (
      this.newFreeformKeys()[path] ?? nextEntryName(this.fieldValue({ path } as SchemaField), 'key')
    );
  }

  protected updateNewFreeformKey(path: string, value: unknown): void {
    this.newFreeformKeys.update((current) => ({ ...current, [path]: sanitizeKey(value) }));
  }

  protected addFreeformEntry(field: SchemaField): void {
    const key = this.newFreeformKey(field.path);
    if (!key) {
      return;
    }
    const value = this.fieldValue(field);
    const record = isRecord(value) ? { ...value } : {};
    if (key in record) {
      return;
    }
    record[key] = '';
    this.emitPathUpdate(field.path, record);
    this.newFreeformKeys.update((current) => ({
      ...current,
      [field.path]: nextEntryName(record, 'key'),
    }));
  }

  protected updateFreeformValue(field: SchemaField, key: string, value: unknown): void {
    const current = this.fieldValue(field);
    const record = isRecord(current) ? { ...current } : {};
    record[key] = value;
    this.emitPathUpdate(field.path, record);
  }

  protected removeFreeformEntry(field: SchemaField, key: string): void {
    const current = this.fieldValue(field);
    if (!isRecord(current)) {
      return;
    }
    const record = { ...current };
    delete record[key];
    this.emitPathUpdate(field.path, record);
  }

  protected updateScalar(field: SchemaField, value: unknown): void {
    if (field.widget === 'number') {
      this.emitPathUpdate(field.path, Number(value));
      return;
    }
    if (field.widget === 'checkbox') {
      this.emitPathUpdate(field.path, value === true);
      return;
    }
    this.emitPathUpdate(field.path, value);
  }

  protected updateStringList(field: SchemaField, value: unknown): void {
    const lines = String(value ?? '')
      .split('\n')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
    this.emitPathUpdate(field.path, lines);
  }

  protected updateJson(field: SchemaField, value: unknown): void {
    try {
      const parsed = JSON.parse(String(value ?? 'null')) as unknown;
      this.jsonErrors.update((current) => {
        const next = { ...current };
        delete next[field.path];
        return next;
      });
      this.emitPathUpdate(field.path, parsed);
    } catch (error) {
      this.jsonErrors.update((current) => ({
        ...current,
        [field.path]: error instanceof Error ? error.message : String(error),
      }));
    }
  }

  private emitPathUpdate(path: string, value: unknown): void {
    this.modelChange.emit(setValueAtPath(this.model, path, value));
  }

  private expandPath(path: string): void {
    this.collapsedSections.update((current) => {
      const next = { ...current };
      for (const sectionPath of Object.keys(next)) {
        if (path === sectionPath || path.startsWith(`${sectionPath}.`)) {
          delete next[sectionPath];
        }
      }
      return next;
    });
  }

  private findPathElement(path: string): HTMLElement | undefined {
    return Array.from(
      this.elementRef.nativeElement.querySelectorAll<HTMLElement>('[data-schema-path]'),
    ).find((item) => item.dataset['schemaPath'] === path);
  }

  private countErrorsForNode(schema: JsonSchema, basePath: string): number {
    let count = 0;
    for (const field of this.fieldsFor(schema, basePath)) {
      count += this.fieldErrors(field).length;
      if (field.widget === 'object') {
        count += this.countErrorsForNode(field.schema, field.path);
      }
      if (field.widget === 'map') {
        for (const entry of this.mapEntries(field)) {
          count += this.countErrorsForNode(this.mapValueSchema(field), entry.path);
        }
      }
      if (field.widget === 'array-object') {
        for (const entry of this.arrayEntries(field)) {
          count += this.countErrorsForNode(this.arrayItemSchema(field), entry.path);
        }
      }
    }
    return count;
  }

  private displayValue(field: SchemaField): unknown {
    const value = this.fieldValue(field);
    if (value !== undefined) {
      return value;
    }
    return schemaDisplayDefault(field.schema);
  }

  private defaultHelperText(field: SchemaField): string {
    if (this.fieldValue(field) !== undefined || !hasSchemaDisplayDefault(field.schema)) {
      return '';
    }
    return `Using default: ${defaultText(schemaDisplayDefault(field.schema))}.`;
  }

  private fieldErrors(field: SchemaField): string[] {
    const errors: string[] = [];
    const jsonError = this.jsonErrors()[field.path];
    if (jsonError) {
      errors.push(jsonError);
    }

    const value = this.displayValue(field);
    if (field.required && isEmptyFormValue(value)) {
      errors.push(`${field.label} is required.`);
    }

    if (field.schema.minLength !== undefined && typeof value === 'string') {
      if (value.length < field.schema.minLength) {
        errors.push(`${field.label} must be at least ${field.schema.minLength} characters.`);
      }
    }

    if (field.schema.pattern && typeof value === 'string' && value.length > 0) {
      try {
        if (!new RegExp(field.schema.pattern).test(value)) {
          errors.push(`${field.label} does not match the required format.`);
        }
      } catch {
        // Ignore invalid schema patterns in the UI; full schema validation still reports them.
      }
    }

    if (
      (field.schema.minimum !== undefined || field.schema.maximum !== undefined) &&
      (typeof value === 'number' || (typeof value === 'string' && value.trim() !== ''))
    ) {
      const number = Number(value);
      if (!Number.isFinite(number)) {
        errors.push(`${field.label} must be a number.`);
      } else {
        if (field.schema.minimum !== undefined && number < field.schema.minimum) {
          errors.push(`${field.label} must be ${field.schema.minimum} or greater.`);
        }
        if (field.schema.maximum !== undefined && number > field.schema.maximum) {
          errors.push(`${field.label} must be ${field.schema.maximum} or less.`);
        }
      }
    }

    errors.push(...this.infrastructureFormatErrors(field, value));
    errors.push(...this.conditionalRequirementErrors(field, value));

    return [...new Set(errors)];
  }

  private infrastructureFormatErrors(field: SchemaField, value: unknown): string[] {
    if (isEmptyFormValue(value)) {
      return [];
    }

    const errors: string[] = [];
    if (typeof value === 'string') {
      const text = value.trim();
      if (text.length === 0) {
        return [];
      }

      if (isSubnetMaskField(field) && !isSubnetMask(text)) {
        errors.push(`${field.label} must be a valid IPv4 subnet mask.`);
      } else if (isIpv4Field(field) && !isIpv4(text)) {
        errors.push(`${field.label} must be an IPv4 address.`);
      }

      if (isHostnameField(field) && !isDnsLabel(text)) {
        errors.push(`${field.label} must be a DNS label.`);
      }
      if (isDomainNameField(field) && !isDnsName(text)) {
        errors.push(`${field.label} must be a DNS name.`);
      }
    }

    if (Array.isArray(value) && isNameserverField(field)) {
      const invalidNameservers = value
        .filter((item): item is string => typeof item === 'string' && item.trim().length > 0)
        .filter((item) => !isIpv4(item.trim()));
      if (invalidNameservers.length > 0) {
        errors.push(`${field.label} entries must be IPv4 addresses.`);
      }
    }

    return errors;
  }

  private conditionalRequirementErrors(field: SchemaField, value: unknown): string[] {
    const errors: string[] = [];
    const installSourceType = this.installSourceTypeForField(field);
    if (installSourceType) {
      const text = typeof value === 'string' ? value.trim() : '';
      if (field.key === 'url' && installSourceTypeRequiresUrl(installSourceType)) {
        if (!text) {
          errors.push(`${field.label} is required when source type is ${installSourceType}.`);
        } else if (installSourceTypeRequiresHttpUrl(installSourceType) && !isHttpUrl(text)) {
          errors.push(`${field.label} must be an HTTP or HTTPS URL for ${installSourceType}.`);
        }
      }
      if (field.key === 'path' && installSourceTypeRequiresPath(installSourceType) && !text) {
        errors.push(`${field.label} is required when source type is ${installSourceType}.`);
      }
      if (field.key === 'datastore' && installSourceType === 'datastore_iso' && !text) {
        errors.push(`${field.label} is required when source type is datastore_iso.`);
      }
    }

    const credentialPair = providerCredentialPair(field.key);
    if (credentialPair && this.providerKindForCredentialField(field) === 'vsphere') {
      const parent = parentPath(field.path);
      const literal = valueAtPath(this.model, joinPath(parent, credentialPair.literal));
      const env = valueAtPath(this.model, joinPath(parent, credentialPair.env));
      if (!hasTextValue(literal) && !hasTextValue(env) && field.key === credentialPair.literal) {
        errors.push(
          `Provide ${credentialPair.label} or ${credentialPair.label} Env for vSphere credentials.`,
        );
      }
    }

    return errors;
  }

  private installSourceTypeForField(field: SchemaField): string | undefined {
    const parts = field.path.split('.');
    if (parts[0] !== 'install_sources' || parts.length < 3) {
      return undefined;
    }

    const type = valueAtPath(this.model, joinPath(parentPath(field.path), 'type'));
    return typeof type === 'string' && type.trim() ? type.trim() : 'http_iso';
  }

  private providerKindForCredentialField(field: SchemaField): string | undefined {
    const parts = field.path.split('.');
    if (parts[0] !== 'providers' || parts[2] !== 'credentials' || parts.length < 4) {
      return undefined;
    }

    const kind = valueAtPath(this.model, `providers.${parts[1]}.kind`);
    return typeof kind === 'string' && kind.trim() ? kind.trim() : 'vsphere';
  }
}

function normalizedOrder(order: number): number {
  return order === -1 ? Number.MAX_SAFE_INTEGER : order;
}

function hasSchemaDisplayDefault(schema: JsonSchema): boolean {
  return 'default' in schema || 'const' in schema;
}

function schemaDisplayDefault(schema: JsonSchema): unknown {
  if ('default' in schema) {
    return cloneJson(schema.default);
  }
  if ('const' in schema) {
    return schema.const;
  }
  return undefined;
}

function defaultText(value: unknown): string {
  if (typeof value === 'string') {
    return value.length > 0 ? value : 'empty string';
  }
  return formatJson(value);
}

function isEmptyFormValue(value: unknown): boolean {
  if (value === undefined || value === null) {
    return true;
  }
  if (typeof value === 'string') {
    return value.trim().length === 0;
  }
  if (Array.isArray(value)) {
    return value.length === 0;
  }
  return false;
}

function isIpv4Field(field: SchemaField): boolean {
  if (isSubnetMaskField(field)) {
    return false;
  }
  if (field.key === 'ip' || field.key === 'gateway' || field.key === 'starting_ip') {
    return true;
  }
  if (field.key.endsWith('_ip')) {
    return true;
  }
  return field.key === 'network' && /\.networks\.(wan|lan)\.network$/.test(field.path);
}

function isSubnetMaskField(field: SchemaField): boolean {
  return field.key === 'subnet_mask' || field.key.endsWith('_subnet_mask');
}

function isHostnameField(field: SchemaField): boolean {
  return field.key === 'hostname';
}

function isDomainNameField(field: SchemaField): boolean {
  return field.key === 'domain_name' || field.key.endsWith('_domain_name');
}

function isNameserverField(field: SchemaField): boolean {
  return field.key === 'nameservers';
}

function isIpv4(value: string): boolean {
  const parts = value.split('.');
  if (parts.length !== 4) {
    return false;
  }
  return parts.every((part) => {
    if (!/^\d{1,3}$/.test(part)) {
      return false;
    }
    const octet = Number(part);
    return Number.isInteger(octet) && octet >= 0 && octet <= 255;
  });
}

function isSubnetMask(value: string): boolean {
  if (!isIpv4(value)) {
    return false;
  }
  const bits = value
    .split('.')
    .map((part) => Number(part).toString(2).padStart(8, '0'))
    .join('');
  return /^1*0*$/.test(bits);
}

function isDnsLabel(value: string): boolean {
  return /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/i.test(value);
}

function isDnsName(value: string): boolean {
  return (
    value.length <= 253 &&
    value
      .replace(/\.$/, '')
      .split('.')
      .every((label) => isDnsLabel(label))
  );
}

function isHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

function installSourceTypeRequiresUrl(type: string): boolean {
  return ['http_ovf', 'http_iso', 'rclone_iso'].includes(type);
}

function installSourceTypeRequiresHttpUrl(type: string): boolean {
  return ['http_ovf', 'http_iso'].includes(type);
}

function installSourceTypeRequiresPath(type: string): boolean {
  return ['local_ovf', 'datastore_iso'].includes(type);
}

function providerCredentialPair(
  key: string,
): { literal: string; env: string; label: string } | undefined {
  const pairs: Record<string, { literal: string; env: string; label: string }> = {
    server: { literal: 'server', env: 'server_env', label: 'Server' },
    user: { literal: 'user', env: 'user_env', label: 'User' },
    password: { literal: 'password', env: 'password_env', label: 'Password' },
  };
  return pairs[key];
}

function hasTextValue(value: unknown): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function widgetForSchema(schema: JsonSchema): SchemaWidget {
  if ('const' in schema) {
    return 'readonly';
  }
  if (schema.enum) {
    return 'select';
  }
  if (schema.type === 'boolean') {
    return 'checkbox';
  }
  if (schema.type === 'number' || schema.type === 'integer') {
    return 'number';
  }
  if (schema.type === 'array' && schema.items?.type === 'string') {
    return 'array-string';
  }
  if (schema.type === 'array' && schema.items?.type === 'object') {
    return 'array-object';
  }
  if (schema.type === 'array') {
    return 'array-json';
  }
  if (schema.type === 'object' && schema.properties) {
    return 'object';
  }
  if (schema.type === 'object' && isSchema(schema.additionalProperties)) {
    return 'map';
  }
  if (schema.type === 'object' && schema.additionalProperties === true) {
    return 'freeform-map';
  }
  if (schema.type === 'string') {
    return 'text';
  }
  return 'json';
}

function isWideFieldPath(path: string, key: string): boolean {
  if (path.endsWith('.credentials.password') || key === 'password') {
    return false;
  }
  return [
    /(^|_)(url|path|file|remote)$/,
    /(^|_)(server|endpoint)$/,
    /(^|_)(compute_host)$/,
    /(^|_)(http_root|tftp_root)$/,
    /(^|_)(ssh_common_args)$/,
  ].some((pattern) => pattern.test(key));
}

function entryPrefixForPath(path: string): string {
  const key = path.split('.').at(-1) ?? '';
  const prefixes: Record<string, string> = {
    providers: 'provider',
    install_sources: 'source',
    routers: 'router',
    storages: 'storage',
    esxi_groups: 'esxi_group',
    vcenters: 'vcenter',
    networks: 'network',
    luns: 'lun',
    disks: 'disk',
    vmkernel_adapters: 'vmkernel',
  };
  return prefixes[key] ?? 'item';
}

function defaultValueForSchema(schema: JsonSchema): unknown {
  if ('default' in schema) {
    return cloneJson(schema.default);
  }
  if ('const' in schema) {
    return schema.const;
  }
  if (schema.type === 'array') {
    return [];
  }
  if (schema.type === 'object') {
    const result: Record<string, unknown> = {};
    for (const [key, property] of Object.entries(schema.properties ?? {})) {
      if ('default' in property || 'const' in property || schema.required?.includes(key)) {
        result[key] = defaultValueForSchema(property);
      }
    }
    return result;
  }
  if (schema.type === 'boolean') {
    return false;
  }
  if (schema.type === 'number' || schema.type === 'integer') {
    return 0;
  }
  if (schema.enum?.length) {
    return schema.enum[0];
  }
  return '';
}

function valueAtPath(model: unknown, path: string): unknown {
  if (path === '') {
    return model;
  }
  const parts = path.split('.');
  let cursor = model;
  for (const part of parts) {
    if (isArrayIndex(part)) {
      if (!Array.isArray(cursor)) {
        return undefined;
      }
      cursor = cursor[Number(part)];
    } else {
      if (!isRecord(cursor)) {
        return undefined;
      }
      cursor = cursor[part];
    }
  }
  return cursor;
}

function setValueAtPath(model: unknown, path: string, value: unknown): unknown {
  if (path === '') {
    return value;
  }
  return setPathPart(model === undefined ? undefined : cloneJson(model), path.split('.'), value);
}

function setPathPart(container: unknown, parts: string[], value: unknown): unknown {
  const [part, ...rest] = parts;
  if (part === undefined) {
    return value;
  }
  if (rest.length === 0) {
    return setContainerValue(container, part, value);
  }

  const currentValue = isArrayIndex(part)
    ? Array.isArray(container)
      ? container[Number(part)]
      : undefined
    : isRecord(container)
      ? container[part]
      : undefined;
  const fallback = isArrayIndex(rest[0] ?? '') ? [] : {};
  return setContainerValue(container, part, setPathPart(currentValue ?? fallback, rest, value));
}

function setContainerValue(container: unknown, key: string, value: unknown): unknown {
  if (isArrayIndex(key)) {
    const result = Array.isArray(container) ? [...container] : [];
    result[Number(key)] = value;
    return result;
  }
  return {
    ...(isRecord(container) ? container : {}),
    [key]: value,
  };
}

function joinPath(basePath: string, key: string): string {
  return basePath ? `${basePath}.${key}` : key;
}

function parentPath(path: string): string {
  return path.includes('.') ? path.slice(0, path.lastIndexOf('.')) : '';
}

function labelFromPath(path: string): string {
  return (
    path
      .split('.')
      .at(-1)
      ?.split('_')
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ') ?? path
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isArrayIndex(value: string): boolean {
  return /^(0|[1-9]\d*)$/.test(value);
}

function isSchema(value: unknown): value is JsonSchema {
  return isRecord(value);
}

function nextEntryName(value: unknown, prefix: string): string {
  const record = isRecord(value) ? value : {};
  let index = 1;
  let candidate = `${prefix}_${index}`;
  while (candidate in record) {
    index += 1;
    candidate = `${prefix}_${index}`;
  }
  return candidate;
}

function sanitizeKey(value: unknown): string {
  return String(value ?? '')
    .trim()
    .replace(/\s+/g, '_');
}

function pathId(path: string): string {
  return path.replace(/[^A-Za-z0-9_-]+/g, '-');
}
