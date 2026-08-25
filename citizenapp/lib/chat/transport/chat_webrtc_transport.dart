import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../chat_media_limits.dart';
import '../chat_models.dart';
import '../crypto/mls_boundary.dart';
import '../proto/chat_envelope.pb.dart';
import 'chat_cloud_transport.dart';
import 'chat_transport.dart';

typedef ChatAttachmentReceiver = Future<void> Function({
  required String senderCidNumber,
  required String conversationId,
  required String attachmentId,
  required String fileName,
  required String contentType,
  required String filePath,
  required int byteSize,
});

/// 直连控制通道收到 Envelope 后，由运行态完成 OpenMLS 解密与本机安全落盘。
/// 返回已经持久化的应用 Envelope ID；传输层随后只在同一 DataChannel 回确认。
typedef ChatDirectEnvelopeReceiver = Future<List<String>> Function({
  required String senderCidNumber,
  required List<int> envelopeBytes,
});

/// 对端确认 Envelope 已经写入其本机数据库；该确认只驱动本地补发队列，不是已读回执。
typedef ChatEnvelopeStoredReceiver = Future<void> Function({
  required String senderCidNumber,
  required String envelopeId,
});

/// 对端通过直连请求首次会话 KeyPackage 时，运行态在本机 OpenMLS 中即时生成。
typedef ChatDirectKeyPackageProvider = Future<MlsKeyPackage> Function();

/// 把 WebRTC 的每个文件/网络动作纳入当前 binding 的持久 CID 临界区。
typedef ChatWebrtcMutationRunner = Future<T> Function<T>(
  Future<T> Function() operation,
);

/// DataChannel 附件帧只描述设备间传输，不允许出现云端对象引用。
class ChatWebrtcAttachmentFrame {
  const ChatWebrtcAttachmentFrame._();

  static Map<String, dynamic> start({
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required int byteSize,
  }) =>
      {
        'kind': 'attachment_start',
        'conversation_id': conversationId,
        'attachment_id': attachmentId,
        'file_name': fileName,
        'content_type': contentType,
        'byte_size': byteSize,
      };

  /// 接收端回给发送端的续传偏移:本地同 attachment_id 的 `.part` 已存字节数。
  /// 发送端据此 `openRead(offset)` 只补缺口,不从头重传。
  static Map<String, dynamic> resume({required int resumeOffset}) => {
        'kind': 'attachment_resume',
        'resume_offset': resumeOffset,
      };
}

/// 接收端已完整落盘的媒体临时文件句柄。
class ChatReceivedAttachment {
  const ChatReceivedAttachment({
    required this.conversationId,
    required this.attachmentId,
    required this.fileName,
    required this.contentType,
    required this.filePath,
    required this.byteSize,
  });

  final String conversationId;
  final String attachmentId;
  final String fileName;
  final String contentType;
  final String filePath;
  final int byteSize;
}

/// WebRTC 控制 DataChannel 的严格帧编解码边界。
///
/// 控制帧只允许 Envelope、设备落盘确认和按需 KeyPackage 交换。字段集合必须精确，
/// 避免把云端对象引用、任意消息元数据或兼容字段偷偷带回聊天协议。
class ChatWebrtcControlFrame {
  const ChatWebrtcControlFrame._();

  static Map<String, dynamic> envelope(List<int> envelopeBytes) =>
      <String, dynamic>{
        'kind': 'envelope',
        'envelope': _base64UrlEncode(envelopeBytes),
      };

  static Map<String, dynamic> envelopeStored(String envelopeId) =>
      <String, dynamic>{
        'kind': 'envelope_stored',
        'envelope_id': envelopeId,
      };

  static Map<String, dynamic> keyPackageRequest(String requestId) =>
      <String, dynamic>{
        'kind': 'key_package_request',
        'request_id': requestId,
      };

  static Map<String, dynamic> keyPackageResponse(
    String requestId,
    MlsKeyPackage keyPackage,
  ) =>
      <String, dynamic>{
        'kind': 'key_package_response',
        'request_id': requestId,
        'key_package': _keyPackageToJson(keyPackage),
      };

