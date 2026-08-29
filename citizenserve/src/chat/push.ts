import type { Env } from '../types';
import { nowMs } from '../shared/time';
import { assertDeliverySize } from '../limits/delivery';
import { readUserByCidNumber } from '../account/user_repository';

type PushProvider = 'apns' | 'fcm';
export type ApnsEnvironment = 'sandbox' | 'production';
const PUSH_TIMEOUT_MS = 10_000;

interface PushDeviceRow {
  push_provider: PushProvider;
  push_token: string;
  apns_environment: ApnsEnvironment | null;
}

interface WakePayload {
  kind: 'chat_wake';
  sender_cid_number: string;
  conversation_id?: string;
}

interface PushOutcome {
  device: PushDeviceRow;
  accepted: boolean;
  invalid: boolean;
  status: number;
  reason: string | null;
}

/** 同一次 Worker/Queue 调用内复用推送凭据，禁止每台设备重复签名或请求 OAuth。 */
export interface PushAuth {
  apns_jwt?: Promise<string>;
  fcm_access_token?: Promise<string>;
}

export function createPushAuth(): PushAuth {
  return {};
}

/**
 * 发送无聊天内容的设备唤醒通知。
 *
 * Cloudflare 不保存待通知任务；未确认的端到端密文只留在接收 CID 的有界临时邮箱。
 * 推送载荷只告知“哪个身份(cid_number)有待发送数据”，不得加入消息文字、会话编号、附件或文件名。
 */
export async function sendChatWake(
  env: Env,
  recipientCidNumber: string,
  senderCidNumber: string,
): Promise<number> {
  // 推送令牌也属于钱包授权派生凭证：每次唤醒前读取 finalized D1 用户投影，
  // 只向当前 binding_revision + account_id 注册的设备发送，换绑后的旧设备不得继续收信号。
  const recipientIdentity = await readUserByCidNumber(env, recipientCidNumber);
  if (!recipientIdentity || !recipientIdentity.account_id || recipientIdentity.binding_revision <= 0) {
    return 0;
  }
  const result = await env.DB.prepare(
    `SELECT push_provider, push_token, apns_environment
      FROM chat_push_endpoints
      WHERE cid_number = ?
        AND binding_revision = ?
        AND account_id = ?
        AND expires_at > ?`,
  )
    .bind(
      recipientCidNumber,
      recipientIdentity.binding_revision,
      recipientIdentity.account_id,
      nowMs(),
    )
    .all<PushDeviceRow>();
  const payload: WakePayload = {
    kind: 'chat_wake',
    sender_cid_number: senderCidNumber,
  };
  assertDeliverySize('push_wake', JSON.stringify(payload));
  const auth = createPushAuth();
  const outcomes = await Promise.all(
    (result.results ?? []).map((device) => sendDeviceWake(env, device, payload, auth)),
  );
  return outcomes.filter(Boolean).length;
}

/**
 * 密文邮箱首次保存后的可见系统通知。通知正文固定且不含聊天内容；是否存在活动 WSS
 * 不影响本通知。既有 envelope_id 只用作平台通知去重标识；既有 conversation_id
 * 只用于系统通知分组与已读清除，不携带消息或附件内容。
 */
