import { AwsClient } from 'aws4fetch';

import { readUserByCidNumber } from '../account/user_repository';
import { resourceLimit } from '../limits/catalog';
import { requireActiveMembership } from '../membership/service';
import { HttpError, jsonResponse, readJson, requireSession } from '../shared/http';
import type { Env } from '../types';
import { assertChatCidNumber } from './codec';

const CHAT_ATTACHMENT_TTL_MILLIS = 7 * 24 * 60 * 60 * 1000;
const CHAT_ATTACHMENT_PART_BYTES = 64 * 1024 * 1024;
const CHAT_ATTACHMENT_MAX_BYTES = 5 * 1024 * 1024 * 1024 + 1024 * 1024;
const PRESIGNED_TTL_SECONDS = 6 * 60 * 60;
const CLEANUP_BATCH = 100;

interface ChatAttachmentRow {
  attachment_id: string;
  sender_cid_number: string;
  object_key: string;
  cipher_byte_size: number;
  cipher_sha256: string;
  multipart_upload_id: string;
  part_count: number;
  upload_state: 'uploading' | 'ready';
  expires_at: number;
}

interface PrepareBody {
  attachment_id?: unknown;
  recipient_cid_numbers?: unknown;
  cipher_byte_size?: unknown;
  cipher_sha256?: unknown;
}

interface CompleteBody {
  attachment_id?: unknown;
  etags?: unknown;
}

interface AttachmentIdBody {
  attachment_id?: unknown;
}

/**
 * 私聊和群聊共用一个附件入口：手机先加密，Worker 只签一组 multipart URL，
 * D1 只记录一份 R2 密文及接收 CID 集合，附件正文永远不经过 Worker。
 */
export async function prepareChatAttachment(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const body = await readJson<PrepareBody>(request);
  assertExactFields(body, [
    'attachment_id',
    'cipher_byte_size',
    'cipher_sha256',
    'recipient_cid_numbers',
  ]);
  const attachmentId = assertAttachmentId(body.attachment_id);
  const recipientCidNumbers = assertRecipientCidNumbers(
    body.recipient_cid_numbers,
    session.cid_number,
  );
  const cipherByteSize = assertCipherByteSize(body.cipher_byte_size);
  const cipherSha256 = assertSha256(body.cipher_sha256);
  await requireChatMembershipRecipients(
    env,
    session.cid_number,
    session.account_id,
    recipientCidNumbers,
  );

  const existing = await readAttachment(env, attachmentId);
  if (existing) {
    await requireSenderMatch(
      env,
      existing,
      session.cid_number,
      recipientCidNumbers,
      cipherByteSize,
      cipherSha256,
    );
    if (existing.upload_state === 'ready') {
      return jsonResponse({ attachment_id: attachmentId, upload_state: 'ready', parts: [] });
    }
    return jsonResponse(await uploadPlan(env, existing));
  }

  const objectKey = `chat/${session.cid_number}/${attachmentId}.cipher`;
  const uploadId = await createMultipartUpload(env, objectKey, cipherSha256);
  const now = Date.now();
  const partCount = Math.ceil(cipherByteSize / CHAT_ATTACHMENT_PART_BYTES);
  try {
    await env.DB.batch([
      env.DB.prepare(
        `INSERT INTO chat_attachments (
           attachment_id, sender_cid_number, recipient_cid_number, object_key, cipher_byte_size,
           cipher_sha256, multipart_upload_id, part_count, upload_state,
           created_at, expires_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'uploading', ?, ?)`,
      ).bind(
        attachmentId,
        session.cid_number,
        recipientCidNumbers[0],
        objectKey,
        cipherByteSize,
        cipherSha256,
        uploadId,
        partCount,
        now,
        now + CHAT_ATTACHMENT_TTL_MILLIS,
      ),
      ...recipientCidNumbers.map((recipientCidNumber) =>
        env.DB.prepare(
          `INSERT INTO chat_attachment_recipients (
             attachment_id, recipient_cid_number, created_at
           ) VALUES (?, ?, ?)`,
        ).bind(attachmentId, recipientCidNumber, now)
      ),
    ]);
  } catch (error) {
    await abortMultipartUpload(env, objectKey, uploadId).catch(() => undefined);
    throw error;
  }
  return jsonResponse(await uploadPlan(env, {
    attachment_id: attachmentId,
    sender_cid_number: session.cid_number,
    object_key: objectKey,
    cipher_byte_size: cipherByteSize,
    cipher_sha256: cipherSha256,
    multipart_upload_id: uploadId,
    part_count: partCount,
    upload_state: 'uploading',
    expires_at: now + CHAT_ATTACHMENT_TTL_MILLIS,
  }));
}