  static Map<String, dynamic> decode(String text) {
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Chat 控制帧必须是对象');
    }
    switch (value['kind']) {
      case 'envelope':
        _requireExactFrameKeys(value, const ['kind', 'envelope']);
        final bytes = envelopeBytes(value);
        if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
          throw const FormatException('Chat Envelope 帧大小不合法');
        }
      case 'envelope_stored':
        _requireExactFrameKeys(value, const ['kind', 'envelope_id']);
        _requireControlToken(value['envelope_id'], 'envelope_id');
      case 'key_package_request':
        _requireExactFrameKeys(value, const ['kind', 'request_id']);
        _requireControlToken(value['request_id'], 'request_id');
      case 'key_package_response':
        _requireExactFrameKeys(
          value,
          const ['kind', 'request_id', 'key_package'],
        );
        _requireControlToken(value['request_id'], 'request_id');
        keyPackage(value);
      default:
        throw const FormatException('Chat 控制帧类型不合法');
    }
    return value;
  }

  static List<int> envelopeBytes(Map<String, dynamic> frame) {
    final encoded = frame['envelope'];
    if (encoded is! String || encoded.isEmpty) {
      throw const FormatException('Chat Envelope 帧缺少密文字节');
    }
    try {
      return _base64UrlDecode(encoded);
    } on FormatException {
      throw const FormatException('Chat Envelope 帧编码不合法');
    }
  }

  static MlsKeyPackage keyPackage(Map<String, dynamic> frame) {
    final value = frame['key_package'];
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Chat KeyPackage 帧格式不合法');
    }
    _requireExactFrameKeys(value, const [
      'cid_number',
      'device_id',
      'device_public_key_hex',
      'key_package_id',
      'key_package',
      'cipher_suite',
      'not_before',
      'not_after',
      'last_resort',
    ]);
    for (final field in const [
      'cid_number',
      'device_id',
      'device_public_key_hex',
      'key_package_id',
      'cipher_suite',
    ]) {
      _requireControlToken(value[field], field, maxLength: 512);
    }
    final encoded = value['key_package'];
    if (encoded is! String || encoded.isEmpty) {
      throw const FormatException('Chat KeyPackage 字节缺失');
    }
    final keyPackageBytes = _base64UrlDecode(encoded);
    if (keyPackageBytes.isEmpty || keyPackageBytes.length > 1024 * 1024) {
      throw const FormatException('Chat KeyPackage 字节大小不合法');
    }
    final notBefore = value['not_before'];
    final notAfter = value['not_after'];
    if (notBefore is! int ||
        notAfter is! int ||
        notBefore < 0 ||
        notAfter <= notBefore ||
        value['last_resort'] is! bool) {
      throw const FormatException('Chat KeyPackage 生命周期不合法');
    }
    return MlsKeyPackage(
      cidNumber: value['cid_number'] as String,
      deviceId: value['device_id'] as String,
      devicePublicKey: value['device_public_key_hex'] as String,
      keyPackageId: value['key_package_id'] as String,
      keyPackageBytes: keyPackageBytes,
      cipherSuite: value['cipher_suite'] as String,
      notBeforeMillis: notBefore,
      notAfterMillis: notAfter,
      lastResort: value['last_resort'] as bool,
    );
  }
}

void _requireExactFrameKeys(
  Map<String, dynamic> value,
  List<String> expected,
) {
  if (value.length != expected.length || !expected.every(value.containsKey)) {
    throw const FormatException('Chat 控制帧字段不合法');
  }
}

void _requireControlToken(
  Object? value,
  String field, {
  int maxLength = 256,
}) {
  if (value is! String || value.isEmpty || value.length > maxLength) {
    throw FormatException('Chat 控制帧 $field 不合法');
  }
}

/// 接收端媒体**流式落盘 + 大小门控(门②)**。
///
/// 把 WebRTC 分片直写临时文件,只维护运行字节计数做门控,内存里不堆整文件——
/// 5GB 媒体也不会 OOM。门控用 `content_type` 定额:
///   - `attachment_start` 声明就超限(或缺失)→ 拒收,连临时文件都不建;
///   - 累积字节超限 → 立即中止 + 删临时(防发送方谎报小 byte_size 却狂发);
///   - `attachment_end` 时字节数须与声明**精确一致**,否则视为截断/损坏丢弃。
/// 与 WebRTC 解耦以便单测。
class ChatAttachmentReceiveBuffer {
  ChatAttachmentReceiveBuffer({
    required this.tempDirectory,
    int Function(String mime)? limitForMime,
  }) : _limitForMime = limitForMime ?? ChatMediaLimits.forMime;

  final String tempDirectory;

  /// 按 mime 取上限。默认走单源 [ChatMediaLimits.forMime];测试可注入小额度以
  /// 驱动累积超限中止,无需真的流 100MB。
  final int Function(String mime) _limitForMime;

  IOSink? _sink;
  String? _tempPath;
  Map<String, dynamic>? _header;
  int _running = 0;
  int _limit = 0;
  int _resumeOffset = 0;
  bool _rejected = false;

  bool get rejected => _rejected;
  int get running => _running;

  /// 本次 start 时同 attachment_id 的 `.part` 已存字节数;发送端据此续流。
  int get resumeOffset => _resumeOffset;
  String? get tempPath => _tempPath;

  Future<void> start(Map<String, dynamic> header, String transferId) async {
    await _closeSink(); // 关旧 sink,但保留 partial(可能正是要续传的)
    _header = header;
    _running = 0;
    _resumeOffset = 0;
    _rejected = false;
    final contentType =
        header['content_type']?.toString() ?? 'application/octet-stream';
    final declared = (header['byte_size'] as num?)?.toInt() ?? -1;
    _limit = _limitForMime(contentType);
    if (declared < 0 || declared > _limit) {
      _rejected = true;
      return;
    }
    // 按 attachment_id 命名 partial,同一媒体跨传输尝试可复用以断点续传。
    final attachmentId = header['attachment_id']?.toString() ?? transferId;
    final path = '$tempDirectory/${_safeSegment(attachmentId)}.part';
    final file = File(path);
    await file.parent.create(recursive: true);
    var existing = 0;
    if (await file.exists()) {
      existing = await file.length();
      // 现有 partial 比声明还大 = 陈旧/异常,清掉从头来。
      if (existing > declared) {
        await _deleteTemp(path);
        existing = 0;
      }
    }
    _tempPath = path;
    _resumeOffset = existing;
    _running = existing;
    // 追加写:已存字节保留,只续写缺口。
    _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
  }

  Future<void> addChunk(List<int> chunk) async {
    if (_rejected || _sink == null) return;
    _running += chunk.length;
    if (_running > _limit) {
      _rejected = true;
      await _deletePartial(); // 谎报小 byte_size 却狂发:中止并删档
      return;
    }
    _sink!.add(chunk);
  }

