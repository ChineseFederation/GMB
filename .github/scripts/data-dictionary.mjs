#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptPath = fileURLToPath(import.meta.url);
const repositoryRoot = resolve(dirname(scriptPath), '../..');
// 中文注释：统一数据字典属于 GMB 公开跨产品契约，公开门禁不得反向依赖私人 AI 规则。
const dictionaryPath = join(repositoryRoot, 'shared/data-dictionary.json');
const sourceExtensions = /\.(?:dart|js|jsx|json|kts?|md|mjs|proto|py|rs|sh|sql|swift|toml|tsx?|ya?ml)$/;
const authorities = new Set(['gmb', 'polkadot_sdk']);
const dataTypes = new Set(['array', 'boolean', 'enum', 'hash', 'hex_32', 'integer', 'string']);
const valueTypes = new Set(['boolean', 'integer', 'string']);

function fail(message) {
  throw new Error(message);
}

export function toCamelCase(fieldName) {
  return fieldName.replace(/_([a-z0-9])/g, (_, value) => value.toUpperCase());
}

export function toSnakeCase(fieldName) {
  return fieldName.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function globToRegex(glob) {
  let pattern = '';
  for (let index = 0; index < glob.length; index += 1) {
    const char = glob[index];
    if (char !== '*') {
      pattern += escapeRegex(char);
      continue;
    }
    if (glob[index + 1] === '*') {
      index += 1;
      if (glob[index + 1] === '/') {
        index += 1;
        pattern += '(?:.*/)?';
      } else {
        pattern += '.*';
      }
    } else {
      pattern += '[^/]*';
    }
  }
  return new RegExp(`^${pattern}$`);
}

function matchesAny(path, globs) {
  return globs.some((glob) => globToRegex(glob).test(path));
}

function sortedUnique(values, label, selector = (value) => value) {
  if (!Array.isArray(values)) fail(`${label} 必须是数组`);
  const keys = values.map(selector);
  if (keys.some((value) => typeof value !== 'string' || value.length === 0)) {
    fail(`${label} 存在空值或非字符串标识`);
  }
  if (new Set(keys).size !== keys.length) fail(`${label} 存在重复项`);
  const sorted = [...keys].sort();
  if (JSON.stringify(sorted) !== JSON.stringify(keys)) fail(`${label} 必须按字典序排列`);
}

function exactKeys(value, expected, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(`${label} 必须是对象`);
  const actual = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(sortedExpected)) {
    fail(`${label} 属性无效：只允许 ${expected.join(', ')}`);
  }
}

function nonEmptyText(value, label) {
  if (typeof value !== 'string' || value.trim() !== value || value.length === 0) {
    fail(`${label} 必须是无首尾空白的非空字符串`);
  }
}

function validateClosedValue(value, valueType, label) {
  if (typeof value !== valueType) fail(`${label}.value 必须是 ${valueType}`);
  if (valueType !== 'string') return;
  nonEmptyText(value, `${label}.value`);
  if (value.length > 80) fail(`${label}.value 过长，不属于精简闭集值`);
  if (/^https?:\/\//i.test(value)
      || /^0x[0-9a-f]{64}$/i.test(value)
      || /^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(value)
      || /^\d{4}-\d{2}-\d{2}(?:T|$)/.test(value)) {
    fail(`${label}.value 疑似动态 URL、哈希、ID 或时间，不得进入闭集值`);
  }
}

