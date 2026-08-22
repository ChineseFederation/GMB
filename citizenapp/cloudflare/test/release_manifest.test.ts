import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { afterEach, describe, expect, test } from 'vitest';
const projectPath = resolve(import.meta.dirname, '..');
const gitCommitSha = '1234567890abcdef1234567890abcdef12345678';
const temporaryRoots: string[] = [];
// 生成器属于仓库级 ESM 脚本，不复制 TypeScript 镜像；动态导入让测试直接执行唯一实现。
const releaseModule = await import(resolve(
  import.meta.dirname,
  '../../../.github/scripts/build-citizenapp-cloudflare-release.mjs',
));
const {
  buildCitizenAppCloudflareRelease,
  extractCitizenAppCloudflareArchive,
  verifyCitizenAppCloudflareRelease,
} = releaseModule;
const publishModule = await import(resolve(
  import.meta.dirname,
  '../../../.github/scripts/plan-citizenapp-cloudflare-publish.mjs',
));
const { planCitizenAppCloudflarePublish } = publishModule;

function temporaryRoot(): string {
  const path = mkdtempSync(join(tmpdir(), 'gmb-cloudflare-release-'));
  temporaryRoots.push(path);
  return path;
}

function buildCandidate(root: string, name: string, sourceProject = projectPath) {
  const bundlePath = join(root, `${name}.mjs`);
  const outputPath = join(root, name);
  writeFileSync(bundlePath, 'export default { fetch() { return new Response("ok"); } };\n');
  const manifest = buildCitizenAppCloudflareRelease({
    projectPath: sourceProject,
    bundlePath,
    outputPath,
    gitCommitSha,
  });
  return { manifest, outputPath };
}

function liveState() {
  return {
    active_percentage: 100,
    stable_version_id: '11111111-1111-4111-8111-111111111111',
    worker_name: 'citizenapp',
  };
}

function fixtureProject(root: string): string {
  const fixture = join(root, 'project');
  mkdirSync(join(fixture, 'schema'), { recursive: true });
  for (const path of ['package.json', 'package-lock.json', 'wrangler.toml']) {
    copyFileSync(join(projectPath, path), join(fixture, path));
  }
  copyFileSync(join(projectPath, 'schema/citizenapp.sql'), join(fixture, 'schema/citizenapp.sql'));
  return fixture;
}

afterEach(() => {
  for (const path of temporaryRoots.splice(0)) rmSync(path, { recursive: true, force: true });
});