  Future<ChatReceivedAttachment?> finish() async {
    final sink = _sink;
    final header = _header;
    final tempPath = _tempPath;
    _sink = null;
    if (_rejected || sink == null || header == null || tempPath == null) {
      await _deletePartial();
      return null;
    }
    await sink.flush();
    await sink.close();
    final declared = (header['byte_size'] as num?)?.toInt() ?? -1;
    if (_running != declared) {
      // 大小不符 = 截断/损坏:删档,下次同 attachment_id 从头传。
      _tempPath = null;
      await _deleteTemp(tempPath);
      return null;
    }
    _tempPath = null; // 完整:交调用方移入缓存,dispose 不再触碰
    return ChatReceivedAttachment(
      conversationId: header['conversation_id']?.toString() ?? '',
      attachmentId: header['attachment_id']?.toString() ?? '',
      fileName: header['file_name']?.toString() ?? 'attachment.bin',
      contentType:
          header['content_type']?.toString() ?? 'application/octet-stream',
      filePath: tempPath,
      byteSize: _running,
    );
  }

  /// 关流但**保留** partial(断线/复用前):下次同 attachment_id 续写,断点续传核心。
  Future<void> _closeSink() async {
    final sink = _sink;
    _sink = null;
    if (sink != null) {
      try {
        await sink.flush();
        await sink.close();
      } on FileSystemException {
        // 关流失败不阻断续传:磁盘已存字节仍是有效前缀。
      }
    }
  }

  /// 主动作废:关流并删 partial(拒收 / 累积超限 / 大小不符),下次从头。
  Future<void> _deletePartial() async {
    await _closeSink();
    final tempPath = _tempPath;
    _tempPath = null;
    if (tempPath != null) {
      await _deleteTemp(tempPath);
    }
  }

  /// 通道断开/接收端释放:只关流保留 partial,已存字节等下次续传。
  Future<void> dispose() => _closeSink();

  static Future<void> _deleteTemp(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // 临时文件删除失败可忽略,由缓存清理兜底。
      }
    }
  }

  static String _safeSegment(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');

  /// 清理被永久放弃的续传残档:删 [tempDirectory] 下 mtime 超 [maxAge] 的 `.part`。
  /// 对端删了会话/待投递行后,其半程 partial 不会再被续写,由此回收磁盘。
  static Future<void> sweepStalePartials(
    String tempDirectory, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final dir = Directory(tempDirectory);
    if (!await dir.exists()) return;
    final cutoff = maxAge.inMilliseconds;
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.part')) continue;
      try {
        final age = DateTime.now().difference(await entity.lastModified());
        if (age.inMilliseconds > cutoff) {
          await entity.delete();
        }
      } on FileSystemException {
        // 单个残档处理失败不阻断整体清扫。
      }
    }
  }
}

/// WebRTC 设备直连传输。
///
/// 控制通道承载 OpenMLS Envelope、KeyPackage 和本机落盘确认；媒体通道承载附件
/// 分片。Cloudflare 只转发 SDP/ICE 建连信令，绝不接收这些 DataChannel 帧。
class ChatWebrtcTransport implements ChatTransport {
  ChatWebrtcTransport({
    required this.accountId,
    required this.localCidNumber,
    required this.cloud,
    required this.onAttachment,
    required this.onEnvelope,
    required this.onEnvelopeStored,
    required this.createKeyPackage,
    required this.tempDirectory,
    required this.runBindingMutation,
  });

  static const _chunkSize = 64 * 1024;
  static const _timeout = Duration(seconds: 8);
  static const _iceGatheringTimeout = Duration(seconds: 5);
  static const _controlIdleTimeout = Duration(seconds: 90);
  // 背压水位:发送缓冲超过高水位则暂停灌注,等其回落到低水位再继续。5GB 文件
  // 因此不会把 SCTP 发送缓冲撑爆。
  static const _highWaterBytes = 1 * 1024 * 1024;
  static const _lowWaterBytes = 256 * 1024;
  // 只使用 STUN 发现公网候选；不配置中继 URL、用户名或凭证，附件因此绝不会
  // 经云端中继。直连失败时保留在发送设备，等待接收方网络条件允许后重试。
  static const _iceServers = <Map<String, Object>>[
    <String, Object>{
      'urls': <String>['stun:stun.cloudflare.com:3478'],
    },
  ];

  final String accountId;
  final String localCidNumber;
  final ChatCloudTransport cloud;
  final ChatAttachmentReceiver onAttachment;
  final ChatDirectEnvelopeReceiver onEnvelope;
  final ChatEnvelopeStoredReceiver onEnvelopeStored;
  final ChatDirectKeyPackageProvider createKeyPackage;
  final ChatWebrtcMutationRunner runBindingMutation;

  /// 接收端字节流落盘的临时目录(App 私有,由运行态注入)。
  final String tempDirectory;

  final Map<String, _PeerTransfer> _peers = {};
  final Map<String, _ControlPeer> _controlPeers = {};
  final Map<String, String> _outboundControlPeerIds = {};
  final Map<String, Future<_ControlPeer>> _controlFlights = {};
  final Map<String, Completer<MlsKeyPackage>> _keyPackageRequests = {};
  final Map<String, Future<void>> _signalTails = {};

  @override
  ChatTransportType get type => ChatTransportType.webrtc;

