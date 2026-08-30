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
var dataTypes = /* @__PURE__ */ new Set(["array", "boolean", "enum", "hash", "hex_32", "integer", "object", "string"]);
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
// 中文注释：钱包崩溃恢复快照是结构化对象，数据字典必须准确表达其 wire 类型。
test("数据字典准确支持持久 JSON 对象字段", () => {
  const { index, shards } = fixture();
  const objectShards = structuredClone(shards);
  objectShards[0].concepts = [{
    concept_id: "previous_profile",
    field_name: "previous_profile",
    field_name_zh: "操作前钱包资料",
    authority: "gmb",
    data_type: "object",
    forbidden_names: []
  }];
  objectShards[0].value_sets = [];
  objectShards[0].contracts[0].fields = ["previous_profile"];
  objectShards[0].contracts[0].value_sets = [];
  const result = validateDictionary(index, objectShards);
  assert.equal(result.concepts.get("previous_profile").data_type, "object");
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

// GitHub Release 统一事务合同
import assert2 from "node:assert/strict";
import test2 from "node:test";
import { readFileSync as readReleaseScript } from "node:fs";

const releaseScriptPaths2 = [
  ".github/scripts/citizenapp/release-ios.mjs",
  ".github/scripts/citizenapp/release-android.mjs",
  ".github/scripts/citizenwallet/release-ios.mjs",
  ".github/scripts/citizenwallet/release-android.mjs",
  ".github/scripts/citizenchain/release-node-linux-arm.mjs",
  ".github/scripts/citizenchain/release-node-linux-amd.mjs",
  ".github/scripts/citizenchain/release-node-macos.mjs",
  ".github/scripts/citizenchain/release-node-windows.mjs",
  ".github/scripts/citizenchain/release-runtime-wasm.mjs",
  ".github/scripts/citizenserve/release-cloudflare.mjs",
  ".github/scripts/citizensdk/release-sdk.mjs",
  ".github/scripts/citizenweb/release-web.mjs",
];

function embeddedReleaseSource2(path) {
  const text = readReleaseScript(new URL(`../../../${path}`, import.meta.url), "utf8");
  const prefix = "const implementations = Object.freeze(";
  const start = text.indexOf(prefix) + prefix.length;
  const end = text.indexOf(");\nconst [command", start);
  assert2.ok(start >= prefix.length && end > start, `${path} 缺少独立实现登记`);
  return JSON.parse(text.slice(start, end))["github-release"];
}

const releaseSources2 = releaseScriptPaths2.map(embeddedReleaseSource2);
const releaseSource2 = releaseSources2[0];
const releaseModule2 = await import(`data:text/javascript;base64,${Buffer.from(releaseSource2).toString("base64")}#unified-release`);
const { gh: gh2, release: release2 } = releaseModule2;

function input2() {
  return {
    repository: "ChineseFederation/GMB",
    tag: "citizenserve-cloudflare-v1.0.0",
    sourceSHA: "6f2c0e5355156db2fd36216ab7f928f8090ab3e0",
    title: "公民服务端 · Release · Cloudflare",
    notes: "公民服务端 1.0.0。",
    latest: false,
    assets: [{ path: "/tmp/release.tgz", name: "release.tgz", size: 7 }],
  };
}

function marker2(value = input2()) {
  return `<!-- GMB_RELEASE_SOURCE_SHA:${value.sourceSHA} -->`;
}

function client2(options = {}) {
  const calls = [];
  const value = input2();
  const defaultSHA = options.wrongTagSHA ?? value.sourceSHA;
  const annotatedTargetSHA = options.annotatedTagObjectSHA ?? defaultSHA;
  let tagExists = options.staleTag === true || options.staleDraft === true;
  let created = false;
  let draft = options.staleDraft === true;
  let published = options.publishedExisting === true;
  let createAttempted = false;
  let publishThrew = false;
  let listReleaseCalls = 0;
  const remote = (isDraft = draft, foreign = false) => ({
    id: !isDraft && options.formalDifferentId ? 43 : 42,
    name: value.title,
    tag_name: value.tag,
    target_commitish: "main",
    body: foreign
      ? `${value.notes}\n\n<!-- GMB_RELEASE_SOURCE_SHA:${"0".repeat(40)} -->\n`
      : `${value.notes}\n\n${marker2(value)}\n`,
    draft: isDraft,
    assets: value.assets.map((asset) => ({
      name: asset.name,
      size: options.badSize || (!isDraft && options.badFormalSize)
        ? asset.size + 1
        : asset.size,
      state: "uploaded",
    })),
  });
  return {
    calls,
    async listReleases() {
      calls.push("list");
      listReleaseCalls += 1;
      if (options.concurrentDraftBeforeStaleTagDelete && listReleaseCalls === 2) {
        return [remote(true, true)];
      }
      if (options.concurrentDraftBeforeRollbackTagDelete && listReleaseCalls === 3) {
        return [remote(true, true)];
      }
      if (published) return [remote(false)];
      if (draft || created) return [remote(true)];
      if (createAttempted && options.foreignDiscoveredDraft) {
        return [remote(true, true)];
      }
      return [];
    },
    async getTag() {
      calls.push("get-tag");
      if (options.tagReadError) throw new Error(options.tagReadError);
      if (published && options.formalTagError) {
        throw new Error(options.formalTagError);
      }
      if (published && options.formalTagMissing) return null;
      return tagExists
        ? {
          ref: `refs/tags/${value.tag}`,
          object: {
            type: options.invalidTagType ?? (options.annotatedTag ? "tag" : "commit"),
            sha: options.annotatedTag ? "1".repeat(40) : defaultSHA,
          },
        }
        : null;
    },
    async getTagObject() {
      calls.push("get-tag-object");
      if (options.annotatedTagObjectError) throw new Error(options.annotatedTagObjectError);
      if (!options.annotatedTag) throw new Error("轻量 Tag 不应读取 Tag 对象");
      return {
        tag: value.tag,
        object: {
          type: options.annotatedTargetType ?? "commit",
          sha: annotatedTargetSHA,
        },
      };
    },
    async createDraft() {
      calls.push("create-draft");
      createAttempted = true;
      if (options.foreignDiscoveredDraft) throw new Error("草稿创建响应中断");
      created = true;
      draft = true;
      tagExists = true;
    },
    async getRelease() {
      calls.push("get-release");
      if (publishThrew && options.recoveryGetReleaseError) {
        throw new Error(options.recoveryGetReleaseError);
      }
      if (createAttempted && options.foreignDiscoveredDraft) {
        return remote(true, true);
      }
      if (!created && !draft && !published) return null;
      return remote(!published);
    },
    async getReleaseByTag() {
      calls.push("by-tag");
      if (options.byTagError) throw new Error(options.byTagError);
      if (options.byTagMissing) return null;
      return published ? remote(false) : null;
    },
    async publish() {
      calls.push("publish");
      if (options.publishServerFailure) {
        publishThrew = true;
        throw new Error("发布请求失败");
      }
      published = true;
      draft = false;
      if (options.publishResponseFailure) {
        publishThrew = true;
        throw new Error("发布响应中断");
      }
    },
    async deleteRelease() {
      calls.push("delete-release");
      if (options.deleteResponseFailureUnknown) {
        throw new Error("删除响应中断且服务端未删除");
      }
      created = false;
      draft = false;
      published = false;
      if (options.deleteResponseFailure) throw new Error("删除响应中断");
    },
    async deleteTag() {
      calls.push("delete-tag");
      if (options.tagDeleteResponseFailureUnknown) {
        throw new Error("Tag 删除响应中断且服务端未删除");
      }
      tagExists = false;
      if (options.tagDeleteResponseFailure) throw new Error("Tag 删除响应中断");
    },
    async wait() { calls.push("wait"); },
  };
}

// 中文注释：12 个直接文件必须内嵌完全相同的事务，禁止产品例外、公共运行文件或旧双提交模型。
test2("12 个独立 Release 动作使用完全相同的原子 Tag 事务", () => {
  for (const [index, source] of releaseSources2.entries()) {
    assert2.equal(source, releaseSource2, `${releaseScriptPaths2[index]} 的 Release 事务发生漂移`);
  }
  assert2.doesNotMatch(releaseSource2, /releaseSHA|createTag\(|--verify-tag/);
  assert2.doesNotMatch(releaseSource2, /GITHUB_SHA/);
  assert2.match(
    releaseSource2,
    /'release', 'create', input\.tag, '--repo', input\.repository,[\s\S]*'--target', input\.sourceSHA,[\s\S]*'--draft'/,
  );
  assert2.match(releaseSource2, /GMB_RELEASE_SOURCE_SHA/);
  assert2.match(releaseSource2, /await client\.createDraft\(input\)/);
  assert2.equal(
    [...releaseSource2.matchAll(/versionTagCommit\(client, input\) === input\.sourceSHA/g)].length,
    3,
    "孤立 Tag、主路径与恢复路径都必须逐字节核对版本 Tag 的成功 CI 源提交",
  );
  assert2.equal(
    [...releaseSource2.matchAll(/await verifyTagDeletionOwnership\(client, input,/g)].length,
    2,
    "孤立 Tag 与失败回滚 Tag 每次删除前都必须重新核对 Release 附着关系和 sourceSHA",
  );
});

test2("GitHub 不存在查询只把准确 HTTP 404 作为空结果", () => {
  let receivedArguments;
  const missing = gh2(["api", "repos/ChineseFederation/GMB/git/ref/tags/example"], {
    notFound: true,
    run(command, args) {
      assert2.equal(command, "gh");
      receivedArguments = args;
      return {
        status: 1,
        stdout: "HTTP/2.0 404 Not Found\r\ncontent-type: application/json\r\n\r\n{\"message\":\"Not Found\"}\n",
        stderr: "gh: Not Found (HTTP 404)",
      };
    },
  });
  assert2.equal(missing, null);
  assert2.deepEqual(receivedArguments, [
    "api",
    "repos/ChineseFederation/GMB/git/ref/tags/example",
    "--include",
  ]);

  const body = gh2(["api", "repos/ChineseFederation/GMB/releases/tags/example"], {
    notFound: true,
    run() {
      return {
        status: 0,
        stdout: "HTTP/2.0 200 OK\ncontent-type: application/json\n\n{\"id\":42}\n",
        stderr: "",
      };
    },
  });
  assert2.equal(body, '{"id":42}');
});

test2("GitHub 503 正文 Not Found、403 与网络错误全部失败关闭", () => {
  assert2.throws(
    () => gh2(["api", "repos/ChineseFederation/GMB/releases/tags/example"], {
      notFound: true,
      retryRead: true,
      wait() {},
      run() {
        return {
          status: 1,
          stdout: "HTTP/2.0 503 Service Unavailable\n\nNot Found\n",
          stderr: "Not Found",
        };
      },
    }),
    /Not Found/,
  );
  assert2.throws(
    () => gh2(["api", "repos/ChineseFederation/GMB/git/ref/tags/example"], {
      notFound: true,
      run() {
        return {
          status: 1,
          stdout: "HTTP/2.0 403 Forbidden\n\n{\"message\":\"Not Found\"}\n",
          stderr: "Forbidden",
        };
      },
    }),
    /Forbidden/,
  );
  assert2.throws(
    () => gh2(["api", "repos/ChineseFederation/GMB/git/ref/tags/example"], {
      notFound: true,
      run() {
        return { error: new Error("network unavailable") };
      },
    }),
    /network unavailable/,
  );
});

// 中文注释：GitHub 必须在草稿创建请求中通过 --target 将 Tag 原子锚定到成功 CI 源提交。
test2("Release 不预建 Tag、精确锚定成功 CI 源提交并在资产验真后发布", async () => {
  const fake = client2();
  const result = await release2(input2(), fake);
  assert2.equal(result.draft, false);
  assert2.ok(fake.calls.indexOf("create-draft") < fake.calls.indexOf("publish"));
  assert2.equal(fake.calls.includes("create-tag"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("主路径与恢复路径发现版本 Tag 偏离成功 CI 源提交时都保留正式结果", async () => {
  for (const options of [
    { wrongTagSHA: "8b1a9953c4611296a827abf8c47804d7fddf6abc" },
    {
      publishResponseFailure: true,
      wrongTagSHA: "8b1a9953c4611296a827abf8c47804d7fddf6abc",
    },
  ]) {
    const fake = client2(options);
    await assert2.rejects(
      release2(input2(), fake),
      /远端状态已保留.*正式版本 Tag 未锚定本次成功 CI 源提交/,
    );
    assert2.equal(fake.calls.includes("delete-release"), false);
    assert2.equal(fake.calls.includes("delete-tag"), false);
  }
});

test2("同版本同源遗留草稿、轻量 Tag 与注解 Tag 验真后重新原子创建", async () => {
  for (const options of [
    { staleDraft: true },
    { staleTag: true },
    { staleTag: true, annotatedTag: true },
  ]) {
    const fake = client2(options);
    await release2(input2(), fake);
    assert2.ok(fake.calls.indexOf("delete-tag") < fake.calls.indexOf("create-draft"));
    assert2.equal(fake.calls.includes("get-tag-object"), options.annotatedTag === true);
    if (options.staleDraft) {
      assert2.ok(fake.calls.indexOf("delete-release") < fake.calls.indexOf("create-draft"));
    }
  }
});

test2("孤立同名 Tag 不同 source、异常类型或 API 未知时保留并失败关闭", async () => {
  for (const [options, pattern] of [
    [
      { staleTag: true, wrongTagSHA: "8b1a9953c4611296a827abf8c47804d7fddf6abc" },
      /未锚定本次成功 CI 源提交/,
    ],
    [{ staleTag: true, invalidTagType: "blob" }, /类型无效/],
    [
      { staleTag: true, annotatedTag: true, annotatedTagObjectError: "Tag 对象 API 未知" },
      /Tag 对象 API 未知/,
    ],
    [{ staleTag: true, tagReadError: "Tag 读取网络异常" }, /Tag 读取网络异常/],
  ]) {
    const fake = client2(options);
    await assert2.rejects(release2(input2(), fake), pattern);
    assert2.equal(fake.calls.includes("delete-tag"), false);
    assert2.equal(fake.calls.includes("create-draft"), false);
  }
});

test2("孤立同源 Tag 删除响应丢失只以准确不存在收敛", async () => {
  const removed = client2({ staleTag: true, tagDeleteResponseFailure: true });
  await release2(input2(), removed);
  assert2.equal(removed.calls.filter((call) => call === "delete-tag").length, 1);
  assert2.ok(removed.calls.indexOf("delete-tag") < removed.calls.indexOf("create-draft"));

  const unknown = client2({ staleTag: true, tagDeleteResponseFailureUnknown: true });
  await assert2.rejects(release2(input2(), unknown), /孤立 Tag 删除状态未确认/);
  assert2.equal(unknown.calls.includes("create-draft"), false);
});

test2("孤立同源 Tag 删除紧前发现并发附着草稿时保留 Tag 并失败关闭", async () => {
  const fake = client2({
    staleTag: true,
    concurrentDraftBeforeStaleTagDelete: true,
  });
  await assert2.rejects(
    release2(input2(), fake),
    /同名孤立版本 Tag 已附着 GitHub Release，禁止删除/,
  );
  assert2.equal(fake.calls.filter((call) => call === "list").length, 2);
  assert2.equal(fake.calls.includes("delete-tag"), false);
  assert2.equal(fake.calls.includes("create-draft"), false);
});

test2("资产不一致时精确回滚草稿与本次 Tag", async () => {
  const fake = client2({ badSize: true });
  await assert2.rejects(release2(input2(), fake), /资产大小不符/);
  assert2.equal(fake.calls.includes("delete-release"), true);
  assert2.equal(fake.calls.includes("delete-tag"), true);
});

test2("草稿回滚后 Tag 删除紧前发现并发附着草稿时只保留 Tag", async () => {
  const fake = client2({
    badSize: true,
    concurrentDraftBeforeRollbackTagDelete: true,
  });
  await assert2.rejects(
    release2(input2(), fake),
    /资产大小不符.*；Tag 回滚前归属核验失败：待回滚版本 Tag 已附着 GitHub Release，禁止删除/,
  );
  assert2.equal(fake.calls.includes("delete-release"), true);
  assert2.equal(fake.calls.filter((call) => call === "list").length, 3);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("发布响应中断但正式终态完整时禁止误回滚", async () => {
  const fake = client2({ publishResponseFailure: true });
  const result = await release2(input2(), fake);
  assert2.equal(result.draft, false);
  assert2.equal(fake.calls.includes("delete-release"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("PATCH 已成功但恢复按 id 遇到 503 时保留全部远端状态", async () => {
  const fake = client2({
    publishResponseFailure: true,
    recoveryGetReleaseError: "HTTP 503 Service Unavailable",
  });
  await assert2.rejects(
    release2(input2(), fake),
    /PATCH 后恢复核对失败.*HTTP 503 Service Unavailable/,
  );
  assert2.equal(fake.calls.includes("delete-release"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("PATCH 已成功但恢复 by-tag 遇到 403 时正式状态进入吸收态", async () => {
  const fake = client2({
    publishResponseFailure: true,
    byTagError: "HTTP 403 Resource not accessible by integration",
  });
  await assert2.rejects(
    release2(input2(), fake),
    /远端状态已保留.*HTTP 403 Resource not accessible by integration/,
  );
  assert2.equal(fake.calls.includes("delete-release"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("主路径已经读到正式 Release 后 by-tag 503 绝不回滚", async () => {
  const fake = client2({ byTagError: "HTTP 503 Service Unavailable" });
  await assert2.rejects(
    release2(input2(), fake),
    /远端状态已保留.*HTTP 503 Service Unavailable/,
  );
  assert2.equal(fake.calls.includes("delete-release"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("正式 Release 与 by-tag 均已读到后 Tag 查询异常或 404 都保留正式结果", async () => {
  for (const options of [
    { formalTagError: "HTTP 503 Service Unavailable" },
    { formalTagMissing: true },
  ]) {
    const fake = client2(options);
    await assert2.rejects(release2(input2(), fake), /远端状态已保留/);
    assert2.equal(fake.calls.includes("delete-release"), false);
    assert2.equal(fake.calls.includes("delete-tag"), false);
  }
});

test2("只有 by-tag 精确 404 且按 id 仍是本次草稿时才回滚", async () => {
  const fake = client2({ publishServerFailure: true });
  await assert2.rejects(release2(input2(), fake), /发布请求失败/);
  assert2.equal(fake.calls.includes("delete-release"), true);
  assert2.equal(fake.calls.includes("delete-tag"), true);
  assert2.ok(fake.calls.indexOf("by-tag") < fake.calls.indexOf("delete-release"));
  assert2.ok(fake.calls.indexOf("delete-release") < fake.calls.indexOf("delete-tag"));
});

test2("by-tag 精确 404 但按 id 已是正式 Release 时禁止回滚", async () => {
  const fake = client2({ publishResponseFailure: true, byTagMissing: true });
  await assert2.rejects(
    release2(input2(), fake),
    /正式 Release 已形成但 Tag 查询尚未关联.*远端状态已保留|远端状态已保留.*正式 Release 已形成但 Tag 查询尚未关联/,
  );
  assert2.equal(fake.calls.includes("delete-release"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("恢复读到内容不符的正式 Release 时保留而不是删除", async () => {
  const fake = client2({ badFormalSize: true });
  await assert2.rejects(release2(input2(), fake), /远端状态已保留.*资产大小不符/);
  assert2.equal(fake.calls.includes("delete-release"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("createDraft 响应失败后不得删除 source marker 不符的同名草稿", async () => {
  const fake = client2({ foreignDiscoveredDraft: true });
  await assert2.rejects(
    release2(input2(), fake),
    /发布前恢复核对失败.*未绑定本次成功 CI 源提交/,
  );
  assert2.equal(fake.calls.includes("delete-release"), false);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("草稿删除响应丢失只在按 id 精确 404 后继续删除 Tag", async () => {
  const fake = client2({ badSize: true, deleteResponseFailure: true });
  await assert2.rejects(release2(input2(), fake), /资产大小不符/);
  assert2.equal(fake.calls.filter((value) => value === "delete-release").length, 1);
  assert2.equal(fake.calls.includes("delete-tag"), true);
  assert2.ok(fake.calls.lastIndexOf("get-release") < fake.calls.indexOf("delete-tag"));
});

test2("草稿删除失败且按 id 仍存在时保留 Tag", async () => {
  const fake = client2({ badSize: true, deleteResponseFailureUnknown: true });
  await assert2.rejects(release2(input2(), fake), /草稿删除未确认，已保留 Tag/);
  assert2.equal(fake.calls.includes("delete-release"), true);
  assert2.equal(fake.calls.includes("delete-tag"), false);
});

test2("已有正式 Release 时拒绝覆盖", async () => {
  const fake = client2({ publishedExisting: true });
  await assert2.rejects(release2(input2(), fake), /正式 Release 已存在/);
  assert2.equal(fake.calls.includes("create-draft"), false);
});

// ../../../private/var/folders/z1/h1pvtv0x76xg5h60y_2npmbc0000gn/T/gmb-script-tests-BK47jS/version-tag-contract.test.mjs
import assert5 from "node:assert/strict";
import {
  chmodSync as chmodSync7,
  existsSync as existsSync7,
  mkdirSync as mkdirSync7,
  mkdtempSync as mkdtempSync7,
  readdirSync,
  readFileSync as readFileSync7,
  realpathSync as realpathSync7,
  rmSync as rmSync7,
  writeFileSync as writeFileSync7,
} from "node:fs";
import { tmpdir as tmpdir7 } from "node:os";
import { join as join7 } from "node:path";
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
  return normalized.length === 0 ? seed : nextSemanticVersion(normalized.at(-1));
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
  assert5.equal(expectedSemanticCandidate("1.0.0", []), "1.0.0");
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
    ["../../workflows/citizensdk/", "citizensdk/"],
    ["../../workflows/citizenweb/", "citizenweb/"],
    ["../../workflows/citizenserve/", "citizenserve/"],
    ["../../workflows/citizenchain/", "citizenchain/"]
  ];
  const ciFiles = workflowDirs.flatMap(([directory, prefix]) => readdirSync(new URL(directory, import.meta.url)).map((value2) => `${prefix}${value2}`)).filter((value2) => /(?:^|\/)ci-[^/]+\.ya?ml$/.test(value2));
  assert5.equal(ciFiles.length, 12);
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
    ["citizensdk/release-sdk", "citizensdk-v", "citizensdk", "sdk", "citizensdk/ci-sdk.yml"],
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
// 中文注释：所有产品直接脚本统一由 GitHub 在创建草稿时将 Tag 原子锚定到成功 CI 的 sourceSHA。
test5("Release 公共工具禁止预建 Tag 并精确锚定成功 CI 源提交", () => {
  const wrapper = readFileSync7(new URL("../citizenapp/release-ios.mjs", import.meta.url), "utf8");
  const prefix = "const implementations = Object.freeze(";
  const start = wrapper.indexOf(prefix) + prefix.length;
  const end = wrapper.indexOf(");\nconst [command", start);
  const source = JSON.parse(wrapper.slice(start, end))["github-release"];
  assert5.doesNotMatch(source, /async createTag|releaseSHA|--verify-tag/);
  assert5.match(source, /'--target', input\.sourceSHA/);
  assert5.match(source, /GMB_RELEASE_SOURCE_SHA/);
  assert5.match(source, /await client\.createDraft\(input\)[\s\S]*await client\.publish/);
  assert5.equal(
    [...source.matchAll(/versionTagCommit\(client, input\) === input\.sourceSHA/g)].length,
    3,
  );
  assert5.match(source, /async deleteTag/);
  assert5.match(source, /Tag 回滚失败/);
});
test5("GitHub \u53EA\u4FDD\u7559 26 \u6761 CI/Release workflow\uFF0C\u4E0D\u5B58\u5728\u8FDC\u7A0B\u53D1\u5E03\u5165\u53E3", () => {
  const repositoryRoot = new URL("../../../", import.meta.url);
  const contract = JSON.parse(readFileSync7(new URL(".github/dependencies.json", repositoryRoot), "utf8"));
  const productWorkflows = Object.entries(contract.scopes)
    .filter(([name]) => name !== "repository")
    .flatMap(([, scope]) => scope.workflows);
  assert5.equal(productWorkflows.length, 26);
  assert5.ok(productWorkflows.every((workflow) => /\/(?:ci|release)-[^/]+\.ya?ml$/.test(workflow)));
  for (const path of [
    ".github/workflows/citizenapp/publish-android.yml",
    ".github/workflows/citizenapp/publish-ios.yml",
    ".github/workflows/citizenwallet/publish-android.yml",
    ".github/workflows/citizenwallet/publish-ios.yml",
    ".github/workflows/citizenserve/publish-cloudflare.yml",
    ".github/workflows/citizenweb/publish-web.yml",
    ".github/workflows/citizensdk/publish-sdk.yml",
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
test5("\u9876\u5C42\u552F\u4E00\u6CE8\u518C\u5165\u53E3\u4FDD\u7559\u4ED3\u5E93\u95E8\u7981\u5E76\u8DEF\u7531 26 \u6761\u5206\u7EC4\u4EA7\u54C1\u6D41\u6C34\u7EBF", () => {
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
  assert5.match(repositorySource, /retain-terminal-run:/);
  assert5.match(repositorySource, /continue-on-error: true/);
  assert5.match(repositorySource, /success_count[\s\S]*failure_count/);
  assert5.doesNotMatch(repositorySource, /校验产品 CI 的全仓成功基线/);
  assert5.doesNotMatch(repositorySource, /最近一次全仓门禁不是成功，禁止发起产品 CI/);
  assert5.ok(repositorySource.includes('.conclusion // \\"failure\\"'));
  assert5.match(repositorySource, /actions\/artifacts\/\$\{artifact_id\}/);
  assert5.match(repositorySource, /actions\/runs\/\$\{run_id\}/);
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
  assert5.equal(productWorkflows.length, 26);
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
test5("ChatSDK 保持独立分组动作、三件套Release且没有发布入口", () => {
  const root = new URL("../../../", import.meta.url);
  const ci = readFileSync7(new URL(".github/workflows/chatsdk/ci-sdk.yml", root), "utf8");
  const release = readFileSync7(new URL(".github/workflows/chatsdk/release-sdk.yml", root), "utf8");
  const central = readFileSync7(new URL(".github/workflows/gmb-repository.yml", root), "utf8");
  const ciScript = readFileSync7(new URL(".github/scripts/chatsdk/ci-sdk.mjs", root), "utf8");
  const releaseScript = readFileSync7(new URL(".github/scripts/chatsdk/release-sdk.mjs", root), "utf8");
  const packaging = readFileSync7(new URL("chatsdk/scripts/release.mjs", root), "utf8");
  assert5.match(ci, /^name: 聊天SDK · CI · SDK/m);
  assert5.match(release, /^name: 聊天SDK · Release · SDK/m);
  assert5.doesNotMatch(ci, /software_version:|source_sha:/);
  assert5.match(release, /gh run download "\$GMB_CI_RUN_ID" --name ChatSDK-CI/);
  assert5.match(release, /chatsdk\.tgz[\s\S]*chatsdk-release\.json[\s\S]*SHA256SUMS/);
  assert5.match(central, /^  chatsdk_ci_sdk__check:/m);
  assert5.match(central, /^  chatsdk_release_sdk__check:/m);
  assert5.match(central, /inputs\.pipeline == '\.github\/workflows\/chatsdk\/ci-sdk\.yml'/);
  assert5.match(central, /inputs\.pipeline == '\.github\/workflows\/chatsdk\/release-sdk\.yml'/);
  assert5.equal(existsSync7(new URL(".github/workflows/chatsdk/publish-sdk.yml", root)), false);
  assert5.doesNotMatch(`${ciScript}\n${releaseScript}`, /citizensdk|CitizenSDK|公民SDK/);
  assert5.match(packaging, /const RELEASE_ASSETS = \[ARCHIVE_NAME, MANIFEST_NAME, CHECKSUMS_NAME\]/);
});

// 中文注释：缓存恢复和显式保存是同一官方Action的两个准确入口，必须共同登记并锁定同一提交。
test5("GMB全部CI缓存入口使用依赖真源登记的同一固定Action提交", () => {
  const root = new URL("../../../", import.meta.url);
  const contract = JSON.parse(readFileSync7(new URL(".github/dependencies.json", root), "utf8"));
  const cacheSHA = "5a3ec84eff668545956fd18022155c47e93e2684";
  assert5.equal(contract.actions["actions/cache"], cacheSHA);
  assert5.equal(contract.actions["actions/cache/save"], cacheSHA);
  const chatSDKCI = readFileSync7(new URL(".github/workflows/chatsdk/ci-sdk.yml", root), "utf8");
  assert5.match(chatSDKCI, new RegExp(`actions/cache@${cacheSHA}`));
  assert5.match(chatSDKCI, new RegExp(`actions/cache/save@${cacheSHA}`));
});

test5("\u516C\u5F00\u4ED3\u5E93\u95E8\u7981\u7981\u6B62\u65B0\u589E\u660E\u6587\u7F51\u7EDC\u534F\u8BAE", () => {
  const source = readFileSync7(new URL("ci-repository.mjs", import.meta.url), "utf8");
  assert5.match(source, /\u660E\u6587\u7F51\u7EDC\u534F\u8BAE/);
  assert5.match(source, /insecure_transport_hits/);
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
test5("CitizenSDK \u53EA\u4F7F\u7528\u7EDF\u4E00 GMB \u5165\u53E3\u5E76\u4E14\u4EA7\u7269\u4E0D\u56DE\u5199\u6E90\u7801\u6811", () => {
  const ci = readFileSync7(new URL("../../workflows/citizensdk/ci-sdk.yml", import.meta.url), "utf8");
  const release = readFileSync7(new URL("../../workflows/citizensdk/release-sdk.yml", import.meta.url), "utf8");
  const registered = readFileSync7(new URL("../../workflows/gmb-repository.yml", import.meta.url), "utf8");
  const powTests = 'cargo test --manifest-path "$build_source/native/smoldot/pow/Cargo.toml" --workspace --locked';
  const powAllTargetsCheck = 'cargo check --manifest-path "$build_source/native/smoldot/pow/Cargo.toml" --workspace --all-targets --locked';
  const dependencies = JSON.parse(readFileSync7(new URL("../../dependencies.json", import.meta.url), "utf8"));
  const nativeBuild = readFileSync7(new URL("../../../citizensdk/scripts/build-native.sh", import.meta.url), "utf8");
  const releaseTool = readFileSync7(new URL("../../../citizensdk/scripts/release.mjs", import.meta.url), "utf8");
  const releaseWrapper = readFileSync7(new URL("../citizensdk/release-sdk.mjs", import.meta.url), "utf8");
  for (const source of [ci, release]) {
    assert5.match(source, /cargo install cargo-audit --version 0\.22\.2 --locked/);
    assert5.match(source, /node --test citizensdk\/scripts\/release\.test\.mjs/);
    assert5.match(source, /PROGRAM_CONSOLE_WORK_DIR: \$\{\{ runner\.temp \}\}\/citizensdk\/release-tests/);
    assert5.match(source, /CITIZENSDK_WORK_DIR: \$\{\{ runner\.temp \}\}\/citizensdk\/work/);
    assert5.match(source, /CITIZENSDK_NATIVE_OUTPUT_DIR: \$\{\{ runner\.temp \}\}\/citizensdk\/native/);
    assert5.match(source, /\$RUNNER_TEMP\/citizensdk\/build-source/);
    assert5.match(source, /flutter pub get --enforce-lockfile/);
    assert5.match(source, /dart format --output=none --set-exit-if-changed lib test/);
    assert5.match(source, /flutter analyze --no-fatal-infos --no-fatal-warnings/);
    assert5.ok(source.includes(powTests), "CitizenSDK PoW workspace 必须完整运行确定性测试");
    assert5.ok(source.includes(powAllTargetsCheck), "CitizenSDK PoW workspace 必须编译全部 target");
    assert5.doesNotMatch(source, /cargo test[^\n]+native\/smoldot\/pow\/Cargo\.toml[^\n]+--all-targets/);
    assert5.match(source, /flutter test --timeout=2m/);
    assert5.doesNotMatch(source, /native\/smoldot\/dart/);
    assert5.match(source, /native\/host\/libsmoldot\.dylib/);
    assert5.match(source, /build-source\/libsmoldot\.dylib/);
    assert5.match(source, /flutter create --platforms=android/);
    assert5.match(source, /flutter build apk --debug --target-platform android-arm64/);
    assert5.match(source, /:citizen_sdk:testDebugUnitTest --no-daemon/);
    assert5.match(source, /flutter create --platforms=ios/);
    assert5.match(source, /flutter build ios --no-codesign --release/);
    assert5.match(source, /aarch64-apple-ios-sim,x86_64-apple-ios/);
    assert5.match(source, /PROGRAM_CONSOLE_NATIVE_IOS_SIMULATOR_DIR/);
    assert5.match(source, /xcrun simctl bootstatus/);
    assert5.match(source, /xcodebuild test/);
    assert5.match(source, /-only-testing:RunnerTests/);
    assert5.match(source, /native\/host\/libsmoldot\.dylib/);
    assert5.match(source, /--source citizensdk/);
    assert5.match(source, /citizensdk\/citizensdk\.tgz/);
    assert5.doesNotMatch(source, /citizensdk\/(?:target|build|\.dart_tool)\//);
  }
  for (const expected of [
    "$RUNNER_TEMP/citizensdk/build-source",
    "flutter pub get --enforce-lockfile",
    "dart format --output=none --set-exit-if-changed lib test",
    "flutter analyze --no-fatal-infos --no-fatal-warnings",
    powTests,
    powAllTargetsCheck,
    "flutter test --timeout=2m",
  ]) assert5.ok(registered.includes(expected), expected);
  assert5.doesNotMatch(registered, /cargo test[^\n]+native\/smoldot\/pow\/Cargo\.toml[^\n]+--all-targets/);
  assert5.doesNotMatch(registered, /citizensdk\/native\/smoldot\/dart/);
  const registeredCiStart = registered.indexOf('  citizensdk_ci_sdk__check:');
  const registeredReleaseStart = registered.indexOf('  citizensdk_release_sdk__check:');
  assert5.ok(registeredCiStart >= 0 && registeredReleaseStart > registeredCiStart);
  const registeredCi = registered.slice(registeredCiStart, registeredReleaseStart);
  const registeredRelease = registered.slice(registeredReleaseStart);
  for (const source of [registeredCi, registeredRelease]) {
    assert5.match(source, /cargo install cargo-audit --version 0\.22\.2 --locked/);
    assert5.match(source, /dependencies audit --scope citizensdk/);
    assert5.match(source, /node --test citizensdk\/scripts\/release\.test\.mjs/);
    assert5.match(source, /:citizen_sdk:testDebugUnitTest --no-daemon/);
    assert5.match(source, /flutter build ios --no-codesign --release/);
    assert5.match(source, /PROGRAM_CONSOLE_NATIVE_IOS_SIMULATOR_DIR/);
    assert5.match(source, /xcodebuild test/);
    assert5.match(source, /-only-testing:RunnerTests/);
  }
  assert5.match(release, /--verify "\$RUNNER_TEMP\/citizensdk\/candidate"[\s\S]*--archive "\$RUNNER_TEMP\/citizensdk\/citizensdk\.tgz"/);
  assert5.match(registeredRelease, /--verify "\$RUNNER_TEMP\/citizensdk\/candidate"[\s\S]*--archive "\$RUNNER_TEMP\/citizensdk\/citizensdk\.tgz"/);
  const normalizedSteps = (source) => {
    const start = source.indexOf("    steps:\n");
    assert5.ok(start >= 0, "CitizenSDK workflow 缺少 steps");
    let body = source.slice(start);
    const nextJob = body.indexOf("\n\n\n  # ──");
    if (nextJob >= 0) body = body.slice(0, nextJob);
    return body
      .replaceAll("${{ github.sha }}", "${{ env.GMB_SOURCE_SHA }}")
      .replaceAll("${{ inputs.source_sha }}", "${{ env.GMB_SOURCE_SHA }}")
      .trim();
  };
  assert5.equal(normalizedSteps(ci), normalizedSteps(registeredCi));
  assert5.equal(normalizedSteps(release), normalizedSteps(registeredRelease));
  assert5.ok(dependencies.dartApplications.includes("citizensdk"));
  assert5.equal(dependencies.dartApplications.includes("citizensdk/native/smoldot/dart"), false);
  for (const required of [
    "citizensdk/pubspec.yaml",
    "citizensdk/pubspec.lock",
  ]) assert5.ok(dependencies.scopes.citizensdk.requiredFiles.includes(required), required);
  assert5.equal(
    dependencies.scopes.citizensdk.requiredFiles.some(
      (path) => path.startsWith("citizensdk/native/smoldot/dart/"),
    ),
    false,
  );
  assert5.match(registered, /inputs\.pipeline == '\.github\/workflows\/citizensdk\/ci-sdk\.yml'/);
  assert5.match(registered, /inputs\.pipeline == '\.github\/workflows\/citizensdk\/release-sdk\.yml'/);
  assert5.match(nativeBuild, /CITIZENSDK_WORK_DIR/);
  assert5.match(nativeBuild, /CITIZENSDK_NATIVE_OUTPUT_DIR/);
  assert5.match(nativeBuild, /\/Users\/rhett\/Only\/ProgramConsole\/target\/citizensdk/);
  assert5.match(nativeBuild, /cargo build[^\n]+--locked/);
  assert5.match(nativeBuild, /aarch64-apple-ios-sim/);
  assert5.match(nativeBuild, /x86_64-apple-ios/);
  assert5.match(nativeBuild, /output_dir\/ios-simulator/);
  assert5.match(nativeBuild, /aarch64-apple-darwin/);
  assert5.match(nativeBuild, /x86_64-apple-darwin/);
  assert5.match(nativeBuild, /lipo -create/);
  assert5.match(nativeBuild, /output_dir\/host\/libsmoldot\.dylib/);
  assert5.match(nativeBuild, /citizen_sr25519_derive_hard/);
  assert5.match(nativeBuild, /\^\(citizen_chat_mls_\|account_crypto_\)/);
  assert5.match(releaseTool, /android\/src\/main\/jniLibs\/arm64-v8a\/libsmoldot\.so/);
  assert5.match(releaseTool, /ios\/libsmoldot\.a/);
  assert5.match(releaseTool, /citizensdk-release\.json/);
  assert5.match(releaseTool, /assertOutsideSource/);
  assert5.match(releaseTool, /\/Users\/rhett\/Only\/ProgramConsole\/target\/citizensdk/);
  assert5.match(releaseTool, /'test\/smoldot\/subscription_test\.dart'/);
  assert5.match(releaseTool, /'docs\/smoldot-dart\/example\/README\.md'/);
  assert5.match(releaseWrapper, /const localRepositoryRoot = resolve\(dirname\(fileURLToPath\(import\.meta\.url\)\), '\.\.\/\.\.\/\.\.'\)/);
  assert5.match(releaseWrapper, /process\.env\.GITHUB_WORKSPACE[\s\S]*: localRepositoryRoot/);
  // 中文注释：单包重构只允许移动无需适配的上游资料和夹具；这些文件继续逐字节
  // 对齐 CitizenApp，生产绑定与测试中的适配文件则由 release.mjs 的固定哈希闭集约束。
  const byteIdenticalSmoldotDartFiles = new Map([
    ["BUILD.md", "docs/smoldot-dart/BUILD.md"],
    ["CHANGELOG.md", "docs/smoldot-dart/CHANGELOG.md"],
    ["LICENSE", "docs/smoldot-dart/LICENSE"],
    ["README.md", "docs/smoldot-dart/README.md"],
    ["UPSTREAM.md", "docs/smoldot-dart/UPSTREAM.md"],
    ["analysis_options.yaml", "docs/smoldot-dart/source-analysis_options.yaml"],
    ["pubspec.lock", "docs/smoldot-dart/source-pubspec.lock"],
    ["pubspec.yaml", "docs/smoldot-dart/source-pubspec.yaml"],
    ["lib/src/types.dart", "lib/src/smoldot/types.dart"],
    ["test/fixtures/polkadot.json", "test/smoldot/fixtures/polkadot.json"],
    ["test/fixtures/westend.json", "test/smoldot/fixtures/westend.json"],
  ]);
  for (const [sourcePath, targetPath] of byteIdenticalSmoldotDartFiles) {
    const source = readFileSync7(new URL(`../../../citizenapp/smoldot/dart/${sourcePath}`, import.meta.url));
    const target = readFileSync7(new URL(`../../../citizensdk/${targetPath}`, import.meta.url));
    assert5.ok(source.equals(target), `${sourcePath} -> ${targetPath}`);
  }
  const eventMetadataSource = readFileSync7(new URL(
    "../../../citizenapp/smoldot/pow/full-node/tests/substrate-node-template-metadata.hex",
    import.meta.url,
  ));
  const eventMetadataFixture = readFileSync7(new URL(
    "../../../citizensdk/test/transaction/fixtures/substrate-v14-system-events-metadata.hex",
    import.meta.url,
  ));
  assert5.ok(
    eventMetadataSource.equals(eventMetadataFixture),
    "CitizenSDK System.Event metadata 测试夹具必须与登记来源逐字节一致",
  );
  const powSourceLock = readFileSync7(
    new URL("../../../citizenapp/smoldot/pow/Cargo.lock", import.meta.url),
    "utf8",
  );
  const powTargetLock = readFileSync7(
    new URL("../../../citizensdk/native/smoldot/pow/Cargo.lock", import.meta.url),
    "utf8",
  );
  const ffiTargetLock = readFileSync7(
    new URL("../../../citizensdk/native/smoldot/ffi/Cargo.lock", import.meta.url),
    "utf8",
  );
  const ffiSourceLock = readFileSync7(
    new URL("../../../citizenapp/smoldot/ffi/Cargo.lock", import.meta.url),
    "utf8",
  );
  for (const forbidden of ["account-crypto", "openmls", "hpke-rs", "aes-gcm"]) {
    assert5.doesNotMatch(ffiTargetLock, new RegExp(`name = "${forbidden}"`));
  }
  const registryIdentities = (lock) => new Set(
    [...lock.matchAll(
      /\[\[package\]\]\nname = "([^"]+)"\nversion = "([^"]+)"\nsource = "registry\+[^"]+"\nchecksum = "([0-9a-f]{64})"/g,
    )].map((match) => `${match[1]}@${match[2]}#${match[3]}`),
  );
  const sourceRegistry = registryIdentities(ffiSourceLock);
  for (const identity of registryIdentities(ffiTargetLock)) {
    assert5.ok(sourceRegistry.has(identity), `FFI 锁文件引入未经 CitizenApp 验证的依赖：${identity}`);
  }
  const powSourceRegistry = registryIdentities(powSourceLock);
  for (const identity of registryIdentities(powTargetLock)) {
    assert5.ok(
      powSourceRegistry.has(identity),
      `PoW 锁文件引入未经 CitizenApp 验证的依赖：${identity}`,
    );
  }
  for (const forbidden of ["smoldot-full-node", "smoldot-light-wasm"]) {
    assert5.doesNotMatch(powTargetLock, new RegExp(`name = "${forbidden}"`));
  }
  for (const path of ["Cargo.toml", "src/lib.rs"]) {
    const source = readFileSync7(new URL(`../../../shared/citizen-signer/${path}`, import.meta.url));
    const target = readFileSync7(new URL(`../../../citizensdk/native/signer/${path}`, import.meta.url));
    assert5.ok(source.equals(target), `native/signer/${path}`);
  }
  for (const relativePath of [
    "android/src/main/kotlin/org/citizen/sdk/CitizenSdkPlugin.kt",
    "android/src/main/kotlin/org/citizen/sdk/AndroidHardwareSecretVault.kt",
    "android/src/test/kotlin/org/citizen/sdk/HardwareSecretVaultTest.kt",
    "android/src/test/kotlin/org/citizen/sdk/VaultEnvelopeTest.kt",
    "ios/Tests/SecureEnclaveSecretVaultTests.swift",
    "ios/Tests/VaultEnvelopeTests.swift",
  ]) {
    assert5.ok(existsSync7(new URL(`../../../citizensdk/${relativePath}`, import.meta.url)), relativePath);
  }
  for (const obsoletePath of [
    "android/src/main/kotlin/CitizenSdkPlugin.kt",
    "android/src/main/kotlin/AndroidHardwareSecretVault.kt",
    "android/src/test/kotlin/HardwareSecretVaultTest.kt",
    "android/src/test/kotlin/VaultEnvelopeTest.kt",
  ]) {
    assert5.equal(existsSync7(new URL(`../../../citizensdk/${obsoletePath}`, import.meta.url)), false, obsoletePath);
  }
  const podspec = readFileSync7(new URL("../../../citizensdk/ios/citizen_sdk.podspec", import.meta.url), "utf8");
  assert5.match(podspec, /s\.test_spec 'Tests'/);
  assert5.equal(
    existsSync7(new URL("../../../citizensdk/native/smoldot/dart", import.meta.url)),
    false,
  );
  assert5.deepEqual(
    readdirSync(new URL("../../../citizensdk/lib/src/smoldot", import.meta.url)).sort(),
    ["bindings.dart", "chain.dart", "client.dart", "json_rpc.dart", "platform.dart", "smoldot.dart", "types.dart"],
  );
  assert5.deepEqual(
    readdirSync(new URL("../../../citizensdk/test/smoldot", import.meta.url)).sort(),
    ["chain_info_test.dart", "client_basic_test.dart", "ffi_basic_test.dart", "fixtures",
      "json_rpc_test.dart", "smoldot_test.dart", "subscription_test.dart"],
  );
  const prefix2 = "const implementations = Object.freeze(";
  const repositoryAction = readFileSync7(new URL("ci-repository.mjs", import.meta.url), "utf8");
  const repositoryLine = repositoryAction.split("\n").find((candidate) => candidate.startsWith(prefix2));
  const guardrails = JSON.parse(repositoryLine.slice(prefix2.length, -2)).guardrails;
  assert5.match(guardrails, /citizensdk\/native\/smoldot\/pow\/\*/);
  assert5.match(guardrails, /citizensdk\/docs\/smoldot-dart\/\*/);
  assert5.match(guardrails, /citizensdk\/lib\/src\/smoldot\/\*/);
  assert5.match(guardrails, /citizensdk\/test\/smoldot\/\*/);
  assert5.doesNotMatch(guardrails, /citizensdk\/native\/smoldot\/dart\/\*/);
  assert5.ok(
    guardrails.includes("grep -vE '^\\+const implementations = Object\\.freeze\\('")
  );
  assert5.match(guardrails, /citizen_sdk\.smoldot\.database\.v1/);
  assert5.match(guardrails, /citizensdk-v\[0-9\]\+/);
  for (const action of ["ci-sdk.mjs", "release-sdk.mjs"]) {
    const wrapper = readFileSync7(new URL(`../citizensdk/${action}`, import.meta.url), "utf8");
    const line = wrapper.split("\n").find((candidate) => candidate.startsWith(prefix2));
    assert5.ok(line?.endsWith(");"));
    assert5.equal(JSON.parse(line.slice(prefix2.length, -2))["citizensdk-release"], releaseTool);
  }
});
// 中文注释：中央原生产物可以位于仓库外，但 CocoaPods 文件模式必须始终保持相对路径。
test5("CitizenApp iOS 本机中央原生库使用 CocoaPods 合法相对文件模式", () => {
  const podspec = readFileSync7(new URL("../../../citizenapp/ios/smoldot/smoldot_ffi.podspec", import.meta.url), "utf8");
  assert5.match(podspec, /Pathname\.new\(library_path\)\.relative_path_from\(Pathname\.new\(__dir__\)\)\.to_s/);
  assert5.match(podspec, /s\.source\s*=\s*\{ :git => 'https:\/\/github\.com\/ChineseFederation\/GMB\.git' \}/);
  assert5.match(podspec, /s\.vendored_libraries\s*=\s*library_pattern/);
  assert5.doesNotMatch(podspec, /s\.vendored_libraries\s*=\s*library_path/);
});
// 中文注释：Flutter 的默认目录误报只能由准确中央 APK 收口，禁止搜索或复制回产品 build。
test5("CitizenApp Android 本机只接管固定中央 Gradle 产物", () => {
  const localRun = readFileSync7(new URL("../../../citizenapp/scripts/citizenapp-run.sh", import.meta.url), "utf8");
  assert5.match(localRun, /ANDROID_APK="\$BUILD_DIR\/app\/outputs\/flutter-apk\/app-release\.apk"[\s\S]*if ! flutter build apk/);
  assert5.match(localRun, /if ! flutter build apk[\s\S]*\[\[ -f "\$ANDROID_APK" \]\]/);
  assert5.doesNotMatch(localRun, /find [^\n]*app-release\.apk|cp [^\n]*ANDROID_APK[^\n]*build\//);
});
test5("CitizenApp轻节点与ChatSDK聊天原生库分别从各自目录加载", () => {
  const platform = readFileSync7(new URL("../../../citizenapp/smoldot/dart/lib/src/platform.dart", import.meta.url), "utf8");
  const mls = readFileSync7(new URL("../../../chatsdk/lib/src/mls/mls_native.dart", import.meta.url), "utf8");
  const testEntry = readFileSync7(new URL("../../../citizenapp/scripts/citizenapp-test.sh", import.meta.url), "utf8");
  assert5.ok(platform.includes("'smoldot',\n        'ffi',\n        'target',\n        'release'"));
  assert5.ok(platform.includes("'..', 'ffi', 'target', 'release'"));
  assert5.match(mls, /'native',\s*'target',\s*'release',\s*'libchat_sdk\.dylib'/u);
  assert5.match(mls, /'chatsdk',\s*'native',\s*'target',\s*'release'/u);
  assert5.doesNotMatch(mls, /'smoldot',\s*'ffi'/u);
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

test5("12 个独立 Release 动作锚定成功 CI 源码且首次版本不递增", () => {
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
    "citizensdk/release-sdk.mjs",
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

test5("CitizenSDK 实际版本门禁验证 CI 身份、版本真源和 Tag 软件版本", () => {
  const prefix = "const implementations = Object.freeze(";
  const actions = [
    "citizenapp/release-ios.mjs", "citizenapp/release-android.mjs",
    "citizenwallet/release-ios.mjs", "citizenwallet/release-android.mjs",
    "citizenchain/release-node-linux-arm.mjs", "citizenchain/release-node-linux-amd.mjs",
    "citizenchain/release-node-macos.mjs", "citizenchain/release-node-windows.mjs",
    "citizenchain/release-runtime-wasm.mjs", "citizenserve/release-cloudflare.mjs",
    "citizensdk/release-sdk.mjs", "citizenweb/release-web.mjs",
  ];
  const versions = actions.map((action) => {
    const wrapper = readFileSync7(new URL(`../${action}`, import.meta.url), "utf8");
    const line = wrapper.split("\n").find((candidate) => candidate.startsWith(prefix));
    return JSON.parse(line.slice(prefix.length, -2))["version-tag"];
  });
  assert5.equal(new Set(versions).size, 1, "12 个 Release 必须使用同一版本门禁字节");

  // macOS 的 /var 是 /private/var 的符号链接；使用规范路径确保被测模块的
  // import.meta.url 主入口判断真实执行，而不是把空操作误判成成功。
  const root = realpathSync7(mkdtempSync7(join7(tmpdir7(), "citizensdk-version-gate-")));
  try {
    const bin = join7(root, "bin");
    mkdirSync7(join7(root, "citizensdk"), { recursive: true });
    mkdirSync7(bin);
    writeFileSync7(join7(root, "citizensdk", "pubspec.yaml"), "name: citizen_sdk\nversion: 0.1.0\n");
    writeFileSync7(join7(root, "version-tag.mjs"), versions[0]);
    const sourceSha = "a".repeat(40);
    writeFileSync7(join7(bin, "git"), `#!/bin/sh\nprintf '%s\\n' '${sourceSha}'\n`);
    writeFileSync7(join7(bin, "gh"), `#!/bin/sh
case "$*" in
  *actions/runs/77*) printf '%s\\n' '{"status":"completed","conclusion":"success","event":"workflow_dispatch","head_branch":"main","head_sha":"${sourceSha}","display_title":"公民SDK · CI · SDK","path":".github/workflows/gmb-repository.yml"}' ;;
  *releases?*) printf '%s\\n' '[]' ;;
  *) exit 2 ;;
esac
`);
    chmodSync7(join7(bin, "git"), 0o700);
    chmodSync7(join7(bin, "gh"), 0o700);
    const base = [
      join7(root, "version-tag.mjs"), "verify-release-source",
      "--ci-run-id", "77", "--version-tag", "citizensdk-v0.1.0",
      "--source-sha", sourceSha, "--software-version", "0.1.0",
      "--prefix", "citizensdk-v", "--product-id", "citizensdk",
      "--target", "sdk", "--workflow", "citizensdk/ci-sdk.yml",
    ];
    const environment = { ...process.env, PATH: `${bin}:${process.env.PATH}` };
    const success = spawnSync2(process.execPath, base, { cwd: root, env: environment, encoding: "utf8" });
    assert5.equal(success.status, 0, success.stderr);
    assert5.match(success.stdout, /Release 已锁定成功 CI/);
    const softwareVersionIndex = base.indexOf("--software-version") + 1;
    const mismatchedArguments = [...base];
    mismatchedArguments[softwareVersionIndex] = "0.1.1";
    const mismatch = spawnSync2(
      process.execPath,
      mismatchedArguments,
      { cwd: root, env: environment, encoding: "utf8" },
    );
    assert5.notEqual(mismatch.status, 0);
    assert5.match(mismatch.stderr, /CitizenSDK Tag 与正式软件版本不一致/);

    writeFileSync7(join7(bin, "gh"), `#!/bin/sh
case "$*" in
  *actions/runs/77*) printf '%s\\n' '{"status":"completed","conclusion":"success","event":"workflow_dispatch","head_branch":"main","head_sha":"${sourceSha}","display_title":"错误 CI","path":".github/workflows/gmb-repository.yml"}' ;;
  *releases?*) printf '%s\\n' '[]' ;;
  *) exit 2 ;;
esac
`);
    const wrongIdentity = spawnSync2(
      process.execPath,
      base,
      { cwd: root, env: environment, encoding: "utf8" },
    );
    assert5.notEqual(wrongIdentity.status, 0);
    assert5.match(wrongIdentity.stderr, /Release 来源不是同产品、同端、同 workflow 的成功 CI/);
  } finally {
    rmSync7(root, { recursive: true, force: true });
  }
});

// 中文注释：产品分组真源和 GitHub 唯一登记入口必须同时满足同一 Release 工具合同，防止只修一侧。
test5("节点 Release 前置验证与正式构建统一使用隔离工具", () => {
  const workflows = [
    ["release-node-linux-arm.yml", "release-node-linux-arm.mjs"],
    ["release-node-linux-amd.yml", "release-node-linux-amd.mjs"],
    ["release-node-macos.yml", "release-node-macos.mjs"],
    ["release-node-windows.yml", "release-node-windows.mjs"],
  ];
  const registered = readFileSync7(new URL("../../workflows/gmb-repository.yml", import.meta.url), "utf8");
  for (const [workflow, action] of workflows) {
    const source = readFileSync7(new URL(`../../workflows/citizenchain/${workflow}`, import.meta.url), "utf8");
    const verifier = `node release-tool/.github/scripts/citizenchain/${action} version-tag verify-release-source`;
    for (const [entry, contract] of [[workflow, source], ["gmb-repository.yml", registered]]) {
      assert5.ok(contract.includes(verifier), `${entry} 前置验证未使用隔离 Release 工具`);
      assert5.doesNotMatch(contract, new RegExp(`node \\.github/scripts/citizenchain/${action} version-tag verify-release-source`));
      assert5.ok(contract.indexOf("拉取前置 Release 工具") < contract.indexOf(verifier));
    }
  }
});

// 中文注释：仓库级 Latest 不能表达产品、端、动作的独立最新版本，13 个 Release 必须统一禁用该标记。
test5("13 个 Release 分组真源与登记入口统一禁用仓库级 Latest", () => {
  const workflows = [
    "citizenapp/release-ios.yml",
    "citizenapp/release-android.yml",
    "citizenwallet/release-ios.yml",
    "citizenwallet/release-android.yml",
    "citizenchain/release-node-linux-arm.yml",
    "citizenchain/release-node-linux-amd.yml",
    "citizenchain/release-node-macos.yml",
    "citizenchain/release-node-windows.yml",
    "citizenchain/release-runtime-wasm.yml",
    "citizenserve/release-cloudflare.yml",
    "citizensdk/release-sdk.yml",
    "chatsdk/release-sdk.yml",
    "citizenweb/release-web.yml",
  ];
  for (const workflow of workflows) {
    const source = readFileSync7(new URL(`../../workflows/${workflow}`, import.meta.url), "utf8");
    assert5.match(source, /--latest false/);
    assert5.doesNotMatch(source, /--latest true/);
  }
  const registered = readFileSync7(new URL("../../workflows/gmb-repository.yml", import.meta.url), "utf8");
  assert5.equal((registered.match(/--latest false/g) ?? []).length, 13);
  assert5.doesNotMatch(registered, /--latest true/);
});

// 中文注释：动作必须继续自包含，但依赖门禁载荷必须逐字一致，防止单个产品再次保留过期构建命令。
test5("25 个独立动作的 Tauri 依赖契约完全一致", () => {
  const actions = [
    "citizenapp/ci-android.mjs",
    "citizenapp/ci-ios.mjs",
    "citizenapp/release-android.mjs",
    "citizenapp/release-ios.mjs",
    "citizenchain/ci-node-linux-amd.mjs",
    "citizenchain/ci-node-linux-arm.mjs",
    "citizenchain/ci-node-macos.mjs",
    "citizenchain/ci-node-windows.mjs",
    "citizenchain/ci-runtime-wasm.mjs",
    "citizenchain/release-node-linux-amd.mjs",
    "citizenchain/release-node-linux-arm.mjs",
    "citizenchain/release-node-macos.mjs",
    "citizenchain/release-node-windows.mjs",
    "citizenchain/release-runtime-wasm.mjs",
    "citizenserve/ci-cloudflare.mjs",
    "citizenserve/release-cloudflare.mjs",
    "citizensdk/ci-sdk.mjs",
    "citizensdk/release-sdk.mjs",
    "citizenwallet/ci-android.mjs",
    "citizenwallet/ci-ios.mjs",
    "citizenwallet/release-android.mjs",
    "citizenwallet/release-ios.mjs",
    "citizenweb/ci-web.mjs",
    "citizenweb/release-web.mjs",
    "gmb-repository/ci-repository.mjs",
  ];
  assert5.equal(actions.length, 25);
  const prefix = "const implementations = Object.freeze(";
  const dependencies = actions.map((action) => {
    const source = readFileSync7(new URL(`../${action}`, import.meta.url), "utf8");
    const line = source.split("\n").find((candidate) => candidate.startsWith(prefix));
    assert5.ok(line?.endsWith(");"), `${action} 缺少独立 implementations 登记`);
    const implementation = JSON.parse(line.slice(prefix.length, -2)).dependencies;
    assert5.ok(implementation.includes('`${cli} build --config "$tauri_override"`'));
    assert5.ok(implementation.includes('`--no-bundle --ci -- --locked`'));
    assert5.ok(implementation.includes('`${cli} bundle --config "$tauri_override"`'));
    assert5.ok(implementation.includes('`--bundles app --ci`'));
    assert5.doesNotMatch(implementation, /\$\{cli\} build --no-bundle --ci -- --locked/);
    assert5.doesNotMatch(implementation, /\$\{cli\} bundle --bundles app --ci/);
    return implementation;
  });
  assert5.equal(new Set(dependencies).size, 1, "25 个动作的 dependencies 实现发生漂移");
});


// 中文注释：Android NDK 官方版本由主版本、次版本和构建号组成，禁止再次误按四段版本拦截全部任务。
test5("Android NDK 官方三段版本能够通过统一依赖门禁", () => {
  const source = readFileSync7(new URL("ci-repository.mjs", import.meta.url), "utf8");
  const prefix = "const implementations = Object.freeze(";
  const line = source.split("\n").find((candidate) => candidate.startsWith(prefix));
  const dependencies = JSON.parse(line.slice(prefix.length, -2)).dependencies;
  assert5.ok(dependencies.includes("if (!/^\\d+(?:\\.\\d+){2}$/.test(androidNdk))"));
});
