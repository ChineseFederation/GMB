import 'dart:convert';

import 'chat_models.dart';

/// 聊天消息载荷(即 OpenMLS 明文内容)的唯一编解码。
///
/// [ChatPayloadCodec] 是全仓消息类型与媒体元数据的单一真源:发送端编码、
/// 接收端与展示端解码都只经此处。载荷只使用显式 `kind` 判别消息类型，
/// 不存在额外类型别名、版本字段或另一套文本格式。
///
/// 本 JSON 只存在于端到端明文里:图片/视频/文件/语音的**字节**走端到端附件通道
/// 直传,本结构只承载文件名、尺寸、时长、blurhash 占位等**控制元数据**;
/// 该 JSON 与媒体字节都只在参与聊天的设备之间传输，Cloudflare 不接收其明文或密文。
class ChatContent {
  const ChatContent._({
    required this.kind,
    this.text,
    this.attachmentId,
    this.fileName,
    this.mime,
    this.byteSize,
    this.width,
    this.height,
    this.durationMs,
    this.blurhash,
    this.packId,
    this.stickerId,
  });

  /// 纯文本消息。
  factory ChatContent.text(String text) =>
      ChatContent._(kind: ChatMessageKind.text, text: text);

  /// 媒体消息(image / video / file / audio)。字节另经附件通道传输,以 [attachmentId]
  /// 关联;本结构只带控制元数据。
  factory ChatContent.media({
    required ChatMessageKind kind,
    required String attachmentId,
    required String fileName,
    required String mime,
    required int byteSize,
    int? width,
    int? height,
    int? durationMs,
    String? blurhash,
  }) {
    assert(
      kind == ChatMessageKind.image ||
          kind == ChatMessageKind.video ||
          kind == ChatMessageKind.file ||
          kind == ChatMessageKind.audio,
      'ChatContent.media 只接受 image/video/file/audio',
    );
    return ChatContent._(
      kind: kind,
      attachmentId: attachmentId,
      fileName: fileName,
      mime: mime,
      byteSize: byteSize,
      width: width,
      height: height,
      durationMs: durationMs,
      blurhash: blurhash,
    );
  }

  /// 贴纸消息:只承载内置贴纸包 id,不传任何字节。
  factory ChatContent.sticker({
    required String packId,
    required String stickerId,
  }) =>
      ChatContent._(
        kind: ChatMessageKind.sticker,
        packId: packId,
        stickerId: stickerId,
      );

  final ChatMessageKind kind;

  /// kind=text。
  final String? text;

  /// kind=image/video/file/audio:关联附件字节流的附件 ID。
  final String? attachmentId;
  final String? fileName;
  final String? mime;
  final int? byteSize;

  /// image/video 像素宽高；video/audio 带 [durationMs]。
  final int? width;
  final int? height;
  final int? durationMs;

  /// image/video 的低清占位串(blurhash),字节到达前先渲染占位。
  final String? blurhash;

  /// kind=sticker:内置贴纸包与贴纸 id。
  final String? packId;
  final String? stickerId;

  /// 是否为带附件字节的媒体(image/video/file/audio)。
  bool get isMedia =>
      kind == ChatMessageKind.image ||
      kind == ChatMessageKind.video ||
      kind == ChatMessageKind.file ||
      kind == ChatMessageKind.audio;

  /// 会话列表 / 通知用的简短摘要。
  String get summary => switch (kind) {
        ChatMessageKind.text => text ?? '',
        ChatMessageKind.image => '[图片]',
        ChatMessageKind.video => '[视频]',
        ChatMessageKind.file =>
          (fileName ?? '').isEmpty ? '[文件]' : '[文件] ${fileName!}',
        ChatMessageKind.audio => '[语音]',
        ChatMessageKind.sticker => '[贴纸]',
      };
}

/// 载荷 JSON 的编解码器。
class ChatPayloadCodec {
  ChatPayloadCodec._();

  static String encode(ChatContent content) {
    final map = <String, Object?>{
      'kind': content.kind.name,
    };
    switch (content.kind) {
      case ChatMessageKind.text:
        map['text'] = content.text ?? '';
      case ChatMessageKind.image:
      case ChatMessageKind.video:
      case ChatMessageKind.file:
      case ChatMessageKind.audio:
        map['attachment_id'] = content.attachmentId;
        map['file_name'] = content.fileName;
        map['mime'] = content.mime;
        map['byte_size'] = content.byteSize;
        if (content.width != null) map['width'] = content.width;
        if (content.height != null) map['height'] = content.height;
        if (content.durationMs != null) map['duration_ms'] = content.durationMs;
        if (content.blurhash != null) map['blurhash'] = content.blurhash;
      case ChatMessageKind.sticker:
        map['pack_id'] = content.packId;
        map['sticker_id'] = content.stickerId;
    }
    final encoded = jsonEncode(map);
    // 发送端同样走一次严格结构校验，禁止构造出本端自己也
    // 不会接受的空附件 ID、负数尺寸或云端中继字段。
    decode(encoded);
    return encoded;
  }