  /// 把 OpenMLS Envelope 直接写入对端控制通道。失败只返回 queued，本地可靠队列
  /// 保持原字节，后续网络恢复、peer_ready 或推送唤醒会重试同一 Envelope。
  @override
  Future<ChatDeliveryResult> sendEncryptedEnvelope({
    required String envelopeId,
    required List<int> envelopeBytes,
    required String recipientCidNumber,
  }) async {
    try {
      final envelope = ChatEnvelope.fromBuffer(envelopeBytes);
      if (envelope.envelopeId != envelopeId ||
          envelope.recipientCidNumber != recipientCidNumber ||
          envelope.senderCidNumber != localCidNumber) {
        throw const FormatException('Chat Envelope 与直连路由不一致');
      }
      final peer = await _controlPeer(recipientCidNumber);
      await peer.channel!.send(RTCDataChannelMessage(
        jsonEncode(ChatWebrtcControlFrame.envelope(envelopeBytes)),
      ));
      _touchControlPeer(peer);
      return ChatDeliveryResult(
        envelopeId: envelopeId,
        transportType: type,
        state: ChatMessageDeliveryState.sent,
      );
    } catch (error) {
      return ChatDeliveryResult(
        envelopeId: envelopeId,
        transportType: type,
        state: ChatMessageDeliveryState.queued,
        errorMessage: error.toString(),
      );
    }
  }

  /// 首次会话 KeyPackage 只通过已经建立的设备直连请求，不建立云端库存。
  Future<MlsKeyPackage> requestKeyPackage(String recipientCidNumber) async {
    final peer = await _controlPeer(recipientCidNumber);
    _touchControlPeer(peer);
    final requestId = _newControlId('key-package');
    final completer = Completer<MlsKeyPackage>();
    _keyPackageRequests[requestId] = completer;
    try {
      await peer.channel!.send(RTCDataChannelMessage(
        jsonEncode(ChatWebrtcControlFrame.keyPackageRequest(requestId)),
      ));
      final keyPackage = await completer.future.timeout(_timeout);
      if (keyPackage.cidNumber != recipientCidNumber) {
        throw StateError('直连 KeyPackage CID 与请求目标不一致');
      }
      return keyPackage;
    } finally {
      _keyPackageRequests.remove(requestId);
    }
  }

  Future<_ControlPeer> _controlPeer(String peerCidNumber) {
    final existingId = _outboundControlPeerIds[peerCidNumber];
    final existing = existingId == null ? null : _controlPeers[existingId];
    if (existing?.channel != null &&
        existing!.open.isCompleted &&
        !existing.closing) {
      _touchControlPeer(existing);
      return Future<_ControlPeer>.value(existing);
    }
    final flight = _controlFlights[peerCidNumber];
    if (flight != null) return flight;
    late final Future<_ControlPeer> created;
    created = _openOutboundControlPeer(peerCidNumber).whenComplete(() {
      if (identical(_controlFlights[peerCidNumber], created)) {
        _controlFlights.remove(peerCidNumber);
      }
    });
    _controlFlights[peerCidNumber] = created;
    return created;
  }

  Future<_ControlPeer> _openOutboundControlPeer(String peerCidNumber) async {
    final connectionId = _newControlId('control');
    final peer = await _createControlPeer(connectionId, peerCidNumber);
    _outboundControlPeerIds[peerCidNumber] = connectionId;
    final channel = await peer.connection.createDataChannel(
      'chat-control',
      RTCDataChannelInit()..ordered = true,
    );
    peer.channel = channel;
    _bindControlChannel(peer, channel);
    final offer = await peer.connection.createOffer();
    final localOffer = await _setLocalDescriptionAndGatherIce(
      peer.connection,
      offer,
    );
    final offerSignal = <String, dynamic>{
      'kind': 'offer',
      'connection_kind': 'control',
      'connection_id': connectionId,
      'sdp': localOffer.sdp,
      'sdp_type': localOffer.type,
    };
    try {
      // 一个 connection_id 只发送一次 Offer。重复发送同一 Offer 会让接收端在
      // have-local-offer 等非法状态再次 createAnswer，并且重复触发系统唤醒。
      await cloud.sendSignal(
        recipientCidNumber: peerCidNumber,
        signal: offerSignal,
      );
      await peer.open.future.timeout(_timeout);
      _touchControlPeer(peer);
      return peer;
    } catch (error) {
      await _closeControlPeer(connectionId);
      if (error is TimeoutException) {
        throw TimeoutException('接收设备暂未建立直连，消息保留在发送设备');
      }
      rethrow;
    }
  }

  Future<void> sendAttachment({
    required String recipientCidNumber,
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String sourcePath,
    required int byteSize,
  }) {
    return runBindingMutation(
      () => _sendAttachment(
        recipientCidNumber: recipientCidNumber,
        conversationId: conversationId,
        attachmentId: attachmentId,
        fileName: fileName,
        contentType: contentType,
        sourcePath: sourcePath,
        byteSize: byteSize,
      ),
    );
  }