export async function sendChatAlert(
  env: Env,
  recipientCidNumber: string,
  senderCidNumber: string,
  conversationId: string,
  envelopeId: string,
): Promise<number> {
  const recipientIdentity = await readUserByCidNumber(env, recipientCidNumber);
  if (!recipientIdentity || !recipientIdentity.account_id || recipientIdentity.binding_revision <= 0) {
    return 0;
  }
  const result = await env.DB.prepare(
    `SELECT push_provider, push_token, apns_environment
       FROM chat_push_endpoints
      WHERE cid_number = ?
        AND binding_revision = ?
        AND account_id = ?
        AND expires_at > ?`,
  ).bind(
    recipientCidNumber,
    recipientIdentity.binding_revision,
    recipientIdentity.account_id,
    nowMs(),
  ).all<PushDeviceRow>();
  const payload: WakePayload = {
    kind: 'chat_wake',
    sender_cid_number: senderCidNumber,
    conversation_id: conversationId,
  };
  assertDeliverySize('push_wake', JSON.stringify(payload));
  const auth = createPushAuth();
  const outcomes = await Promise.all(
    (result.results ?? []).map((device) =>
      sendDeviceAlert(env, device, payload, envelopeId, auth).catch(() => ({
        device,
        accepted: false,
        invalid: false,
        status: 0,
        reason: 'request_failed',
      })),
    ),
  );
  for (const outcome of outcomes) {
    if (!outcome.accepted) logPushFailure(outcome);
  }
  await Promise.all(
    outcomes.filter((outcome) => outcome.invalid).map((outcome) =>
      env.DB.prepare(
        `DELETE FROM chat_push_endpoints
          WHERE push_provider = ? AND push_token = ?`,
      ).bind(outcome.device.push_provider, outcome.device.push_token).run()
    ),
  );
  return outcomes.filter((outcome) => outcome.accepted).length;
}

async function sendDeviceAlert(
  env: Env,
  device: PushDeviceRow,
  payload: WakePayload,
  envelopeId: string,
  auth: PushAuth,
): Promise<PushOutcome> {
  if (device.push_provider === 'apns') {
    if (device.apns_environment === null) {
      return {
        device,
        accepted: false,
        invalid: true,
        status: 0,
        reason: 'environment_missing',
      };
    }
    return sendApnsChatAlert(
      env,
      device,
      device.apns_environment,
      payload,
      auth,
    );
  }
  return sendFcmChatAlert(env, device, payload, envelopeId, auth);
}

async function sendApnsChatAlert(
  env: Env,
  device: PushDeviceRow,
  environment: ApnsEnvironment,
  payload: WakePayload,
  auth: PushAuth,
): Promise<PushOutcome> {
  if (!env.APNS_KEY || !env.APNS_KID || !env.APNS_TEAM || !env.APNS_TOPIC) {
    return {
      device,
      accepted: false,
      invalid: false,
      status: 0,
      reason: 'configuration_missing',
    };
  }
  const jwt = await apnsJwt(env, auth);
  // 每条聊天消息都要独立通知，不能把内部 envelope_id 当 APNs collapse-id。
  // collapse-id 只适合可被后续状态覆盖的通知；省略后由 APNs 为每条 alert 独立投递。
  const response = await fetchPush(() => fetch(
    `https://${apnsHost(environment)}/3/device/${encodeURIComponent(device.push_token)}`,
    {
      method: 'POST',
      headers: {
        authorization: `bearer ${jwt}`,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-topic': env.APNS_TOPIC!,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        aps: {
          alert: { title: '公民', body: '你有一条新消息' },
          sound: 'default',
          'content-available': 1,
          'thread-id': payload.conversation_id,
        },
        ...payload,
      }),
      signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
    },
  ));
  const reason = response.ok ? null : await pushFailureReason(response);
  // APNs 明确拒绝当前 Token 时立即删除，手机启动、恢复或 Token 更新会幂等重登；
  // Topic/鉴权等服务配置错误只保留端点并输出脱敏诊断。
  const invalid = response.status === 410 ||
    ['Unregistered', 'BadDeviceToken'].includes(reason ?? '');
  return {
    device,
    accepted: response.ok,
    invalid,
    status: response.status,
    reason,
  };
}

