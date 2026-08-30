import 'dart:io';

/// Server-neutral storage contract for already encrypted attachment bytes.
/// Implementations may use Cloudflare R2 or self-hosted object storage. They
/// never receive the content key and accept only HTTPS transfer URLs.
abstract interface class AttachmentStorage {
  Future<void> uploadEncryptedAttachment({
    required String attachmentId,
    required List<String> recipientUserIds,
    required File cipherFile,
    required int cipherByteSize,
    required String cipherSha256,
  });

  Future<void> downloadEncryptedAttachment({
    required String attachmentId,
    required File target,
    required int expectedByteSize,
    required String expectedSha256,
  });

  Future<void> acknowledgeAttachment(String attachmentId);
  Future<void> abortAttachment(String attachmentId);
}

/// Validates a transfer URL without prohibiting signed query parameters.
Uri requireAttachmentHttps(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw ArgumentError.value(uri, 'uri', 'attachment URL must use HTTPS');
  }
  return uri;
}
