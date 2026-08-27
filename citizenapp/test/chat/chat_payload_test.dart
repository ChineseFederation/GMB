import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/chat/chat_models.dart';
import 'package:citizenapp/chat/chat_payload.dart';

void main() {
  test('text content round-trips through the codec', () {
    final encoded = ChatPayloadCodec.encode(ChatContent.text('你好'));
    final wire = jsonDecode(encoded) as Map<String, dynamic>;
    expect(wire, <String, dynamic>{'kind': 'text', 'text': '你好'});
    final decoded = ChatPayloadCodec.decode(encoded);
    expect(decoded.kind, ChatMessageKind.text);
    expect(decoded.text, '你好');
    expect(decoded.summary, '你好');
  });

  test('image/video/file media round-trip with control metadata', () {
    for (final kind in const [
      ChatMessageKind.image,
      ChatMessageKind.video,
      ChatMessageKind.file,
    ]) {
      final encoded = ChatPayloadCodec.encode(
        ChatContent.media(
          kind: kind,
          attachmentId: 'att-1',
          fileName: 'IMG.jpg',
          mime: 'image/jpeg',
          byteSize: 2048,
          width: 1080,
          height: 1920,
          durationMs: kind == ChatMessageKind.video ? 4200 : null,
          blurhash: 'L6Pj0',
          cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          cipherByteSize: 2084,
          cipherSha256: '0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );
      final decoded = ChatPayloadCodec.decode(encoded);
      expect(decoded.kind, kind);
      expect(decoded.isMedia, isTrue);
      expect(decoded.attachmentId, 'att-1');
      expect(decoded.fileName, 'IMG.jpg');
      expect(decoded.mime, 'image/jpeg');
      expect(decoded.byteSize, 2048);
      expect(decoded.width, 1080);
      expect(decoded.height, 1920);
      expect(decoded.blurhash, 'L6Pj0');
      expect(decoded.durationMs, kind == ChatMessageKind.video ? 4200 : null);
      expect(decoded.cipherByteSize, 2084);
    }
  });

  test('audio round-trips with the only allowed voice metadata', () {
    final encoded = ChatPayloadCodec.encode(ChatContent.media(
      kind: ChatMessageKind.audio,
      attachmentId: 'voice-1',
      fileName: 'voice.m4a',
      mime: 'audio/mp4',
      byteSize: 4096,
      durationMs: 12500,
      cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      cipherByteSize: 4132,
      cipherSha256: '1111111111111111111111111111111111111111111111111111111111111111',
    ));
    final decoded = ChatPayloadCodec.decode(encoded);
    expect(decoded.kind, ChatMessageKind.audio);
    expect(decoded.durationMs, 12500);
    expect(decoded.summary, '[语音]');
    expect(decoded.isMedia, isTrue);
  });

  test('audio duration, mime and image metadata fail closed', () {
    for (final raw in const [
      '{"kind":"audio","attachment_id":"a","file_name":"v.m4a",'
          '"mime":"audio/mp4","byte_size":1}',
      '{"kind":"audio","attachment_id":"a","file_name":"v.m4a",'
          '"mime":"audio/mp4","byte_size":1,"duration_ms":60001}',
      '{"kind":"audio","attachment_id":"a","file_name":"v.m4a",'
          '"mime":"video/mp4","byte_size":1,"duration_ms":1000}',
      '{"kind":"audio","attachment_id":"a","file_name":"v.m4a",'
          '"mime":"audio/mp4","byte_size":1,"duration_ms":1000,"width":1}',
    ]) {
      expect(() => ChatPayloadCodec.decode(raw), throwsFormatException);
    }
  });

  test('sticker carries only ids, no bytes/metadata', () {
    final encoded = ChatPayloadCodec.encode(
      ChatContent.sticker(packId: 'fluent3d', stickerId: 'grinning_face'),
    );
    final decoded = ChatPayloadCodec.decode(encoded);
    expect(decoded.kind, ChatMessageKind.sticker);
    expect(decoded.packId, 'fluent3d');
    expect(decoded.stickerId, 'grinning_face');
    expect(decoded.summary, '[贴纸]');
    expect(decoded.isMedia, isFalse);
  });

  test('looks-like-JSON text remains text inside the single target payload',
      () {
    const jsonyText = '{"type":"unknown_chat_attachment","file_name":"x"}';
    final decoded = ChatPayloadCodec.decode(
      ChatPayloadCodec.encode(ChatContent.text(jsonyText)),
    );
    expect(decoded.kind, ChatMessageKind.text);
    expect(decoded.text, jsonyText);
  });

  test('garbage, unknown kind, missing and extra fields fail closed', () {
    for (final raw in const <String>[
      '',
      'not json {{{',
      '{"kind":"unknown","text":"x"}',
      '{"kind":"text"}',
      '{"kind":"text","text":"x","extra":1}',
      '{"kind":"image","attachment_id":"a","file_name":"p.png",'
          '"mime":"image/png","byte_size":1,"unexpected":"x"}',
    ]) {
      expect(
        () => ChatPayloadCodec.decode(raw),
        throwsA(isA<FormatException>()),
        reason: raw,
      );
    }
  });

  test('media summaries are typed placeholders', () {
    String summaryOf(ChatContent c) =>
        ChatPayloadCodec.decode(ChatPayloadCodec.encode(c)).summary;
    expect(
      summaryOf(ChatContent.media(
        kind: ChatMessageKind.image,
        attachmentId: 'a',
        fileName: 'p.png',
        mime: 'image/png',
        byteSize: 1,
        cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        cipherByteSize: 21,
        cipherSha256: '2222222222222222222222222222222222222222222222222222222222222222',
      )),
      '[图片]',
    );
    expect(
      summaryOf(ChatContent.media(
        kind: ChatMessageKind.video,
        attachmentId: 'a',
        fileName: 'v.mp4',
        mime: 'video/mp4',
        byteSize: 1,
        cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        cipherByteSize: 21,
        cipherSha256: '3333333333333333333333333333333333333333333333333333333333333333',
      )),
      '[视频]',
    );
    expect(
      summaryOf(ChatContent.media(
        kind: ChatMessageKind.file,
        attachmentId: 'a',
        fileName: 'doc.pdf',
        mime: 'application/pdf',
        byteSize: 1,
        cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        cipherByteSize: 21,
        cipherSha256: '4444444444444444444444444444444444444444444444444444444444444444',
      )),
      '[文件] doc.pdf',
    );
    expect(
      summaryOf(ChatContent.media(
        kind: ChatMessageKind.audio,
        attachmentId: 'a',
        fileName: 'voice.m4a',
        mime: 'audio/mp4',
        byteSize: 1,
        durationMs: 1000,
        cipherKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        cipherByteSize: 21,
        cipherSha256: '5555555555555555555555555555555555555555555555555555555555555555',
      )),
      '[语音]',
    );
  });
}
