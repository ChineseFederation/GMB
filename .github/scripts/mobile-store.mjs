#!/usr/bin/env node

import { createHash, createPrivateKey, sign } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { basename, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const APPLE_API = 'https://api.appstoreconnect.apple.com/v1';
const GOOGLE_API = 'https://androidpublisher.googleapis.com';
const GOOGLE_TOKEN = 'https://oauth2.googleapis.com/token';
const acceptedAppleStates = new Set([
  'ACCEPTED', 'IN_REVIEW', 'PENDING_APPLE_RELEASE', 'PENDING_DEVELOPER_RELEASE',
  'PROCESSING_FOR_DISTRIBUTION', 'READY_FOR_DISTRIBUTION', 'WAITING_FOR_REVIEW',
]);
const products = Object.freeze({
  citizenapp: Object.freeze({
    title: '公民', bundleId: 'ios.citizenapp', packageName: 'com.crcfrcn.citizenapp',
  }),
  citizenwallet: Object.freeze({
    title: '公民钱包', bundleId: 'ios.citizenwallet', packageName: 'com.crcfrcn.citizenwallet',
  }),
});

function fail(message) { throw new Error(message); }
function exactKeys(value, expected, label) {
  if (!value || Array.isArray(value) || typeof value !== 'object'
      || Object.keys(value).sort().join(',') !== [...expected].sort().join(',')) {
    fail(`${label}字段集合无效`);
  }
}
function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}
function base64url(value) {
  return Buffer.from(value).toString('base64url');
}
function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
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
  for (const key of ['platform', 'product', 'version-tag', 'manifest', 'asset', 'receipt']) {
    if (!values[key]) fail(`缺少参数 --${key}`);
  }
  return values;
}

export function verifyMobileStoreInput({ platform, productId, versionTag, manifestPath, assetPath, sourceSha }) {
  // 中文注释：发布只能消费正式 Release 中清单明确登记的同端资产，Tag、源码与摘要必须闭合。
  const product = products[productId];
  if (!product || !['ios', 'android'].includes(platform)) fail('应用商店产品或平台未登记');
  const manifest = JSON.parse(readFileSync(resolve(manifestPath), 'utf8'));
  exactKeys(manifest, [
    'product_id', 'version', 'build_number', 'head_sha', 'bundle_id', 'package_name', 'assets',
  ], '移动端 Release 清单');
  if (manifest.product_id !== productId || manifest.bundle_id !== product.bundleId
      || manifest.package_name !== product.packageName
      || !/^\d+\.\d{1,2}\.\d{1,2}$/.test(manifest.version)
      || !Number.isSafeInteger(manifest.build_number) || manifest.build_number <= 0
      || !/^[0-9a-f]{40}$/.test(manifest.head_sha)
      || manifest.head_sha !== sourceSha
      || versionTag !== `${productId}-${platform}-v${manifest.version}`
      || !Array.isArray(manifest.assets) || manifest.assets.length === 0) {
    fail('移动端 Release 身份与发布输入不一致');
  }
  const assetName = basename(assetPath);
  const expectedName = platform === 'ios' ? `${productId}.ipa` : `${productId}.aab`;
  if (assetName !== expectedName) fail('应用商店正式资产名无效');
  const matches = manifest.assets.filter((asset) => asset?.platform === platform
    && asset?.asset_name === assetName && /^[0-9a-f]{64}$/.test(asset?.asset_sha256));
  if (matches.length !== 1 || matches[0].asset_sha256 !== sha256(assetPath)) {
    fail('应用商店正式资产摘要与 Release 清单不一致');
  }
  return { manifest, product, assetName, assetSha256: matches[0].asset_sha256 };
}