describe('CitizenApp Cloudflare Release 候选', () => {
  test('相同代码、工具和 Git SHA 重复生成完全一致的候选', () => {
    const root = temporaryRoot();
    const first = buildCandidate(root, 'first');
    const second = buildCandidate(root, 'second');

    expect(first.manifest).toEqual(second.manifest);
    expect(readFileSync(join(first.outputPath, 'release-manifest.json'), 'utf8'))
      .toBe(readFileSync(join(second.outputPath, 'release-manifest.json'), 'utf8'));
    expect(readFileSync(join(first.outputPath, 'SHA256SUMS'), 'utf8'))
      .toBe(readFileSync(join(second.outputPath, 'SHA256SUMS'), 'utf8'));
    expect(first.manifest.migrations).toEqual([]);
  });

  test('规范 tar.gz 归档可重复生成并安全解包复核', () => {
    const root = temporaryRoot();
    const first = buildCandidate(root, 'archive-source');
    const firstArchive = join(root, 'first.tgz');
    const secondArchive = join(root, 'second.tgz');
    releaseModule.writeCitizenAppCloudflareArchive(first.outputPath, firstArchive);
    releaseModule.writeCitizenAppCloudflareArchive(first.outputPath, secondArchive);

    expect(readFileSync(firstArchive)).toEqual(readFileSync(secondArchive));
    const extracted = join(root, 'extracted');
    const manifest = extractCitizenAppCloudflareArchive(firstArchive, extracted, gitCommitSha);
    expect(manifest).toEqual(first.manifest);
    expect(readFileSync(join(extracted, 'SHA256SUMS'), 'utf8'))
      .toBe(readFileSync(join(first.outputPath, 'SHA256SUMS'), 'utf8'));
  });

  test('候选只接受准确 Git SHA，任何 payload 篡改立即拒绝', () => {
    const root = temporaryRoot();
    const { outputPath } = buildCandidate(root, 'candidate');

    expect(() => verifyCitizenAppCloudflareRelease(outputPath, '0'.repeat(40)))
      .toThrow('候选 Git SHA 与期望提交不一致');
    writeFileSync(join(outputPath, 'worker.mjs'), 'export default {};\n');
    expect(() => verifyCitizenAppCloudflareRelease(outputPath, gitCommitSha))
      .toThrow('候选文件哈希不一致：worker.mjs');
  });

  test('manifest 多出未知字段时严格拒绝', () => {
    const root = temporaryRoot();
    const { outputPath } = buildCandidate(root, 'manifest-fields');
    const manifestPath = join(outputPath, 'release-manifest.json');
    const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
    manifest.unexpected = true;
    writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    expect(() => verifyCitizenAppCloudflareRelease(outputPath, gitCommitSha))
      .toThrow('release manifest 字段集合不正确');
  });

  test('manifest 未登记文件和候选中的私钥均失败关闭', () => {
    const root = temporaryRoot();
    const first = buildCandidate(root, 'unknown-file');
    writeFileSync(join(first.outputPath, 'extra.txt'), 'extra\n');
    expect(() => verifyCitizenAppCloudflareRelease(first.outputPath, gitCommitSha))
      .toThrow('候选包含未登记文件');

    const bundlePath = join(root, 'private.mjs');
    writeFileSync(
      bundlePath,
      '-----BEGIN PRIVATE KEY-----\nsecret\n-----END PRIVATE KEY-----\n',
    );
    expect(() => buildCitizenAppCloudflareRelease({
      projectPath,
      bundlePath,
      outputPath: join(root, 'private-material'),
      gitCommitSha,
    })).toThrow('候选疑似包含私密材料：worker.mjs');
  });

  test('D1 migration 只接受从 citizenapp_0001.sql 开始的连续编号', () => {
    const firstRoot = temporaryRoot();
    const firstProject = fixtureProject(firstRoot);
    mkdirSync(join(firstProject, 'migrations'));
    writeFileSync(join(firstProject, 'migrations/citizenapp_0002.sql'), 'ALTER TABLE users ADD COLUMN test_value TEXT;\n');
    const firstBundle = join(firstRoot, 'worker.mjs');
    writeFileSync(firstBundle, 'export default {};\n');
    expect(() => buildCitizenAppCloudflareRelease({
      projectPath: firstProject,
      bundlePath: firstBundle,
      outputPath: join(firstRoot, 'candidate'),
      gitCommitSha,
    })).toThrow('D1 migration 编号必须从 0001 连续递增');

    const secondRoot = temporaryRoot();
    const secondProject = fixtureProject(secondRoot);
    mkdirSync(join(secondProject, 'migrations'));
    writeFileSync(join(secondProject, 'migrations/citizenapp_0001.sql'), 'CREATE INDEX first_index ON users(cid_number);\n');
    writeFileSync(join(secondProject, 'migrations/citizenapp_0002.sql'), 'CREATE INDEX second_index ON users(account_id);\n');
    const secondBundle = join(secondRoot, 'worker.mjs');
    writeFileSync(secondBundle, 'export default {};\n');
    const manifest = buildCitizenAppCloudflareRelease({
      projectPath: secondProject,
      bundlePath: secondBundle,
      outputPath: join(secondRoot, 'candidate'),
      gitCommitSha,
    });
    expect(manifest.migrations.map(({ name }: { name: string }) => name))
      .toEqual(['citizenapp_0001.sql', 'citizenapp_0002.sql']);
  });

  test('首次发布计划只读取生产稳定版本并将已声明资源列为逐项验证', () => {
    const root = temporaryRoot();
    const candidate = buildCandidate(root, 'bootstrap');
    const plan = planCitizenAppCloudflarePublish({
      candidatePath: candidate.outputPath,
      liveState: liveState(),
    });

    expect(plan.bootstrap).toBe(true);
    expect(plan.stable_version_id).toBe(liveState().stable_version_id);
    expect(plan.migrations).toEqual([]);
    expect(plan.resources.d1.action).toBe('verify');
    expect(plan.resources.r2.action).toBe('verify');
  });

  test('后续发布只允许更高版本且不重写既有 migration', () => {
    const root = temporaryRoot();
    const currentProject = fixtureProject(join(root, 'current-fixture'));
    const nextProject = fixtureProject(join(root, 'next-fixture'));
    const currentPackage = JSON.parse(readFileSync(join(currentProject, 'package.json'), 'utf8'));
    const currentLock = JSON.parse(readFileSync(join(currentProject, 'package-lock.json'), 'utf8'));
    currentPackage.version = '1.0.0';
    currentLock.version = '1.0.0';
    currentLock.packages[''].version = '1.0.0';
    writeFileSync(join(currentProject, 'package.json'), `${JSON.stringify(currentPackage, null, 2)}\n`);
    writeFileSync(join(currentProject, 'package-lock.json'), `${JSON.stringify(currentLock, null, 2)}\n`);
    const nextPackage = JSON.parse(readFileSync(join(nextProject, 'package.json'), 'utf8'));
    const nextLock = JSON.parse(readFileSync(join(nextProject, 'package-lock.json'), 'utf8'));
    nextPackage.version = '1.1.0';
    nextLock.version = '1.1.0';
    nextLock.packages[''].version = '1.1.0';
    writeFileSync(join(nextProject, 'package.json'), `${JSON.stringify(nextPackage, null, 2)}\n`);
    writeFileSync(join(nextProject, 'package-lock.json'), `${JSON.stringify(nextLock, null, 2)}\n`);
    const current = buildCandidate(root, 'current', currentProject);
    const next = buildCandidate(root, 'next', nextProject);

    const plan = planCitizenAppCloudflarePublish({
      candidatePath: next.outputPath,
      currentCandidatePath: current.outputPath,
      liveState: liveState(),
    });
    expect(plan.bootstrap).toBe(false);
    expect(plan.resources.d1.action).toBe('skip');
    expect(() => planCitizenAppCloudflarePublish({
      candidatePath: current.outputPath,
      currentCandidatePath: next.outputPath,
      liveState: liveState(),
    })).toThrow('发布版本必须高于当前已发布版本');

    const migrationCurrentProject = fixtureProject(join(root, 'migration-current-fixture'));
    const migrationNextProject = fixtureProject(join(root, 'migration-next-fixture'));
    mkdirSync(join(migrationCurrentProject, 'migrations'));
    mkdirSync(join(migrationNextProject, 'migrations'));
    writeFileSync(
      join(migrationCurrentProject, 'migrations/citizenapp_0001.sql'),
      'CREATE INDEX IF NOT EXISTS users_account_idx ON users(account_id);\n',
    );
    writeFileSync(
      join(migrationNextProject, 'migrations/citizenapp_0001.sql'),
      'CREATE INDEX IF NOT EXISTS users_account_idx ON users(cid_number);\n',
    );
    const migrationNextPackage = JSON.parse(readFileSync(join(migrationNextProject, 'package.json'), 'utf8'));
    const migrationNextLock = JSON.parse(readFileSync(join(migrationNextProject, 'package-lock.json'), 'utf8'));
    migrationNextPackage.version = '1.1.0';
    migrationNextLock.version = '1.1.0';
    migrationNextLock.packages[''].version = '1.1.0';
    writeFileSync(join(migrationNextProject, 'package.json'), `${JSON.stringify(migrationNextPackage, null, 2)}\n`);
    writeFileSync(join(migrationNextProject, 'package-lock.json'), `${JSON.stringify(migrationNextLock, null, 2)}\n`);
    const migrationCurrent = buildCandidate(root, 'migration-current', migrationCurrentProject);
    const migrationNext = buildCandidate(root, 'migration-next', migrationNextProject);
    expect(() => planCitizenAppCloudflarePublish({
      candidatePath: migrationNext.outputPath,
      currentCandidatePath: migrationCurrent.outputPath,
      liveState: liveState(),
    })).toThrow('Release 改写了已经登记的 D1 migration：citizenapp_0001.sql');
  });

  test('发布计划拒绝删除持久绑定、Durable Object 生命周期变化和破坏性 D1 SQL', () => {
    const root = temporaryRoot();
    const currentProject = fixtureProject(join(root, 'current-resources'));
    const nextProject = fixtureProject(join(root, 'next-resources'));
    const nextConfigPath = join(nextProject, 'wrangler.toml');
    const nextConfig = readFileSync(nextConfigPath, 'utf8')
      .replace(/\n\[\[r2_buckets\]\]\nbinding = "SQUARE_PRIVATE"\nbucket_name = "citizenapp-private"\n/, '\n');
    writeFileSync(nextConfigPath, nextConfig);
    const nextPackage = JSON.parse(readFileSync(join(nextProject, 'package.json'), 'utf8'));
    const nextLock = JSON.parse(readFileSync(join(nextProject, 'package-lock.json'), 'utf8'));
    nextPackage.version = '1.1.0';
    nextLock.version = '1.1.0';
    nextLock.packages[''].version = '1.1.0';
    writeFileSync(join(nextProject, 'package.json'), `${JSON.stringify(nextPackage, null, 2)}\n`);
    writeFileSync(join(nextProject, 'package-lock.json'), `${JSON.stringify(nextLock, null, 2)}\n`);
    const current = buildCandidate(root, 'resource-current', currentProject);
    const next = buildCandidate(root, 'resource-next', nextProject);
    expect(() => planCitizenAppCloudflarePublish({
      candidatePath: next.outputPath,
      currentCandidatePath: current.outputPath,
      liveState: liveState(),
    })).toThrow('r2 禁止自动删除或解绑生产持久资源：SQUARE_PRIVATE');

    const durableProject = fixtureProject(join(root, 'durable-change'));
    const durableConfigPath = join(durableProject, 'wrangler.toml');
    writeFileSync(
      durableConfigPath,
      readFileSync(durableConfigPath, 'utf8')
        .replace('storage = "sqlite"', 'state = "deleted"'),
    );
    const durablePackage = JSON.parse(readFileSync(join(durableProject, 'package.json'), 'utf8'));
    const durableLock = JSON.parse(readFileSync(join(durableProject, 'package-lock.json'), 'utf8'));
    durablePackage.version = '1.1.0';
    durableLock.version = '1.1.0';
    durableLock.packages[''].version = '1.1.0';
    writeFileSync(join(durableProject, 'package.json'), `${JSON.stringify(durablePackage, null, 2)}\n`);
    writeFileSync(join(durableProject, 'package-lock.json'), `${JSON.stringify(durableLock, null, 2)}\n`);
    const durable = buildCandidate(root, 'durable-next', durableProject);
    expect(() => planCitizenAppCloudflarePublish({
      candidatePath: durable.outputPath,
      currentCandidatePath: current.outputPath,
      liveState: liveState(),
    })).toThrow('Durable Object 类生命周期变化会阻断旧 Worker 回退');

    const migrationProject = fixtureProject(join(root, 'destructive-migration'));
    mkdirSync(join(migrationProject, 'migrations'));
    writeFileSync(join(migrationProject, 'migrations/citizenapp_0001.sql'), 'DROP TABLE users;\n');
    const migrationCandidate = buildCandidate(root, 'destructive', migrationProject);
    expect(() => planCitizenAppCloudflarePublish({
      candidatePath: migrationCandidate.outputPath,
      liveState: liveState(),
    })).toThrow('D1 migration 包含禁止的数据破坏操作');
  });
});