function validateConcept(concept, label) {
  const expected = ['concept_id', 'field_name', 'field_name_zh', 'authority', 'data_type', 'forbidden_names'];
  if ('value_set_id' in concept) expected.push('value_set_id');
  if ('paths' in concept) expected.push('paths');
  if ('legacy_reads' in concept) expected.push('legacy_reads');
  exactKeys(concept, expected, label);
  if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(concept.concept_id)) {
    fail(`${label}.concept_id 必须使用 snake_case`);
  }
  if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(concept.field_name)) {
    fail(`${label}.field_name 必须使用 snake_case`);
  }
  nonEmptyText(concept.field_name_zh, `${label}.field_name_zh`);
  if (!authorities.has(concept.authority)) fail(`${label}.authority 无效`);
  if (!dataTypes.has(concept.data_type)) fail(`${label}.data_type 无效`);
  if (concept.data_type === 'enum' && !concept.value_set_id) fail(`${label} 枚举字段缺少 value_set_id`);
  if (concept.data_type !== 'enum' && concept.value_set_id) fail(`${label} 非枚举字段不得引用 value_set_id`);
  sortedUnique(concept.forbidden_names, `${label}.forbidden_names`);
  const canonicalNames = new Set([concept.field_name, toCamelCase(concept.field_name)]);
  for (const forbiddenName of concept.forbidden_names) {
    if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(forbiddenName)) fail(`${label} 废弃字段名无效：${forbiddenName}`);
    if (canonicalNames.has(forbiddenName)) fail(`${label} 把规范字段形式误登记为废弃名：${forbiddenName}`);
  }
  if (concept.paths) sortedUnique(concept.paths, `${label}.paths`);
  if (concept.legacy_reads) {
    sortedUnique(
      concept.legacy_reads,
      `${label}.legacy_reads`,
      (entry) => `${entry?.field_name ?? ''}:${entry?.path ?? ''}`,
    );
    for (const [index, entry] of concept.legacy_reads.entries()) {
      const entryLabel = `${label}.legacy_reads[${index}]`;
      exactKeys(entry, ['field_name', 'path'], entryLabel);
      if (!concept.forbidden_names.includes(entry.field_name)) {
        fail(`${entryLabel}.field_name 必须同时登记为废弃字段名`);
      }
      nonEmptyText(entry.path, `${entryLabel}.path`);
      if (entry.path.includes('*') || !sourceExtensions.test(entry.path)) {
        fail(`${entryLabel}.path 必须是精确源码文件路径`);
      }
      if (concept.paths && !matchesAny(entry.path, concept.paths)) {
        fail(`${entryLabel}.path 不在字段受控路径内`);
      }
    }
  }
}

function validateValueSet(valueSet, label) {
  exactKeys(valueSet, ['value_set_id', 'value_set_zh', 'authority', 'value_type', 'forbidden_values', 'values'], label);
  if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(valueSet.value_set_id)) {
    fail(`${label}.value_set_id 必须使用 snake_case`);
  }
  nonEmptyText(valueSet.value_set_zh, `${label}.value_set_zh`);
  if (!authorities.has(valueSet.authority)) fail(`${label}.authority 无效`);
  if (!valueTypes.has(valueSet.value_type)) fail(`${label}.value_type 无效`);
  sortedUnique(valueSet.forbidden_values, `${label}.forbidden_values`);
  if (!Array.isArray(valueSet.values) || valueSet.values.length === 0) fail(`${label}.values 必须是非空数组`);
  const values = [];
  for (let index = 0; index < valueSet.values.length; index += 1) {
    const entry = valueSet.values[index];
    const entryLabel = `${label}.values[${index}]`;
    exactKeys(entry, ['value', 'full_name_en', 'short_name_en', 'full_name_zh', 'short_name_zh'], entryLabel);
    validateClosedValue(entry.value, valueSet.value_type, entryLabel);
    for (const key of ['full_name_en', 'full_name_zh']) nonEmptyText(entry[key], `${entryLabel}.${key}`);
    for (const [shortKey, fullKey] of [['short_name_en', 'full_name_en'], ['short_name_zh', 'full_name_zh']]) {
      if (entry[shortKey] === null) continue;
      nonEmptyText(entry[shortKey], `${entryLabel}.${shortKey}`);
      if (entry[shortKey] === entry[fullKey]) fail(`${entryLabel}.${shortKey} 与全称重复，应改为 null`);
    }
    values.push(String(entry.value));
  }
  sortedUnique(values, `${label}.values.value`);
  const allowed = new Set(values);
  for (const forbidden of valueSet.forbidden_values) {
    if (allowed.has(String(forbidden))) fail(`${label} 把规范值误登记为废弃值：${forbidden}`);
  }
}