function appleJWT() {
  const issuer = String(process.env.ASC_ISS || '');
  const keyId = String(process.env.ASC_KID || '');
  const pem = String(process.env.ASC_KEY || '');
  if (!/^[0-9a-f-]{36}$/i.test(issuer) || !/^[A-Z0-9]{10}$/.test(keyId)
      || !pem.includes('PRIVATE KEY')) fail('App Store Connect GitHub Secrets 格式无效');
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(stableJson({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const claims = base64url(stableJson({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' }));
  const unsigned = `${header}.${claims}`;
  const signature = sign('sha256', Buffer.from(unsigned), {
    key: createPrivateKey(pem), dsaEncoding: 'ieee-p1363',
  });
  return `${unsigned}.${base64url(signature)}`;
}

function googleTokenAssertion(account) {
  const required = [
    'type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id',
    'auth_uri', 'token_uri', 'auth_provider_x509_cert_url', 'client_x509_cert_url',
  ];
  if (!account || Array.isArray(account) || typeof account !== 'object'
      || required.some((key) => typeof account[key] !== 'string' || account[key].length === 0)) {
    fail('Google Play 服务账号字段集合无效');
  }
  if (account.type !== 'service_account'
      || !/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.iam\.gserviceaccount\.com$/.test(account.client_email)
      || account.token_uri !== GOOGLE_TOKEN || !String(account.private_key).includes('PRIVATE KEY')) {
    fail('Google Play GitHub Secret 格式无效');
  }
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(stableJson({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(stableJson({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: GOOGLE_TOKEN, iat: now, exp: now + 600,
  }));
  const unsigned = `${header}.${claims}`;
  return `${unsigned}.${base64url(sign('RSA-SHA256', Buffer.from(unsigned), account.private_key))}`;
}

async function request(url, { method = 'GET', token = '', headers = {}, body, accepted = [200], timeout = 120_000 } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(url, {
      method, signal: controller.signal,
      headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers }, body,
    });
    const bytes = Buffer.from(await response.arrayBuffer());
    if (bytes.length > 4 * 1024 * 1024) fail(`远端响应超过限制：${new URL(url).host}`);
    if (!accepted.includes(response.status)) {
      // 中文注释：第三方错误正文可能包含账号、请求标识或平台内部信息，禁止写入 Actions 日志。
      fail(`远端请求失败：${new URL(url).host} HTTP ${response.status}`);
    }
    return { response, bytes };
  } finally { clearTimeout(timer); }
}
async function jsonRequest(url, options = {}) {
  const result = await request(url, options);
  if (result.bytes.length === 0) return {};
  try { return JSON.parse(result.bytes.toString('utf8')); } catch { fail('远端 JSON 响应无效'); }
}
function jsonBody(data) {
  return { 'content-type': 'application/json', body: Buffer.from(stableJson(data)) };
}
function appleUrl(path, query = {}) {
  const url = new URL(`${APPLE_API}/${path}`);
  for (const [key, value] of Object.entries(query)) url.searchParams.set(key, value);
  return url;
}
function resources(object) {
  if (!Array.isArray(object?.data)) fail('Apple API 资源列表无效');
  return object.data;
}

async function appleBuild(token, appId, version, buildNumber) {
  const object = await jsonRequest(appleUrl('builds', {
    'filter[app]': appId, 'filter[version]': String(buildNumber), include: 'preReleaseVersion',
  }), { token });
  const preReleaseIds = new Set((object.included || []).filter((row) =>
    row?.type === 'preReleaseVersions' && row?.attributes?.version === version).map((row) => row.id));
  const matches = resources(object).filter((row) =>
    preReleaseIds.has(row?.relationships?.preReleaseVersion?.data?.id));
  if (matches.length > 1) fail('Apple 返回多个相同版本与 build number 的 Build');
  return matches[0]?.id || null;
}

async function uploadAppleBuild(token, appId, manifest, assetPath) {
  // 中文注释：Ubuntu Runner 通过 App Store Connect Build Upload API 直传 IPA，不依赖 Xcode。
  const upload = await jsonRequest(`${APPLE_API}/buildUploads`, {
    method: 'POST', token, headers: jsonBody({}).headers,
    body: jsonBody({ data: {
      type: 'buildUploads', attributes: {
        cfBundleShortVersionString: manifest.version,
        cfBundleVersion: String(manifest.build_number), platform: 'IOS',
      }, relationships: { app: { data: { type: 'apps', id: appId } } },
    } }).body, accepted: [201],
  });
  const uploadId = upload?.data?.id;
  if (!uploadId) fail('Apple Build Upload 响应缺少 id');
  const binary = readFileSync(assetPath);
  const file = await jsonRequest(`${APPLE_API}/buildUploadFiles`, {
    method: 'POST', token, headers: { 'content-type': 'application/json' },
    body: jsonBody({ data: {
      type: 'buildUploadFiles', attributes: {
        assetType: 'ASSET', fileName: basename(assetPath), fileSize: binary.length, uti: 'com.apple.ipa',
      }, relationships: { buildUpload: { data: { type: 'buildUploads', id: uploadId } } },
    } }).body, accepted: [201],
  });
  const fileId = file?.data?.id; const operations = file?.data?.attributes?.uploadOperations;
  if (!fileId || !Array.isArray(operations) || operations.length === 0) {
    fail('Apple Build Upload 未返回上传操作');
  }
  for (const operation of operations) {
    const url = new URL(String(operation.url || ''));
    const offset = Number(operation.offset); const length = Number(operation.length);
    if (url.protocol !== 'https:' || !url.hostname.endsWith('.blobstore.apple.com')
        || !Number.isSafeInteger(offset) || !Number.isSafeInteger(length)
        || offset < 0 || length <= 0 || offset + length > binary.length
        || !['PUT', 'POST'].includes(operation.method)) fail('Apple Build Upload 分片指令无效');
    const headers = Object.fromEntries((operation.requestHeaders || []).map((row) => [row.name, row.value]));
    await request(url, {
      method: operation.method, headers, body: binary.subarray(offset, offset + length),
      accepted: [200, 201, 204], timeout: 10 * 60_000,
    });
  }
  await request(`${APPLE_API}/buildUploadFiles/${fileId}`, {
    method: 'PATCH', token, headers: { 'content-type': 'application/json' },
    body: jsonBody({ data: { type: 'buildUploadFiles', id: fileId, attributes: { uploaded: true } } }).body,
  });
}

async function submitApple({ manifest, product, assetPath }) {
  // 中文注释：相同版本与 build number 重试时复用 Apple 已处理的 Build，禁止重复制造二进制。
  const token = appleJWT();
  const apps = resources(await jsonRequest(appleUrl('apps', { 'filter[bundleId]': product.bundleId }), { token }));
  if (apps.length !== 1 || apps[0]?.attributes?.name !== product.title) {
    fail(`App Store Connect 软件名称必须是中文“${product.title}”且应用记录唯一`);
  }
  const appId = apps[0].id;
  let buildId = await appleBuild(token, appId, manifest.version, manifest.build_number);
  if (!buildId) {
    await uploadAppleBuild(token, appId, manifest, assetPath);
    const deadline = Date.now() + 30 * 60_000;
    while (!buildId && Date.now() < deadline) {
      await new Promise((resolvePromise) => setTimeout(resolvePromise, 10_000));
      buildId = await appleBuild(appleJWT(), appId, manifest.version, manifest.build_number);
    }
  }
  if (!buildId) fail('Apple 已接收 IPA，但 30 分钟内未完成 Build 处理；保留同版本重试');
  const currentToken = appleJWT();
  const versions = resources(await jsonRequest(appleUrl('appStoreVersions', {
    'filter[app]': appId, 'filter[platform]': 'IOS', 'filter[versionString]': manifest.version,
  }), { token: currentToken }));
  if (versions.length !== 1) fail('App Store Connect 缺少准确版本记录或存在重复版本');
  const versionId = versions[0].id; const state = versions[0]?.attributes?.appVersionState;
  if (acceptedAppleStates.has(state)) {
    return {
      publish_state: state === 'READY_FOR_DISTRIBUTION' ? 'published' : 'reviewing',
      publish_receipt_id: versionId,
    };
  }
  await request(`${APPLE_API}/appStoreVersions/${versionId}/relationships/build`, {
    method: 'PATCH', token: currentToken, headers: { 'content-type': 'application/json' },
    body: jsonBody({ data: { type: 'builds', id: buildId } }).body, accepted: [204],
  });
  const submission = await jsonRequest(`${APPLE_API}/reviewSubmissions`, {
    method: 'POST', token: currentToken, headers: { 'content-type': 'application/json' },
    body: jsonBody({ data: {
      type: 'reviewSubmissions', relationships: { app: { data: { type: 'apps', id: appId } } },
    } }).body, accepted: [201],
  });
  const submissionId = submission?.data?.id;
  if (!submissionId) fail('Apple Review Submission 响应缺少 id');
  await jsonRequest(`${APPLE_API}/reviewSubmissionItems`, {
    method: 'POST', token: currentToken, headers: { 'content-type': 'application/json' },
    body: jsonBody({ data: {
      type: 'reviewSubmissionItems', relationships: {
        reviewSubmission: { data: { type: 'reviewSubmissions', id: submissionId } },
        appStoreVersion: { data: { type: 'appStoreVersions', id: versionId } },
      },
    } }).body, accepted: [201],
  });
  await jsonRequest(`${APPLE_API}/reviewSubmissions/${submissionId}`, {
    method: 'PATCH', token: currentToken, headers: { 'content-type': 'application/json' },
    body: jsonBody({ data: {
      type: 'reviewSubmissions', id: submissionId, attributes: { submitted: true },
    } }).body,
  });
  return { publish_state: 'reviewing', publish_receipt_id: submissionId };
}

async function googleAccessToken() {
  let account;
  try { account = JSON.parse(String(process.env.PLAY_KEY || '')); } catch { fail('PLAY_KEY 不是有效 JSON'); }
  const assertion = googleTokenAssertion(account);
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
  });
  const response = await jsonRequest(GOOGLE_TOKEN, {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body,
  });
  if (!response.access_token || String(response.access_token).length < 20) fail('Google OAuth 未返回有效 access token');
  return response.access_token;
}

async function submitGoogle({ manifest, product, assetPath }) {
  // 中文注释：Google Play 的上传、production 轨道更新、验证和提交必须位于同一个 Edit 事务。
  const token = await googleAccessToken();
  const root = `${GOOGLE_API}/androidpublisher/v3/applications/${product.packageName}/edits`;
  const edit = await jsonRequest(root, {
    method: 'POST', token, headers: { 'content-type': 'application/json' }, body: '{}',
  });
  const editId = edit.id;
  if (!/^[A-Za-z0-9._-]+$/.test(String(editId || ''))) fail('Google Play edit 响应缺少有效 id');
  const exact = `${root}/${editId}`;
  let committed = false;
  try {
    const listings = await jsonRequest(`${exact}/listings`, { token });
    if (!Array.isArray(listings.listings) || listings.listings.length === 0
        || !listings.listings.every((row) => row.title === product.title)) {
      fail(`Google Play 软件名称必须全部是中文“${product.title}”`);
    }
    const trackUrl = `${exact}/tracks/production`;
    const track = await jsonRequest(trackUrl, { token, accepted: [200, 404] });
    const versionCode = String(manifest.build_number);
    const exists = (track.releases || []).some((release) => (release.versionCodes || []).includes(versionCode));
    if (!exists) {
      const upload = new URL(`${GOOGLE_API}/upload/androidpublisher/v3/applications/${product.packageName}/edits/${editId}/bundles`);
      upload.searchParams.set('uploadType', 'media');
      const uploaded = await jsonRequest(upload, {
        method: 'POST', token, headers: { 'content-type': 'application/octet-stream' },
        body: readFileSync(assetPath), timeout: 10 * 60_000,
      });
      if (String(uploaded.versionCode) !== versionCode) fail('Google Play 返回的 versionCode 与 Release 不一致');
    }
    await jsonRequest(trackUrl, {
      method: 'PUT', token, headers: { 'content-type': 'application/json' },
      body: jsonBody({ track: 'production', releases: [{
        name: `${product.title} ${manifest.version}`, status: 'completed', versionCodes: [versionCode],
      }] }).body,
    });
    await jsonRequest(`${exact}:validate`, {
      method: 'POST', token, headers: { 'content-type': 'application/json' }, body: '{}',
    });
    const commit = new URL(`${exact}:commit`);
    commit.searchParams.set('changesInReviewBehavior', 'ERROR_IF_IN_REVIEW');
    await jsonRequest(commit, {
      method: 'POST', token, headers: { 'content-type': 'application/json' }, body: '{}',
    });
    committed = true;
    return { publish_state: 'reviewing', publish_receipt_id: editId };
  } finally {
    if (!committed) await request(exact, { method: 'DELETE', token, accepted: [200, 204, 404] }).catch(() => {});
  }
}

export async function publishMobileStore(input) {
  // 中文注释：平台接受后只生成无机密回执；GitHub Deployment 由独立最小权限脚本记录。
  const verified = verifyMobileStoreInput(input);
  const result = input.platform === 'ios'
    ? await submitApple({ ...verified, assetPath: input.assetPath })
    : await submitGoogle({ ...verified, assetPath: input.assetPath });
  return {
    product_id: input.productId, platform: input.platform, software_flow: 'publish',
    software_version: verified.manifest.version, build_number: verified.manifest.build_number,
    source_sha: verified.manifest.head_sha, version_tag: input.versionTag,
    asset_sha256: verified.assetSha256, publish_state: result.publish_state,
    publish_receipt_id: result.publish_receipt_id,
  };
}

const isMain = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isMain) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const receipt = await publishMobileStore({
      platform: args.platform, productId: args.product, versionTag: args['version-tag'],
      manifestPath: args.manifest, assetPath: args.asset,
      sourceSha: String(process.env.GMB_SOURCE_SHA || ''),
    });
    writeFileSync(resolve(args.receipt), `${stableJson(receipt)}\n`, { mode: 0o600, flag: 'wx' });
    process.stdout.write(`应用商店已接受 ${receipt.product_id} ${receipt.platform} ${receipt.software_version}\n`);
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
