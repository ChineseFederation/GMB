// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/data-dictionary.test.mjs
import assert from "node:assert/strict";
import test from "node:test";

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/ci-repository.mjs data-dictionary
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
var scriptPath = fileURLToPath(import.meta.url);
var repositoryRoot = resolve(dirname(scriptPath), "../../..");
var dictionaryPath = join(repositoryRoot, "shared/data-dictionary.json");
var sourceExtensions = /\.(?:dart|js|jsx|json|kts?|md|mjs|proto|py|rs|sh|sql|swift|toml|tsx?|ya?ml)$/;
var authorities = /* @__PURE__ */ new Set(["gmb", "polkadot_sdk"]);
var dataTypes = /* @__PURE__ */ new Set(["array", "boolean", "enum", "hash", "hex_32", "integer", "string"]);
var valueTypes = /* @__PURE__ */ new Set(["boolean", "integer", "string"]);
function fail(message) {
  throw new Error(message);
}
function toCamelCase(fieldName) {
  return fieldName.replace(/_([a-z0-9])/g, (_, value2) => value2.toUpperCase());
}
function toSnakeCase(fieldName) {
  return fieldName.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
}
function escapeRegex(value2) {
  return value2.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
function globToRegex(glob) {
  let pattern = "";
  for (let index = 0; index < glob.length; index += 1) {
    const char = glob[index];
    if (char !== "*") {
      pattern += escapeRegex(char);
      continue;
    }
    if (glob[index + 1] === "*") {
      index += 1;
      if (glob[index + 1] === "/") {
        index += 1;
        pattern += "(?:.*/)?";
      } else {
        pattern += ".*";
      }
    } else {
      pattern += "[^/]*";
    }
  }
  return new RegExp(`^${pattern}$`);
}
function matchesAny(path, globs) {
  return globs.some((glob) => globToRegex(glob).test(path));
}
function sortedUnique(values, label, selector = (value2) => value2) {
  if (!Array.isArray(values)) fail(`${label} \u5FC5\u987B\u662F\u6570\u7EC4`);
  const keys = values.map(selector);
  if (keys.some((value2) => typeof value2 !== "string" || value2.length === 0)) {
    fail(`${label} \u5B58\u5728\u7A7A\u503C\u6216\u975E\u5B57\u7B26\u4E32\u6807\u8BC6`);
  }
  if (new Set(keys).size !== keys.length) fail(`${label} \u5B58\u5728\u91CD\u590D\u9879`);
  const sorted = [...keys].sort();
  if (JSON.stringify(sorted) !== JSON.stringify(keys)) fail(`${label} \u5FC5\u987B\u6309\u5B57\u5178\u5E8F\u6392\u5217`);
}
function exactKeys(value2, expected, label) {
  if (!value2 || typeof value2 !== "object" || Array.isArray(value2)) fail(`${label} \u5FC5\u987B\u662F\u5BF9\u8C61`);
  const actual = Object.keys(value2).sort();
  const sortedExpected = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(sortedExpected)) {
    fail(`${label} \u5C5E\u6027\u65E0\u6548\uFF1A\u53EA\u5141\u8BB8 ${expected.join(", ")}`);
  }
}
function nonEmptyText(value2, label) {
  if (typeof value2 !== "string" || value2.trim() !== value2 || value2.length === 0) {
    fail(`${label} \u5FC5\u987B\u662F\u65E0\u9996\u5C3E\u7A7A\u767D\u7684\u975E\u7A7A\u5B57\u7B26\u4E32`);
  }
}
function validateClosedValue(value2, valueType, label) {
  if (typeof value2 !== valueType) fail(`${label}.value \u5FC5\u987B\u662F ${valueType}`);
  if (valueType !== "string") return;
  nonEmptyText(value2, `${label}.value`);
  if (value2.length > 80) fail(`${label}.value \u8FC7\u957F\uFF0C\u4E0D\u5C5E\u4E8E\u7CBE\u7B80\u95ED\u96C6\u503C`);
  if (/^https?:\/\//i.test(value2) || /^0x[0-9a-f]{64}$/i.test(value2) || /^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(value2) || /^\d{4}-\d{2}-\d{2}(?:T|$)/.test(value2)) {
    fail(`${label}.value \u7591\u4F3C\u52A8\u6001 URL\u3001\u54C8\u5E0C\u3001ID \u6216\u65F6\u95F4\uFF0C\u4E0D\u5F97\u8FDB\u5165\u95ED\u96C6\u503C`);
  }
}
function validateConcept(concept, label) {
  const expected = ["concept_id", "field_name", "field_name_zh", "authority", "data_type", "forbidden_names"];
  if ("value_set_id" in concept) expected.push("value_set_id");
  if ("paths" in concept) expected.push("paths");
  if ("legacy_reads" in concept) expected.push("legacy_reads");
  exactKeys(concept, expected, label);
  if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(concept.concept_id)) {
    fail(`${label}.concept_id \u5FC5\u987B\u4F7F\u7528 snake_case`);
  }
  if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(concept.field_name)) {
    fail(`${label}.field_name \u5FC5\u987B\u4F7F\u7528 snake_case`);
  }
  nonEmptyText(concept.field_name_zh, `${label}.field_name_zh`);
  if (!authorities.has(concept.authority)) fail(`${label}.authority \u65E0\u6548`);
  if (!dataTypes.has(concept.data_type)) fail(`${label}.data_type \u65E0\u6548`);
  if (concept.data_type === "enum" && !concept.value_set_id) fail(`${label} \u679A\u4E3E\u5B57\u6BB5\u7F3A\u5C11 value_set_id`);
  if (concept.data_type !== "enum" && concept.value_set_id) fail(`${label} \u975E\u679A\u4E3E\u5B57\u6BB5\u4E0D\u5F97\u5F15\u7528 value_set_id`);
  sortedUnique(concept.forbidden_names, `${label}.forbidden_names`);
  const canonicalNames = /* @__PURE__ */ new Set([concept.field_name, toCamelCase(concept.field_name)]);
  for (const forbiddenName of concept.forbidden_names) {
    if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(forbiddenName)) fail(`${label} \u5E9F\u5F03\u5B57\u6BB5\u540D\u65E0\u6548\uFF1A${forbiddenName}`);
    if (canonicalNames.has(forbiddenName)) fail(`${label} \u628A\u89C4\u8303\u5B57\u6BB5\u5F62\u5F0F\u8BEF\u767B\u8BB0\u4E3A\u5E9F\u5F03\u540D\uFF1A${forbiddenName}`);
  }
  if (concept.paths) sortedUnique(concept.paths, `${label}.paths`);
  if (concept.legacy_reads) {
    sortedUnique(
      concept.legacy_reads,
      `${label}.legacy_reads`,
      (entry) => `${entry?.field_name ?? ""}:${entry?.path ?? ""}`
    );
    for (const [index, entry] of concept.legacy_reads.entries()) {
      const entryLabel = `${label}.legacy_reads[${index}]`;
      exactKeys(entry, ["field_name", "path"], entryLabel);
      if (!concept.forbidden_names.includes(entry.field_name)) {
        fail(`${entryLabel}.field_name \u5FC5\u987B\u540C\u65F6\u767B\u8BB0\u4E3A\u5E9F\u5F03\u5B57\u6BB5\u540D`);
      }
      nonEmptyText(entry.path, `${entryLabel}.path`);
      if (entry.path.includes("*") || !sourceExtensions.test(entry.path)) {
        fail(`${entryLabel}.path \u5FC5\u987B\u662F\u7CBE\u786E\u6E90\u7801\u6587\u4EF6\u8DEF\u5F84`);
      }
      if (concept.paths && !matchesAny(entry.path, concept.paths)) {
        fail(`${entryLabel}.path \u4E0D\u5728\u5B57\u6BB5\u53D7\u63A7\u8DEF\u5F84\u5185`);
      }
    }
  }
}
function validateValueSet(valueSet, label) {
  exactKeys(valueSet, ["value_set_id", "value_set_zh", "authority", "value_type", "forbidden_values", "values"], label);
  if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(valueSet.value_set_id)) {
    fail(`${label}.value_set_id \u5FC5\u987B\u4F7F\u7528 snake_case`);
  }
  nonEmptyText(valueSet.value_set_zh, `${label}.value_set_zh`);
  if (!authorities.has(valueSet.authority)) fail(`${label}.authority \u65E0\u6548`);
  if (!valueTypes.has(valueSet.value_type)) fail(`${label}.value_type \u65E0\u6548`);
  sortedUnique(valueSet.forbidden_values, `${label}.forbidden_values`);
  if (!Array.isArray(valueSet.values) || valueSet.values.length === 0) fail(`${label}.values \u5FC5\u987B\u662F\u975E\u7A7A\u6570\u7EC4`);
  const values = [];
  for (let index = 0; index < valueSet.values.length; index += 1) {
    const entry = valueSet.values[index];
    const entryLabel = `${label}.values[${index}]`;
    exactKeys(entry, ["value", "full_name_en", "short_name_en", "full_name_zh", "short_name_zh"], entryLabel);
    validateClosedValue(entry.value, valueSet.value_type, entryLabel);
    for (const key of ["full_name_en", "full_name_zh"]) nonEmptyText(entry[key], `${entryLabel}.${key}`);
    for (const [shortKey, fullKey] of [["short_name_en", "full_name_en"], ["short_name_zh", "full_name_zh"]]) {
      if (entry[shortKey] === null) continue;
      nonEmptyText(entry[shortKey], `${entryLabel}.${shortKey}`);
      if (entry[shortKey] === entry[fullKey]) fail(`${entryLabel}.${shortKey} \u4E0E\u5168\u79F0\u91CD\u590D\uFF0C\u5E94\u6539\u4E3A null`);
    }
    values.push(String(entry.value));
  }
  sortedUnique(values, `${label}.values.value`);
  const allowed = new Set(values);
  for (const forbidden of valueSet.forbidden_values) {
    if (allowed.has(String(forbidden))) fail(`${label} \u628A\u89C4\u8303\u503C\u8BEF\u767B\u8BB0\u4E3A\u5E9F\u5F03\u503C\uFF1A${forbidden}`);
  }
}
function validateContract(contract, label) {
  exactKeys(contract, ["contract_id", "contract_name_zh", "authority", "paths", "fields", "value_sets"], label);
  if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(contract.contract_id)) fail(`${label}.contract_id \u5FC5\u987B\u4F7F\u7528 snake_case`);
  nonEmptyText(contract.contract_name_zh, `${label}.contract_name_zh`);
  if (!authorities.has(contract.authority)) fail(`${label}.authority \u65E0\u6548`);
  sortedUnique(contract.paths, `${label}.paths`);
  sortedUnique(contract.fields, `${label}.fields`);
  sortedUnique(contract.value_sets, `${label}.value_sets`);
  if (contract.paths.length === 0 || contract.fields.length === 0) fail(`${label} \u5FC5\u987B\u58F0\u660E\u8DEF\u5F84\u548C\u5B57\u6BB5`);
}
function validateDictionary(index, shards, jsonFiles = []) {
  exactKeys(index, ["domains", "ignored_paths"], "index.json");
  sortedUnique(index.domains, "index.json.domains", (domain) => domain?.domain_id);
  sortedUnique(index.ignored_paths, "index.json.ignored_paths");
  const indexedFiles = /* @__PURE__ */ new Set(["index.json"]);
  for (const domain of index.domains) {
    exactKeys(domain, ["domain_id", "file"], `index.json.domains.${domain.domain_id ?? "\u672A\u77E5"}`);
    if (!/^[a-z][a-z0-9]*$/.test(domain.domain_id)) fail(`\u9886\u57DF\u6807\u8BC6\u65E0\u6548\uFF1A${domain.domain_id}`);
    if (domain.file !== `${domain.domain_id}.json`) fail(`${domain.domain_id} \u7684\u6587\u4EF6\u5FC5\u987B\u662F ${domain.domain_id}.json`);
    indexedFiles.add(domain.file);
  }
  if (jsonFiles.length > 0) {
    sortedUnique(jsonFiles, "\u6570\u636E\u5B57\u5178 JSON \u6587\u4EF6");
    const expected = [...indexedFiles].sort();
    if (JSON.stringify(jsonFiles) !== JSON.stringify(expected)) fail("\u6570\u636E\u5B57\u5178\u5B58\u5728\u672A\u7D22\u5F15\u6216\u7F3A\u5931\u7684 JSON \u5206\u7247");
  }
  if (shards.length !== index.domains.length) fail("\u6570\u636E\u5B57\u5178\u5206\u7247\u6570\u91CF\u4E0E\u7D22\u5F15\u4E0D\u4E00\u81F4");
  const concepts = /* @__PURE__ */ new Map();
  const fieldNames = /* @__PURE__ */ new Map();
  const valueSets = /* @__PURE__ */ new Map();
  const contracts = /* @__PURE__ */ new Map();
  for (let shardIndex = 0; shardIndex < shards.length; shardIndex += 1) {
    const shard = shards[shardIndex];
    const domain = index.domains[shardIndex];
    exactKeys(shard, ["domain_id", "concepts", "value_sets", "contracts"], domain.file);
    if (shard.domain_id !== domain.domain_id) fail(`${domain.file} \u7684 domain_id \u4E0D\u4E00\u81F4`);
    sortedUnique(shard.concepts, `${domain.file}.concepts`, (entry) => entry?.concept_id);
    sortedUnique(shard.value_sets, `${domain.file}.value_sets`, (entry) => entry?.value_set_id);
    sortedUnique(shard.contracts, `${domain.file}.contracts`, (entry) => entry?.contract_id);
    shard.concepts.forEach((concept, index2) => {
      validateConcept(concept, `${domain.file}.concepts[${index2}]`);
      if (concepts.has(concept.concept_id)) fail(`concept_id \u8DE8\u5206\u7247\u91CD\u590D\uFF1A${concept.concept_id}`);
      if (fieldNames.has(concept.field_name)) fail(`field_name \u8DE8\u5206\u7247\u91CD\u590D\uFF1A${concept.field_name}`);
      concepts.set(concept.concept_id, concept);
      fieldNames.set(concept.field_name, concept.concept_id);
    });
    shard.value_sets.forEach((valueSet, index2) => {
      validateValueSet(valueSet, `${domain.file}.value_sets[${index2}]`);
      if (valueSets.has(valueSet.value_set_id)) fail(`value_set_id \u8DE8\u5206\u7247\u91CD\u590D\uFF1A${valueSet.value_set_id}`);
      valueSets.set(valueSet.value_set_id, valueSet);
    });
    shard.contracts.forEach((contract, index2) => {
      validateContract(contract, `${domain.file}.contracts[${index2}]`);
      if (contracts.has(contract.contract_id)) fail(`contract_id \u8DE8\u5206\u7247\u91CD\u590D\uFF1A${contract.contract_id}`);
      contracts.set(contract.contract_id, contract);
    });
  }
  const referencedFields = /* @__PURE__ */ new Set();
  const referencedValueSets = /* @__PURE__ */ new Set();
  for (const concept of concepts.values()) {
    if (concept.value_set_id && !valueSets.has(concept.value_set_id)) {
      fail(`${concept.concept_id} \u5F15\u7528\u4E86\u4E0D\u5B58\u5728\u7684 value_set_id\uFF1A${concept.value_set_id}`);
    }
  }
  for (const contract of contracts.values()) {
    const expectedValueSets = /* @__PURE__ */ new Set();
    for (const conceptId of contract.fields) {
      if (!concepts.has(conceptId)) fail(`${contract.contract_id} \u5F15\u7528\u4E86\u4E0D\u5B58\u5728\u7684\u5B57\u6BB5\uFF1A${conceptId}`);
      referencedFields.add(conceptId);
      const valueSetId = concepts.get(conceptId).value_set_id;
      if (valueSetId) expectedValueSets.add(valueSetId);
    }
    for (const valueSetId of contract.value_sets) {
      if (!valueSets.has(valueSetId)) fail(`${contract.contract_id} \u5F15\u7528\u4E86\u4E0D\u5B58\u5728\u7684\u503C\u96C6\uFF1A${valueSetId}`);
      referencedValueSets.add(valueSetId);
    }
    if (JSON.stringify([...expectedValueSets].sort()) !== JSON.stringify(contract.value_sets)) {
      fail(`${contract.contract_id} \u7684 value_sets \u5FC5\u987B\u4E0E\u679A\u4E3E\u5B57\u6BB5\u5F15\u7528\u5B8C\u5168\u4E00\u81F4`);
    }
  }
  for (const conceptId of concepts.keys()) {
    if (!referencedFields.has(conceptId)) fail(`\u5B57\u6BB5\u672A\u8FDB\u5165\u4EFB\u4F55\u5951\u7EA6\uFF1A${conceptId}`);
  }
  for (const valueSetId of valueSets.keys()) {
    if (!referencedValueSets.has(valueSetId)) fail(`\u503C\u96C6\u672A\u8FDB\u5165\u4EFB\u4F55\u5951\u7EA6\uFF1A${valueSetId}`);
  }
  return { concepts, valueSets, contracts, ignoredPaths: index.ignored_paths };
}
function loadDictionary() {
  const dictionary = JSON.parse(readFileSync(dictionaryPath, "utf8"));
  exactKeys(dictionary, ["fields", "value_sets", "contracts", "ignored_paths"], "data-dictionary.json");
  sortedUnique(dictionary.fields, "data-dictionary.json.fields", (entry) => entry?.concept_id);
  sortedUnique(dictionary.value_sets, "data-dictionary.json.value_sets", (entry) => entry?.value_set_id);
  sortedUnique(dictionary.contracts, "data-dictionary.json.contracts", (entry) => entry?.contract_id);
  sortedUnique(dictionary.ignored_paths, "data-dictionary.json.ignored_paths");
  const entries = [...dictionary.fields, ...dictionary.value_sets, ...dictionary.contracts];
  const domains = [...new Set(entries.map((entry) => entry?.domain))].sort();
  if (domains.some((domain) => typeof domain !== "string" || !/^[a-z][a-z0-9]*$/.test(domain))) {
    fail("data-dictionary.json \u5B58\u5728\u65E0\u6548\u9886\u57DF\u6807\u8BC6");
  }
  const withoutDomain = (entry) => {
    const { domain: _domain, ...value2 } = entry;
    return value2;
  };
  const index = {
    domains: domains.map((domainId) => ({ domain_id: domainId, file: `${domainId}.json` })),
    ignored_paths: dictionary.ignored_paths
  };
  const shards = domains.map((domainId) => ({
    domain_id: domainId,
    concepts: dictionary.fields.filter((entry) => entry.domain === domainId).map(withoutDomain),
    value_sets: dictionary.value_sets.filter((entry) => entry.domain === domainId).map(withoutDomain),
    contracts: dictionary.contracts.filter((entry) => entry.domain === domainId).map(withoutDomain)
  }));
  return validateDictionary(index, shards);
}
function fieldPatterns(fieldName) {
  const escaped = escapeRegex(fieldName);
  return [
    new RegExp(`['"]${escaped}['"]\\s*:`),
    new RegExp(`\\[['"]${escaped}['"]\\]`),
    new RegExp(`\\b(?:this\\.)?${escaped}\\b\\s*[?!]?\\s*:`),
    new RegExp(`\\bthis\\.${escaped}\\b`),
    new RegExp(`\\b${escaped}\\b\\s*[;=]`),
    new RegExp(`^\\s*${escaped}\\s+(?:BIGINT|BLOB|BOOLEAN|INTEGER|REAL|TEXT)\\b`, "i"),
    new RegExp(`rename(?:_all)?\\s*=\\s*['"]${escaped}['"]`)
  ];
}
function isDeclaredLegacyRead(line, path, fieldName, legacyReads = []) {
  if (!legacyReads.some((entry) => entry.field_name === fieldName && entry.path === path)) return false;
  const escaped = escapeRegex(fieldName);
  return new RegExp(`(?:rename\\s*=\\s*['"]${escaped}['"]|['"]${escaped}['"]\\s*:)`).test(line);
}
function lineUsesFieldName(line, fieldName) {
  return fieldPatterns(fieldName).some((pattern) => pattern.test(line));
}
function markdownUsesFieldName(line, fieldName) {
  if (!/(字段|参数|载荷|协议|API|DTO|JSON|SQL|storage|Storage)/i.test(line)) return false;
  if (/(禁止|不得|废弃|旧名|历史|拒绝|不再|零命中)/.test(line)) return false;
  return new RegExp(`\`${escapeRegex(fieldName)}\``).test(line);
}
function addedFieldNames(line, extension = "") {
  const fields = /* @__PURE__ */ new Map();
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
  if (extension === ".proto") {
    const proto = line.match(/^\s*(?:repeated\s+)?[A-Za-z][A-Za-z0-9_.<>]*\s+([a-z][a-z0-9_]*)\s*=\s*\d+/);
    if (proto) add(proto[1], true);
  }
  if (extension === ".sql") {
    const sql = line.match(/^\s*([a-z][a-z0-9_]*)\s+(?:BIGINT|BLOB|BOOLEAN|INTEGER|REAL|TEXT)\b/i);
    if (sql) add(sql[1], true);
  }
  return [...fields.values()];
}
function addedClosedValues(line, concepts, valueSets) {
  const violations = [];
  for (const concept of concepts.values()) {
    if (!concept.value_set_id) continue;
    const snake = concept.field_name;
    const camel = toCamelCase(snake);
    const field = `(?:['"])?(?:${escapeRegex(snake)}|${escapeRegex(camel)})(?:['"])?`;
    const assignment = new RegExp(`${field}\\s*(?::|={1,3}|!={1,2})\\s*['"]([A-Za-z][A-Za-z0-9_-]*)['"]`, "g");
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
  const output = execFileSync("git", ["ls-files", "-co", "--exclude-standard", "-z"], {
    cwd: repositoryRoot,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024
  });
  return [...new Set(output.split("\0").filter(Boolean))].sort((a, b) => a.localeCompare(b));
}
function baseFieldNames(baseRef) {
  const output = execFileSync("git", ["grep", "-h", "-o", "-I", "-E", "[A-Za-z][A-Za-z0-9_]{2,}", baseRef, "--"], {
    cwd: repositoryRoot,
    encoding: "utf8",
    maxBuffer: 128 * 1024 * 1024
  });
  return new Set(output.split("\n").filter(Boolean).map(toSnakeCase));
}
function changedDictionaryViolations(baseRef, dictionary) {
  execFileSync("git", ["rev-parse", "--verify", baseRef], { cwd: repositoryRoot, stdio: "ignore" });
  const diff = execFileSync("git", ["diff", "--unified=0", "--no-color", baseRef, "--"], {
    cwd: repositoryRoot,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024
  });
  const additions = /* @__PURE__ */ new Map();
  const valueViolations = [];
  let currentPath = "";
  for (const line of diff.split("\n")) {
    if (line.startsWith("+++ b/")) {
      currentPath = line.slice(6);
      continue;
    }
    if (!currentPath || !line.startsWith("+") || line.startsWith("+++")) continue;
    if (!sourceExtensions.test(currentPath) || matchesAny(currentPath, dictionary.ignoredPaths)) continue;
    const added = line.slice(1);
    for (const field of addedFieldNames(added, extname(currentPath))) {
      const value2 = additions.get(field.fieldName) ?? { files: /* @__PURE__ */ new Set(), strong: false };
      value2.files.add(currentPath);
      value2.strong ||= field.strong;
      additions.set(field.fieldName, value2);
    }
    if (!/(?:^|\/)(?:test|tests)(?:\/|$)/.test(currentPath)) {
      for (const violation of addedClosedValues(added, dictionary.concepts, dictionary.valueSets)) {
        valueViolations.push(`${currentPath}: ${violation.conceptId} \u65B0\u589E\u672A\u767B\u8BB0\u95ED\u96C6\u503C ${violation.value}`);
      }
    }
  }
  const registered = new Set([...dictionary.concepts.values()].map((concept) => concept.field_name));
  const existing = baseFieldNames(baseRef);
  const violations = [];
  for (const [fieldName, value2] of [...additions].sort(([left], [right]) => left.localeCompare(right))) {
    if (registered.has(fieldName) || !value2.strong && value2.files.size < 2 || existing.has(fieldName)) continue;
    violations.push(`\u65B0\u589E\u5951\u7EA6\u5B57\u6BB5 ${fieldName} \u5C1A\u672A\u767B\u8BB0\uFF1A${[...value2.files].sort().join(", ")}`);
  }
  return [...violations, ...valueViolations];
}
function checkRepository(baseRef = "") {
  const dictionary = loadDictionary();
  const files = repositoryFiles().filter((path) => sourceExtensions.test(path) && existsSync(join(repositoryRoot, path)) && !matchesAny(path, dictionary.ignoredPaths));
  const violations = [];
  if (baseRef) violations.push(...changedDictionaryViolations(baseRef, dictionary));
  const forbiddenFields = [...dictionary.concepts.values()].flatMap((concept) => concept.forbidden_names.map((forbiddenName) => ({
    canonicalName: concept.field_name,
    forbiddenName,
    legacyReads: concept.legacy_reads ?? [],
    paths: concept.paths,
    patterns: fieldPatterns(forbiddenName)
  })));
  for (const path of files) {
    const candidates = forbiddenFields.filter((field) => !field.paths || matchesAny(path, field.paths));
    if (candidates.length === 0) continue;
    const text = readFileSync(join(repositoryRoot, path), "utf8");
    const present = candidates.filter((field) => text.includes(field.forbiddenName));
    if (present.length === 0) continue;
    const lines = text.split("\n");
    for (let index = 0; index < lines.length; index += 1) {
      for (const field of present) {
        const used = path.endsWith(".md") ? markdownUsesFieldName(lines[index], field.forbiddenName) : field.patterns.some((pattern) => pattern.test(lines[index]));
        if (used && isDeclaredLegacyRead(lines[index], path, field.forbiddenName, field.legacyReads)) continue;
        if (used) violations.push(`${path}:${index + 1}: \u5B57\u6BB5 ${field.forbiddenName} \u5DF2\u5E9F\u5F03\uFF0C\u5E94\u4F7F\u7528 ${field.canonicalName} / ${toCamelCase(field.canonicalName)}`);
      }
    }
  }
  if (violations.length > 0) fail(`\u7EDF\u4E00\u6570\u636E\u5B57\u5178\u68C0\u67E5\u5931\u8D25\uFF1A
  - ${violations.join("\n  - ")}`);
  const values = [...dictionary.valueSets.values()].reduce((sum, valueSet) => sum + valueSet.values.length, 0);
  return { files: files.length, fields: dictionary.concepts.size, valueSets: dictionary.valueSets.size, values };
}
var invokedPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : "";
if (false && import.meta.url === invokedPath) {
  try {
    const baseIndex = process.argv.indexOf("--base-ref");
    if (baseIndex >= 0 && !process.argv[baseIndex + 1]) fail("--base-ref \u7F3A\u5C11 Git ref");
    const result = checkRepository(baseIndex >= 0 ? process.argv[baseIndex + 1] : "");
    console.log(`\u7EDF\u4E00\u6570\u636E\u5B57\u5178\u68C0\u67E5\u901A\u8FC7\uFF1A${result.fields} \u4E2A\u5B57\u6BB5\uFF0C${result.valueSets} \u4E2A\u503C\u96C6\uFF0C${result.values} \u4E2A\u95ED\u96C6\u503C\uFF0C${result.files} \u4E2A\u7B2C\u4E00\u65B9\u6587\u4EF6\u3002`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/data-dictionary.test.mjs
function value(value2, fullNameEn, fullNameZh) {
  return {
    value: value2,
    full_name_en: fullNameEn,
    short_name_en: null,
    full_name_zh: fullNameZh,
    short_name_zh: null
  };
}
function fixture() {
  return {
    index: {
      domains: [{ domain_id: "account", file: "account.json" }],
      ignored_paths: ["**/*.g.dart"]
    },
    shards: [{
      domain_id: "account",
      concepts: [{
        concept_id: "sign_mode",
        field_name: "sign_mode",
        field_name_zh: "\u7B7E\u540D\u6A21\u5F0F",
        authority: "gmb",
        data_type: "enum",
        value_set_id: "sign_mode",
        forbidden_names: ["wallet_mode"],
        legacy_reads: [{ field_name: "wallet_mode", path: "citizenapp/lib/wallet.dart" }]
      }],
      value_sets: [{
        value_set_id: "sign_mode",
        value_set_zh: "\u7B7E\u540D\u6A21\u5F0F",
        authority: "gmb",
        value_type: "string",
        forbidden_values: ["local"],
        values: [value("cold", "Cold Signing", "\u51B7\u7B7E\u540D"), value("hot", "Hot Signing", "\u70ED\u7B7E\u540D")]
      }],
      contracts: [{
        contract_id: "wallet_signing_route",
        contract_name_zh: "\u94B1\u5305\u7B7E\u540D\u8DEF\u7531",
        authority: "gmb",
        paths: ["citizenapp/**"],
        fields: ["sign_mode"],
        value_sets: ["sign_mode"]
      }]
    }]
  };
}
test("snake_case \u53EA\u505A\u673A\u68B0 lowerCamelCase \u8F6C\u6362", () => {
  assert.equal(toCamelCase("account_id"), "accountId");
  assert.equal(toCamelCase("credential_signer_public_key"), "credentialSignerPublicKey");
  assert.equal(toSnakeCase("credentialSignerPublicKey"), "credential_signer_public_key");
});
test("\u8DEF\u5F84\u89C4\u5219\u7CBE\u786E\u652F\u6301\u5355\u5C42\u4E0E\u9012\u5F52\u901A\u914D", () => {
  assert.ok(globToRegex("citizenapp/lib/**").test("citizenapp/lib/a/b.dart"));
  assert.ok(globToRegex("**/*.g.dart").test("citizenapp/lib/isar/a.g.dart"));
  assert.ok(!globToRegex("citizenapp/lib/*.dart").test("citizenapp/lib/a/b.dart"));
});
test("\u5B57\u6BB5\u63D0\u53D6\u53EA\u6536\u5E8F\u5217\u5316\u548C\u8DE8\u6587\u4EF6\u5951\u7EA6\u5F62\u6001", () => {
  assert.deepEqual(addedFieldNames("value['account_id']", ".dart"), [{ fieldName: "account_id", strong: true }]);
  assert.deepEqual(addedFieldNames("accountId: value,", ".dart"), [{ fieldName: "account_id", strong: false }]);
  assert.deepEqual(addedFieldNames("final value = input;", ".dart"), []);
});
test("\u5B57\u6BB5\u547D\u4E2D\u4E0D\u8BEF\u4F24\u76F8\u540C\u8BCD\u6839\u51FD\u6570\u540D", () => {
  assert.ok(lineUsesFieldName("final value = json['wallet_account'];", "wallet_account"));
  assert.ok(lineUsesFieldName("wallet_account: input,", "wallet_account"));
  assert.ok(!lineUsesFieldName("resolve_wallet_account(input);", "wallet_account"));
});
test("\u5E9F\u5F03\u5B57\u6BB5\u53EA\u5141\u8BB8\u5728\u767B\u8BB0\u8DEF\u5F84\u4F5C\u4E3A\u5355\u5411\u8BFB\u53D6\u952E", () => {
  const reads = [{ field_name: "wallet_mode", path: "citizenapp/lib/wallet.dart" }];
  assert.ok(isDeclaredLegacyRead('#[serde(rename = "wallet_mode")]', "citizenapp/lib/wallet.dart", "wallet_mode", reads));
  assert.ok(isDeclaredLegacyRead('r#"{"wallet_mode":null}"#', "citizenapp/lib/wallet.dart", "wallet_mode", reads));
  assert.ok(!isDeclaredLegacyRead("wallet_mode: value,", "citizenapp/lib/wallet.dart", "wallet_mode", reads));
  assert.ok(!isDeclaredLegacyRead('"wallet_mode": value,', "citizenapp/lib/other.dart", "wallet_mode", reads));
});
test("\u6587\u6863\u5141\u8BB8\u660E\u786E\u7981\u6B62\u65E7\u5B57\u6BB5\u4F46\u62D2\u7EDD\u5F53\u524D\u5951\u7EA6\u4F7F\u7528", () => {
  assert.ok(markdownUsesFieldName("API \u5B57\u6BB5 `wallet_account` \u7528\u4E8E\u6388\u6743\u3002", "wallet_account"));
  assert.ok(!markdownUsesFieldName("API \u5B57\u6BB5\u7981\u6B62\u6062\u590D `wallet_account`\u3002", "wallet_account"));
});
test("\u6570\u636E\u5B57\u5178\u8981\u6C42\u5B57\u6BB5\u3001\u503C\u96C6\u548C\u5951\u7EA6\u53CC\u5411\u5F15\u7528\u5B8C\u6574", () => {
  const { index, shards } = fixture();
  const result = validateDictionary(index, shards);
  assert.equal(result.concepts.size, 1);
  assert.equal(result.valueSets.size, 1);
  assert.throws(() => validateDictionary(index, [{ ...shards[0], contracts: [] }]), /字段未进入任何契约/);
});
test("\u6570\u636E\u5B57\u5178\u62D2\u7EDD\u91CD\u590D\u5B57\u6BB5\u3001\u5047\u7B80\u79F0\u548C\u52A8\u6001\u503C", () => {
  const { index, shards } = fixture();
  const duplicate = structuredClone(shards);
  duplicate[0].concepts.push({ ...duplicate[0].concepts[0], concept_id: "second_sign_mode" });
  assert.throws(() => validateDictionary(index, duplicate), /field_name 跨分片重复|字典序/);
  const fakeShort = structuredClone(shards);
  fakeShort[0].value_sets[0].values[0].short_name_en = "Cold Signing";
  assert.throws(() => validateDictionary(index, fakeShort), /与全称重复/);
  const dynamic = structuredClone(shards);
  dynamic[0].value_sets[0].values[0].value = "0x".padEnd(66, "a");
  assert.throws(() => validateDictionary(index, dynamic), /动态 URL、哈希、ID 或时间/);
});
test("\u95ED\u96C6\u5B57\u6BB5\u65B0\u589E\u503C\u5FC5\u987B\u5148\u8FDB\u5165\u5BF9\u5E94\u503C\u96C6", () => {
  const { index, shards } = fixture();
  const dictionary = validateDictionary(index, shards);
  assert.deepEqual(addedClosedValues("signMode: 'hot'", dictionary.concepts, dictionary.valueSets), []);
  assert.deepEqual(addedClosedValues("signMode: 'external'", dictionary.concepts, dictionary.valueSets), [
    { conceptId: "sign_mode", value: "external" }
  ]);
  assert.deepEqual(addedClosedValues("signMode: 'hot', label: '\u672C\u673A'", dictionary.concepts, dictionary.valueSets), []);
});

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/github-release.test.mjs
import assert2 from "node:assert/strict";
import test2 from "node:test";

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/citizenapp/release-ios.mjs github-release
import { lstatSync } from "node:fs";
import { basename } from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL as pathToFileURL2 } from "node:url";
var SHA_PATTERN = /^[0-9a-f]{40}$/;
var REPOSITORY_PATTERN = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
var TAG_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/;
var READ_ATTEMPTS = 7;
var READ_RETRY_MS = 1e4;
function required2(condition, message) {
  if (!condition) throw new Error(message);
}
function gh(args, options = {}) {
  const run = options.run || spawnSync;
  const wait = options.wait || ((milliseconds) => {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
  });
  const attempts = options.retryRead ? READ_ATTEMPTS : 1;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const result = run("gh", args, {
      encoding: "utf8",
      input: options.input,
      env: process.env,
      maxBuffer: 16 * 1024 * 1024
    });
    if (result.error) throw result.error;
    if (result.status === 0) return String(result.stdout || "").trim();
    const detail = String(result.stderr || result.stdout || "").trim();
    if (options.notFound && /(?:HTTP 404|Not Found)/i.test(detail)) return null;
    const integrationDenied = /HTTP 403:\s*Resource not accessible by integration/i.test(detail);
    const retryable = options.retryRead && (integrationDenied || /HTTP 5\d\d/i.test(detail));
    if (!retryable || attempt === attempts) {
      throw new Error(detail || `gh \u6267\u884C\u5931\u8D25\uFF0C\u9000\u51FA\u7801 ${result.status}`);
    }
    console.error(`[GitHub] Release \u53EA\u8BFB\u63A5\u53E3\u6682\u65F6\u4E0D\u53EF\u7528\uFF0C${READ_RETRY_MS / 1e3} \u79D2\u540E\u91CD\u8BD5\uFF08${attempt}/${attempts - 1}\uFF09`);
    wait(READ_RETRY_MS);
  }
  throw new Error("GitHub Release \u53EA\u8BFB\u63A5\u53E3\u91CD\u8BD5\u72B6\u6001\u5F02\u5E38");
}
function json(output, context) {
  try {
    return JSON.parse(output);
  } catch {
    throw new Error(`${context}\u8FD4\u56DE\u4E86\u65E0\u6548 JSON`);
  }
}
function createClient() {
  return {
    async listReleases(repository) {
      const releases = [];
      for (let page = 1; page <= 100; page += 1) {
        const output = gh(["api", `repos/${repository}/releases?per_page=100&page=${page}`], {
          retryRead: true
        });
        const values = json(output, "GitHub Release \u5217\u8868");
        required2(Array.isArray(values), "GitHub Release \u5217\u8868\u683C\u5F0F\u65E0\u6548");
        releases.push(...values);
        if (values.length < 100) return releases;
      }
      throw new Error("GitHub Release \u5217\u8868\u8D85\u8FC7\u5B89\u5168\u5206\u9875\u4E0A\u9650");
    },
    async getTag(repository, tag) {
      const output = gh(["api", `repos/${repository}/git/ref/tags/${encodeURIComponent(tag)}`], {
        notFound: true,
        retryRead: true
      });
      return output === null ? null : json(output, "GitHub Tag");
    },
    async getTagObject(repository, objectSHA) {
      return json(gh(["api", `repos/${repository}/git/tags/${objectSHA}`], { retryRead: true }), "GitHub Tag \u5BF9\u8C61");
    },
    async createTag(repository, tag, releaseSHA) {
      const payload = JSON.stringify({ ref: `refs/tags/${tag}`, sha: releaseSHA });
      gh(["api", "--method", "POST", `repos/${repository}/git/refs`, "--input", "-"], {
        input: payload
      });
    },
    async createDraft(input2) {
      const args = [
        "release",
        "create",
        input2.tag,
        "--repo",
        input2.repository,
        "--verify-tag",
        "--draft",
        "--title",
        input2.title
      ];
      if (input2.notes) args.push("--notes", input2.notes);
      else args.push("--notes-file", input2.notesFile);
      args.push(...input2.assets.map((asset) => asset.path));
      gh(args);
    },
    async getRelease(repository, releaseId) {
      return json(gh(["api", `repos/${repository}/releases/${releaseId}`], { retryRead: true }), "GitHub Release");
    },
    async getReleaseByTag(repository, tag) {
      const output = gh(
        ["api", `repos/${repository}/releases/tags/${encodeURIComponent(tag)}`],
        { notFound: true, retryRead: true }
      );
      return output === null ? null : json(output, "GitHub Tag Release");
    },
    async publish(repository, releaseId, latest) {
      const payload = JSON.stringify({ draft: false, make_latest: latest ? "true" : "false" });
      gh(["api", "--method", "PATCH", `repos/${repository}/releases/${releaseId}`, "--input", "-"], {
        input: payload
      });
    },
    async deleteRelease(repository, releaseId) {
      gh(["api", "--method", "DELETE", `repos/${repository}/releases/${releaseId}`]);
    },
    async deleteTag(repository, tag) {
      gh(["api", "--method", "DELETE", `repos/${repository}/git/refs/tags/${encodeURIComponent(tag)}`]);
    },
    async wait() {
      await new Promise((resolve4) => setTimeout(resolve4, 1e3));
    }
  };
}
function verifyAssets(release2, assets) {
  required2(Array.isArray(release2.assets), "GitHub Release \u8D44\u4EA7\u683C\u5F0F\u65E0\u6548");
  required2(release2.assets.length === assets.length, "GitHub Release \u8D44\u4EA7\u6570\u91CF\u4E0D\u7B26");
  const actual = /* @__PURE__ */ new Map();
  for (const asset of release2.assets) {
    required2(typeof asset?.name === "string" && !actual.has(asset.name), "GitHub Release \u8D44\u4EA7\u540D\u79F0\u91CD\u590D\u6216\u65E0\u6548");
    actual.set(asset.name, asset);
  }
  for (const expected of assets) {
    const asset = actual.get(expected.name);
    required2(asset, `GitHub Release \u7F3A\u5C11\u8D44\u4EA7\uFF1A${expected.name}`);
    required2(asset.state === "uploaded", `GitHub Release \u8D44\u4EA7\u672A\u5B8C\u6210\u4E0A\u4F20\uFF1A${expected.name}`);
    required2(asset.size === expected.size, `GitHub Release \u8D44\u4EA7\u5927\u5C0F\u4E0D\u7B26\uFF1A${expected.name}`);
  }
}
function verifyRelease(release2, input2, draft) {
  required2(Number.isSafeInteger(release2?.id) && release2.id > 0, "GitHub Release id \u65E0\u6548");
  required2(release2.tag_name === input2.tag, "GitHub \u7248\u672C Tag \u4E0D\u7B26");
  required2(release2.name === input2.title, "GitHub Release \u6807\u9898\u4E0D\u7B26");
  required2(release2.draft === draft, draft ? "GitHub Release \u4E0D\u662F\u8349\u7A3F" : "GitHub Release \u5C1A\u672A\u56FA\u5316");
  verifyAssets(release2, input2.assets);
}
async function findDraft(client2, input2) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const matches = (await client2.listReleases(input2.repository)).filter((value2) => value2?.tag_name === input2.tag && value2?.name === input2.title && value2?.draft === true);
    required2(matches.length <= 1, `\u53D1\u73B0\u591A\u4E2A\u540C\u540D GitHub Release\uFF1A${input2.tag}`);
    if (matches.length === 1) return matches[0];
    await client2.wait();
  }
  return null;
}
async function versionTagCommit(client2, input2) {
  const reference = await client2.getTag(input2.repository, input2.tag);
  required2(reference?.ref === `refs/tags/${input2.tag}` && SHA_PATTERN.test(String(reference?.object?.sha || "")), "\u6B63\u5F0F\u7248\u672C Tag \u4E0D\u5B58\u5728\u6216\u65E0\u6548");
  if (reference.object.type === "commit") {
    required2(reference.object.sha === input2.releaseSHA, "\u6B63\u5F0F\u7248\u672C Tag \u672A\u6307\u5411\u672C\u6B21 Release \u63D0\u4EA4");
    return reference.object.sha;
  }
  required2(reference.object.type === "tag", "\u6B63\u5F0F\u7248\u672C Tag \u7C7B\u578B\u65E0\u6548");
  const object = await client2.getTagObject(input2.repository, reference.object.sha);
  required2(object?.tag === input2.tag && object?.object?.type === "commit" && object.object.sha === input2.releaseSHA, "\u6B63\u5F0F\u7248\u672C Tag \u672A\u6307\u5411\u672C\u6B21 Release \u63D0\u4EA4");
  return object.object.sha;
}
async function release(input2, client2 = createClient()) {
  let releaseId = null;
  let transactionStarted = false;
  let reuseExistingTag = false;
  const existing = (await client2.listReleases(input2.repository)).filter((value2) => value2?.tag_name === input2.tag);
  const published = existing.filter((value2) => value2?.draft === false);
  required2(published.length === 0, `\u6B63\u5F0F Release \u5DF2\u5B58\u5728\uFF0C\u7981\u6B62\u8986\u76D6\uFF1A${input2.tag}`);
  const drafts = existing.filter((value2) => value2?.draft === true);
  required2(drafts.length <= 1, `\u53D1\u73B0\u591A\u4E2A\u540C Tag \u8349\u7A3F Release\uFF1A${input2.tag}`);
  if (drafts.length === 1) {
    const draftTag = await client2.getTag(input2.repository, input2.tag);
    if (draftTag) {
      await versionTagCommit(client2, input2);
    } else {
      required2(
        drafts[0]?.target_commitish === input2.sourceSHA,
        "\u9057\u7559\u8349\u7A3F\u672A\u7ED1\u5B9A\u672C\u6B21\u6210\u529F CI \u6E90\u63D0\u4EA4\uFF0C\u7981\u6B62\u6E05\u7406"
      );
    }
    await client2.deleteRelease(input2.repository, drafts[0].id);
    if (draftTag) await client2.deleteTag(input2.repository, input2.tag);
  } else {
    const staleTag = await client2.getTag(input2.repository, input2.tag);
    if (staleTag) {
      await versionTagCommit(client2, input2);
      reuseExistingTag = true;
    }
  }
  try {
    transactionStarted = true;
    if (!reuseExistingTag) await client2.createTag(input2.repository, input2.tag, input2.releaseSHA);
    await client2.createDraft(input2);
    let draft = await findDraft(client2, input2);
    required2(draft, `\u65E0\u6CD5\u53D6\u5F97\u65B0\u5EFA\u8349\u7A3F Release\uFF1A${input2.tag}`);
    releaseId = draft.id;
    draft = await client2.getRelease(input2.repository, releaseId);
    verifyRelease(draft, input2, true);
    await client2.publish(input2.repository, releaseId, input2.latest);
    const result = await client2.getRelease(input2.repository, releaseId);
    verifyRelease(result, input2, false);
    const byTag = await client2.getReleaseByTag(input2.repository, input2.tag);
    required2(byTag?.id === releaseId, "\u7248\u672C Tag \u672A\u5173\u8054\u672C\u6B21 GitHub Release");
    await versionTagCommit(client2, input2);
    console.log(`\u6B63\u5F0F Release \u4E0E\u552F\u4E00\u7248\u672C Tag \u5DF2\u56FA\u5316\uFF1A${input2.tag}`);
    return result;
  } catch (error) {
    const cleanupErrors = [];
    if (transactionStarted) {
      try {
        if (releaseId) await client2.deleteRelease(input2.repository, releaseId);
        else {
          const draft = await findDraft(client2, input2);
          if (draft) await client2.deleteRelease(input2.repository, draft.id);
        }
      } catch (cleanupError) {
        cleanupErrors.push(`\u8349\u7A3F\u56DE\u6EDA\u5931\u8D25\uFF1A${cleanupError.message}`);
      }
      try {
        const tag = await client2.getTag(input2.repository, input2.tag);
        if (tag) {
          await versionTagCommit(client2, input2);
          await client2.deleteTag(input2.repository, input2.tag);
        }
      } catch (cleanupError) {
        cleanupErrors.push(`Tag \u56DE\u6EDA\u5931\u8D25\uFF1A${cleanupError.message}`);
      }
    }
    const suffix = cleanupErrors.length > 0 ? `\uFF1B${cleanupErrors.join("\uFF1B")}` : "";
    throw new Error(`${error.message}${suffix}`);
  }
}
function parseArgs(argv, environment = process.env) {
  const values = /* @__PURE__ */ new Map();
  const assetIndex = argv.indexOf("--assets");
  required2(assetIndex >= 0 && assetIndex < argv.length - 1, "\u7F3A\u5C11 --assets");
  const assetPaths = argv.slice(assetIndex + 1);
  const optionArgs = argv.slice(0, assetIndex);
  required2(optionArgs.length % 2 === 0, "Release \u53C2\u6570\u5FC5\u987B\u6210\u5BF9\u63D0\u4F9B");
  for (let index = 0; index < optionArgs.length; index += 2) {
    const key = optionArgs[index];
    required2(/^--[a-z-]+$/.test(key) && !values.has(key), `Release \u53C2\u6570\u65E0\u6548\u6216\u91CD\u590D\uFF1A${key}`);
    values.set(key, optionArgs[index + 1]);
  }
  const repository = environment.GITHUB_REPOSITORY;
  const releaseSHA = environment.GITHUB_SHA;
  const tag = values.get("--tag");
  const sourceSHA = values.get("--source-sha");
  const title = values.get("--title");
  const notes = values.get("--notes");
  const notesFile = values.get("--notes-file");
  const latestValue = values.get("--latest");
  required2(REPOSITORY_PATTERN.test(repository || ""), "GITHUB_REPOSITORY \u65E0\u6548");
  required2(SHA_PATTERN.test(releaseSHA || ""), "Release workflow \u63D0\u4EA4\u65E0\u6548");
  required2(TAG_PATTERN.test(tag || ""), "\u7248\u672C Tag \u65E0\u6548");
  required2(SHA_PATTERN.test(sourceSHA || ""), "Release \u6E90\u63D0\u4EA4\u65E0\u6548");
  required2(typeof title === "string" && title.trim() === title && title.length > 0, "Release \u6807\u9898\u65E0\u6548");
  required2(Boolean(notes) !== Boolean(notesFile), "\u5FC5\u987B\u4E14\u53EA\u80FD\u63D0\u4F9B --notes \u6216 --notes-file");
  required2(latestValue === "true" || latestValue === "false", "--latest \u53EA\u5141\u8BB8 true \u6216 false");
  const assets = assetPaths.map((path) => {
    const value2 = lstatSync(path);
    required2(value2.isFile() && value2.size > 0, `Release \u8D44\u4EA7\u4E0D\u662F\u975E\u7A7A\u666E\u901A\u6587\u4EF6\uFF1A${path}`);
    return { path, name: basename(path), size: value2.size };
  });
  required2(new Set(assets.map((asset) => asset.name)).size === assets.length, "Release \u8D44\u4EA7\u6587\u4EF6\u540D\u91CD\u590D");
  return {
    repository,
    releaseSHA,
    tag,
    sourceSHA,
    title,
    notes,
    notesFile,
    latest: latestValue === "true",
    assets
  };
}
if (false && process.argv[1] && import.meta.url === pathToFileURL2(process.argv[1]).href) {
  try {
    await release(parseArgs(process.argv.slice(2)));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/github-release.test.mjs
function input() {
  return {
    repository: "ChineseFederation/GMB",
    releaseSHA: "7a46f2f7c2e58a2672961a2b66d4e882b725f560",
    tag: `citizenserve-cloudflare-v${["1", "0", "1"].join(".")}`,
    sourceSHA: "6f2c0e5355156db2fd36216ab7f928f8090ab3e0",
    title: "\u516C\u6C11\u540E\u7AEF \xB7 Release \xB7 Cloudflare",
    notes: "\u516C\u6C11\u540E\u7AEF 1.0.1\u3002",
    latest: false,
    assets: [
      { path: "/candidate/archive.tgz", name: "archive.tgz", size: 12 },
      { path: "/candidate/SHA256SUMS", name: "SHA256SUMS", size: 64 }
    ]
  };
}
function client(options = {}) {
  const calls = [];
  const tagTargets = [];
  const value2 = input();
  let created = false;
  let published = false;
  let tagExists = options.staleDraft === true && options.staleDraftWithoutTag !== true || options.staleTag === true;
  let staleDraft = options.staleDraft === true;
  const remote = (id = 42, draft = !published) => ({
    id,
    name: value2.title,
    tag_name: value2.tag,
    target_commitish: value2.sourceSHA,
    draft,
    assets: value2.assets.map((asset, index) => ({
      name: asset.name,
      size: index === 0 && options.badSize ? asset.size + 1 : asset.size,
      state: "uploaded"
    }))
  });
  return {
    calls,
    tagTargets,
    async listReleases() {
      calls.push("list");
      if (options.publishedExisting) return [remote(7, false)];
      if (staleDraft) return [remote(7, true)];
      return created ? [remote()] : [];
    },
    async getTag() {
      calls.push("tag");
      return tagExists ? { ref: `refs/tags/${value2.tag}`, object: { type: "commit", sha: value2.releaseSHA } } : null;
    },
    async getTagObject() {
      calls.push("tag-object");
      return { tag: value2.tag, object: { type: "commit", sha: value2.releaseSHA } };
    },
    async createTag(_repository, _tag, targetSHA) {
      calls.push("create-tag");
      tagTargets.push(targetSHA);
      if (options.tagFailure) throw new Error("Tag \u521B\u5EFA\u5931\u8D25");
      tagExists = true;
    },
    async createDraft() {
      calls.push("create");
      created = true;
      if (options.createFailure) throw new Error("\u8D44\u4EA7\u4E0A\u4F20\u5931\u8D25");
    },
    async getRelease() {
      calls.push("get");
      return remote();
    },
    async getReleaseByTag() {
      calls.push("by-tag");
      return remote();
    },
    async publish() {
      calls.push("publish");
      published = true;
      tagExists = true;
    },
    async deleteRelease() {
      calls.push("delete-release");
      staleDraft = false;
      created = false;
    },
    async deleteTag() {
      calls.push("delete-tag");
      tagExists = false;
    },
    async wait() {
      calls.push("wait");
    }
  };
}
test2("Release \u4E8B\u52A1\u5148\u521B\u5EFA\u552F\u4E00 Tag\uFF0C\u6B63\u5F0F\u8D44\u4EA7\u5B8C\u6210\u540E\u53D1\u5E03", async () => {
  const fake = client();
  const result = await release(input(), fake);
  assert2.equal(result.draft, false);
  assert2.ok(fake.calls.indexOf("create-tag") < fake.calls.indexOf("create"));
  assert2.equal(fake.calls.includes("create"), true);
  assert2.equal(fake.calls.includes("publish"), true);
  assert2.equal(fake.calls.includes("delete-tag"), false);
  assert2.deepEqual(fake.tagTargets, [input().releaseSHA]);
  assert2.notEqual(input().releaseSHA, input().sourceSHA);
});
test2("\u8349\u7A3F\u8D44\u4EA7\u4E0D\u4E00\u81F4\u65F6\u56DE\u6EDA\u8349\u7A3F\u4E0E\u4E8B\u52A1 Tag", async () => {
  const fake = client({ badSize: true });
  await assert2.rejects(release(input(), fake), /资产大小不符/);
  assert2.equal(fake.calls.includes("publish"), false);
  assert2.equal(fake.calls.includes("delete-release"), true);
  assert2.equal(fake.calls.includes("delete-tag"), true);
});
test2("\u4E0B\u4E00\u6761\u540C\u7248\u672C Release \u5148\u56DE\u6EDA\u4E0A\u6B21\u4E2D\u65AD\u9057\u7559\u8349\u7A3F\u4E0E Tag", async () => {
  const fake = client({ staleDraft: true });
  await release(input(), fake);
  assert2.ok(fake.calls.filter((value2) => value2 === "delete-release").length >= 1);
  assert2.ok(fake.calls.filter((value2) => value2 === "delete-tag").length >= 1);
  assert2.equal(fake.calls.includes("create"), true);
});
test2("\u4E0B\u4E00\u6761\u540C\u7248\u672C Release \u53EF\u56DE\u6EDA\u5C1A\u672A\u521B\u5EFA Tag \u7684\u9057\u7559\u8349\u7A3F", async () => {
  const fake = client({ staleDraft: true, staleDraftWithoutTag: true });
  await release(input(), fake);
  assert2.ok(fake.calls.filter((value2) => value2 === "delete-release").length >= 1);
  assert2.equal(fake.calls.includes("delete-tag"), false);
  assert2.equal(fake.calls.includes("publish"), true);
});
test2("\u590D\u7528\u4E0A\u6B21\u4E8B\u52A1\u9884\u5EFA\u4E14\u51C6\u786E\u6307\u5411 Release workflow \u7684 Tag", async () => {
  const fake = client({ staleTag: true });
  await release(input(), fake);
  assert2.equal(fake.calls.includes("create-tag"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
  assert2.equal(fake.calls.includes("publish"), true);
});
test2("\u5DF2\u6709\u6B63\u5F0F Release \u65F6\u62D2\u7EDD\u8986\u76D6", async () => {
  const fake = client({ publishedExisting: true });
  await assert2.rejects(release(input(), fake), /正式 Release 已存在/);
  assert2.equal(fake.calls.includes("create"), false);
  assert2.equal(fake.calls.includes("delete-release"), false);
});
test2("\u521B\u5EFA\u547D\u4EE4\u90E8\u5206\u5931\u8D25\u65F6\u56DE\u6EDA\u53EF\u80FD\u5DF2\u7ECF\u751F\u6210\u7684\u8349\u7A3F\u4E14\u4E0D\u5360\u7528 Tag", async () => {
  const fake = client({ createFailure: true });
  await assert2.rejects(release(input(), fake), /资产上传失败/);
  assert2.equal(fake.calls.includes("delete-release"), true);
  assert2.equal(fake.calls.includes("delete-tag"), true);
  assert2.equal(fake.calls.includes("publish"), false);
});
test2("Release \u53EA\u8BFB\u63A5\u53E3\u5BF9 GitHub integration \u4E34\u65F6 403 \u6709\u9650\u91CD\u8BD5", () => {
  let attempts = 0;
  const delays = [];
  const output = gh(["api", "repos/ChineseFederation/GMB/releases"], {
    retryRead: true,
    run() {
      attempts += 1;
      if (attempts < 3) {
        return { status: 1, stdout: "", stderr: "HTTP 403: Resource not accessible by integration" };
      }
      return { status: 0, stdout: "[]\n", stderr: "" };
    },
    wait(milliseconds) {
      delays.push(milliseconds);
    }
  });
  assert2.equal(output, "[]");
  assert2.equal(attempts, 3);
  assert2.deepEqual(delays, [1e4, 1e4]);
});
test2("Release \u5199\u64CD\u4F5C\u9047\u5230 integration 403 \u4E0D\u81EA\u52A8\u91CD\u653E", () => {
  let attempts = 0;
  assert2.throws(() => gh(["release", "create"], {
    run() {
      attempts += 1;
      return { status: 1, stdout: "", stderr: "HTTP 403: Resource not accessible by integration" };
    },
    wait() {
      throw new Error("\u5199\u64CD\u4F5C\u4E0D\u5F97\u7B49\u5F85\u91CD\u8BD5");
    }
  }), /Resource not accessible by integration/);
  assert2.equal(attempts, 1);
});
test2("Tag \u521B\u5EFA\u5931\u8D25\u65F6\u4E0D\u521B\u5EFA\u8349\u7A3F\u4E14\u4E0D\u5360\u7528\u7248\u672C\u53F7", async () => {
  const fake = client({ tagFailure: true });
  await assert2.rejects(release(input(), fake), /Tag 创建失败/);
  assert2.equal(fake.calls.includes("create"), false);
  assert2.equal(fake.calls.includes("publish"), false);
});

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/version-tag-contract.test.mjs
import assert5 from "node:assert/strict";
import { existsSync as existsSync7, readdirSync, readFileSync as readFileSync7 } from "node:fs";
import test5 from "node:test";

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/version-tag-contract.mjs
import { execFileSync as execFileSync2 } from "node:child_process";
import { readFileSync as readFileSync5 } from "node:fs";
import { pathToFileURL as pathToFileURL3 } from "node:url";
var semanticVersionPattern = /^(0|[1-9]\d*)\.(0|[1-9]\d?)\.(0|[1-9]\d?)$/;
var tagPrefixPattern = /^[a-z0-9][a-z0-9-]*-v$/;
var sourceSHAPattern = /^[0-9a-f]{40}$/;
var workflowFilePattern = /^(?:[a-z0-9-]+\/)*[a-z0-9-]+\.ya?ml$/;
function validateWorkflowFileName(value2) {
  if (!workflowFilePattern.test(String(value2))) throw new Error("workflow \u65E0\u6548");
  return value2;
}
function parseSemanticVersion(value2) {
  const match = semanticVersionPattern.exec(String(value2));
  if (!match) throw new Error(`\u8F6F\u4EF6\u7248\u672C\u5FC5\u987B\u5F62\u5982 a.b.c \u4E14 b\u3001c \u4E0D\u8D85\u8FC7 99\uFF1A${value2}`);
  return match.slice(1).map(Number);
}
function compareSemanticVersions(left, right) {
  const a = parseSemanticVersion(left);
  const b = parseSemanticVersion(right);
  for (let index = 0; index < 3; index += 1) {
    if (a[index] !== b[index]) return a[index] - b[index];
  }
  return 0;
}
function nextSemanticVersion(value2) {
  let [major, minor, patch] = parseSemanticVersion(value2);
  patch += 1;
  if (patch > 99) {
    patch = 0;
    minor += 1;
  }
  if (minor > 99) {
    minor = 0;
    major += 1;
  }
  return `${major}.${minor}.${patch}`;
}
function expectedSemanticCandidate(seed, successfulVersions) {
  parseSemanticVersion(seed);
  const normalized = [...new Set(successfulVersions.map((value2) => {
    parseSemanticVersion(value2);
    return value2;
  }))].sort(compareSemanticVersions);
  return nextSemanticVersion(normalized.length === 0 ? seed : normalized.at(-1));
}
function parseArguments(argv) {
  const [command, ...rest] = argv;
  if (!command) throw new Error("\u7F3A\u5C11\u7248\u672C\u547D\u4EE4");
  const values = {};
  for (let index = 0; index < rest.length; index += 2) {
    const key = rest[index];
    const value2 = rest[index + 1];
    if (!key?.startsWith("--") || value2 === void 0) throw new Error(`\u53C2\u6570\u683C\u5F0F\u65E0\u6548\uFF1A${key ?? ""}`);
    const name = key.slice(2);
    if (Object.hasOwn(values, name)) throw new Error(`\u53C2\u6570\u91CD\u590D\uFF1A${key}`);
    values[name] = value2;
  }
  return { command, values };
}
function requireExactKeys(values, required4, optional = []) {
  const allowed = /* @__PURE__ */ new Set([...required4, ...optional]);
  for (const key of Object.keys(values)) {
    if (!allowed.has(key)) throw new Error(`\u4E0D\u652F\u6301\u7684\u53C2\u6570\uFF1A--${key}`);
  }
  for (const key of required4) {
    if (!Object.hasOwn(values, key) || values[key] === "") throw new Error(`\u7F3A\u5C11\u53C2\u6570\uFF1A--${key}`);
  }
}
function ghJSON(path) {
  const output = execFileSync2("gh", ["api", path], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"]
  });
  try {
    return JSON.parse(output);
  } catch {
    throw new Error(`GitHub API \u8FD4\u56DE\u4E86\u65E0\u6548 JSON\uFF1A${path}`);
  }
}
function readSeed(kind, path) {
  const text = readFileSync5(path, "utf8");
  if (kind === "json") {
    const value2 = JSON.parse(text)?.version;
    parseSemanticVersion(value2);
    return value2;
  }
  if (kind === "pubspec") {
    const matches = [...text.matchAll(/^version:\s*([^+\s]+)(?:\+\d+)?\s*$/gm)];
    if (matches.length !== 1) throw new Error(`pubspec \u8F6F\u4EF6\u7248\u672C\u771F\u6E90\u4E0D\u552F\u4E00\uFF1A${path}`);
    parseSemanticVersion(matches[0][1]);
    return matches[0][1];
  }
  throw new Error(`\u4E0D\u652F\u6301\u7684\u7248\u672C\u771F\u6E90\u7C7B\u578B\uFF1A${kind}`);
}
function publishedSemanticVersions(prefix) {
  if (!tagPrefixPattern.test(prefix)) throw new Error("Tag \u524D\u7F00\u65E0\u6548");
  const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(`^${escaped}(${semanticVersionPattern.source.slice(1, -1)})$`);
  const versions = [];
  for (let page = 1; page <= 100; page += 1) {
    const releases = ghJSON(`repos/{owner}/{repo}/releases?per_page=100&page=${page}`);
    if (!Array.isArray(releases)) throw new Error("GitHub Release \u5217\u8868\u683C\u5F0F\u65E0\u6548");
    for (const release2 of releases) {
      if (release2?.draft === true || release2?.prerelease === true) continue;
      const tag = String(release2?.tag_name || "");
      if (!tag.startsWith(prefix)) continue;
      const match = pattern.exec(tag);
      if (!match) throw new Error(`\u540C\u524D\u7F00\u6B63\u5F0F Release Tag \u4E0D\u7B26\u5408\u7EDF\u4E00\u7248\u672C\u5951\u7EA6\uFF1A${tag}`);
      parseSemanticVersion(match[1]);
      versions.push(match[1]);
    }
    if (releases.length < 100) return versions;
  }
  throw new Error("GitHub Release \u5217\u8868\u8D85\u8FC7\u5B89\u5168\u5206\u9875\u4E0A\u9650");
}
function validateIdentity(values) {
  if (!/^[a-z][a-z0-9-]*$/.test(values["product-id"])) throw new Error("product_id \u65E0\u6548");
  if (!/^[a-z][a-z0-9-]*$/.test(values.target)) throw new Error("target \u65E0\u6548");
  validateWorkflowFileName(values.workflow);
  if (!sourceSHAPattern.test(values["source-sha"])) throw new Error("source_sha \u65E0\u6548");
  if (!/^[1-9]\d*$/.test(values["ci-run-id"])) throw new Error("ci_run_id \u65E0\u6548");
}
function verifySuccessfulCIRun(values) {
  validateIdentity(values);
  const run = ghJSON(`repos/{owner}/{repo}/actions/runs/${values["ci-run-id"]}`);
  if (run.status !== "completed" || run.conclusion !== "success" || run.event !== "workflow_dispatch" || run.head_branch !== "main" || run.head_sha !== values["source-sha"] || !String(run.path || "").endsWith(`/${values.workflow}`)) {
    throw new Error("Release \u6765\u6E90\u4E0D\u662F\u540C\u4EA7\u54C1\u3001\u540C\u7AEF\u3001\u540C workflow \u7684\u6210\u529F CI");
  }
  const head = execFileSync2("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  if (head !== values["source-sha"]) throw new Error(`checkout \u4E0E source_sha \u4E0D\u4E00\u81F4\uFF1A${head}`);
}
function verifyRuntimeVersion(values) {
  const specVersion = Number(values["spec-version"]);
  if (!/^[1-9]\d*$/.test(values["spec-version"]) || !Number.isSafeInteger(specVersion) || specVersion > 2 ** 32 - 1) {
    throw new Error("spec_version \u65E0\u6548");
  }
}
function printNextSemanticRelease(values) {
  requireExactKeys(values, ["prefix", "seed"]);
  const candidate = expectedSemanticCandidate(
    values.seed,
    publishedSemanticVersions(values.prefix)
  );
  process.stdout.write(`${candidate}
`);
}
function verifyReleaseSource(values) {
  requireExactKeys(values, [
    "version-tag",
    "source-sha",
    "ci-run-id",
    "prefix",
    "product-id",
    "target",
    "workflow"
  ], ["spec-version"]);
  if (!tagPrefixPattern.test(values.prefix) || !values["version-tag"].startsWith(values.prefix) || !/^[a-z0-9][a-z0-9.-]*$/.test(values["version-tag"])) {
    throw new Error("Release \u7248\u672C Tag \u8EAB\u4EFD\u65E0\u6548");
  }
  verifySuccessfulCIRun(values);
  const suffix = values["version-tag"].slice(values.prefix.length);
  if (Object.hasOwn(values, "spec-version")) {
    if (values["product-id"] !== "citizenchain-runtime" || suffix !== values["spec-version"]) throw new Error("Runtime Release \u7248\u672C\u53C2\u6570\u65E0\u6548");
    verifyRuntimeVersion(values);
  } else {
    const seedSources = {
      citizenapp: ["pubspec", "citizenapp/pubspec.yaml"],
      citizenwallet: ["pubspec", "citizenwallet/pubspec.yaml"],
      "citizenchain-node": ["json", "citizenchain/node/tauri.conf.json"],
      citizenserve: ["json", "citizenserve/package.json"],
      citizenweb: ["json", "citizenweb/package.json"]
    };
    const source = seedSources[values["product-id"]];
    if (!source) throw new Error("\u8BED\u4E49\u7248\u672C Release \u7F3A\u5C11\u7248\u672C\u771F\u6E90");
    parseSemanticVersion(suffix);
    const expected = expectedSemanticCandidate(
      readSeed(source[0], source[1]),
      publishedSemanticVersions(values.prefix)
    );
    if (suffix !== expected) {
      throw new Error(`Release \u7248\u672C\u4E0D\u662F\u6B63\u5F0F Release \u771F\u6E90\u7684\u4E0B\u4E00\u7248\u672C\uFF1A\u671F\u671B ${expected}\uFF0C\u6536\u5230 ${suffix}`);
    }
  }
  process.stdout.write(`Release \u5DF2\u9501\u5B9A\u6210\u529F CI\uFF1A${values["ci-run-id"]} \xB7 ${values["source-sha"]}
`);
}
function main(argv) {
  const { command, values } = parseArguments(argv);
  if (command === "next-semantic-release") return printNextSemanticRelease(values);
  if (command === "verify-release-source") return verifyReleaseSource(values);
  throw new Error(`\u4E0D\u652F\u6301\u7684\u7248\u672C\u547D\u4EE4\uFF1A${command}`);
}
if (false && process.argv[1] && import.meta.url === pathToFileURL3(process.argv[1]).href) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}
`);
    process.exitCode = 1;
  }
}

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/citizenchain/ci-node-linux-amd.mjs node-version
import { readFileSync as readFileSync6, writeFileSync as writeFileSync3 } from "node:fs";
import { spawnSync as spawnSync2 } from "node:child_process";
import { pathToFileURL as pathToFileURL4 } from "node:url";
var VERSION_PATTERN = /^\d+\.(?:0|[1-9]\d?)\.(?:0|[1-9]\d?)$/;
var CARGO_PATH = "citizenchain/Cargo.toml";
var LOCK_PATH = "citizenchain/Cargo.lock";
var TAURI_PATH = "citizenchain/node/tauri.conf.json";
function required3(condition, message) {
  if (!condition) throw new Error(message);
}
function applyVersion(version) {
  required3(VERSION_PATTERN.test(version), "\u516C\u6C11\u94FE\u8282\u70B9\u5019\u9009\u7248\u672C\u65E0\u6548");
  const tauri = JSON.parse(readFileSync6(TAURI_PATH, "utf8"));
  tauri.version = version;
  writeFileSync3(TAURI_PATH, `${JSON.stringify(tauri, null, 2)}
`);
  let cargo = readFileSync6(CARGO_PATH, "utf8");
  const pattern = /(\[workspace\.package\][\s\S]*?\nversion\s*=\s*")[^"]+("\s*)/;
  required3(pattern.test(cargo), "CitizenChain workspace.package \u7248\u672C\u771F\u6E90\u65E0\u6548");
  cargo = cargo.replace(pattern, `$1${version}$2`);
  writeFileSync3(CARGO_PATH, cargo);
}
function packageBlocks(text) {
  const normalized = text.replaceAll("\r\n", "\n");
  const marker = "[[package]]\n";
  const first = normalized.indexOf(marker);
  required3(first >= 0, "Cargo.lock \u7F3A\u5C11 package");
  const prefix = normalized.slice(0, first);
  const blocks = normalized.slice(first).split(/(?=^\[\[package\]\]\n)/m);
  return { prefix, blocks };
}
function packageField(block, field) {
  return new RegExp(`^${field} = "([^"]+)"$`, "m").exec(block)?.[1] ?? null;
}
function validateLockChange(before, after, version) {
  const left = packageBlocks(before);
  const right = packageBlocks(after);
  required3(
    left.prefix === right.prefix && left.blocks.length === right.blocks.length,
    "Cargo.lock \u53D1\u751F\u4E86\u975E workspace \u7248\u672C\u53D8\u5316"
  );
  let changes = 0;
  for (let index = 0; index < left.blocks.length; index += 1) {
    const oldBlock = left.blocks[index];
    const newBlock = right.blocks[index];
    if (oldBlock === newBlock) continue;
    const oldName = packageField(oldBlock, "name");
    const newName = packageField(newBlock, "name");
    const oldVersion = packageField(oldBlock, "version");
    const newVersion = packageField(newBlock, "version");
    required3(
      oldName && oldName === newName && oldVersion && newVersion === version,
      "Cargo.lock workspace \u5305\u8EAB\u4EFD\u6216\u5019\u9009\u7248\u672C\u65E0\u6548"
    );
    required3(
      packageField(oldBlock, "source") === null && packageField(newBlock, "source") === null,
      `Cargo.lock \u7981\u6B62\u4FEE\u6539\u8FDC\u7AEF\u4F9D\u8D56\uFF1A${oldName}`
    );
    const normalize = (block) => block.replace(/^version = "[^"]+"$/m, 'version = "<workspace>"');
    required3(
      normalize(oldBlock) === normalize(newBlock),
      `Cargo.lock \u9664 workspace \u7248\u672C\u5916\u53D1\u751F\u53D8\u5316\uFF1A${oldName}`
    );
    required3(oldVersion !== newVersion, `Cargo.lock \u51FA\u73B0\u65E0\u6548\u7248\u672C\u53D8\u5316\uFF1A${oldName}`);
    changes += 1;
  }
  return changes;
}
function runCargo(args) {
  const result = spawnSync2("cargo", args, {
    cwd: "citizenchain",
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"]
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(String(result.stderr || result.stdout).trim());
}
function lockVersion(version) {
  required3(VERSION_PATTERN.test(version), "\u516C\u6C11\u94FE\u8282\u70B9\u5019\u9009\u7248\u672C\u65E0\u6548");
  const cargo = readFileSync6(CARGO_PATH, "utf8");
  const tauri = JSON.parse(readFileSync6(TAURI_PATH, "utf8"));
  const escapedVersion = version.replaceAll(".", "\\.");
  required3(new RegExp(`\\[workspace\\.package\\][\\s\\S]*?\\nversion\\s*=\\s*"${escapedVersion}"`).test(cargo) && tauri.version === version, "\u9501\u6587\u4EF6\u540C\u6B65\u524D\u7684\u8282\u70B9\u5019\u9009\u7248\u672C\u4E0D\u4E00\u81F4");
  const before = readFileSync6(LOCK_PATH, "utf8");
  runCargo(["update", "--workspace"]);
  const after = readFileSync6(LOCK_PATH, "utf8");
  validateLockChange(before, after, version);
  runCargo(["metadata", "--locked", "--offline", "--no-deps", "--format-version", "1"]);
}
if (false && process.argv[1] && import.meta.url === pathToFileURL4(process.argv[1]).href) {
  try {
    const [command, version] = process.argv.slice(2);
    if (command === "apply") applyVersion(version);
    else if (command === "lock") lockVersion(version);
    else throw new Error("\u516C\u6C11\u94FE\u8282\u70B9\u7248\u672C\u547D\u4EE4\u65E0\u6548");
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/version-tag-contract.test.mjs
test5("workflow \u5408\u540C\u540C\u65F6\u63A5\u53D7 yml \u4E0E yaml \u4E14\u62D2\u7EDD\u8DEF\u5F84\u548C\u4F2A\u6269\u5C55\u540D", () => {
  assert5.equal(validateWorkflowFileName("citizenchain/ci-node-linux-amd.yml"), "citizenchain/ci-node-linux-amd.yml");
  assert5.equal(validateWorkflowFileName("citizenchain/ci-node-linux-arm.yaml"), "citizenchain/ci-node-linux-arm.yaml");
  for (const value2 of [
    ".github/workflows/citizenchain/ci-node-linux-arm.yaml",
    "citizenchain/ci-node-linux-arm.yaml.bak",
    "citizenchain-node-ci-linux-arm.YAML",
    "citizenchain_node_ci_linux_arm.yaml"
  ]) assert5.throws(() => validateWorkflowFileName(value2), /workflow 无效/);
});
test5("\u6B63\u5F0F Release \u8F6F\u4EF6\u7248\u672C\u6309\u672B\u4E24\u6BB5 0\u201399 \u7EDF\u4E00\u8FDB\u4F4D", () => {
  assert5.equal(nextSemanticVersion("1.0.0"), "1.0.1");
  assert5.equal(nextSemanticVersion("1.0.99"), "1.1.0");
  assert5.equal(nextSemanticVersion("1.23.99"), "1.24.0");
  assert5.equal(nextSemanticVersion("1.99.99"), "2.0.0");
  assert5.equal(expectedSemanticCandidate("1.0.0", []), "1.0.1");
  assert5.equal(expectedSemanticCandidate("1.0.0", ["1.0.2", "1.0.1"]), "1.0.3");
});
test5("\u4E0D\u540C\u7AEF\u5206\u522B\u8BFB\u53D6\u81EA\u5DF1\u7684\u6B63\u5F0F Release \u96C6\u5408\uFF0C\u4E0D\u5171\u4EAB\u7248\u672C\u57FA\u7EBF", () => {
  assert5.equal(expectedSemanticCandidate("1.0.0", ["1.0.4"]), "1.0.5");
  assert5.equal(expectedSemanticCandidate("1.0.0", ["1.0.2"]), "1.0.3");
});
test5("\u62D2\u7EDD\u8D8A\u754C\u3001\u524D\u5BFC\u96F6\u548C\u975E\u4E09\u6BB5\u8F6F\u4EF6\u7248\u672C", () => {
  for (const value2 of ["1.0.100", "1.100.0", "1.00.1", "1.0", "v1.0.0"]) {
    assert5.throws(() => parseSemanticVersion(value2));
  }
  assert5.equal(compareSemanticVersions("1.2.9", "1.2.10"), -1);
});
test5("\u8282\u70B9\u9501\u6587\u4EF6\u53EA\u5141\u8BB8\u672C\u5730 workspace \u5305\u540C\u6B65\u5230\u5019\u9009\u7248\u672C", () => {
  const script = readFileSync7(new URL("../citizenchain/ci-node-linux-amd.mjs", import.meta.url), "utf8");
  const before = `# lock
[[package]]
name = "citizenchain"
version = "1.0.0"
dependencies = [
 "serde",
]

[[package]]
name = "serde"
version = "1.0.0"
source = "registry+https://example.invalid"
checksum = "abc"
`;
  const after = before.replace(
    'name = "citizenchain"\nversion = "1.0.0"',
    'name = "citizenchain"\nversion = "1.0.1"'
  );
  assert5.equal(validateLockChange(before, after, "1.0.1"), 1);
  assert5.equal(validateLockChange(before, before, "1.0.0"), 0);
  const windowsBefore = before.replaceAll("\n", "\r\n");
  const windowsAfter = after.replaceAll("\n", "\r\n");
  assert5.equal(validateLockChange(windowsBefore, windowsAfter, "1.0.1"), 1);
  assert5.equal(validateLockChange(windowsBefore, after, "1.0.1"), 1);
  assert5.throws(
    () => validateLockChange(before, after.replace('checksum = "abc"', 'checksum = "def"'), "1.0.1"),
    /Cargo\.lock/
  );
  assert5.match(script, /runCargo\(\['update', '--workspace'\]\)/);
  assert5.match(script, /runCargo\(\['metadata', '--locked', '--offline', '--no-deps'/);
});
test5("Windows \u8282\u70B9 CI \u4E0E Release \u56FA\u5B9A\u7528 Bash \u4F20\u5165\u5019\u9009\u7248\u672C", () => {
  for (const workflow of [
    "citizenchain/release-node-windows.yml"
  ]) {
    const source = readFileSync7(new URL(`../../workflows/${workflow}`, import.meta.url), "utf8");
    assert5.match(
      source,
      /- name: 同步并锁定节点候选版本\n(?:[ ]{8}#.*\n)*[ ]{8}shell: bash\n[ ]{8}run: node .*citizenchain\/[^\s]+\.mjs node-version lock "\$GMB_SOFTWARE_VERSION"/
    );
  }
});
test5("\u5168\u90E8 CI \u53EA\u9A8C\u8BC1\u6784\u5EFA\uFF0C\u4E0D\u521B\u5EFA Tag\u3001\u4E0D\u63A8\u8FDB\u6B63\u5F0F\u7248\u672C", () => {
  const workflowsUrl = new URL("../../workflows/", import.meta.url);
  const workflowDirs = [
    ["../../workflows/", ""],
    ["../../workflows/citizenapp/", "citizenapp/"],
    ["../../workflows/citizenwallet/", "citizenwallet/"],
    ["../../workflows/citizenweb/", "citizenweb/"],
    ["../../workflows/citizenserve/", "citizenserve/"],
    ["../../workflows/citizenchain/", "citizenchain/"]
  ];
  const ciFiles = workflowDirs.flatMap(([directory, prefix]) => readdirSync(new URL(directory, import.meta.url)).map((value2) => `${prefix}${value2}`)).filter((value2) => /(?:^|\/)ci-[^/]+\.ya?ml$/.test(value2));
  assert5.equal(ciFiles.length, 11);
  for (const workflow of ciFiles) {
    const source = readFileSync7(new URL(workflow, workflowsUrl), "utf8");
    assert5.doesNotMatch(source, /finalize-version-tag|finalize-semantic-ci|finalize-runtime-ci/);
    assert5.doesNotMatch(source, /contents:\s*write/);
    assert5.doesNotMatch(source, /GMB_VERSION_TAG/);
    assert5.doesNotMatch(source, /inputs\.source_sha|source_sha:\s*\n/);
    assert5.match(source, /GMB_SOURCE_SHA: \$\{\{ github\.sha \}\}/);
    assert5.match(source, /ref: \$\{\{ github\.sha \}\}/);
    assert5.doesNotMatch(source, /inputs\.software_version|GMB_SOFTWARE_VERSION/);
  }
  const runtimeCI = readFileSync7(new URL("../../workflows/citizenchain/ci-runtime-wasm.yml", import.meta.url), "utf8");
  assert5.doesNotMatch(runtimeCI, /chain_spec_version:|genesis_hash:|finalized_head:|inputs\.spec_version/u);
  assert5.doesNotMatch(runtimeCI, /chain_getFinalizedHead|state_getRuntimeVersion|runtime-ci-candidate/u);
  const runtimeRelease = readFileSync7(new URL("../../workflows/citizenchain/release-runtime-wasm.yml", import.meta.url), "utf8");
  assert5.match(runtimeRelease, /chain_spec_version:[\s\S]*genesis_hash:[\s\S]*finalized_head:/u);
  assert5.match(runtimeRelease, /target_version != chain_version \+ 1/u);
});
test5("\u6BCF\u4E2A Release \u7528\u6210\u529F ci_run_id \u590D\u6838\u6765\u6E90\u5E76\u521B\u5EFA\u552F\u4E00\u6B63\u5F0F Tag", () => {
  const releases = [
    ["citizenapp/release-ios", "citizenapp-ios-v", "citizenapp", "ios", "citizenapp/ci-ios.yml"],
    ["citizenapp/release-android", "citizenapp-android-v", "citizenapp", "android", "citizenapp/ci-android.yml"],
    ["citizenwallet/release-ios", "citizenwallet-ios-v", "citizenwallet", "ios", "citizenwallet/ci-ios.yml"],
    ["citizenwallet/release-android", "citizenwallet-android-v", "citizenwallet", "android", "citizenwallet/ci-android.yml"],
    ["citizenserve/release-cloudflare", "citizenserve-cloudflare-v", "citizenserve", "cloudflare", "citizenserve/ci-cloudflare.yml"],
    ["citizenweb/release-web", "citizenweb-v", "citizenweb", "web", "citizenweb/ci-web.yml"],
    ["citizenchain/release-node-linux-arm", "citizenchain-node-linux-arm-v", "citizenchain-node", "linux-arm", "citizenchain/ci-node-linux-arm.yaml"],
    ["citizenchain/release-node-linux-amd", "citizenchain-node-linux-amd-v", "citizenchain-node", "linux-amd", "citizenchain/ci-node-linux-amd.yml"],
    ["citizenchain/release-node-macos", "citizenchain-node-macos-v", "citizenchain-node", "macos", "citizenchain/ci-node-macos.yml"],
    ["citizenchain/release-node-windows", "citizenchain-node-windows-v", "citizenchain-node", "windows", "citizenchain/ci-node-windows.yml"],
    ["citizenchain/release-runtime-wasm", "citizenchain-runtime-wasm-v", "citizenchain-runtime", "wasm", "citizenchain/ci-runtime-wasm.yml"]
  ];
  for (const [release2, prefix, product, target, workflow] of releases) {
    const source = readFileSync7(new URL(`../../workflows/${release2}.yml`, import.meta.url), "utf8");
    assert5.match(source, /ci_run_id:[\s\S]*GMB_CI_RUN_ID: \$\{\{ inputs\.ci_run_id \}\}/);
    assert5.match(source, /verify-release-source[\s\S]*--ci-run-id "\$GMB_CI_RUN_ID"/);
    assert5.ok(source.includes(`--prefix ${prefix}`), `${release2} \u7F3A\u5C11\u6B63\u5F0F Tag \u524D\u7F00`);
    assert5.ok(source.includes(`--product-id ${product}`), `${release2} \u7F3A\u5C11\u51C6\u786E\u4EA7\u54C1`);
    assert5.ok(source.includes(`--target ${target}`), `${release2} \u7F3A\u5C11\u51C6\u786E\u7AEF`);
    assert5.ok(source.includes(`--workflow ${workflow}`), `${release2} \u7F3A\u5C11\u51C6\u786E CI workflow`);
    assert5.match(source, /--tag "\$GMB_VERSION_TAG"/);
  }
});
test5("Release \u516C\u5171\u5DE5\u5177\u5148\u521B\u5EFA\u4E8B\u52A1 Tag\uFF0C\u6B63\u5F0F\u8D44\u4EA7\u5931\u8D25\u65F6\u56DE\u6EDA\u8349\u7A3F\u4E0E Tag", () => {
  const source = readFileSync7(new URL("../citizenapp/release-ios.mjs", import.meta.url), "utf8");
  assert5.match(source, /async createTag[\s\S]*repos\/\$\{repository\}\/git\/refs/);
  assert5.match(source, /release', 'create'[\s\S]*'--verify-tag'/);
  assert5.doesNotMatch(source, /release', 'create'[\s\S]*'--target'/);
  assert5.match(source, /reuseExistingTag[\s\S]*await versionTagCommit[\s\S]*reuseExistingTag = true/);
  assert5.match(source, /await client\.createTag[\s\S]*await client\.createDraft/);
  assert5.match(source, /async deleteTag/);
  assert5.match(source, /Tag 回滚失败/);
});
test5("GitHub \u53EA\u4FDD\u7559 22 \u6761 CI/Release workflow\uFF0C\u4E0D\u5B58\u5728\u8FDC\u7A0B\u53D1\u5E03\u5165\u53E3", () => {
  const repositoryRoot = new URL("../../../", import.meta.url);
  const contract = JSON.parse(readFileSync7(new URL(".github/dependencies.json", repositoryRoot), "utf8"));
  const productWorkflows = Object.entries(contract.scopes)
    .filter(([name]) => name !== "repository")
    .flatMap(([, scope]) => scope.workflows);
  assert5.equal(productWorkflows.length, 22);
  assert5.ok(productWorkflows.every((workflow) => /\/(?:ci|release)-[^/]+\.ya?ml$/.test(workflow)));
  for (const path of [
    ".github/workflows/citizenapp/publish-android.yml",
    ".github/workflows/citizenapp/publish-ios.yml",
    ".github/workflows/citizenwallet/publish-android.yml",
    ".github/workflows/citizenwallet/publish-ios.yml",
    ".github/workflows/citizenserve/publish-cloudflare.yml",
    ".github/workflows/citizenweb/publish-web.yml",
  ]) assert5.equal(existsSync7(new URL(path, repositoryRoot)), false, `\u65E7 GitHub \u53D1\u5E03\u5165\u53E3\u4ECD\u5B58\u5728\uFF1A${path}`);
});
test5("Android Release \u63A5\u53D7\u81EA\u7B7E\u540D\u4E0A\u4F20\u8BC1\u4E66\u4E14\u4E0D\u4EA7\u751F detached v4 \u6587\u4EF6", () => {
  for (const workflow of ["citizenapp/release-android.yml", "citizenwallet/release-android.yml"]) {
    const source = readFileSync7(new URL(`../../workflows/${workflow}`, import.meta.url), "utf8");
    assert5.match(source, /--v4-signing-enabled false/);
    assert5.match(source, /test "\$apk_certificate_sha256" = "\$key_certificate_sha256"/);
    assert5.match(source, /test "\$apk_certificate_sha256" = "\$aab_certificate_sha256"/);
  }
});
test5("\u79FB\u52A8\u7AEF\u6B63\u5F0F Release \u8D44\u4EA7\u540D\u7EDF\u4E00\u4F7F\u7528 ASCII \u4EA7\u54C1 id", () => {
  const products2 = ["citizenapp", "citizenwallet"];
  for (const product of products2) {
    const android = readFileSync7(new URL(`../../workflows/${product}/release-android.yml`, import.meta.url), "utf8");
    const ios = readFileSync7(new URL(`../../workflows/${product}/release-ios.yml`, import.meta.url), "utf8");
    for (const extension of ["apk", "aab"]) {
      assert5.ok(android.includes(`asset_name: "${product}.${extension}"`));
    }
    assert5.ok(ios.includes(`asset_name: '${product}.ipa'`));
    assert5.doesNotMatch(android, /asset_name:\s*["'][^"']*[^\x00-\x7F][^"']*["']/);
    assert5.doesNotMatch(ios, /asset_name:\s*["'][^"']*[^\x00-\x7F][^"']*["']/);
  }
});
test5("iOS Release \u4E0D\u4F9D\u8D56 runner \u94A5\u5319\u4E32\u89E3\u5305\u63CF\u8FF0\u6587\u4EF6\u4E14\u5F3A\u5236\u6838\u5BF9\u6B63\u5F0F\u8BC1\u4E66", () => {
  for (const product of ["citizenapp", "citizenwallet"]) {
    const source = readFileSync7(new URL(`../../workflows/${product}/release-ios.yml`, import.meta.url), "utf8");
    assert5.match(source, /security list-keychains -d user -s "\$keychain"/);
    assert5.match(source, /security find-identity -v -p codesigning "\$keychain"[\s\S]*grep -Fq "\$certificate_sha1"/);
    assert5.match(source, /openssl smime -verify -inform DER[\s\S]*-noverify -out "\$work\/profile\.plist"/);
    assert5.match(source, /DeveloperCertificates\.0[\s\S]*test "\$profile_certificate_sha1" = "\$certificate_sha1"/);
    assert5.doesNotMatch(source, /security cms -D/);
  }
});
test5("\u9876\u5C42\u552F\u4E00\u6CE8\u518C\u5165\u53E3\u4FDD\u7559\u4ED3\u5E93\u95E8\u7981\u5E76\u8DEF\u7531 22 \u6761\u5206\u7EC4\u4EA7\u54C1\u6D41\u6C34\u7EBF", () => {
  const workflowsUrl = new URL("../../workflows/", import.meta.url);
  const repositoryWorkflow = "gmb-repository.yml";
  const repositorySource = readFileSync7(new URL(repositoryWorkflow, workflowsUrl), "utf8");
  for (const required4 of [
    "ci-repository.mjs golden-vectors",
    "ci-repository.mjs data-dictionary",
    "ci-repository.test.mjs",
    "ci-repository.mjs guardrails",
    "ci-repository.mjs pallet-registry",
    "cargo fmt --all -- --check",
    "cargo clippy --workspace --all-targets --locked -- -D warnings",
    "cargo test --workspace --all-targets --locked"
  ]) assert5.ok(repositorySource.includes(required4), `\u72EC\u7ACB\u4ED3\u5E93\u95E8\u7981\u7F3A\u5C11 ${required4}`);
  assert5.match(repositorySource, /actions: write/);
  assert5.match(repositorySource, /retain-current-run:/);
  assert5.match(repositorySource, /actions\/runs\/\$\{previous\}/);
  assert5.match(repositorySource, /needs: retain-current-run/g);
  assert5.match(repositorySource, /inputs\.pipeline/);
  assert5.match(repositorySource, /contains\(inputs\.pipeline, '\/release-'\)[\s\S]*inputs\.source_sha \|\| github\.sha/);
  assert5.match(repositorySource, /CI 禁止接收 source_sha/);
  assert5.match(repositorySource, /Release 必须指定成功 CI 的准确 source_sha/);
  assert5.match(repositorySource, /actions\/upload-artifact/);
  // \u8282\u70B9\u7AEF\u7684 CI \u4E0E Release \u5728\u552F\u4E00\u5165\u53E3\u4E2D\u4ECD\u662F\u72EC\u7ACB\u4EFB\u52A1\uFF0C\u5FC5\u987B\u4FDD\u7559\u5404\u81EA\u7684\u5E73\u53F0\u5E38\u91CF\u3002
  for (const [jobId, platform] of [
    ["citizenchain_ci_node_linux_amd__changes", "linux-amd"],
    ["citizenchain_ci_node_linux_arm__changes", "linux-arm"],
    ["citizenchain_ci_node_macos__changes", "macos"],
    ["citizenchain_ci_node_windows__changes", "windows"],
    ["citizenchain_release_node_linux_amd__changes", "linux-amd"],
    ["citizenchain_release_node_linux_arm__changes", "linux-arm"],
    ["citizenchain_release_node_macos__changes", "macos"],
    ["citizenchain_release_node_windows__changes", "windows"]
  ]) {
    assert5.ok(
      repositorySource.includes(`  ${jobId}:\n    env:\n      GMB_NODE_PLATFORM: ${platform}\n`),
      `${jobId} \u7F3A\u5C11\u72EC\u7ACB\u5E73\u53F0\u5E38\u91CF ${platform}`
    );
  }
  const contract = JSON.parse(readFileSync7(new URL("../../../.github/dependencies.json", import.meta.url), "utf8"));
  const productWorkflows = Object.entries(contract.scopes)
    .filter(([name]) => name !== "repository")
    .flatMap(([, scope]) => scope.workflows);
  assert5.equal(productWorkflows.length, 22);
  for (const workflow of productWorkflows) {
    assert5.ok(repositorySource.includes(`inputs.pipeline == '${workflow}'`), `\u7EDF\u4E00\u5165\u53E3\u7F3A\u5C11\u8DEF\u7531\uFF1A${workflow}`);
  }
  for (const file of readdirSync(workflowsUrl).filter((value2) => /\.ya?ml$/.test(value2))) {
    if (file === repositoryWorkflow) continue;
    const source = readFileSync7(new URL(file, workflowsUrl), "utf8");
    for (const command of [
      "ci-repository.mjs golden-vectors",
      "ci-repository.mjs data-dictionary",
      "data-dictionary.test.mjs",
      "ci-repository.mjs guardrails",
      "ci-repository.mjs pallet-registry"
    ]) assert5.ok(!source.includes(command), `${file} \u7981\u6B62\u91CD\u590D\u8C03\u7528\u4ED3\u5E93\u95E8\u7981 ${command}`);
  }
});
test5("\u5168\u90E8\u7B2C\u4E00\u65B9 npm \u9879\u76EE\u4E0E Workflow \u7EDF\u4E00\u7CBE\u786E Node.js \u7248\u672C", () => {
  const repositoryRoot = new URL("../../../", import.meta.url);
  const contract = JSON.parse(readFileSync7(new URL(".github/dependencies.json", repositoryRoot), "utf8"));
  assert5.equal(contract.toolchains.node, "25.2.1");
  for (const project of contract.npmProjects) {
    const manifest = JSON.parse(readFileSync7(new URL(`${project}/package.json`, repositoryRoot), "utf8"));
    const lock = JSON.parse(readFileSync7(new URL(`${project}/package-lock.json`, repositoryRoot), "utf8"));
    assert5.equal(manifest.engines?.node, contract.toolchains.node, `${project} manifest Node.js \u672A\u7EDF\u4E00`);
    assert5.equal(lock.packages?.[""]?.engines?.node, contract.toolchains.node, `${project} lockfile Node.js \u672A\u7EDF\u4E00`);
  }
  for (const scope of Object.values(contract.scopes)) {
    for (const workflow of scope.workflows) {
      const source = readFileSync7(new URL(workflow, repositoryRoot), "utf8");
      if (source.includes("node-version:")) {
        assert5.ok(source.includes(`node-version: ${contract.toolchains.node}`), `${workflow} Node.js \u672A\u7EDF\u4E00`);
      }
    }
  }
});
// 中文注释：以下合同防止统一入口或原生打包门禁在后续同步时只改分组文件的一侧。
test5("\u5168\u4ED3\u4F9D\u8D56\u95E8\u7981\u771F\u5B9E\u89E3\u6790\u672C\u5730\u8DEF\u5F84\u4E0E Cargo workspace", () => {
  const source = readFileSync7(new URL("ci-repository.mjs", import.meta.url), "utf8");
  assert5.match(source, /checkLocalDependencyPaths/);
  assert5.match(source, /cargo[^\n]+metadata/);
  assert5.match(source, /--locked/);
  assert5.match(source, /--no-deps/);
});
test5("\u79FB\u52A8\u7AEF CI\u3001Release \u4E0E\u672C\u5730\u6784\u5EFA\u90FD\u6838\u9A8C\u6700\u7EC8\u5305\u5185\u539F\u751F\u5E93", () => {
  for (const product of ["citizenapp", "citizenwallet"]) {
    const scriptName = product === "citizenapp" ? "build-smoldot-native.sh" : "build-signer-native.sh";
    const script = readFileSync7(new URL(`../../../${product}/scripts/${scriptName}`, import.meta.url), "utf8");
    assert5.match(script, /verify-android-package/);
    assert5.match(script, /verify-ios-package/);
    assert5.match(script, /lipo -archs/);
    for (const workflow of ["ci-android.yml", "release-android.yml", "ci-ios.yml", "release-ios.yml"]) {
      const source = readFileSync7(new URL(`../../workflows/${product}/${workflow}`, import.meta.url), "utf8");
      assert5.ok(source.includes(scriptName));
      assert5.match(source, /verify-(?:android|ios)-package/);
    }
  }
});
test5("CitizenApp \u5BBF\u4E3B\u6D4B\u8BD5\u53EA\u4ECE smoldot/ffi \u65B0\u76EE\u5F55\u52A0\u8F7D\u539F\u751F\u5E93", () => {
  const platform = readFileSync7(new URL("../../../citizenapp/smoldot/dart/lib/src/platform.dart", import.meta.url), "utf8");
  const mls = readFileSync7(new URL("../../../citizenapp/lib/chat/crypto/mls_native.dart", import.meta.url), "utf8");
  const testEntry = readFileSync7(new URL("../../../citizenapp/scripts/citizenapp-test.sh", import.meta.url), "utf8");
  assert5.ok(platform.includes("'smoldot',\n        'ffi',\n        'target',\n        'release'"));
  assert5.ok(platform.includes("'..', 'ffi', 'target', 'release'"));
  assert5.ok(mls.includes("'smoldot',\n        'ffi',\n        'target',\n        'release'"));
  assert5.doesNotMatch(`${platform}\n${mls}`, /(?:'native'|'rust'),\s*'target'/u);
  assert5.match(testEntry, /build-smoldot-native\.sh" host[\s\S]*FLUTTER_BIN" test/u);
});
test5("\u672C\u5730\u516C\u6C11\u94FE\u5165\u53E3\u7EDF\u4E00\u51C6\u5907\u7CBE\u786E\u5DE5\u5177\u94FE\u4E0E\u9501\u5B9A\u4F9D\u8D56", () => {
  const repositoryRoot = new URL("../../../", import.meta.url);
  const prepare = readFileSync7(new URL("scripts/prepare-toolchain.sh", repositoryRoot), "utf8");
  assert5.match(prepare, /\.github\/dependencies\.json/);
  assert5.match(prepare, /CURRENT_NODE_VERSION[\s\S]*EXPECTED_NODE_VERSION/);
  for (const project of [
    "shared/scanner-react",
    "citizenchain/node/frontend",
    "citizenchain/onchina/frontend"
  ]) assert5.ok(prepare.includes(project), `\u5DE5\u5177\u94FE\u51C6\u5907\u7F3A\u5C11 ${project}`);
  assert5.match(prepare, /npm --prefix[\s\S]* ci/);
  for (const script of ["run.sh", "clean-run.sh"]) {
    const source = readFileSync7(new URL(`citizenchain/scripts/${script}`, repositoryRoot), "utf8");
    const prepareIndex = source.indexOf('source "$GMB_REPOSITORY_ROOT/scripts/prepare-toolchain.sh"');
    const tauriIndex = source.indexOf("frontend/node_modules/@tauri-apps/cli/tauri.js");
    assert5.ok(prepareIndex >= 0 && tauriIndex > prepareIndex, `${script} \u5FC5\u987B\u5148\u51C6\u5907\u5DE5\u5177\u94FE\u518D\u8C03\u7528 Tauri`);
    assert5.doesNotMatch(source, /\[ ! -d node_modules \]/);
  }
});
test5("仓库中文注释门禁使用跨平台 Unicode 汉字检测", () => {
  const source = readFileSync7(new URL("ci-repository.mjs", import.meta.url), "utf8");
  assert5.match(source, /Script=Han/);
  assert5.doesNotMatch(source, /一-龥/);
});

test5("11 个独立 Release 动作锚定成功 CI 源码且首次版本不递增", () => {
  const actions = [
    "citizenapp/release-ios.mjs",
    "citizenapp/release-android.mjs",
    "citizenwallet/release-ios.mjs",
    "citizenwallet/release-android.mjs",
    "citizenchain/release-node-linux-arm.mjs",
    "citizenchain/release-node-linux-amd.mjs",
    "citizenchain/release-node-macos.mjs",
    "citizenchain/release-node-windows.mjs",
    "citizenchain/release-runtime-wasm.mjs",
    "citizenserve/release-cloudflare.mjs",
    "citizenweb/release-web.mjs",
  ];
  for (const action of actions) {
    const source = readFileSync7(new URL(`../${action}`, import.meta.url), "utf8");
    assert5.match(source, /process\.env\.GITHUB_WORKSPACE/);
    assert5.match(source, /realpathSync\(process\.env\.GITHUB_WORKSPACE\)/);
    assert5.match(source, /normalized\.length === 0 \? seed : nextSemanticVersion\(normalized\.at\(-1\)\)/);
    assert5.doesNotMatch(source, /nextSemanticVersion\(normalized\.length === 0 \? seed/);
  }
});

test5("节点 Release 前置验证与正式构建统一使用隔离工具", () => {
  const workflows = [
    ["release-node-linux-arm.yml", "release-node-linux-arm.mjs"],
    ["release-node-linux-amd.yml", "release-node-linux-amd.mjs"],
    ["release-node-macos.yml", "release-node-macos.mjs"],
    ["release-node-windows.yml", "release-node-windows.mjs"],
  ];
  for (const [workflow, action] of workflows) {
    const source = readFileSync7(new URL(`../../workflows/citizenchain/${workflow}`, import.meta.url), "utf8");
    const verifier = `node release-tool/.github/scripts/citizenchain/${action} version-tag verify-release-source`;
    assert5.ok(source.includes(verifier), `${workflow} 前置验证未使用隔离 Release 工具`);
    assert5.doesNotMatch(source, new RegExp(`node \.github/scripts/citizenchain/${action} version-tag verify-release-source`));
    assert5.ok(source.indexOf("拉取前置 Release 工具") < source.indexOf(verifier));
  }
});