/** 完成 multipart 后通过私有 R2 绑定复核对象大小，未验真的对象不得进入 ready。 */
export async function completeChatAttachment(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const body = await readJson<CompleteBody>(request);
  assertExactFields(body, ['attachment_id', 'etags']);
  const attachmentId = assertAttachmentId(body.attachment_id);
  const row = await requireAttachment(env, attachmentId);
  requireSender(row, session.cid_number);
  const recipients = await readAttachmentRecipients(env, attachmentId);
  await requireChatMembershipRecipients(
    env,
    session.cid_number,
    session.account_id,
    recipients,
  );
  if (row.upload_state === 'ready') return jsonResponse({ ok: true });
  const etags = assertEtags(body.etags, row.part_count);
  await completeMultipartUpload(env, row.object_key, row.multipart_upload_id, etags);
  const object = await env.SQUARE_PRIVATE.head(row.object_key);
  if (!object || object.size !== row.cipher_byte_size) {
    await env.SQUARE_PRIVATE.delete(row.object_key).catch(() => undefined);
    throw new HttpError(422, 'chat_attachment_size_mismatch', 'Chat 附件密文大小校验失败');
  }
  await env.DB.prepare(
    `UPDATE chat_attachments SET upload_state = 'ready'
      WHERE attachment_id = ? AND sender_cid_number = ? AND upload_state = 'uploading'`,
  ).bind(attachmentId, session.cid_number).run();
  return jsonResponse({ ok: true });
}

/** 当前会话 CID 必须存在于接收人表，才可取得短期 HTTPS R2 下载地址。 */
export async function downloadChatAttachment(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const attachmentId = await readAttachmentId(request);
  const row = await requireAttachment(env, attachmentId);
  const recipient = await env.DB.prepare(
    `SELECT recipient_cid_number FROM chat_attachment_recipients
      WHERE attachment_id = ? AND recipient_cid_number = ?`,
  ).bind(attachmentId, session.cid_number).first<{ recipient_cid_number: string }>();
  if (!recipient || row.upload_state !== 'ready') {
    throw new HttpError(404, 'chat_attachment_not_found', 'Chat 附件不存在');
  }
  await requireActiveMembership(env, session.cid_number, session.account_id);
  return jsonResponse({
    attachment_id: row.attachment_id,
    cipher_byte_size: row.cipher_byte_size,
    cipher_sha256: row.cipher_sha256,
    download_url: await presignedR2Url(env, row.object_key, 'GET'),
  });
}

/**
 * 每个接收 CID 独立 ACK。删除自己的接收权限后，只有接收人集合为空时才删除
 * 唯一 R2 密文和主索引，因此群成员离线不会被其它成员的 ACK 提前清除附件。
 */
export async function acknowledgeChatAttachment(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const attachmentId = await readAttachmentId(request);
  const row = await readAttachment(env, attachmentId);
  if (!row) return jsonResponse({ ok: true });
  const result = await env.DB.prepare(
    `DELETE FROM chat_attachment_recipients
      WHERE attachment_id = ? AND recipient_cid_number = ?`,
  ).bind(attachmentId, session.cid_number).run();
  if ((result.meta.changes ?? 0) === 0) {
    const remaining = await countAttachmentRecipients(env, attachmentId);
    if (remaining > 0) {
      throw new HttpError(404, 'chat_attachment_not_found', 'Chat 附件不存在');
    }
  }
  if (await countAttachmentRecipients(env, attachmentId) === 0) {
    await deleteAttachment(env, row);
  }
  return jsonResponse({ ok: true });
}

/** 发送端在上传或本地可靠队列提交失败时幂等中止整个附件生命周期。 */
export async function abortChatAttachment(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(request, env);
  const attachmentId = await readAttachmentId(request);
  const row = await readAttachment(env, attachmentId);
  if (!row) return jsonResponse({ ok: true });
  requireSender(row, session.cid_number);
  await deleteAttachment(env, row);
  return jsonResponse({ ok: true });
}