  Future<void> _sendAttachment({
    required String recipientCidNumber,
    required String conversationId,
    required String attachmentId,
    required String fileName,
    required String contentType,
    required String sourcePath,
    required int byteSize,
  }) async {
    final transferId = '$attachmentId-${DateTime.now().microsecondsSinceEpoch}';
    final peer = await _createPeer(transferId, recipientCidNumber);
    // 任一 await(建连/续传偏移/ack 超时,或发送出错)都必须关闭对端连接,否则
    // 泄漏 _peers 表项与原生 RTCPeerConnection。_closePeer 幂等,成功路径也复用。
    try {
      final channel = await peer.connection.createDataChannel(
        'chat-attachment',
        RTCDataChannelInit()..ordered = true,
      );
      channel.bufferedAmountLowThreshold = _lowWaterBytes;
      peer.channel = channel;
      _bindChannel(peer, channel);
      final offer = await peer.connection.createOffer();
      final localOffer = await _setLocalDescriptionAndGatherIce(
        peer.connection,
        offer,
      );
      await _sendOfferUntilOpen(
        peer,
        {
          'kind': 'offer',
          'transfer_id': transferId,
          'sdp': localOffer.sdp,
          'sdp_type': localOffer.type,
        },
      );
      await channel.send(RTCDataChannelMessage(jsonEncode(
        ChatWebrtcAttachmentFrame.start(
          conversationId: conversationId,
          attachmentId: attachmentId,
          fileName: fileName,
          contentType: contentType,
          byteSize: byteSize,
        ),
      )));
      // 等接收端回报续传偏移(其同 attachment_id 的 .part 已存字节数),据此续流;
      // 超时(对端离线/声明超限拒收未回帧)则抛错,partial 留待下次 peer_ready 续传。
      final reportedOffset = await peer.resumeOffset.future.timeout(_timeout);
      // 对端可被篡改:合法偏移恒在 [0, byteSize],越界即从 0 全量重传。负值若直传
      // openRead 会抛 RangeError(是 Error 非 Exception),逃逸上层 on Exception 门控。
      final resumeOffset = (reportedOffset < 0 || reportedOffset > byteSize)
          ? 0
          : reportedOffset;
      // 从续传偏移起流式读取分片:整文件绝不进内存;每片前按背压节流。已传的
      // [0, resumeOffset) 不再重发,断点续传的核心。
      await for (final block in File(sourcePath).openRead(resumeOffset)) {
        final bytes = block is Uint8List ? block : Uint8List.fromList(block);
        for (var offset = 0; offset < bytes.length; offset += _chunkSize) {
          final end = (offset + _chunkSize).clamp(0, bytes.length);
          await _drainIfNeeded(channel);
          await channel.send(
            RTCDataChannelMessage.fromBinary(
              Uint8List.sublistView(bytes, offset, end),
            ),
          );
        }
      }
      await channel
          .send(RTCDataChannelMessage(jsonEncode({'kind': 'attachment_end'})));
      await peer.ack.future.timeout(_timeout);
    } finally {
      await _closePeer(transferId);
    }
  }