async function sendFcmChatAlert(
  env: Env,
  device: PushDeviceRow,
  payload: WakePayload,
  envelopeId: string,
  auth: PushAuth,
): Promise<PushOutcome> {
  if (!env.FCM_PROJECT || !env.FCM_EMAIL || !env.FCM_KEY) {
    return {
      device,
      accepted: false,
      invalid: false,
      status: 0,
      reason: 'configuration_missing',
    };
  }
  const accessToken = await fcmAccessToken(env, auth);
  const response = await fetchPush(() => fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FCM_PROJECT!)}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: device.push_token,
          notification: { title: '公民', body: '你有一条新消息' },
          data: payload,
          android: {
            priority: 'high',
            ttl: '604800s',
            notification: {
              channel_id: 'chat_messages',
              sound: 'default',
              tag: `${payload.conversation_id}|${envelopeId}`,
            },
          },
        },
      }),
      signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
    },
  ));
  const reason = response.ok ? null : await pushFailureReason(response);
  return {
    device,
    accepted: response.ok,
    invalid: reason === 'UNREGISTERED',
    status: response.status,
    reason,
  };
}

function directConversationId(leftCidNumber: string, rightCidNumber: string): string {
  const members = [leftCidNumber, rightCidNumber].sort();
  return `dm:${members[0]}:${members[1]}`;
}

/** APNs/FCM 短时故障在同一 Worker 生命周期内只重试一次，避免消息提交被外部服务拖住。 */
async function fetchPush(send: () => Promise<Response>): Promise<Response> {
  let response: Response | undefined;
  let failure: unknown;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      response = await send();
      if (response.ok || (response.status !== 429 && response.status < 500)) {
        return response;
      }
    } catch (error) {
      failure = error;
    }
    if (attempt === 0) {
      await new Promise<void>((resolve) => setTimeout(resolve, 250));
    }
  }
  if (response !== undefined) return response;
  throw failure instanceof Error ? failure : new Error('chat_push_request_failed');
}

async function pushFailureReason(response: Response): Promise<string> {
  const body = await response.clone().json().catch(() => null) as {
    reason?: unknown;
    error?: { status?: unknown };
  } | null;
  const value = body?.reason ?? body?.error?.status;
  return typeof value === 'string' && /^[A-Za-z0-9_.-]{1,64}$/.test(value)
    ? value
    : `http_${response.status}`;
}

/** 只记录平台、状态和官方稳定 reason，禁止输出 CID、Token、正文或密文。 */
function logPushFailure(outcome: PushOutcome): void {
  console.warn(JSON.stringify({
    stage: 'chat_push_rejected',
    provider: outcome.device.push_provider,
    status: outcome.status,
    reason: outcome.reason,
  }));
}

async function sendDeviceWake(
  env: Env,
  device: PushDeviceRow,
  payload: WakePayload,
  auth: PushAuth,
): Promise<boolean> {
  if (device.push_provider === 'apns') {
    if (device.apns_environment === null) return false;
    return sendApnsWake(env, device.push_token, device.apns_environment, payload, auth);
  }
  return sendFcmWake(env, device.push_token, payload, auth);
}

/// 单台设备的推送目标（provider + token）；广场扇出按批查出后逐台发送。
export interface PushDevice {
  push_provider: PushProvider;
  push_token: string;
  apns_environment: ApnsEnvironment | null;
}

interface SquarePostAlert {
  title: string;
  body: string;
  post_id: string;
}

interface StorageCleanupAlert {
  title: string;
  body: string;
  cleanup_after: number;
  target_storage_bytes: number;
}

/**
 * 会员权益过期后的存储清理预告。只向当前 finalized 绑定仍有效的设备发送，载荷不含
 * 帖子正文或对象键；调用方必须在通知后另留等待期，禁止同一轮直接删除。
 */
