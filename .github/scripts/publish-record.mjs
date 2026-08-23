#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

function fail(message) { throw new Error(message); }
const FAILED_DEPLOYMENT_STATES = new Set(['error', 'failure']);

function exactKeys(value, expected) {
  if (Object.keys(value).sort().join(',') !== [...expected].sort().join(',')) {
    fail('GitHub 发布回执字段集合无效');
  }
}

function keepLatestFailure(deployments, createdAt = Date.parse) {
  const failed = deployments
    .filter((value) => FAILED_DEPLOYMENT_STATES.has(String(value?.state || ''))
      && value?.id !== undefined)
    .map((value) => ({
      ...value,
      createdAt: Number.isNaN(createdAt(value.created_at || '')) ? 0 : createdAt(value.created_at || ''),
    }))
    .sort((left, right) => right.createdAt - left.createdAt);
  return failed;
}

function parseArgs(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index]; const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined || Object.hasOwn(values, key.slice(2))) {
      fail(`参数格式无效：${key || ''}`);
    }
    values[key.slice(2)] = value;
  }
  for (const key of ['receipt', 'environment', 'description', 'url']) {
    if (!values[key]) fail(`缺少参数 --${key}`);
  }
  return values;
}

export function verifyPublishReceipt(receipt, { environment, url }) {
  // 中文注释：Deployment payload 只接受发布合同的公开身份，不允许日志或任意字段混入。
  const targets = {
    'citizenapp-ios-production': ['citizenapp', 'ios', 'https://apps.apple.com/'],
    'citizenapp-android-production': ['citizenapp', 'android', 'https://play.google.com/store/apps/details?id=com.crcfrcn.citizenapp'],
    'citizenwallet-ios-production': ['citizenwallet', 'ios', 'https://apps.apple.com/'],
    'citizenwallet-android-production': ['citizenwallet', 'android', 'https://play.google.com/store/apps/details?id=com.crcfrcn.citizenwallet'],
    'citizenapp-cloudflare-production': ['citizenapp-cloudflare', null, 'https://www.crcfrcn.com/api/health'],
    'citizenweb-production': ['citizenweb', null, 'https://www.crcfrcn.com/'],
  };
  const target = targets[environment];
  if (!receipt || Array.isArray(receipt) || typeof receipt !== 'object' || !target
      || url !== target[2] || receipt.product_id !== target[0]
      || receipt.software_flow !== 'publish'
      || !/^\d+\.\d{1,2}\.\d{1,2}$/.test(String(receipt.software_version || ''))
      || !/^[0-9a-f]{40}$/.test(String(receipt.source_sha || ''))
      || !['reviewing', 'published'].includes(receipt.publish_state)
      || !/^[A-Za-z0-9._-]{1,256}$/.test(String(receipt.publish_receipt_id || ''))) {
    fail('GitHub 发布回执身份无效');
  }
  const base = [
    'product_id', 'software_flow', 'software_version', 'version_tag', 'source_sha',
    'publish_state', 'publish_receipt_id',
  ];
  if (target[1] === null) {
    exactKeys(receipt, base);
    if (receipt.version_tag !== `${receipt.product_id}-v${receipt.software_version}`
        || receipt.publish_state !== 'published') fail('GitHub 发布回执身份无效');
  } else {
    exactKeys(receipt, [...base, 'platform', 'build_number', 'asset_sha256']);
    if (receipt.platform !== target[1]
        || receipt.version_tag !== `${receipt.product_id}-${receipt.platform}-v${receipt.software_version}`
        || !Number.isSafeInteger(receipt.build_number) || receipt.build_number <= 0
        || !/^[0-9a-f]{64}$/.test(String(receipt.asset_sha256 || ''))) {
      fail('GitHub 发布回执身份无效');
    }
  }
  return receipt;
}

function githubClient({ repository, token }) {
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository) || token.length < 20) {
    fail('GitHub 发布记录环境无效');
  }
  const request = async (path, body) => {
    const response = await fetch(`https://api.github.com/repos/${repository}/${path}`, {
      method: 'POST', headers: {
        accept: 'application/vnd.github+json', authorization: `Bearer ${token}`,
        'content-type': 'application/json', 'x-github-api-version': '2022-11-28',
      }, body: JSON.stringify(body),
    });
    const text = await response.text();
    // 中文注释：GitHub 错误正文不进入日志，避免 Deployment payload 或平台细节被回显。
    if (!response.ok) fail(`GitHub 发布记录失败：HTTP ${response.status}`);
    return text ? JSON.parse(text) : {};
  };

  const parseDate = (value) => Number(Date.parse(String(value || '')));
  return {
    request,
    async listDeployments(environment) {
      const values = [];
      for (let page = 1; page <= 20; page += 1) {
        const output = await request(`deployments?environment=${encodeURIComponent(environment)}&per_page=100&page=${page}`);
        required(Array.isArray(output), 'GitHub 发布记录列表无效');
        values.push(...output);
        if (output.length < 100) return values;
      }
      fail('GitHub 发布记录列表超过安全分页上限');
    },
    async deleteDeployment(deploymentId) {
      if (!Number.isSafeInteger(deploymentId) || deploymentId <= 0) fail('GitHub 部署 id 无效');
      await request(`deployments/${deploymentId}`, { method: 'DELETE' });
    },
  };
}

async function pruneOldFailedDeployments(client, environment) {
  const deployments = await client.listDeployments(environment);
  const failed = keepLatestFailure(deployments);
  if (failed.length <= 1) return;
  for (const deployment of failed.slice(1)) {
    await client.deleteDeployment(deployment.id);
  }
}

export async function recordPublish({ receipt, environment, description, url, client }) {
  // 中文注释：先创建绑定正式 Tag 的 Deployment，再写成功状态，避免无来源的孤立状态记录。
  verifyPublishReceipt(receipt, { environment, url });
  await pruneOldFailedDeployments(client, environment);
  const deployment = await client.request('deployments', {
    ref: receipt.version_tag, environment, description,
    auto_merge: false, required_contexts: [], payload: receipt,
  });
  if (!Number.isSafeInteger(deployment.id) || deployment.id <= 0) fail('GitHub Deployment id 无效');
  await client.request(`deployments/${deployment.id}/statuses`, {
    state: 'success', environment, environment_url: url,
    log_url: `${process.env.GITHUB_SERVER_URL || 'https://github.com'}/${process.env.GITHUB_REPOSITORY || ''}/actions/runs/${process.env.GITHUB_RUN_ID || ''}`,
    description: `发布已接受：${receipt.publish_state}`,
  });
  return deployment.id;
}

const isMain = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isMain) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const receipt = JSON.parse(readFileSync(resolve(args.receipt), 'utf8'));
    const client = githubClient({
      repository: String(process.env.GITHUB_REPOSITORY || ''),
      token: String(process.env.GH_TOKEN || ''),
    });
    const id = await recordPublish({
      receipt, environment: args.environment, description: args.description,
      url: args.url, client,
    });
    process.stdout.write(`GitHub Deployment 已记录：${id}\n`);
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
