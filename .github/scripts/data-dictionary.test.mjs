import assert from 'node:assert/strict';
import test from 'node:test';

import {
  addedClosedValues,
  addedFieldNames,
  globToRegex,
  isDeclaredLegacyRead,
  lineUsesFieldName,
  markdownUsesFieldName,
  toCamelCase,
  toSnakeCase,
  validateDictionary,
} from './data-dictionary.mjs';

function value(value, fullNameEn, fullNameZh) {
  return {
    value,
    full_name_en: fullNameEn,
    short_name_en: null,
    full_name_zh: fullNameZh,
    short_name_zh: null,
  };
}

function fixture() {
  return {
    index: {
      domains: [{ domain_id: 'account', file: 'account.json' }],
      ignored_paths: ['**/*.g.dart'],
    },
    shards: [{
      domain_id: 'account',
      concepts: [{
        concept_id: 'sign_mode',
        field_name: 'sign_mode',
        field_name_zh: '签名模式',
        authority: 'gmb',
        data_type: 'enum',
        value_set_id: 'sign_mode',
        forbidden_names: ['wallet_mode'],
        legacy_reads: [{ field_name: 'wallet_mode', path: 'citizenapp/lib/wallet.dart' }],
      }],
      value_sets: [{
        value_set_id: 'sign_mode',
        value_set_zh: '签名模式',
        authority: 'gmb',
        value_type: 'string',
        forbidden_values: ['local'],
        values: [value('cold', 'Cold Signing', '冷签名'), value('hot', 'Hot Signing', '热签名')],
      }],
      contracts: [{
        contract_id: 'wallet_signing_route',
        contract_name_zh: '钱包签名路由',
        authority: 'gmb',
        paths: ['citizenapp/**'],
        fields: ['sign_mode'],
        value_sets: ['sign_mode'],
      }],
    }],
  };
}

test('snake_case 只做机械 lowerCamelCase 转换', () => {
  assert.equal(toCamelCase('account_id'), 'accountId');
  assert.equal(toCamelCase('credential_signer_public_key'), 'credentialSignerPublicKey');
  assert.equal(toSnakeCase('credentialSignerPublicKey'), 'credential_signer_public_key');
});

test('路径规则精确支持单层与递归通配', () => {
  assert.ok(globToRegex('citizenapp/lib/**').test('citizenapp/lib/a/b.dart'));
  assert.ok(globToRegex('**/*.g.dart').test('citizenapp/lib/isar/a.g.dart'));
  assert.ok(!globToRegex('citizenapp/lib/*.dart').test('citizenapp/lib/a/b.dart'));
});

test('字段提取只收序列化和跨文件契约形态', () => {
  assert.deepEqual(addedFieldNames("value['account_id']", '.dart'), [{ fieldName: 'account_id', strong: true }]);
  assert.deepEqual(addedFieldNames('accountId: value,', '.dart'), [{ fieldName: 'account_id', strong: false }]);
  assert.deepEqual(addedFieldNames('final value = input;', '.dart'), []);
});

test('字段命中不误伤相同词根函数名', () => {
  assert.ok(lineUsesFieldName("final value = json['wallet_account'];", 'wallet_account'));
  assert.ok(lineUsesFieldName('wallet_account: input,', 'wallet_account'));
  assert.ok(!lineUsesFieldName('resolve_wallet_account(input);', 'wallet_account'));
});

test('废弃字段只允许在登记路径作为单向读取键', () => {
  const reads = [{ field_name: 'wallet_mode', path: 'citizenapp/lib/wallet.dart' }];
  assert.ok(isDeclaredLegacyRead('#[serde(rename = "wallet_mode")]', 'citizenapp/lib/wallet.dart', 'wallet_mode', reads));
  assert.ok(isDeclaredLegacyRead('r#"{"wallet_mode":null}"#', 'citizenapp/lib/wallet.dart', 'wallet_mode', reads));
  assert.ok(!isDeclaredLegacyRead('wallet_mode: value,', 'citizenapp/lib/wallet.dart', 'wallet_mode', reads));
  assert.ok(!isDeclaredLegacyRead('"wallet_mode": value,', 'citizenapp/lib/other.dart', 'wallet_mode', reads));
});

test('文档允许明确禁止旧字段但拒绝当前契约使用', () => {
  assert.ok(markdownUsesFieldName('API 字段 `wallet_account` 用于授权。', 'wallet_account'));
  assert.ok(!markdownUsesFieldName('API 字段禁止恢复 `wallet_account`。', 'wallet_account'));
});

test('数据字典要求字段、值集和契约双向引用完整', () => {
  const { index, shards } = fixture();
  const result = validateDictionary(index, shards);
  assert.equal(result.concepts.size, 1);
  assert.equal(result.valueSets.size, 1);
  assert.throws(() => validateDictionary(index, [{ ...shards[0], contracts: [] }]), /字段未进入任何契约/);
});

test('数据字典拒绝重复字段、假简称和动态值', () => {
  const { index, shards } = fixture();
  const duplicate = structuredClone(shards);
  duplicate[0].concepts.push({ ...duplicate[0].concepts[0], concept_id: 'second_sign_mode' });
  assert.throws(() => validateDictionary(index, duplicate), /field_name 跨分片重复|字典序/);

  const fakeShort = structuredClone(shards);
  fakeShort[0].value_sets[0].values[0].short_name_en = 'Cold Signing';
  assert.throws(() => validateDictionary(index, fakeShort), /与全称重复/);

  const dynamic = structuredClone(shards);
  dynamic[0].value_sets[0].values[0].value = '0x'.padEnd(66, 'a');
  assert.throws(() => validateDictionary(index, dynamic), /动态 URL、哈希、ID 或时间/);
});

test('闭集字段新增值必须先进入对应值集', () => {
  const { index, shards } = fixture();
  const dictionary = validateDictionary(index, shards);
  assert.deepEqual(addedClosedValues("signMode: 'hot'", dictionary.concepts, dictionary.valueSets), []);
  assert.deepEqual(addedClosedValues("signMode: 'external'", dictionary.concepts, dictionary.valueSets), [
    { conceptId: 'sign_mode', value: 'external' },
  ]);
  assert.deepEqual(addedClosedValues("signMode: 'hot', label: '本机'", dictionary.concepts, dictionary.valueSets), []);
});
