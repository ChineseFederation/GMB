import 'dart:convert';
import 'dart:io';

import 'package:citizenapp/chat/transport/chat_cloud_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _aliceCidNumber = 'CN220-CTZN2-100000001-2026';
const _bobCidNumber = 'CN220-CTZN2-100000002-2026';
const _carolCidNumber = 'CN220-CTZN2-100000003-2026';
const _accountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  test('群附件只上传一份密文并提交完整收件人 CID 数组', () async {
    final root = await Directory.systemTemp.createTemp('chat-cloud-upload-');
    addTearDown(() => root.delete(recursive: true));
    final cipher = File('${root.path}/cipher.bin');
    await cipher.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
    final calls = <String>[];
    final transport = ChatCloudTransport(
      accountId: _accountId,
      localCidNumber: _aliceCidNumber,
      localDeviceId: 'alice-phone',
      serviceBaseUrl: Uri.parse('https://worker.example/api'),
      sessionToken: 'session-token',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/chat/attachments/prepare') {
          expect(jsonDecode(request.body), <String, dynamic>{
            'attachment_id': 'att-group-1',
            'recipient_cid_numbers': <String>[
              _bobCidNumber,
              _carolCidNumber,
            ],
            'cipher_byte_size': 4,
            'cipher_sha256': List<String>.filled(64, 'a').join(),
          });
          return _json(<String, Object?>{
            'upload_state': 'uploading',
            'parts': <Object?>[
              <String, Object?>{
                'offset': 0,
                'byte_size': 4,
                'upload_url': 'https://r2.example/upload',
                'upload_headers': <String, String>{},
              },
            ],
          });
        }
        if (request.url.host == 'r2.example') {
          expect(request.method, 'PUT');
          expect(request.bodyBytes, <int>[1, 2, 3, 4]);
          return http.Response(
            '',
            200,
            headers: <String, String>{'etag': 'etag-1'},
          );
        }
        expect(request.url.path, '/api/chat/attachments/complete');
        expect(jsonDecode(request.body), <String, dynamic>{
          'attachment_id': 'att-group-1',
          'etags': <String>['etag-1'],
        });
        return _json(<String, Object?>{'ok': true});
      }),
    );

    await transport.uploadEncryptedAttachment(
      attachmentId: 'att-group-1',
      recipientCidNumbers: const <String>[
        _bobCidNumber,
        _carolCidNumber,
      ],
      cipherFile: cipher,
      cipherByteSize: 4,
      cipherSha256: List<String>.filled(64, 'a').join(),
    );

    expect(calls, <String>[
      'POST /api/chat/attachments/prepare',
      'PUT /upload',
      'POST /api/chat/attachments/complete',
    ]);
  });
}

http.Response _json(Object value) => http.Response(
      jsonEncode(value),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
