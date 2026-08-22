import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import test from 'node:test';

import {
  compareSemanticVersions,
  expectedSemanticCandidate,
  nextSemanticVersion,
  parseSemanticVersion,
  validateWorkflowFileName,
} from './version-tag-contract.mjs';
import { validateLockChange } from './citizenchain-node-version.mjs';

test('workflow 合同同时接受 yml 与 yaml 且拒绝路径和伪扩展名', () => {
  assert.equal(validateWorkflowFileName('citizenchain-node-ci-linux-amd.yml'), 'citizenchain-node-ci-linux-amd.yml');
  assert.equal(validateWorkflowFileName('citizenchain-node-ci-linux-arm.yaml'), 'citizenchain-node-ci-linux-arm.yaml');
  for (const value of [
    '.github/workflows/citizenchain-node-ci-linux-arm.yaml',
    'citizenchain-node-ci-linux-arm.yaml.bak',
    'citizenchain-node-ci-linux-arm.YAML',
    'citizenchain_node_ci_linux_arm.yaml',
  ]) assert.throws(() => validateWorkflowFileName(value), /workflow 无效/);
});

test('正式 Release 软件版本按末两段 0–99 统一进位', () => {
  assert.equal(nextSemanticVersion('1.0.0'), '1.0.1');
  assert.equal(nextSemanticVersion('1.0.99'), '1.1.0');
  assert.equal(nextSemanticVersion('1.23.99'), '1.24.0');
  assert.equal(nextSemanticVersion('1.99.99'), '2.0.0');
  assert.equal(expectedSemanticCandidate('1.0.0', []), '1.0.1');
  assert.equal(expectedSemanticCandidate('1.0.0', ['1.0.2', '1.0.1']), '1.0.3');
});

test('不同端分别读取自己的正式 Release 集合，不共享版本基线', () => {
  assert.equal(expectedSemanticCandidate('1.0.0', ['1.0.4']), '1.0.5');
  assert.equal(expectedSemanticCandidate('1.0.0', ['1.0.2']), '1.0.3');
});

test('拒绝越界、前导零和非三段软件版本', () => {
  for (const value of ['1.0.100', '1.100.0', '1.00.1', '1.0', 'v1.0.0']) {
    assert.throws(() => parseSemanticVersion(value));
  }
  assert.equal(compareSemanticVersions('1.2.9', '1.2.10'), -1);
});