/** 复用现有五分钟 Cron 清理固定七天到期项；失败重试不得改写 expires_at。 */
export async function cleanupExpiredChatAttachments(env: Env): Promise<number> {
  const result = await env.DB.prepare(
    `SELECT attachment_id, sender_cid_number, object_key, cipher_byte_size,
            cipher_sha256, multipart_upload_id, part_count, upload_state, expires_at
       FROM chat_attachments WHERE expires_at <= ? ORDER BY expires_at LIMIT ?`,
  ).bind(Date.now(), CLEANUP_BATCH).all<ChatAttachmentRow>();
  let deleted = 0;
  for (const row of result.results ?? []) {
    await deleteAttachment(env, row);
    deleted += 1;
  }
  return deleted;
}

/**
 * Identity deletion removes every attachment sent by the CID and its own
 * recipient mappings. Shared group ciphertext survives until another recipient
 * ACKs it; an object with no recipients is deleted immediately.
 */
export async function purgeChatAttachmentsForCid(
  env: Env,
  cidNumber: string,
): Promise<number> {
  const result = await env.DB.prepare(
    `SELECT a.attachment_id, a.sender_cid_number, a.object_key,
            a.cipher_byte_size, a.cipher_sha256, a.multipart_upload_id,
            a.part_count, a.upload_state, a.expires_at
       FROM chat_attachments a
      WHERE a.sender_cid_number = ?
         OR EXISTS (
           SELECT 1 FROM chat_attachment_recipients r
            WHERE r.attachment_id = a.attachment_id
              AND r.recipient_cid_number = ?
         )`,
  ).bind(cidNumber, cidNumber).all<ChatAttachmentRow>();
  let deletedObjects = 0;
  for (const row of result.results ?? []) {
    if (row.sender_cid_number === cidNumber) {
      await deleteAttachment(env, row);
      deletedObjects += 1;
      continue;
    }
    await env.DB.prepare(
      `DELETE FROM chat_attachment_recipients
        WHERE attachment_id = ? AND recipient_cid_number = ?`,
    ).bind(row.attachment_id, cidNumber).run();
    const remaining = await countAttachmentRecipients(env, row.attachment_id);
    if (remaining === 0) {
      await deleteAttachment(env, row);
      deletedObjects += 1;
    }
  }
  return deletedObjects;
}

async function requireChatMembershipRecipients(
  env: Env,
  senderCid: string,
  senderAccount: string,
  recipientCidNumbers: string[],
): Promise<void> {
  await requireActiveMembership(env, senderCid, senderAccount);
  for (const recipientCid of recipientCidNumbers) {
    const recipient = await readUserByCidNumber(env, recipientCid);
    if (!recipient) {
      throw recipientMembershipRequired();
    }
    try {
      await requireActiveMembership(env, recipient.cid_number, recipient.account_id);
    } catch {
      throw recipientMembershipRequired();
    }
  }
}

function recipientMembershipRequired(): HttpError {
  return new HttpError(
    403,
    'chat_recipient_membership_required',
    '对方尚未开通会员，无法接收聊天消息',
  );
}

async function uploadPlan(env: Env, row: ChatAttachmentRow): Promise<Record<string, unknown>> {
  const parts = [];
  for (let partNumber = 1; partNumber <= row.part_count; partNumber += 1) {
    const offset = (partNumber - 1) * CHAT_ATTACHMENT_PART_BYTES;
    const byteSize = Math.min(CHAT_ATTACHMENT_PART_BYTES, row.cipher_byte_size - offset);
    const headers = { 'content-length': String(byteSize) };
    parts.push({
      part_number: partNumber,
      offset,
      byte_size: byteSize,
      upload_url: await presignedR2Url(
        env,
        row.object_key,
        'PUT',
        headers,
        new URLSearchParams({
          partNumber: String(partNumber),
          uploadId: row.multipart_upload_id,
        }),
      ),
      upload_headers: headers,
    });
  }
  return {
    attachment_id: row.attachment_id,
    upload_state: row.upload_state,
    cipher_byte_size: row.cipher_byte_size,
    cipher_sha256: row.cipher_sha256,
    expires_at: row.expires_at,
    parts,
  };
}

async function createMultipartUpload(env: Env, objectKey: string, sha256: string): Promise<string> {
  const response = await signedR2Fetch(
    env,
    objectKey,
    'POST',
    { 'content-type': 'application/octet-stream', 'x-amz-meta-sha256': sha256 },
    new URLSearchParams({ uploads: '' }),
  );
  const text = await response.text();
  const uploadId = /<UploadId>([^<]+)<\/UploadId>/.exec(text)?.[1];
  if (!response.ok || !uploadId) {
    throw new HttpError(502, 'chat_attachment_prepare_failed', 'Chat 附件上传初始化失败');
  }
  return decodeXml(uploadId);
}