function validateContract(contract, label) {
  exactKeys(contract, ['contract_id', 'contract_name_zh', 'authority', 'paths', 'fields', 'value_sets'], label);
  if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(contract.contract_id)) fail(`${label}.contract_id 必须使用 snake_case`);
  nonEmptyText(contract.contract_name_zh, `${label}.contract_name_zh`);
  if (!authorities.has(contract.authority)) fail(`${label}.authority 无效`);
  sortedUnique(contract.paths, `${label}.paths`);
  sortedUnique(contract.fields, `${label}.fields`);
  sortedUnique(contract.value_sets, `${label}.value_sets`);
  if (contract.paths.length === 0 || contract.fields.length === 0) fail(`${label} 必须声明路径和字段`);
}

export function validateDictionary(index, shards, jsonFiles = []) {
  exactKeys(index, ['domains', 'ignored_paths'], 'index.json');
  sortedUnique(index.domains, 'index.json.domains', (domain) => domain?.domain_id);
  sortedUnique(index.ignored_paths, 'index.json.ignored_paths');
  const indexedFiles = new Set(['index.json']);
  for (const domain of index.domains) {
    exactKeys(domain, ['domain_id', 'file'], `index.json.domains.${domain.domain_id ?? '未知'}`);
    if (!/^[a-z][a-z0-9]*$/.test(domain.domain_id)) fail(`领域标识无效：${domain.domain_id}`);
    if (domain.file !== `${domain.domain_id}.json`) fail(`${domain.domain_id} 的文件必须是 ${domain.domain_id}.json`);
    indexedFiles.add(domain.file);
  }
  if (jsonFiles.length > 0) {
    sortedUnique(jsonFiles, '数据字典 JSON 文件');
    const expected = [...indexedFiles].sort();
    if (JSON.stringify(jsonFiles) !== JSON.stringify(expected)) fail('数据字典存在未索引或缺失的 JSON 分片');
  }
  if (shards.length !== index.domains.length) fail('数据字典分片数量与索引不一致');

  const concepts = new Map();
  const fieldNames = new Map();
  const valueSets = new Map();
  const contracts = new Map();
  for (let shardIndex = 0; shardIndex < shards.length; shardIndex += 1) {
    const shard = shards[shardIndex];
    const domain = index.domains[shardIndex];
    exactKeys(shard, ['domain_id', 'concepts', 'value_sets', 'contracts'], domain.file);
    if (shard.domain_id !== domain.domain_id) fail(`${domain.file} 的 domain_id 不一致`);
    sortedUnique(shard.concepts, `${domain.file}.concepts`, (entry) => entry?.concept_id);
    sortedUnique(shard.value_sets, `${domain.file}.value_sets`, (entry) => entry?.value_set_id);
    sortedUnique(shard.contracts, `${domain.file}.contracts`, (entry) => entry?.contract_id);
    shard.concepts.forEach((concept, index) => {
      validateConcept(concept, `${domain.file}.concepts[${index}]`);
      if (concepts.has(concept.concept_id)) fail(`concept_id 跨分片重复：${concept.concept_id}`);
      if (fieldNames.has(concept.field_name)) fail(`field_name 跨分片重复：${concept.field_name}`);
      concepts.set(concept.concept_id, concept);
      fieldNames.set(concept.field_name, concept.concept_id);
    });
    shard.value_sets.forEach((valueSet, index) => {
      validateValueSet(valueSet, `${domain.file}.value_sets[${index}]`);
      if (valueSets.has(valueSet.value_set_id)) fail(`value_set_id 跨分片重复：${valueSet.value_set_id}`);
      valueSets.set(valueSet.value_set_id, valueSet);
    });
    shard.contracts.forEach((contract, index) => {
      validateContract(contract, `${domain.file}.contracts[${index}]`);
      if (contracts.has(contract.contract_id)) fail(`contract_id 跨分片重复：${contract.contract_id}`);
      contracts.set(contract.contract_id, contract);
    });
  }

  const referencedFields = new Set();
  const referencedValueSets = new Set();
  for (const concept of concepts.values()) {
    if (concept.value_set_id && !valueSets.has(concept.value_set_id)) {
      fail(`${concept.concept_id} 引用了不存在的 value_set_id：${concept.value_set_id}`);
    }
  }
  for (const contract of contracts.values()) {
    const expectedValueSets = new Set();
    for (const conceptId of contract.fields) {
      if (!concepts.has(conceptId)) fail(`${contract.contract_id} 引用了不存在的字段：${conceptId}`);
      referencedFields.add(conceptId);
      const valueSetId = concepts.get(conceptId).value_set_id;
      if (valueSetId) expectedValueSets.add(valueSetId);
    }
    for (const valueSetId of contract.value_sets) {
      if (!valueSets.has(valueSetId)) fail(`${contract.contract_id} 引用了不存在的值集：${valueSetId}`);
      referencedValueSets.add(valueSetId);
    }
    if (JSON.stringify([...expectedValueSets].sort()) !== JSON.stringify(contract.value_sets)) {
      fail(`${contract.contract_id} 的 value_sets 必须与枚举字段引用完全一致`);
    }
  }
  for (const conceptId of concepts.keys()) {
    if (!referencedFields.has(conceptId)) fail(`字段未进入任何契约：${conceptId}`);
  }
  for (const valueSetId of valueSets.keys()) {
    if (!referencedValueSets.has(valueSetId)) fail(`值集未进入任何契约：${valueSetId}`);
  }
  return { concepts, valueSets, contracts, ignoredPaths: index.ignored_paths };
}