test('节点锁文件只允许本地 workspace 包同步到候选版本', () => {
  const script = readFileSync(new URL('./citizenchain-node-version.mjs', import.meta.url), 'utf8');
  const before = `# lock\n[[package]]\nname = "citizenchain"\nversion = "1.0.0"\ndependencies = [\n "serde",\n]\n\n[[package]]\nname = "serde"\nversion = "1.0.0"\nsource = "registry+https://example.invalid"\nchecksum = "abc"\n`;
  const after = before.replace('name = "citizenchain"\nversion = "1.0.0"',
    'name = "citizenchain"\nversion = "1.0.1"');
  assert.equal(validateLockChange(before, after, '1.0.1'), 1);
  assert.equal(validateLockChange(before, before, '1.0.0'), 0);
  const windowsBefore = before.replaceAll('\n', '\r\n');
  const windowsAfter = after.replaceAll('\n', '\r\n');
  assert.equal(validateLockChange(windowsBefore, windowsAfter, '1.0.1'), 1);
  assert.equal(validateLockChange(windowsBefore, after, '1.0.1'), 1);
  assert.throws(() => validateLockChange(before, after.replace('checksum = "abc"', 'checksum = "def"'), '1.0.1'),
    /Cargo\.lock/);
  assert.match(script, /runCargo\(\['update', '--workspace'\]\)/);
  assert.match(script, /runCargo\(\['metadata', '--locked', '--offline', '--no-deps'/);
});

test('Windows 节点 CI 与 Release 固定用 Bash 传入候选版本', () => {
  for (const workflow of [
    'citizenchain-node-ci-windows.yml',
    'citizenchain-node-release-windows.yml',
  ]) {
    const source = readFileSync(new URL(`../workflows/${workflow}`, import.meta.url), 'utf8');
    assert.match(source,
      /- name: 同步并锁定节点候选版本\n(?:[ ]{8}#.*\n)*[ ]{8}shell: bash\n[ ]{8}run: node .*citizenchain-node-version\.mjs lock "\$GMB_SOFTWARE_VERSION"/);
  }
});

test('全部 CI 只验证构建，不创建 Tag、不推进正式版本', () => {
  const workflowsUrl = new URL('../workflows/', import.meta.url);
  const ciFiles = readdirSync(workflowsUrl).filter((value) => /-ci-.*\.ya?ml$/.test(value));
  assert.equal(ciFiles.length, 11);
  for (const workflow of ciFiles) {
    const source = readFileSync(new URL(workflow, workflowsUrl), 'utf8');
    assert.doesNotMatch(source, /finalize-version-tag|finalize-semantic-ci|finalize-runtime-ci/);
    assert.doesNotMatch(source, /contents:\s*write/);
    assert.doesNotMatch(source, /GMB_VERSION_TAG/);
  }
});

test('每个 Release 用成功 ci_run_id 复核来源并创建唯一正式 Tag', () => {
  const releases = [
    ['citizenapp-release-ios', 'citizenapp-ios-v', 'citizenapp', 'ios', 'citizenapp-ci-ios.yml'],
    ['citizenapp-release-android', 'citizenapp-android-v', 'citizenapp', 'android', 'citizenapp-ci-android.yml'],
    ['citizenwallet-release-ios', 'citizenwallet-ios-v', 'citizenwallet', 'ios', 'citizenwallet-ci-ios.yml'],
    ['citizenwallet-release-android', 'citizenwallet-android-v', 'citizenwallet', 'android', 'citizenwallet-ci-android.yml'],
    ['citizenapp-cloudflare-release-cloudflare', 'citizenapp-cloudflare-v', 'citizenapp-cloudflare', 'cloudflare', 'citizenapp-cloudflare-ci-cloudflare.yml'],
    ['citizenweb-release-web', 'citizenweb-v', 'citizenweb', 'web', 'citizenweb-ci-web.yml'],
    ['citizenchain-node-release-linux-arm', 'citizenchain-node-linux-arm-v', 'citizenchain-node', 'linux-arm', 'citizenchain-node-ci-linux-arm.yaml'],
    ['citizenchain-node-release-linux-amd', 'citizenchain-node-linux-amd-v', 'citizenchain-node', 'linux-amd', 'citizenchain-node-ci-linux-amd.yml'],
    ['citizenchain-node-release-macos', 'citizenchain-node-macos-v', 'citizenchain-node', 'macos', 'citizenchain-node-ci-macos.yml'],
    ['citizenchain-node-release-windows', 'citizenchain-node-windows-v', 'citizenchain-node', 'windows', 'citizenchain-node-ci-windows.yml'],
    ['citizenchain-runtime-release-wasm', 'citizenchain-runtime-wasm-v', 'citizenchain-runtime', 'wasm', 'citizenchain-runtime-ci-wasm.yml'],
  ];
  for (const [release, prefix, product, target, workflow] of releases) {
    const source = readFileSync(new URL(`../workflows/${release}.yml`, import.meta.url), 'utf8');
    assert.match(source, /ci_run_id:[\s\S]*GMB_CI_RUN_ID: \$\{\{ inputs\.ci_run_id \}\}/);
    assert.match(source, /verify-release-source[\s\S]*--ci-run-id "\$GMB_CI_RUN_ID"/);
    assert.ok(source.includes(`--prefix ${prefix}`), `${release} 缺少正式 Tag 前缀`);
    assert.ok(source.includes(`--product-id ${product}`), `${release} 缺少准确产品`);
    assert.ok(source.includes(`--target ${target}`), `${release} 缺少准确端`);
    assert.ok(source.includes(`--workflow ${workflow}`), `${release} 缺少准确 CI workflow`);
    assert.match(source, /--tag "\$GMB_VERSION_TAG"/);
  }
});

test('Release 公共工具先创建事务 Tag，正式资产失败时回滚草稿与 Tag', () => {
  const source = readFileSync(new URL('./github-release.mjs', import.meta.url), 'utf8');
  assert.match(source, /async createTag[\s\S]*repos\/\$\{repository\}\/git\/refs/);
  assert.match(source, /release', 'create'[\s\S]*'--verify-tag'/);
  assert.doesNotMatch(source, /release', 'create'[\s\S]*'--target'/);
  assert.match(source, /reuseExistingTag[\s\S]*await versionTagCommit[\s\S]*reuseExistingTag = true/);
  assert.match(source, /await client\.createTag[\s\S]*await client\.createDraft/);
  assert.match(source, /async deleteTag/);
  assert.match(source, /Tag 回滚失败/);
});

test('Android Release 接受自签名上传证书且不产生 detached v4 文件', () => {
  for (const workflow of ['citizenapp-release-android.yml', 'citizenwallet-release-android.yml']) {
    const source = readFileSync(new URL(`../workflows/${workflow}`, import.meta.url), 'utf8');
    assert.match(source, /--v4-signing-enabled false/);
    assert.match(source, /test "\$apk_certificate_sha256" = "\$key_certificate_sha256"/);
    assert.match(source, /test "\$apk_certificate_sha256" = "\$aab_certificate_sha256"/);
  }
});

test('移动端正式 Release 资产名统一使用 ASCII 产品 id', () => {
  const products = ['citizenapp', 'citizenwallet'];
  for (const product of products) {
    const android = readFileSync(new URL(`../workflows/${product}-release-android.yml`, import.meta.url), 'utf8');
    const ios = readFileSync(new URL(`../workflows/${product}-release-ios.yml`, import.meta.url), 'utf8');
    for (const extension of ['apk', 'aab']) {
      assert.ok(android.includes(`asset_name: "${product}.${extension}"`));
    }
    assert.ok(ios.includes(`asset_name: '${product}.ipa'`));
    assert.doesNotMatch(android, /asset_name:\s*["'][^"']*[^\x00-\x7F][^"']*["']/);
    assert.doesNotMatch(ios, /asset_name:\s*["'][^"']*[^\x00-\x7F][^"']*["']/);
  }
});

test('iOS Release 不依赖 runner 钥匙串解包描述文件且强制核对正式证书', () => {
  for (const product of ['citizenapp', 'citizenwallet']) {
    const source = readFileSync(new URL(`../workflows/${product}-release-ios.yml`, import.meta.url), 'utf8');
    assert.match(source, /security list-keychains -d user -s "\$keychain"/);
    assert.match(source, /security find-identity -v -p codesigning "\$keychain"[\s\S]*grep -Fq "\$certificate_sha1"/);
    assert.match(source, /openssl smime -verify -inform DER[\s\S]*-noverify -out "\$work\/profile\.plist"/);
    assert.match(source, /DeveloperCertificates\.0[\s\S]*test "\$profile_certificate_sha1" = "\$certificate_sha1"/);
    assert.doesNotMatch(source, /security cms -D/);
  }
});

test('仓库统一门禁启动后只保留当前记录且与产品流程解耦', () => {
  const workflowsUrl = new URL('../workflows/', import.meta.url);
  const repositoryWorkflow = 'gmb-repository.yml';
  const repositorySource = readFileSync(new URL(repositoryWorkflow, workflowsUrl), 'utf8');
  for (const required of [
    'check-golden-vectors-sync.mjs', 'data-dictionary.mjs', 'data-dictionary.test.mjs',
    'repository-guardrails.sh', 'check-pallet-registry-sync.mjs',
    'cargo fmt --all -- --check', 'cargo clippy --workspace --all-targets --locked -- -D warnings',
    'cargo test --workspace --all-targets --locked',
  ]) assert.ok(repositorySource.includes(required), `独立仓库门禁缺少 ${required}`);
  assert.match(repositorySource, /actions: write/);
  assert.match(repositorySource, /retain-current-run:/);
  assert.match(repositorySource, /actions\/runs\/\$\{previous\}/);
  assert.match(repositorySource, /needs: retain-current-run/g);
  assert.doesNotMatch(repositorySource, /actions\/upload-artifact|finalize-semantic-ci|create-release/);
  for (const file of readdirSync(workflowsUrl).filter((value) => /\.ya?ml$/.test(value))) {
    if (file === repositoryWorkflow) continue;
    const source = readFileSync(new URL(file, workflowsUrl), 'utf8');
    for (const command of [
      'check-golden-vectors-sync.mjs', 'data-dictionary.mjs', 'data-dictionary.test.mjs',
      'repository-guardrails.sh', 'check-pallet-registry-sync.mjs',
    ]) assert.ok(!source.includes(command), `${file} 禁止重复调用仓库门禁 ${command}`);
  }
});