  /// 发送背压:发送缓冲超过高水位时轮询等待其回落到低水位以下再继续灌注。
  Future<void> _drainIfNeeded(RTCDataChannel channel) async {
    var buffered = channel.bufferedAmount ?? 0;
    while (buffered > _highWaterBytes) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      buffered = await channel.getBufferedAmount();
    }
  }

  /// 关闭 trickle ICE：先在设备端收齐候选，再把候选随 SDP 一次性瞬时转发。
  ///
  /// 真机在双栈与多个网络接口下会瞬间产生几十个候选；逐候选 HTTP 请求会触发
  /// Cloudflare 1015，并且让未等待的 Future 逃逸为未捕获异常。完整 SDP 既不包含
  /// 消息内容，也把每次 offer/answer 收敛为一次协调请求。
  Future<RTCSessionDescription> _setLocalDescriptionAndGatherIce(
    RTCPeerConnection connection,
    RTCSessionDescription description,
  ) async {
    final gathered = Completer<void>();
    connection.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !gathered.isCompleted) {
        gathered.complete();
      }
    };
    try {
      await connection.setLocalDescription(description);
      final currentState = await connection.getIceGatheringState();
      if (currentState == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !gathered.isCompleted) {
        gathered.complete();
      }
      try {
        await gathered.future.timeout(_iceGatheringTimeout);
      } on TimeoutException {
        // 个别真机会很晚才回调 COMPLETE；只要当前 SDP 已包含候选，就直接使用
        // 已收集结果，避免因平台事件延迟反复销毁、重建同一个直连会话。
        final partialDescription = await connection.getLocalDescription();
        final partialSdp = partialDescription?.sdp ?? '';
        if (partialDescription == null ||
            !RegExp(r'^a=candidate:', multiLine: true).hasMatch(partialSdp)) {
          rethrow;
        }
      }
      final localDescription = await connection.getLocalDescription();
      if (localDescription == null ||
          (localDescription.sdp ?? '').trim().isEmpty ||
          (localDescription.type ?? '').trim().isEmpty) {
        throw StateError('WebRTC 本地 SDP 未完成');
      }
      return localDescription;
    } finally {
      connection.onIceGatheringState = null;
    }
  }

  Future<void> handleSignal(
    String senderCidNumber,
    Map<String, dynamic> signal,
  ) {
    final isControl = signal['connection_kind'] == 'control';
    final signalId =
        signal[isControl ? 'connection_id' : 'transfer_id']?.toString();
    if (signalId == null || signalId.isEmpty) return Future<void>.value();
    final key = '${isControl ? 'control' : 'attachment'}|'
        '$senderCidNumber|$signalId';
    final previous = _signalTails[key] ?? Future<void>.value();
    late final Future<void> current;
    // 同一连接的 Offer/Answer 必须严格串行，禁止两个 socket 回调同时推进原生
    // PeerConnection 信令状态机。当前信令失败仍向调用方返回，下一帧不被旧错误阻塞。
    current = previous
        .catchError((Object _, StackTrace __) {})
        .then((_) => _handleSignal(senderCidNumber, signal))
        .whenComplete(() {
      if (identical(_signalTails[key], current)) _signalTails.remove(key);
    });
    _signalTails[key] = current;
    return current;
  }

  Future<void> _handleSignal(
    String senderCidNumber,
    Map<String, dynamic> signal,
  ) async {
    if (signal['connection_kind'] == 'control') {
      await _handleControlSignal(senderCidNumber, signal);
      return;
    }
    final kind = signal['kind']?.toString();
    final transferId = signal['transfer_id']?.toString() ?? '';
    if (transferId.isEmpty) return;
    if (kind == 'offer') {
      final peer = await _createPeer(transferId, senderCidNumber);
      final cachedAnswer = peer.answerSignal;
      if (cachedAnswer != null) {
        await cloud.sendSignal(
          recipientCidNumber: senderCidNumber,
          signal: cachedAnswer,
        );
        return;
      }
      peer.connection.onDataChannel = (channel) {
        peer.channel = channel;
        _bindChannel(peer, channel);
      };
      if (!peer.remoteDescriptionSet) {
        await peer.connection.setRemoteDescription(
          RTCSessionDescription(
              signal['sdp']?.toString(), signal['sdp_type']?.toString()),
        );
        peer.remoteDescriptionSet = true;
      }
      final answer = await peer.connection.createAnswer();
      final localAnswer = await _setLocalDescriptionAndGatherIce(
        peer.connection,
        answer,
      );
      final answerSignal = <String, dynamic>{
        'kind': 'answer',
        'transfer_id': transferId,
        'sdp': localAnswer.sdp,
        'sdp_type': localAnswer.type,
      };
      peer.answerSignal = answerSignal;
      await cloud.sendSignal(
        recipientCidNumber: senderCidNumber,
        signal: answerSignal,
      );
      return;
    }
    final peer = _peers[transferId];
    if (peer == null) return;
    if (kind == 'answer' && !peer.remoteDescriptionSet) {
      await peer.connection.setRemoteDescription(
        RTCSessionDescription(
            signal['sdp']?.toString(), signal['sdp_type']?.toString()),
      );
      peer.remoteDescriptionSet = true;
    }
  }

  Future<void> _handleControlSignal(
    String senderCidNumber,
    Map<String, dynamic> signal,
  ) async {
    final kind = signal['kind']?.toString();
    final connectionId = signal['connection_id']?.toString() ?? '';
    if (connectionId.isEmpty) return;
    if (kind == 'offer') {
      final peer = await _createControlPeer(connectionId, senderCidNumber);
      final cachedAnswer = peer.answerSignal;
      if (cachedAnswer != null) {
        await cloud.sendSignal(
          recipientCidNumber: senderCidNumber,
          signal: cachedAnswer,
        );
        return;
      }
      peer.connection.onDataChannel = (channel) {
        peer.channel = channel;
        _bindControlChannel(peer, channel);
      };
      if (!peer.remoteDescriptionSet) {
        await peer.connection.setRemoteDescription(
          RTCSessionDescription(
            signal['sdp']?.toString(),
            signal['sdp_type']?.toString(),
          ),
        );
        peer.remoteDescriptionSet = true;
      }
      final answer = await peer.connection.createAnswer();
      final localAnswer = await _setLocalDescriptionAndGatherIce(
        peer.connection,
        answer,
      );
      final answerSignal = <String, dynamic>{
        'kind': 'answer',
        'connection_kind': 'control',
        'connection_id': connectionId,
        'sdp': localAnswer.sdp,
        'sdp_type': localAnswer.type,
      };
      peer.answerSignal = answerSignal;
      await cloud.sendSignal(
        recipientCidNumber: senderCidNumber,
        signal: answerSignal,
      );
      return;
    }
    final peer = _controlPeers[connectionId];
    if (peer == null || peer.peerCidNumber != senderCidNumber) return;
    if (kind == 'answer' && !peer.remoteDescriptionSet) {
      await peer.connection.setRemoteDescription(
        RTCSessionDescription(
          signal['sdp']?.toString(),
          signal['sdp_type']?.toString(),
        ),
      );
      peer.remoteDescriptionSet = true;
    }
  }

  Future<_ControlPeer> _createControlPeer(
    String connectionId,
    String peerCidNumber,
  ) async {
    final existing = _controlPeers[connectionId];
    if (existing != null) {
      if (existing.peerCidNumber != peerCidNumber) {
        throw StateError('Chat 控制连接 CID 与既有连接不一致');
      }
      return existing;
    }
    final connection = await createPeerConnection({'iceServers': _iceServers});
    final peer = _ControlPeer(connectionId, peerCidNumber, connection);
    _controlPeers[connectionId] = peer;
    return peer;
  }

  void _bindControlChannel(_ControlPeer peer, RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !peer.open.isCompleted) {
        peer.open.complete();
        _touchControlPeer(peer);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        unawaited(_closeControlPeer(peer.id));
      }
    };
    channel.onMessage = (message) {
      _touchControlPeer(peer);
      peer.tail = peer.tail
          .then((_) => _handleControlFrame(peer, message))
          .catchError((Object _) {});
    };
  }

  Future<void> _handleControlFrame(
    _ControlPeer peer,
    RTCDataChannelMessage message,
  ) async {
    if (message.isBinary || peer.closing) return;
    final decoded = ChatWebrtcControlFrame.decode(message.text);
    switch (decoded['kind']) {
      case 'envelope':
        final storedEnvelopeIds = await runBindingMutation(
          () => onEnvelope(
            senderCidNumber: peer.peerCidNumber,
            envelopeBytes: ChatWebrtcControlFrame.envelopeBytes(decoded),
          ),
        );
        for (final envelopeId in storedEnvelopeIds) {
          await peer.channel?.send(RTCDataChannelMessage(
            jsonEncode(ChatWebrtcControlFrame.envelopeStored(envelopeId)),
          ));
        }
      case 'envelope_stored':
        final envelopeId = decoded['envelope_id'];
        if (envelopeId is! String || envelopeId.isEmpty) return;
        await runBindingMutation(
          () => onEnvelopeStored(
            senderCidNumber: peer.peerCidNumber,
            envelopeId: envelopeId,
          ),
        );
      case 'key_package_request':
        final requestId = decoded['request_id'];
        if (requestId is! String || requestId.isEmpty) return;
        final keyPackage = await runBindingMutation(createKeyPackage);
        await peer.channel?.send(RTCDataChannelMessage(
          jsonEncode(
            ChatWebrtcControlFrame.keyPackageResponse(requestId, keyPackage),
          ),
        ));
      case 'key_package_response':
        final requestId = decoded['request_id'];
        final completer = _keyPackageRequests[requestId];
        if (completer != null && !completer.isCompleted) {
          completer.complete(ChatWebrtcControlFrame.keyPackage(decoded));
        }
    }
  }

  Future<_PeerTransfer> _createPeer(
      String transferId, String peerCidNumber) async {
    final existing = _peers[transferId];
    if (existing != null) {
      if (existing.peerCidNumber != peerCidNumber) {
        throw StateError('Chat 附件连接 CID 与既有连接不一致');
      }
      return existing;
    }
    final connection = await createPeerConnection({'iceServers': _iceServers});
    final peer = _PeerTransfer(transferId, peerCidNumber, connection);
    _peers[transferId] = peer;
    return peer;
  }

  /// 第一次 offer 会触发无内容推送；接收方启动后，后续 offer 和 ICE 仍只瞬时转发。
  Future<void> _sendOfferUntilOpen(
    _PeerTransfer peer,
    Map<String, dynamic> offer,
  ) async {
    // 附件与控制连接采用同一协商规则：一个 transfer_id 只发送一次 Offer，
    // 接收端未及时上线时由本机可靠队列在下一轮创建新连接，而不是重放旧 Offer。
    await cloud.sendSignal(
      recipientCidNumber: peer.peerCidNumber,
      signal: offer,
    );
    try {
      await peer.open.future.timeout(_timeout);
    } on TimeoutException {
      throw TimeoutException('接收设备未连接，附件仍只保留在发送设备');
    }
  }

  void _touchControlPeer(_ControlPeer peer) {
    if (peer.closing) return;
    peer.idleTimer?.cancel();
    peer.idleTimer = Timer(_controlIdleTimeout, () {
      unawaited(_closeControlPeer(peer.id));
    });
  }

  void _bindChannel(_PeerTransfer peer, RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !peer.open.isCompleted) {
        peer.open.complete();
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        // 通道关闭(含中途断线):收口该 peer——释放打开的 append sink 与原生连接,
        // 但 dispose 只关流保留 partial。否则同会话对同一 attachment_id 的补发会
        // 在同一 .part 上再开一个 sink(两 sink 同 inode → partial 损坏/泄漏)。
        unawaited(_closePeer(peer.id));
      }
    };
    final buffer = ChatAttachmentReceiveBuffer(tempDirectory: tempDirectory);
    peer.buffer = buffer;
    // 逐帧串行处理:磁盘 I/O 是异步的,必须保证 start 建好 sink 后分片才写入、
    // 且分片按序落盘,否则会丢首片或乱序。
    channel.onMessage = (message) {
      peer.tail = peer.tail
          .then((_) => handleIncomingFrame(
                buffer: buffer,
                peerCidNumber: peer.peerCidNumber,
                transferId: peer.id,
                message: message,
                sendAck: () => channel.send(
                  RTCDataChannelMessage(jsonEncode({'kind': 'attachment_ack'})),
                ),
                sendResume: (offset) => channel.send(
                  RTCDataChannelMessage(jsonEncode(
                    ChatWebrtcAttachmentFrame.resume(resumeOffset: offset),
                  )),
                ),
                onPeerAck: () {
                  if (!peer.ack.isCompleted) peer.ack.complete();
                },
                onResumeOffset: (offset) {
                  if (!peer.resumeOffset.isCompleted) {
                    peer.resumeOffset.complete(offset);
                  }
                },
              ))
          .catchError((Object _) {});
    };
  }

  /// 处理一帧接收数据(可单测,不依赖真实 DataChannel):二进制→落盘;start/end→
  /// 门控与回调。拒收 / 截断时**既不回调也不 ack**——篡改的发送方不会收到 ack
  /// 误以为超限媒体被接受。
  Future<void> handleIncomingFrame({
    required ChatAttachmentReceiveBuffer buffer,
    required String peerCidNumber,
    required String transferId,
    required RTCDataChannelMessage message,
    required Future<void> Function() sendAck,
    Future<void> Function(int resumeOffset)? sendResume,
    void Function()? onPeerAck,
    void Function(int resumeOffset)? onResumeOffset,
  }) {
    if (_isNonFileControlFrame(message)) {
      return _handleIncomingFrame(
        buffer: buffer,
        peerCidNumber: peerCidNumber,
        transferId: transferId,
        message: message,
        sendAck: sendAck,
        sendResume: sendResume,
        onPeerAck: onPeerAck,
        onResumeOffset: onResumeOffset,
      );
    }
    return runBindingMutation(
      () => _handleIncomingFrame(
        buffer: buffer,
        peerCidNumber: peerCidNumber,
        transferId: transferId,
        message: message,
        sendAck: sendAck,
        sendResume: sendResume,
        onPeerAck: onPeerAck,
        onResumeOffset: onResumeOffset,
      ),
    );
  }

  static bool _isNonFileControlFrame(RTCDataChannelMessage message) {
    if (message.isBinary) return false;
    try {
      final decoded = jsonDecode(message.text);
      if (decoded is! Map<String, dynamic>) return true;
      final kind = decoded['kind'];
      return kind == 'attachment_ack' || kind == 'attachment_resume';
    } catch (_) {
      return true;
    }
  }

  Future<void> _handleIncomingFrame({
    required ChatAttachmentReceiveBuffer buffer,
    required String peerCidNumber,
    required String transferId,
    required RTCDataChannelMessage message,
    required Future<void> Function() sendAck,
    Future<void> Function(int resumeOffset)? sendResume,
    void Function()? onPeerAck,
    void Function(int resumeOffset)? onResumeOffset,
  }) async {
    if (message.isBinary) {
      await buffer.addChunk(message.binary);
      return;
    }
    final decoded = jsonDecode(message.text);
    if (decoded is! Map<String, dynamic>) return;
    switch (decoded['kind']) {
      case 'attachment_start':
        await buffer.start(decoded, transferId);
        // 拒收(声明超限)则不回续传帧:发送端等待超时后中止,不建 partial。
        if (!buffer.rejected && sendResume != null) {
          await sendResume(buffer.resumeOffset);
        }
      case 'attachment_end':
        final received = await buffer.finish();
        if (received == null) return; // 拒收 / 截断:不回调、不 ack。
        await onAttachment(
          senderCidNumber: peerCidNumber,
          conversationId: received.conversationId,
          attachmentId: received.attachmentId,
          fileName: received.fileName,
          contentType: received.contentType,
          filePath: received.filePath,
          byteSize: received.byteSize,
        );
        await sendAck();
      case 'attachment_ack':
        onPeerAck?.call();
      case 'attachment_resume':
        onResumeOffset?.call((decoded['resume_offset'] as num?)?.toInt() ?? 0);
    }
  }

  Future<void> _closePeer(String transferId) async {
    final peer = _peers.remove(transferId);
    if (peer == null) return;
    // 先关输入源，禁止新 frame 排到 tail；随后锁外等待每个已经登记到 binding
    // mutation runner 的 frame。不能持 CID lease 等待 tail，否则 tail 自己取锁会自锁。
    final channel = peer.channel;
    peer.channel = null;
    if (channel != null) {
      // 原生插件可能在 close 完成后继续投递一个晚到状态；先解绑可避免向已经
      // close 的 StreamController 再追加事件。
      channel.onDataChannelState = null;
      channel.onMessage = null;
      await channel.close();
    }
    // 让已入队的 finish() 按截断/成功语义先收尾,再关流。否则
    // dispose 先置 _sink=null,随后 finish 读到 null 会误走删档、丢掉本要保留的
    // partial 甚至作废一次已收全的投递。
    await peer.tail.catchError((Object _) {});
    await peer.buffer?.dispose();
    peer.connection.onDataChannel = null;
    await peer.connection.close();
  }

  Future<void> _closeControlPeer(String connectionId) async {
    final peer = _controlPeers.remove(connectionId);
    if (peer == null || peer.closing) return;
    peer.closing = true;
    peer.idleTimer?.cancel();
    peer.idleTimer = null;
    if (_outboundControlPeerIds[peer.peerCidNumber] == connectionId) {
      _outboundControlPeerIds.remove(peer.peerCidNumber);
    }
    final channel = peer.channel;
    peer.channel = null;
    if (channel != null) {
      channel.onDataChannelState = null;
      channel.onMessage = null;
      await channel.close();
    }
    await peer.tail.catchError((Object _) {});
    peer.connection.onDataChannel = null;
    await peer.connection.close();
  }

  Future<void> dispose() async {
    for (final id in _peers.keys.toList(growable: false)) {
      await _closePeer(id);
    }
    for (final id in _controlPeers.keys.toList(growable: false)) {
      await _closeControlPeer(id);
    }
    for (final completer in _keyPackageRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Chat 直连运行态已关闭'));
      }
    }
    _keyPackageRequests.clear();
  }

  static String _newControlId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