export function loadDictionary() {
  const dictionary = JSON.parse(readFileSync(dictionaryPath, 'utf8'));
  exactKeys(dictionary, ['fields', 'value_sets', 'contracts', 'ignored_paths'], 'data-dictionary.json');
  sortedUnique(dictionary.fields, 'data-dictionary.json.fields', (entry) => entry?.concept_id);
  sortedUnique(dictionary.value_sets, 'data-dictionary.json.value_sets', (entry) => entry?.value_set_id);
  sortedUnique(dictionary.contracts, 'data-dictionary.json.contracts', (entry) => entry?.contract_id);
  sortedUnique(dictionary.ignored_paths, 'data-dictionary.json.ignored_paths');

  const entries = [...dictionary.fields, ...dictionary.value_sets, ...dictionary.contracts];
  const domains = [...new Set(entries.map((entry) => entry?.domain))].sort();
  if (domains.some((domain) => typeof domain !== 'string' || !/^[a-z][a-z0-9]*$/.test(domain))) {
    fail('data-dictionary.json 存在无效领域标识');
  }
  const withoutDomain = (entry) => {
    const { domain: _domain, ...value } = entry;
    return value;
  };
  const index = {
    domains: domains.map((domainId) => ({ domain_id: domainId, file: `${domainId}.json` })),
    ignored_paths: dictionary.ignored_paths,
  };
  const shards = domains.map((domainId) => ({
    domain_id: domainId,
    concepts: dictionary.fields.filter((entry) => entry.domain === domainId).map(withoutDomain),
    value_sets: dictionary.value_sets.filter((entry) => entry.domain === domainId).map(withoutDomain),
    contracts: dictionary.contracts.filter((entry) => entry.domain === domainId).map(withoutDomain),
  }));
  return validateDictionary(index, shards);
}

// 中文注释：只把声明、对象键、序列化键和数据库列视为字段，避免把函数名中的同词根误判为契约字段。
function fieldPatterns(fieldName) {
  const escaped = escapeRegex(fieldName);
  return [
    new RegExp(`['\"]${escaped}['\"]\\s*:`),
    new RegExp(`\\[['\"]${escaped}['\"]\\]`),
    new RegExp(`\\b(?:this\\.)?${escaped}\\b\\s*[?!]?\\s*:`),
    new RegExp(`\\bthis\\.${escaped}\\b`),
    new RegExp(`\\b${escaped}\\b\\s*[;=]`),
    new RegExp(`^\\s*${escaped}\\s+(?:BIGINT|BLOB|BOOLEAN|INTEGER|REAL|TEXT)\\b`, 'i'),
    new RegExp(`rename(?:_all)?\\s*=\\s*['\"]${escaped}['\"]`),
  ];
}

// 中文注释：旧字段只允许作为数据字典明确登记的单向读取键；Rust/TS/Dart 标识符仍必须使用规范名。
export function isDeclaredLegacyRead(line, path, fieldName, legacyReads = []) {
  if (!legacyReads.some((entry) => entry.field_name === fieldName && entry.path === path)) return false;
  const escaped = escapeRegex(fieldName);
  return new RegExp(`(?:rename\\s*=\\s*['\"]${escaped}['\"]|['\"]${escaped}['\"]\\s*:)`).test(line);
}