async function completeMultipartUpload(
  env: Env,
  objectKey: string,
  uploadId: string,
  etags: string[],
): Promise<void> {
  const body = `<CompleteMultipartUpload>${etags.map((etag, index) =>
    `<Part><PartNumber>${index + 1}</PartNumber><ETag>${escapeXml(etag)}</ETag></Part>`,
  ).join('')}</CompleteMultipartUpload>`;
  const response = await signedR2Fetch(
    env,
    objectKey,
    'POST',
    { 'content-type': 'application/xml' },
    new URLSearchParams({ uploadId }),
    body,
  );
  if (!response.ok) {
    throw new HttpError(502, 'chat_attachment_complete_failed', 'Chat 附件上传完成失败');
  }
}

async function abortMultipartUpload(env: Env, objectKey: string, uploadId: string): Promise<void> {
  const response = await signedR2Fetch(
    env,
    objectKey,
    'DELETE',
    {},
    new URLSearchParams({ uploadId }),
  );
  if (!response.ok && response.status !== 404) throw new Error('r2_multipart_abort_failed');
}

async function deleteAttachment(env: Env, row: ChatAttachmentRow): Promise<void> {
  if (row.upload_state === 'uploading') {
    await abortMultipartUpload(env, row.object_key, row.multipart_upload_id).catch(() => undefined);
  }
  await env.SQUARE_PRIVATE.delete(row.object_key);
  await env.DB.prepare('DELETE FROM chat_attachments WHERE attachment_id = ?')
    .bind(row.attachment_id).run();
}

async function signedR2Fetch(
  env: Env,
  objectKey: string,
  method: 'POST' | 'DELETE',
  headers: Record<string, string>,
  query: URLSearchParams,
  body?: string,
): Promise<Response> {
  const { client, url } = r2Client(env, objectKey, query);
  const signed = await client.sign(new Request(url, { method, headers, body }));
  return fetch(signed);
}

async function presignedR2Url(
  env: Env,
  objectKey: string,
  method: 'GET' | 'PUT',
  headers: Record<string, string> = {},
  query = new URLSearchParams(),
): Promise<string> {
  const { client, url } = r2Client(env, objectKey, query);
  url.searchParams.set('X-Amz-Expires', String(PRESIGNED_TTL_SECONDS));
  const signed = await client.sign(new Request(url, { method, headers }), {
    aws: { signQuery: true },
  });
  return signed.url;
}

function r2Client(
  env: Env,
  objectKey: string,
  query: URLSearchParams,
): { client: AwsClient; url: URL } {
  const accountId = env.CF_ACCOUNT_ID?.trim();
  const accessKeyId = env.R2_KEY?.trim();
  const secretAccessKey = env.R2_SECRET?.trim();
  const bucket = env.SQUARE_PRIVATE_BUCKET_NAME?.trim() || 'citizenapp-private';
  if (!accountId || !accessKeyId || !secretAccessKey) {
    throw new HttpError(503, 'r2_upload_signing_not_configured', 'R2 直传签名配置不完整');
  }
  const encodedKey = objectKey.split('/').map(encodeURIComponent).join('/');
  const url = new URL(
    `https://${accountId}.r2.cloudflarestorage.com/${encodeURIComponent(bucket)}/${encodedKey}`,
  );
  for (const [key, value] of query) url.searchParams.set(key, value);
  return {
    client: new AwsClient({ accessKeyId, secretAccessKey, service: 's3', region: 'auto' }),
    url,
  };
}

async function readAttachment(env: Env, attachmentId: string): Promise<ChatAttachmentRow | null> {
  return env.DB.prepare(
    `SELECT attachment_id, sender_cid_number, object_key, cipher_byte_size,
            cipher_sha256, multipart_upload_id, part_count, upload_state, expires_at
       FROM chat_attachments WHERE attachment_id = ?`,
  ).bind(attachmentId).first<ChatAttachmentRow>();
}

async function requireAttachment(env: Env, attachmentId: string): Promise<ChatAttachmentRow> {
  const row = await readAttachment(env, attachmentId);
  if (!row || row.expires_at <= Date.now()) {
    throw new HttpError(404, 'chat_attachment_not_found', 'Chat 附件不存在');
  }
  return row;
}