export async function sendStorageCleanupAlert(
  env: Env,
  cidNumber: string,
  targetStorageBytes: number,
  cleanupAfter: number,
): Promise<number> {
  const identity = await readUserByCidNumber(env, cidNumber);
  if (!identity || !identity.account_id || identity.binding_revision <= 0) return 0;
  const devices = await env.DB.prepare(
    `SELECT push_provider, push_token, apns_environment
       FROM chat_push_endpoints
      WHERE cid_number = ? AND binding_revision = ? AND account_id = ? AND expires_at > ?`,
  ).bind(
    cidNumber,
    identity.binding_revision,
    identity.account_id,
    nowMs(),
  ).all<PushDeviceRow>();
  const targetGb = Math.floor(targetStorageBytes / 1_000_000_000);
  const alert: StorageCleanupAlert = {
    title: '存储空间清理提醒',
    body: `会员权益已过期，24 小时后将按最旧内容清理至 ${targetGb}GB`,
    cleanup_after: cleanupAfter,
    target_storage_bytes: targetStorageBytes,
  };
  assertDeliverySize('push_wake', JSON.stringify(alert));
  const auth = createPushAuth();
  const outcomes = await Promise.all(
    (devices.results ?? []).map((device) =>
      sendDeviceStorageCleanupAlert(env, device, alert, auth).catch(() => false),
    ),
  );
  return outcomes.filter(Boolean).length;
}

async function sendDeviceStorageCleanupAlert(
  env: Env,
  device: PushDeviceRow,
  alert: StorageCleanupAlert,
  auth: PushAuth,
): Promise<boolean> {
  if (device.push_provider === 'apns') {
    if (device.apns_environment === null) return false;
    if (!env.APNS_KEY || !env.APNS_KID || !env.APNS_TEAM || !env.APNS_TOPIC) return false;
    const jwt = await apnsJwt(env, auth);
    const response = await fetch(
      `https://${apnsHost(device.apns_environment)}/3/device/${encodeURIComponent(device.push_token)}`,
      {
        method: 'POST',
        headers: {
          authorization: `bearer ${jwt}`,
          'apns-push-type': 'alert',
          'apns-priority': '10',
          'apns-topic': env.APNS_TOPIC,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          aps: { alert: { title: alert.title, body: alert.body }, sound: 'default' },
          kind: 'storage_cleanup',
          cleanup_after: alert.cleanup_after,
          target_storage_bytes: alert.target_storage_bytes,
        }),
        signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
      },
    );
    return response.ok;
  }
  if (!env.FCM_PROJECT || !env.FCM_EMAIL || !env.FCM_KEY) return false;
  const accessToken = await fcmAccessToken(env, auth);
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FCM_PROJECT)}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: device.push_token,
          notification: { title: alert.title, body: alert.body },
          data: {
            kind: 'storage_cleanup',
            cleanup_after: String(alert.cleanup_after),
            target_storage_bytes: String(alert.target_storage_bytes),
          },
          android: {
            priority: 'high',
            notification: { sound: 'default', channel_id: 'square_posts' },
          },
        },
      }),
      signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
    },
  );
  return response.ok;
}

/// 广场发帖可见推送：与 chat_wake 静默唤醒共用 APNS-JWT / FCM-OAuth 传输，仅 payload
/// 为可见通知（横幅+声音）。帖子是公开内容，含作者名；data.kind='square_post' 供客户端
/// 点击导航，绝不触发聊天重连（客户端 chat_wake 判定要求恰好 2 字段，此处天然不匹配）。
export async function sendSquarePostAlert(
  env: Env,
  device: PushDevice,
  alert: SquarePostAlert,
  auth: PushAuth = createPushAuth(),
): Promise<boolean> {
  if (device.push_provider === 'apns') {
    if (device.apns_environment === null) return false;
    return sendApnsAlert(env, device.push_token, device.apns_environment, alert, auth);
  }
  return sendFcmAlert(env, device.push_token, alert, auth);
}

