import 'dart:convert';

import 'package:citizenapp/chat/group/group_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rename 编解码保真', () {
    final encoded = GroupControlCodec.encode(GroupControl.rename('我的群'));
    expect(
      jsonDecode(encoded),
      <String, dynamic>{'op': 'rename', 'name': '我的群'},
    );
    final decoded = GroupControlCodec.tryDecode(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.op, GroupControlOp.rename);
    expect(decoded.groupName, '我的群');
  });

  test('leave_request 编解码', () {
    final decoded = GroupControlCodec.tryDecode(
      GroupControlCodec.encode(const GroupControl.leaveRequest()),
    );
    expect(decoded, isNotNull);
    expect(decoded!.op, GroupControlOp.leaveRequest);
    expect(decoded.groupName, isNull);
  });

  test('用户载荷不是控制，坏数据和未知 op 失败关闭', () {
    expect(
      GroupControlCodec.tryDecode('{"kind":"text","text":"hi"}'),
      isNull,
    );
    for (final raw in const <String>[
      '随便一句话',
      '{"op":"unknown"}',
      '{"op":"leave_request","extra":true}',
      '{"op":"rename","name":""}',
    ]) {
      expect(
        () => GroupControlCodec.tryDecode(raw),
        throwsA(isA<FormatException>()),
        reason: raw,
      );
    }
  });
}