Map<String, dynamic> _keyPackageToJson(MlsKeyPackage keyPackage) =>
    <String, dynamic>{
      'cid_number': keyPackage.cidNumber,
      'device_id': keyPackage.deviceId,
      'device_public_key_hex': keyPackage.devicePublicKey,
      'key_package_id': keyPackage.keyPackageId,
      'key_package': _base64UrlEncode(keyPackage.keyPackageBytes),
      'cipher_suite': keyPackage.cipherSuite,
      'not_before': keyPackage.notBeforeMillis,
      'not_after': keyPackage.notAfterMillis,
      'last_resort': keyPackage.lastResort,
    };

String _base64UrlEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _base64UrlDecode(String value) {
  final normalized = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(normalized);
}

class _ControlPeer {
  _ControlPeer(this.id, this.peerCidNumber, this.connection);

  final String id;
  final String peerCidNumber;
  final RTCPeerConnection connection;
  final Completer<void> open = Completer<void>();
  RTCDataChannel? channel;
  Future<void> tail = Future<void>.value();
  Map<String, dynamic>? answerSignal;
  Timer? idleTimer;
  bool remoteDescriptionSet = false;
  bool closing = false;
}

class _PeerTransfer {
  _PeerTransfer(this.id, this.peerCidNumber, this.connection);

  final String id;
  final String peerCidNumber;
  final RTCPeerConnection connection;
  final Completer<void> open = Completer<void>();
  final Completer<void> ack = Completer<void>();
  // 发送端等接收端回报的续传偏移,拿到才从该偏移起流。
  final Completer<int> resumeOffset = Completer<int>();
  RTCDataChannel? channel;
  ChatAttachmentReceiveBuffer? buffer;
  Map<String, dynamic>? answerSignal;
  bool remoteDescriptionSet = false;

  /// 逐帧串行处理链。
  Future<void> tail = Future<void>.value();
}