async function sendApnsAlert(
  env: Env,
  token: string,
  environment: ApnsEnvironment,
  alert: SquarePostAlert,
  auth: PushAuth,
): Promise<boolean> {
  if (!env.APNS_KEY || !env.APNS_KID || !env.APNS_TEAM || !env.APNS_TOPIC) {
    return false;
  }
  const jwt = await apnsJwt(env, auth);
  const host = apnsHost(environment);
  const response = await fetch(`https://${host}/3/device/${encodeURIComponent(token)}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'apns-topic': env.APNS_TOPIC,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      aps: { alert: { title: alert.title, body: alert.body }, sound: 'default' },
      kind: 'square_post',
      post_id: alert.post_id,
    }),
    signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
  });
  return response.ok;
}

async function sendFcmAlert(
  env: Env,
  token: string,
  alert: SquarePostAlert,
  auth: PushAuth,
): Promise<boolean> {
  if (!env.FCM_PROJECT || !env.FCM_EMAIL || !env.FCM_KEY) {
    return false;
  }
  const accessToken = await fcmAccessToken(env, auth);
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FCM_PROJECT)}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: alert.title, body: alert.body },
          data: { kind: 'square_post', post_id: alert.post_id },
          // Android 8+ 用 App 侧预建的高优先级渠道 'square_posts' 保证横幅+声音；
          // channel_id 必须与 MainActivity 创建的渠道一致，否则声音由系统默认渠道决定。
          android: {
            priority: 'high',
            notification: { sound: 'default', channel_id: 'square_posts' },
          },
        },
      }),
      signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
    },
  );
  return response.ok;
}

async function sendApnsWake(
  env: Env,
  token: string,
  environment: ApnsEnvironment,
  payload: WakePayload,
  auth: PushAuth,
): Promise<boolean> {
  if (!env.APNS_KEY || !env.APNS_KID || !env.APNS_TEAM || !env.APNS_TOPIC) {
    return false;
  }
  const jwt = await apnsJwt(env, auth);
  const host = apnsHost(environment);
  const response = await fetch(`https://${host}/3/device/${encodeURIComponent(token)}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-push-type': 'background',
      'apns-priority': '5',
      'apns-topic': env.APNS_TOPIC,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      aps: { 'content-available': 1 },
      ...payload,
    }),
    signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
  });
  return response.ok;
}

/// APNs Token 的签发环境属于设备记录，不能由 Worker 环境全局决定。
export function apnsHost(environment: ApnsEnvironment): string {
  return environment === 'sandbox'
    ? 'api.sandbox.push.apple.com'
    : 'api.push.apple.com';
}

async function createApnsJwt(env: Env): Promise<string> {
  const header = encodeJson({ alg: 'ES256', kid: env.APNS_KID });
  const claims = encodeJson({ iss: env.APNS_TEAM, iat: Math.floor(Date.now() / 1000) });
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemBytes(env.APNS_KEY!),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

async function sendFcmWake(
  env: Env,
  token: string,
  payload: WakePayload,
  auth: PushAuth,
): Promise<boolean> {
  if (!env.FCM_PROJECT || !env.FCM_EMAIL || !env.FCM_KEY) {
    return false;
  }
  const accessToken = await fcmAccessToken(env, auth);
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FCM_PROJECT)}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          data: payload,
          android: { priority: 'high', ttl: '300s' },
        },
      }),
      signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
    },
  );
  return response.ok;
}

async function createFcmAccessToken(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const assertionHeader = encodeJson({ alg: 'RS256', typ: 'JWT' });
  const assertionClaims = encodeJson({
    iss: env.FCM_EMAIL,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  const signingInput = `${assertionHeader}.${assertionClaims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemBytes(env.FCM_KEY!),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  );
  const assertion = `${signingInput}.${base64Url(new Uint8Array(signature))}`;
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
    signal: AbortSignal.timeout(PUSH_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error('FCM OAuth token request failed');
  }
  const json = (await response.json()) as { access_token?: string };
  if (!json.access_token) {
    throw new Error('FCM OAuth response missing access token');
  }
  return json.access_token;
}

function apnsJwt(env: Env, auth: PushAuth): Promise<string> {
  auth.apns_jwt ??= createApnsJwt(env);
  return auth.apns_jwt;
}

function fcmAccessToken(env: Env, auth: PushAuth): Promise<string> {
  auth.fcm_access_token ??= createFcmAccessToken(env);
  return auth.fcm_access_token;
}

function pemBytes(value: string): ArrayBuffer {
  const body = value
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\\n/g, '')
    .replace(/\s/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

function encodeJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