  /// 解码明文载荷。非 JSON、未知 `kind`、缺字段、多字段或类型不符
  /// 全部失败关闭；禁止把异常结构伪装成可展示的文本消息。
  static ChatContent decode(String raw) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('聊天载荷必须是完整 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('聊天载荷必须是 JSON 对象');
    }
    final kind = _kindFromName(decoded['kind']);
    return switch (kind) {
      ChatMessageKind.text => _decodeText(decoded),
      ChatMessageKind.image ||
      ChatMessageKind.video ||
      ChatMessageKind.file ||
      ChatMessageKind.audio =>
        _decodeMedia(decoded, kind),
      ChatMessageKind.sticker => _decodeSticker(decoded),
    };
  }

  static ChatMessageKind _kindFromName(Object? value) {
    if (value is! String) {
      throw const FormatException('聊天载荷 kind 缺失');
    }
    for (final kind in ChatMessageKind.values) {
      if (kind.name == value) return kind;
    }
    throw FormatException('聊天载荷 kind 未知：$value');
  }

  static ChatContent _decodeText(Map<String, dynamic> map) {
    _requireExactFieldSet(map, const <String>{'kind', 'text'});
    final text = map['text'];
    if (text is! String) {
      throw const FormatException('文本消息 text 必须是字符串');
    }
    return ChatContent.text(text);
  }

  static ChatContent _decodeMedia(
    Map<String, dynamic> map,
    ChatMessageKind kind,
  ) {
    const requiredKeys = <String>{
      'kind',
      'attachment_id',
      'file_name',
      'mime',
      'byte_size',
    };
    const optionalKeys = <String>{
      'width',
      'height',
      'duration_ms',
      'blurhash',
    };
    _requireAllowedKeys(map, requiredKeys, optionalKeys);
    final attachmentId = _requiredString(map, 'attachment_id');
    final fileName = _requiredString(map, 'file_name');
    final mime = _requiredString(map, 'mime');
    final byteSize = _requiredNonNegativeInt(map, 'byte_size');
    final width = _optionalNonNegativeInt(map, 'width');
    final height = _optionalNonNegativeInt(map, 'height');
    final durationMs = _optionalNonNegativeInt(map, 'duration_ms');
    final blurhash = _optionalString(map, 'blurhash');
    if (kind == ChatMessageKind.audio) {
      if (!mime.startsWith('audio/')) {
        throw const FormatException('语音消息 mime 必须是 audio 类型');
      }
      if (byteSize <= 0) {
        throw const FormatException('语音消息 byte_size 必须是正整数');
      }
      if (durationMs == null || durationMs <= 0 || durationMs > 60000) {
        throw const FormatException('语音消息 duration_ms 必须在1至60000之间');
      }
      if (width != null || height != null || blurhash != null) {
        throw const FormatException('语音消息不得携带图像元数据');
      }
    }
    return ChatContent.media(
      kind: kind,
      attachmentId: attachmentId,
      fileName: fileName,
      mime: mime,
      byteSize: byteSize,
      width: width,
      height: height,
      durationMs: durationMs,
      blurhash: blurhash,
    );
  }

  static ChatContent _decodeSticker(Map<String, dynamic> map) {
    _requireExactFieldSet(
      map,
      const <String>{'kind', 'pack_id', 'sticker_id'},
    );
    return ChatContent.sticker(
      packId: _requiredString(map, 'pack_id'),
      stickerId: _requiredString(map, 'sticker_id'),
    );
  }

  // 严格要求聊天载荷字段集合完全一致，拒绝缺失字段和未声明字段。
  static void _requireExactFieldSet(
    Map<String, dynamic> map,
    Set<String> expected,
  ) {
    if (map.length != expected.length ||
        !map.keys.toSet().containsAll(expected)) {
      throw const FormatException('聊天载荷字段集不匹配');
    }
  }

  static void _requireAllowedKeys(
    Map<String, dynamic> map,
    Set<String> required,
    Set<String> optional,
  ) {
    final keys = map.keys.toSet();
    if (!keys.containsAll(required) ||
        keys.difference(<String>{...required, ...optional}).isNotEmpty) {
      throw const FormatException('聊天载荷字段集不匹配');
    }
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('聊天载荷 $key 必须是非空字符串');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key)) return null;
    return _requiredString(map, key);
  }

  static int _requiredNonNegativeInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int || value < 0) {
      throw FormatException('聊天载荷 $key 必须是非负整数');
    }
    return value;
  }

  static int? _optionalNonNegativeInt(
    Map<String, dynamic> map,
    String key,
  ) {
    if (!map.containsKey(key)) return null;
    return _requiredNonNegativeInt(map, key);
  }
}
