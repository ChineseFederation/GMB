#!/usr/bin/env node

// 全仓依赖检查只读取受 Git 管理的 manifest、lockfile、工具链和 workflow；
// 更新必须由人工明确执行并经过产品真实验收，CI/Release 不得自动改写依赖。
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const contractPath = resolve(repositoryRoot, ".github/dependencies.json");
const contract = JSON.parse(readFileSync(contractPath, "utf8"));
const [command = "check", ...argumentsList] = process.argv.slice(2);
const scopeIndex = argumentsList.indexOf("--scope");
const scopeName = scopeIndex >= 0 ? argumentsList[scopeIndex + 1] : "repository";
const shaPattern = /^[0-9a-f]{40}$/;

function fail(message) {
  throw new Error(message);
}

function pathFor(relativePath) {
  return resolve(repositoryRoot, relativePath);
}

function read(relativePath) {
  const absolutePath = pathFor(relativePath);
  if (!existsSync(absolutePath)) {
    fail(`缺少依赖文件：${relativePath}`);
  }
  return readFileSync(absolutePath, "utf8");
}

function trackedFiles(patterns) {
  const result = spawnSync("git", ["ls-files", "--cached", "--others", "--exclude-standard", "--", ...patterns], {
    cwd: repositoryRoot,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    fail(`无法读取 Git 文件清单：${result.stderr.trim()}`);
  }
  return result.stdout
    .split("\n")
    .filter(Boolean)
    .filter((relativePath) => existsSync(pathFor(relativePath)));
}

function requireText(relativePath, expected, description) {
  if (!read(relativePath).includes(expected)) {
    fail(`${relativePath} 未满足${description}：${expected}`);
  }
}

// 中文注释：构建与封装必须按固定顺序出现，避免只命中两个无关字符串却没有形成正式流程。
function requireOrderedText(relativePath, expectedValues, description) {
  const text = read(relativePath);
  let offset = -1;
  for (const expected of expectedValues) {
    const next = text.indexOf(expected, offset + 1);
    if (next < 0) fail(`${relativePath} 未满足${description}：${expected}`);
    offset = next;
  }
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function exactCargoDependencyVersion(manifest, dependency) {
  const tableMatch = manifest.match(new RegExp(
    `^${escapeRegex(dependency)}\\s*=\\s*\\{[^\\n}]*\\bversion\\s*=\\s*"=([^"]+)"`,
    "m",
  ));
  const scalarMatch = manifest.match(new RegExp(
    `^${escapeRegex(dependency)}\\s*=\\s*"=([^"]+)"`,
    "m",
  ));
  const match = tableMatch ?? scalarMatch;
  if (!match) {
    fail(`citizenchain/node/Cargo.toml 必须准确固定 ${dependency}`);
  }
  return match[1];
}

function cargoLockPackageVersion(lock, packageName) {
  const match = lock.match(new RegExp(
    `\\[\\[package\\]\\]\\r?\\nname = "${escapeRegex(packageName)}"\\r?\\nversion = "([^"]+)"`,
  ));
  if (!match) {
    fail(`citizenchain/Cargo.lock 缺少 ${packageName}`);
  }
  return match[1];
}

function majorMinor(version, dependency) {
  const match = version.match(/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/);
  if (!match) {
    fail(`${dependency} 不是规范三段版本：${version}`);
  }
  return `${match[1]}.${match[2]}`;
}

function checkTauri() {
  const cargoManifest = read("citizenchain/node/Cargo.toml");
  const cargoLock = read("citizenchain/Cargo.lock");
  const npmManifest = JSON.parse(read("citizenchain/node/frontend/package.json"));
  const npmLock = JSON.parse(read("citizenchain/node/frontend/package-lock.json"));
  const rootPackage = npmLock.packages?.[""];
  const rustVersions = {
    tauri: contract.tauri.core.rust,
    "tauri-build": contract.tauri.build,
    "tauri-plugin-dialog": contract.tauri.plugins.dialog,
    "tauri-plugin-process": contract.tauri.plugins.process,
    "tauri-plugin-updater": contract.tauri.plugins.updater,
  };
  const npmVersions = {
    "@tauri-apps/api": contract.tauri.core.api,
    "@tauri-apps/cli": contract.tauri.core.cli,
    "@tauri-apps/plugin-dialog": contract.tauri.plugins.dialog,
    "@tauri-apps/plugin-process": contract.tauri.plugins.process,
    "@tauri-apps/plugin-updater": contract.tauri.plugins.updater,
  };

  for (const [dependency, expected] of Object.entries(rustVersions)) {
    if (exactCargoDependencyVersion(cargoManifest, dependency) !== expected) {
      fail(`citizenchain/node/Cargo.toml 的 ${dependency} 必须准确固定为 ${expected}`);
    }
    if (cargoLockPackageVersion(cargoLock, dependency) !== expected) {
      fail(`citizenchain/Cargo.lock 的 ${dependency} 必须锁定为 ${expected}`);
    }
  }
  for (const [dependency, expected] of Object.entries(npmVersions)) {
    const manifestVersion = npmManifest.dependencies?.[dependency]
      ?? npmManifest.devDependencies?.[dependency];
    const rootVersion = rootPackage?.dependencies?.[dependency]
      ?? rootPackage?.devDependencies?.[dependency];
    const lockVersion = npmLock.packages?.[`node_modules/${dependency}`]?.version;
    if (manifestVersion !== expected || rootVersion !== expected || lockVersion !== expected) {
      fail(`citizenchain/node/frontend 的 ${dependency} 必须在 manifest 与 lockfile 准确固定为 ${expected}`);
    }
  }
  for (const [packagePath, metadata] of Object.entries(npmLock.packages ?? {})) {
    if (packagePath.startsWith("node_modules/@tauri-apps/cli-")
      && metadata.version !== contract.tauri.core.cli) {
      fail(`${packagePath} 必须与 @tauri-apps/cli 同为 ${contract.tauri.core.cli}`);
    }
  }

  const coreMinor = majorMinor(contract.tauri.core.rust, "tauri");
  for (const [dependency, version] of [
    ["@tauri-apps/api", contract.tauri.core.api],
    ["@tauri-apps/cli", contract.tauri.core.cli],
  ]) {
    if (majorMinor(version, dependency) !== coreMinor) {
      fail(`Tauri core 主次版本不一致：tauri=${contract.tauri.core.rust} ${dependency}=${version}`);
    }
  }

  const cli = "node frontend/node_modules/@tauri-apps/cli/tauri.js";
  for (const workflow of contract.scopes["citizenchain-node"].workflows) {
    const text = read(workflow);
    if (text.includes("cargo install tauri-cli") || /\bcargo tauri\b/.test(text)) {
      fail(`${workflow} 仍依赖浮动或全局 Tauri CLI`);
    }
    if (!text.includes(`${cli} build --ci -- --locked`)) {
      fail(`${workflow} 未使用仓库锁定的 Tauri CLI 构建`);
    }
    if (workflow.includes("-release-") && !text.includes(`${cli} signer sign`)) {
      fail(`${workflow} 未使用仓库锁定的 Tauri CLI 签名 updater`);
    }
  }
  for (const script of ["citizenchain/scripts/run.sh", "citizenchain/scripts/clean-run.sh"]) {
    if (/\bcargo tauri\b/.test(read(script))) {
      fail(`${script} 仍依赖本机全局 Tauri CLI`);
    }
  }
  const runScript = "citizenchain/scripts/run.sh";
  requireOrderedText(runScript, [
    `${cli} build --no-bundle --ci -- --locked`,
    `${cli} bundle --bundles app --ci`,
  ], "仓库 Tauri CLI 正式编译与封装顺序");
  if (read(runScript).includes(`${cli} build --bundles app --ci`)) {
    fail(`${runScript} 禁止恢复编译与封装合并的旧 Tauri 命令`);
  }
  requireText("citizenchain/scripts/clean-run.sh", `${cli} dev -- --locked`, "仓库 Tauri CLI 开发构建");
}

function checkRequiredFiles(scope) {
  for (const relativePath of scope.requiredFiles) {
    read(relativePath);
  }
}

function checkPackageLocks(projects) {
  for (const directory of projects) {
    const manifest = JSON.parse(read(`${directory}/package.json`));
    const lock = JSON.parse(read(`${directory}/package-lock.json`));
    const rootPackage = lock.packages?.[""];
    if (lock.lockfileVersion !== 3) {
      fail(`${directory}/package-lock.json 必须使用 lockfileVersion 3`);
    }
    if (!rootPackage || rootPackage.name !== manifest.name) {
      fail(`${directory} 的 package.json 与 package-lock.json 包名不一致`);
    }
    if (manifest.version && rootPackage.version !== manifest.version) {
      fail(`${directory} 的 package.json 与 package-lock.json 版本不一致`);
    }
  }
}

function dartScalar(relativePath, dependency) {
  const escaped = dependency.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = read(relativePath).match(new RegExp(`^  ${escaped}:\\s*([^#\\n]+?)\\s*$`, "m"));
  if (!match) {
    fail(`${relativePath} 缺少统一 Dart 依赖：${dependency}`);
  }
  return match[1].trim();
}

function checkSharedDartDependencies() {
  for (const dependency of contract.sharedDartDependencies) {
    const appVersion = dartScalar("citizenapp/pubspec.yaml", dependency);
    const walletVersion = dartScalar("citizenwallet/pubspec.yaml", dependency);
    if (appVersion !== walletVersion) {
      fail(`移动端共享依赖 ${dependency} 版本不一致：CitizenApp=${appVersion} CitizenWallet=${walletVersion}`);
    }
  }
}

function checkToolchains(name) {
  const { node, rust, flutter, java, gradle } = contract.toolchains;
  const mobileScope = name === "repository" || ["citizenapp", "citizenwallet"].includes(name);
  const chainScope = name === "repository" || ["citizenchain-node", "citizenchain-runtime"].includes(name);
  const nodeScope = name === "repository" || ["citizenchain-node", "citizenapp-cloudflare", "citizenweb"].includes(name);
  if (mobileScope && JSON.parse(read(".fvm/fvm_config.json")).flutterSdkVersion !== flutter) {
    fail(`Flutter 唯一版本必须为 ${flutter}`);
  }
  const rustFiles = name === "repository"
    ? ["citizenchain/rust-toolchain.toml", "citizenapp/rust/rust-toolchain.toml"]
    : name === "citizenapp"
      ? ["citizenapp/rust/rust-toolchain.toml"]
      : chainScope
        ? ["citizenchain/rust-toolchain.toml"]
        : [];
  for (const file of rustFiles) {
    requireText(file, `channel = "${rust}"`, "Rust 版本统一契约");
  }
  const nodeFiles = name === "repository"
    ? ["citizenchain/node/frontend/.nvmrc", "citizenweb/.nvmrc"]
    : name === "citizenchain-node"
      ? ["citizenchain/node/frontend/.nvmrc"]
      : name === "citizenweb"
        ? ["citizenweb/.nvmrc"]
        : [];
  for (const file of nodeFiles) {
    if (read(file).trim() !== node) {
      fail(`${file} 必须精确固定 Node.js ${node}`);
    }
  }
  const gradleFiles = name === "repository"
    ? [
        "citizenapp/android/gradle/wrapper/gradle-wrapper.properties",
        "citizenwallet/android/gradle/wrapper/gradle-wrapper.properties",
      ]
    : name === "citizenapp"
      ? ["citizenapp/android/gradle/wrapper/gradle-wrapper.properties"]
      : name === "citizenwallet"
        ? ["citizenwallet/android/gradle/wrapper/gradle-wrapper.properties"]
        : [];
  for (const file of gradleFiles) {
    requireText(file, `gradle-${gradle}-all.zip`, "Gradle 版本统一契约");
  }
  const workflows = name === "repository"
    ? trackedFiles([
      ".github/workflows/*.yml",
      ".github/workflows/*.yaml",
      ".github/workflows/*/*.yml",
      ".github/workflows/*/*.yaml",
    ])
    : contract.scopes[name].workflows;
  for (const workflow of workflows) {
    const text = read(workflow);
    if (/node-version:\s*(?:['"])?24(?:['"])?\s*$/m.test(text)) {
      fail(`${workflow} 仍使用浮动 Node.js 24，必须精确固定 ${node}`);
    }
    if (nodeScope && text.includes("node-version:") && !text.includes(`node-version: ${node}`)) {
      fail(`${workflow} 的 Node.js 版本未统一为 ${node}`);
    }
    if (text.includes("java-version:") && !text.includes(`java-version: ${java}`)) {
      fail(`${workflow} 的 Java 版本未统一为 ${java}`);
    }
  }
}

function checkActions(workflows) {
  for (const [action, sha] of Object.entries(contract.actions)) {
    if (!shaPattern.test(sha)) {
      fail(`${action} 未配置完整 commit SHA`);
    }
  }
  for (const workflow of workflows) {
    const text = read(workflow);
    for (const match of text.matchAll(/^\s*uses:\s*([^\s#]+)(?:\s+#.*)?$/gm)) {
      const reference = match[1];
      if (reference.startsWith("./") || reference.startsWith("docker://")) {
        continue;
      }
      const separator = reference.lastIndexOf("@");
      const action = reference.slice(0, separator);
      const revision = reference.slice(separator + 1);
      if (!contract.actions[action]) {
        fail(`${workflow} 使用了未登记 Action：${action}`);
      }
      if (revision !== contract.actions[action]) {
        fail(`${workflow} 的 ${action} 未固定到统一 SHA ${contract.actions[action]}`);
      }
    }
  }
}

function checkOfficialRunners(workflows) {
  const allowed = new Set(contract.officialRunners);
  for (const workflow of workflows) {
    const text = read(workflow);
    if (/runs-on:\s*(?:\[[^\]]*\bself-hosted\b|\bself-hosted\b)/m.test(text)) {
      fail(`${workflow} 使用了 self-hosted runner，必须使用统一官方镜像`);
    }
    const runnerLabels = [
      ...text.matchAll(/^\s*runs-on:\s*((?:ubuntu|macos|windows)-[a-zA-Z0-9.-]+)\s*$/gm),
      ...text.matchAll(/["']os["']\s*:\s*["']((?:ubuntu|macos|windows)-[a-zA-Z0-9.-]+)["']/g),
    ];
    for (const match of runnerLabels) {
      if (!allowed.has(match[1])) {
        fail(`${workflow} 使用了未登记的 runner 镜像：${match[1]}`);
      }
    }
  }
}

function checkGitDependencies(manifests) {
  for (const manifest of manifests) {
    const text = read(manifest);
    if (/git\s*=\s*"[^"]+"[^\n}]*\b(branch|tag)\s*=/m.test(text)) {
      fail(`${manifest} 存在可漂移的 Git branch/tag 依赖，必须使用 rev`);
    }
    for (const match of text.matchAll(/git\s*=\s*"[^"]+"[^\n}]*\brev\s*=\s*"([^"]+)"/g)) {
      if (!shaPattern.test(match[1])) {
        fail(`${manifest} 的 Git rev 不是完整 commit SHA：${match[1]}`);
      }
    }
  }
}

function checkWorkflowScopes() {
  const productWorkflows = [];
  const expectedWorkflows = [];
  const legacyName = `${"gmb-ci"}-repository.yml`;
  for (const [name, scope] of Object.entries(contract.scopes)) {
    for (const workflow of scope.workflows) {
      expectedWorkflows.push(workflow);
      const text = read(workflow);
      const invocation = `node .github/scripts/dependencies.mjs check --scope ${name}`;
      if (!text.includes(invocation)) {
        fail(`${workflow} 未调用依赖作用域：${name}`);
      }
      if (name !== "repository") {
        productWorkflows.push(workflow);
        if (text.includes("gmb-repository.yml") || text.includes(legacyName)) {
          fail(`${workflow} 不得调用或依赖仓库门禁`);
        }
      }
    }
  }
  if (productWorkflows.length !== 28) {
    fail(`产品 workflow 必须精确为 28 条，当前契约登记 ${productWorkflows.length} 条`);
  }
  const actualWorkflows = trackedFiles([
    ".github/workflows/*.yml",
    ".github/workflows/*.yaml",
    ".github/workflows/*/*.yml",
    ".github/workflows/*/*.yaml",
  ]);
  const expected = [...expectedWorkflows].sort();
  const actual = [...actualWorkflows].sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    fail(`workflow 清单与依赖契约不一致：期望 ${expected.length} 条，实际 ${actual.length} 条`);
  }
  const legacyWorkflow = `.github/workflows/${"gmb-ci"}-repository.yml`;
  if (existsSync(pathFor(legacyWorkflow))) {
    fail(`旧仓库门禁 ${legacyWorkflow} 仍存在`);
  }
}

function checkFrozenCommands(scopeNames) {
  for (const name of scopeNames) {
    const scope = contract.scopes[name];
    for (const workflow of scope.workflows) {
      const text = read(workflow);
      if (workflow.includes("-publish-")) continue;
      if (["citizenapp", "citizenwallet"].includes(name) && !text.includes("flutter pub get --enforce-lockfile")) {
        fail(`${workflow} 未冻结 Flutter/Dart 应用依赖`);
      }
      if (["citizenapp-cloudflare", "citizenweb"].includes(name) && !text.includes("npm ci")) {
        fail(`${workflow} 未使用 npm ci`);
      }
      if (["citizenchain-node", "citizenchain-runtime"].includes(name) && !text.includes("--locked")) {
        fail(`${workflow} 未冻结 Cargo 依赖`);
      }
    }
  }
}

function checkAuditGates(scopeNames) {
  for (const name of scopeNames) {
    const scope = contract.scopes[name];
    const invocation = `node .github/scripts/dependencies.mjs audit --scope ${name}`;
    const audited = contract.auditedScopes.includes(name);
    const hasCargo = contract.cargoProjects.some((directory) =>
      scope.requiredFiles.includes(projectFile(directory, "Cargo.toml")));
    for (const workflow of scope.workflows) {
      const text = read(workflow);
      if (workflow.includes("-publish-")) {
        if (text.includes(invocation)) fail(`${workflow} 不得重建或审计已固化正式 Release`);
        continue;
      }
      if (audited && !text.includes(invocation)) {
        fail(`${workflow} 未接入已清零产品的阻断安全审计：${name}`);
      }
      if (!audited && text.includes(invocation)) {
        fail(`${workflow} 接入了尚未登记零漏洞基线的安全审计：${name}`);
      }
      if (audited && hasCargo && !text.includes(
        `cargo install cargo-audit --version ${contract.toolchains.cargoAudit} --locked`,
      )) {
        fail(`${workflow} 未安装固定版本 cargo-audit ${contract.toolchains.cargoAudit}`);
      }
    }
  }
}

function checkScope(name) {
  const scope = contract.scopes[name];
  if (!scope) {
    fail(`未知依赖作用域：${name}`);
  }
  checkRequiredFiles(scope);
  if (name === "repository" || name === "citizenchain-node") {
    checkTauri();
  }
  if (name === "repository") {
    for (const candidate of Object.values(contract.scopes)) {
      checkRequiredFiles(candidate);
    }
    checkPackageLocks(contract.npmProjects);
    for (const directory of contract.dartApplications) {
      read(`${directory}/pubspec.yaml`);
      read(`${directory}/pubspec.lock`);
    }
    for (const directory of contract.cargoProjects) {
      read(`${directory}/Cargo.toml`);
      read(`${directory}/Cargo.lock`);
    }
    checkSharedDartDependencies();
    checkToolchains(name);
    const workflows = trackedFiles([
      ".github/workflows/*.yml",
      ".github/workflows/*.yaml",
      ".github/workflows/*/*.yml",
      ".github/workflows/*/*.yaml",
    ]);
    checkActions(workflows);
    checkOfficialRunners(workflows);
    checkGitDependencies(trackedFiles(["**/Cargo.toml", "Cargo.toml"]));
    checkWorkflowScopes();
    checkFrozenCommands(Object.keys(contract.scopes));
    checkAuditGates(Object.keys(contract.scopes));
  } else {
    checkPackageLocks(contract.npmProjects.filter((directory) =>
      scope.requiredFiles.includes(`${directory}/package.json`)));
    checkToolchains(name);
    checkActions(scope.workflows);
    checkOfficialRunners(scope.workflows);
    checkGitDependencies(scope.requiredFiles.filter((file) => file.endsWith("Cargo.toml")));
    checkFrozenCommands([name]);
    checkAuditGates([name]);
    for (const workflow of scope.workflows) {
      const invocation = `node .github/scripts/dependencies.mjs check --scope ${name}`;
      requireText(workflow, invocation, "产品依赖作用域检查");
    }
  }
  console.log(`依赖检查通过：${name}`);
}

function projectFile(directory, fileName) {
  return directory === "." ? fileName : `${directory}/${fileName}`;
}

function scopedProjects(projects, fileName) {
  if (scopeName === "repository") {
    return projects;
  }
  const requiredFiles = contract.scopes[scopeName]?.requiredFiles;
  if (!requiredFiles) {
    fail(`未知依赖作用域：${scopeName}`);
  }
  return projects.filter((directory) => requiredFiles.includes(projectFile(directory, fileName)));
}

function runNative(executable, argumentsValue, cwd, allowFailure = false) {
  console.log(`\n[${cwd}] ${executable} ${argumentsValue.join(" ")}`);
  const result = spawnSync(executable, argumentsValue, {
    cwd: pathFor(cwd),
    encoding: "utf8",
    stdio: "inherit",
  });
  if (result.error) {
    fail(`无法执行 ${executable}：${result.error.message}`);
  }
  if (result.status !== 0 && !allowFailure) {
    fail(`${executable} 检查失败，退出码 ${result.status}`);
  }
}

function audit() {
  checkScope(scopeName);
  const npmProjects = scopedProjects(contract.npmProjects, "package.json");
  const cargoProjects = scopedProjects(contract.cargoProjects, "Cargo.toml");
  for (const directory of npmProjects) {
    runNative("npm", ["audit", "--audit-level=low"], directory);
  }
  if (cargoProjects.length > 0) {
    const auditVersion = spawnSync("cargo", ["audit", "--version"], { encoding: "utf8" });
    if (auditVersion.status !== 0 || !auditVersion.stdout.includes(contract.toolchains.cargoAudit)) {
      fail(`cargo-audit 必须安装并固定为 ${contract.toolchains.cargoAudit}`);
    }
    for (const [index, directory] of cargoProjects.entries()) {
      const argumentsValue = ["audit"];
      if (index > 0) {
        argumentsValue.push("--no-fetch");
      }
      argumentsValue.push("--file", projectFile(directory, "Cargo.lock"));
      runNative("cargo", argumentsValue, ".");
    }
  }
}

function outdated() {
  checkScope(scopeName);
  for (const directory of scopedProjects(contract.npmProjects, "package.json")) {
    runNative("npm", ["outdated"], directory, true);
  }
  for (const directory of scopedProjects(contract.dartApplications, "pubspec.yaml")) {
    runNative("dart", ["pub", "outdated"], directory, true);
  }
  for (const directory of scopedProjects(contract.cargoProjects, "Cargo.toml")) {
    runNative("cargo", ["update", "--dry-run", "--manifest-path", projectFile(directory, "Cargo.toml")], ".", true);
  }
  console.log("\n过期版本仅报告；更新 manifest/lockfile 后必须重新执行产品真实验收。");
}

try {
  if (contract.schema !== 1) {
    fail(`不支持依赖契约 schema：${contract.schema}`);
  }
  if (command === "check") {
    checkScope(scopeName);
  } else if (command === "audit") {
    audit();
  } else if (command === "outdated") {
    outdated();
  } else {
    fail(`未知命令：${command}`);
  }
} catch (error) {
  console.error(`依赖检查失败：${error.message}`);
  process.exitCode = 1;
}