async function readAttachmentRecipients(env: Env, attachmentId: string): Promise<string[]> {
  const result = await env.DB.prepare(
    `SELECT recipient_cid_number FROM chat_attachment_recipients
      WHERE attachment_id = ? ORDER BY recipient_cid_number`,
  ).bind(attachmentId).all<{ recipient_cid_number: string }>();
  return (result.results ?? []).map((item) => item.recipient_cid_number);
}

async function countAttachmentRecipients(env: Env, attachmentId: string): Promise<number> {
  const row = await env.DB.prepare(
    'SELECT COUNT(*) AS n FROM chat_attachment_recipients WHERE attachment_id = ?',
  ).bind(attachmentId).first<{ n: number }>();
  return row?.n ?? 0;
}

async function readAttachmentId(request: Request): Promise<string> {
  const body = await readJson<AttachmentIdBody>(request);
  assertExactFields(body, ['attachment_id']);
  return assertAttachmentId(body.attachment_id);
}

function requireSender(row: ChatAttachmentRow, senderCid: string): void {
  if (row.sender_cid_number !== senderCid) {
    throw new HttpError(404, 'chat_attachment_not_found', 'Chat 附件不存在');
  }
}

async function requireSenderMatch(
  env: Env,
  row: ChatAttachmentRow,
  senderCid: string,
  recipientCidNumbers: string[],
  byteSize: number,
  sha256: string,
): Promise<void> {
  requireSender(row, senderCid);
  const existingRecipients = await readAttachmentRecipients(env, row.attachment_id);
  if (
    row.cipher_byte_size !== byteSize
    || row.cipher_sha256 !== sha256
    || existingRecipients.length !== recipientCidNumbers.length
    || existingRecipients.some((cid, index) => cid !== recipientCidNumbers[index])
  ) {
    throw new HttpError(409, 'chat_attachment_conflict', 'Chat 附件标识已被不同密文占用');
  }
}

function assertExactFields(value: object, fields: string[]): void {
  const actual = Object.keys(value).sort();
  const expected = [...fields].sort();
  if (
    actual.length !== expected.length
    || actual.some((field, index) => field !== expected[index])
  ) {
    throw new HttpError(400, 'invalid_chat_attachment_fields', 'Chat 附件字段不合法');
  }
}

function assertAttachmentId(value: unknown): string {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_.:-]{16,200}$/.test(value)) {
    throw new HttpError(400, 'invalid_chat_attachment_id', 'Chat 附件标识不合法');
  }
  return value;
}

function assertRecipientCidNumbers(value: unknown, senderCid: string): string[] {
  const maxItems = resourceLimit('chat_attachment').max_items ?? 1;
  if (!Array.isArray(value) || value.length === 0 || value.length > maxItems) {
    throw new HttpError(400, 'invalid_chat_attachment_recipients', 'Chat 附件接收人列表不合法');
  }
  const recipients = [...new Set(value.map((item) =>
    assertChatCidNumber(item, 'invalid_recipient_cid_number')
  ))].filter((cid) => cid !== senderCid).sort();
  if (recipients.length === 0 || recipients.length !== value.length) {
    throw new HttpError(400, 'invalid_chat_attachment_recipients', 'Chat 附件接收人列表不合法');
  }
  return recipients;
}

function assertCipherByteSize(value: unknown): number {
  if (
    !Number.isSafeInteger(value)
    || (value as number) <= 0
    || (value as number) > CHAT_ATTACHMENT_MAX_BYTES
  ) {
    throw new HttpError(413, 'chat_attachment_too_large', 'Chat 附件密文大小超过上限');
  }
  return value as number;
}

function assertSha256(value: unknown): string {
  if (typeof value !== 'string' || !/^[0-9a-f]{64}$/.test(value)) {
    throw new HttpError(400, 'invalid_chat_attachment_sha256', 'Chat 附件密文摘要不合法');
  }
  return value;
}

function assertEtags(value: unknown, expectedCount: number): string[] {
  if (!Array.isArray(value) || value.length !== expectedCount) {
    throw new HttpError(400, 'invalid_chat_attachment_parts', 'Chat 附件分片数量不合法');
  }
  return value.map((etag) => {
    if (typeof etag !== 'string' || !/^"?[a-zA-Z0-9_-]{8,200}"?$/.test(etag)) {
      throw new HttpError(400, 'invalid_chat_attachment_etag', 'Chat 附件分片校验值不合法');
    }
    return etag;
  });
}

function escapeXml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function decodeXml(value: string): string {
  return value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"');
}
