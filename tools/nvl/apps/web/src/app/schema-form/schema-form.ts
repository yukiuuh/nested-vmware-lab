import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output, signal } from '@angular/core';
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
  pattern?: string;
}

export interface SchemaUiField {
  path: string;
  label?: string;
  widget?: SchemaWidget;
  description?: string;
  order?: number;
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
        };
      })
      .sort((a, b) => normalizedOrder(a.order) - normalizedOrder(b.order));
  }

  protected fieldValue(field: SchemaField): unknown {
    return valueAtPath(this.model, field.path);
  }

  protected textValue(field: SchemaField): string {
    const value = this.fieldValue(field);
    return typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean'
      ? String(value)
      : '';
  }

  protected checkedValue(field: SchemaField): boolean {
    return this.fieldValue(field) === true;
  }

  protected jsonValue(field: SchemaField): string {
    const value = this.fieldValue(field);
    return formatJson(value ?? defaultValueForSchema(field.schema));
  }

  protected stringListValue(field: SchemaField): string {
    const value = this.fieldValue(field);
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
    return [field.description, fallback, field.required ? 'Required by schema.' : '']
      .filter((part) => part.length > 0)
      .join(' ');
  }

  protected hasHelperText(field: SchemaField, fallback = ''): boolean {
    return this.helperText(field, fallback).length > 0;
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
      this.newEntryNames()[path] ?? nextEntryName(this.fieldValue({ path } as SchemaField), 'item')
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
      [field.path]: nextEntryName(record, 'item'),
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
}

function normalizedOrder(order: number): number {
  return order === -1 ? Number.MAX_SAFE_INTEGER : order;
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