export function lineUsesFieldName(line, fieldName) {
  return fieldPatterns(fieldName).some((pattern) => pattern.test(line));
}

export function markdownUsesFieldName(line, fieldName) {
  if (!/(字段|参数|载荷|协议|API|DTO|JSON|SQL|storage|Storage)/i.test(line)) return false;
  if (/(禁止|不得|废弃|旧名|历史|拒绝|不再|零命中)/.test(line)) return false;
  return new RegExp(`\`${escapeRegex(fieldName)}\``).test(line);
}

// 中文注释：增量门禁只提取能形成跨文件或强序列化契约的字段；普通局部变量不会仅因赋值进入字典。
export function addedFieldNames(line, extension = '') {
  const fields = new Map();
  const add = (fieldName, strong = false) => {
    if (!/^[a-z][A-Za-z0-9_]{2,}$/.test(fieldName)) return;
    const normalized = toSnakeCase(fieldName);
    const previous = fields.get(normalized);
    fields.set(normalized, { fieldName: normalized, strong: strong || previous?.strong || false });
  };
  for (const match of line.matchAll(/['\"]([a-z][a-z0-9_]*)['\"]\s*:/g)) add(match[1], true);
  for (const match of line.matchAll(/\[['\"]([a-z][a-z0-9_]*)['\"]\]/g)) add(match[1], true);
  for (const match of line.matchAll(/(?:^|[,{}]\s*)([a-z][A-Za-z0-9_]*)\??\s*:/g)) add(match[1]);
  const declaration = line.match(/\b(?:final|late\s+final|pub(?:\([^)]*\))?)\s+(?:[A-Za-z0-9_<>,?. ()]+\s+)?([a-z][A-Za-z0-9_]*)\s*[;:]/);
  if (declaration) add(declaration[1]);
  if (extension === '.proto') {
    const proto = line.match(/^\s*(?:repeated\s+)?[A-Za-z][A-Za-z0-9_.<>]*\s+([a-z][a-z0-9_]*)\s*=\s*\d+/);
    if (proto) add(proto[1], true);
  }
  if (extension === '.sql') {
    const sql = line.match(/^\s*([a-z][a-z0-9_]*)\s+(?:BIGINT|BLOB|BOOLEAN|INTEGER|REAL|TEXT)\b/i);
    if (sql) add(sql[1], true);
  }
  return [...fields.values()];
}

export function addedClosedValues(line, concepts, valueSets) {
  const violations = [];
  for (const concept of concepts.values()) {
    if (!concept.value_set_id) continue;
    const snake = concept.field_name;
    const camel = toCamelCase(snake);
    const field = `(?:['\"])?(?:${escapeRegex(snake)}|${escapeRegex(camel)})(?:['\"])?`;
    const assignment = new RegExp(`${field}\\s*(?::|={1,3}|!={1,2})\\s*['\"]([A-Za-z][A-Za-z0-9_-]*)['\"]`, 'g');
    const allowed = new Set(valueSets.get(concept.value_set_id).values.map((entry) => String(entry.value)));
    for (const match of line.matchAll(assignment)) {
      const candidate = match[1];
      if (allowed.has(candidate)) continue;
      violations.push({ conceptId: concept.concept_id, value: candidate });
    }
  }
  return violations;
}

function repositoryFiles() {
  const output = execFileSync('git', ['ls-files', '-co', '--exclude-standard', '-z'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  return [...new Set(output.split('\0').filter(Boolean))].sort((a, b) => a.localeCompare(b));
}

function baseFieldNames(baseRef) {
  const output = execFileSync('git', ['grep', '-h', '-o', '-I', '-E', '[A-Za-z][A-Za-z0-9_]{2,}', baseRef, '--'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
    maxBuffer: 128 * 1024 * 1024,
  });
  return new Set(output.split('\n').filter(Boolean).map(toSnakeCase));
}

export function changedDictionaryViolations(baseRef, dictionary) {
  execFileSync('git', ['rev-parse', '--verify', baseRef], { cwd: repositoryRoot, stdio: 'ignore' });
  const diff = execFileSync('git', ['diff', '--unified=0', '--no-color', baseRef, '--'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  const additions = new Map();
  const valueViolations = [];
  let currentPath = '';
  for (const line of diff.split('\n')) {
    if (line.startsWith('+++ b/')) {
      currentPath = line.slice(6);
      continue;
    }
    if (!currentPath || !line.startsWith('+') || line.startsWith('+++')) continue;
    if (!sourceExtensions.test(currentPath) || matchesAny(currentPath, dictionary.ignoredPaths)) continue;
    const added = line.slice(1);
    for (const field of addedFieldNames(added, extname(currentPath))) {
      const value = additions.get(field.fieldName) ?? { files: new Set(), strong: false };
      value.files.add(currentPath);
      value.strong ||= field.strong;
      additions.set(field.fieldName, value);
    }
    if (!/(?:^|\/)(?:test|tests)(?:\/|$)/.test(currentPath)) {
      for (const violation of addedClosedValues(added, dictionary.concepts, dictionary.valueSets)) {
        valueViolations.push(`${currentPath}: ${violation.conceptId} 新增未登记闭集值 ${violation.value}`);
      }
    }
  }
  const registered = new Set([...dictionary.concepts.values()].map((concept) => concept.field_name));
  const existing = baseFieldNames(baseRef);
  const violations = [];
  for (const [fieldName, value] of [...additions].sort(([left], [right]) => left.localeCompare(right))) {
    if (registered.has(fieldName) || (!value.strong && value.files.size < 2) || existing.has(fieldName)) continue;
    violations.push(`新增契约字段 ${fieldName} 尚未登记：${[...value.files].sort().join(', ')}`);
  }
  return [...violations, ...valueViolations];
}

export function checkRepository(baseRef = '') {
  const dictionary = loadDictionary();
  const files = repositoryFiles().filter((path) => (
    sourceExtensions.test(path)
    && existsSync(join(repositoryRoot, path))
    && !matchesAny(path, dictionary.ignoredPaths)
  ));
  const violations = [];
  if (baseRef) violations.push(...changedDictionaryViolations(baseRef, dictionary));

  const forbiddenFields = [...dictionary.concepts.values()].flatMap((concept) => concept.forbidden_names.map((forbiddenName) => ({
    canonicalName: concept.field_name,
    forbiddenName,
    legacyReads: concept.legacy_reads ?? [],
    paths: concept.paths,
    patterns: fieldPatterns(forbiddenName),
  })));
  for (const path of files) {
    const candidates = forbiddenFields.filter((field) => !field.paths || matchesAny(path, field.paths));
    if (candidates.length === 0) continue;
    const text = readFileSync(join(repositoryRoot, path), 'utf8');
    const present = candidates.filter((field) => text.includes(field.forbiddenName));
    if (present.length === 0) continue;
    const lines = text.split('\n');
    for (let index = 0; index < lines.length; index += 1) {
      for (const field of present) {
        const used = path.endsWith('.md')
          ? markdownUsesFieldName(lines[index], field.forbiddenName)
          : field.patterns.some((pattern) => pattern.test(lines[index]));
        if (used && isDeclaredLegacyRead(lines[index], path, field.forbiddenName, field.legacyReads)) continue;
        if (used) violations.push(`${path}:${index + 1}: 字段 ${field.forbiddenName} 已废弃，应使用 ${field.canonicalName} / ${toCamelCase(field.canonicalName)}`);
      }
    }
  }
  if (violations.length > 0) fail(`统一数据字典检查失败：\n  - ${violations.join('\n  - ')}`);
  const values = [...dictionary.valueSets.values()].reduce((sum, valueSet) => sum + valueSet.values.length, 0);
  return { files: files.length, fields: dictionary.concepts.size, valueSets: dictionary.valueSets.size, values };
}

const invokedPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : '';
if (import.meta.url === invokedPath) {
  try {
    const baseIndex = process.argv.indexOf('--base-ref');
    if (baseIndex >= 0 && !process.argv[baseIndex + 1]) fail('--base-ref 缺少 Git ref');
    const result = checkRepository(baseIndex >= 0 ? process.argv[baseIndex + 1] : '');
    console.log(`统一数据字典检查通过：${result.fields} 个字段，${result.valueSets} 个值集，${result.values} 个闭集值，${result.files} 个第一方文件。`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
