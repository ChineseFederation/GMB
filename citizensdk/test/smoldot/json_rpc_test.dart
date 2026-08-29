import 'package:citizen_sdk/src/smoldot/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON-RPC success 保留 id 与结果', () {
    final response = JsonRpcResponse.fromJson(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': 7,
      'result': <String, Object>{'ok': true},
    });
    expect(response.id, '7');
    expect(response.isSuccess, isTrue);
    expect(response.result, <String, Object>{'ok': true});
  });

  test('JSON-RPC error 不得伪装为成功', () {
    final response = JsonRpcResponse.fromJson(<String, dynamic>{
      'id': 'a',
      'error': <String, dynamic>{'code': -32601, 'message': 'missing'},
    });
    expect(response.isError, isTrue);
    expect(response.error?.code, -32601);
  });
}
