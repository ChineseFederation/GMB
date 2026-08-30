import 'dart:io';

import 'package:chat_sdk/media.dart';

import 'chat_cloud_transport.dart';

/// Maps CitizenServe routing identifiers onto ChatSDK's server-neutral
/// encrypted attachment storage contract. No media key crosses this boundary.
final class ChatAttachmentStorageAdapter implements AttachmentStorage {
  const ChatAttachmentStorageAdapter(this._transport);

  final ChatCloudTransport _transport;

  @override
  Future<void> uploadEncryptedAttachment({
    required String attachmentId,
    required List<String> recipientUserIds,
    required File cipherFile,
    required int cipherByteSize,
    required String cipherSha256,
  }) =>
      _transport.uploadEncryptedAttachment(
        attachmentId: attachmentId,
        recipientCidNumbers: recipientUserIds,
        cipherFile: cipherFile,
        cipherByteSize: cipherByteSize,
        cipherSha256: cipherSha256,
      );

  @override
  Future<void> downloadEncryptedAttachment({
    required String attachmentId,
    required File target,
    required int expectedByteSize,
    required String expectedSha256,
  }) =>
      _transport.downloadEncryptedAttachment(
        attachmentId: attachmentId,
        target: target,
        expectedByteSize: expectedByteSize,
        expectedSha256: expectedSha256,
      );

  @override
  Future<void> acknowledgeAttachment(String attachmentId) =>
      _transport.acknowledgeAttachment(attachmentId);

  @override
  Future<void> abortAttachment(String attachmentId) =>
      _transport.abortAttachment(attachmentId);
}
