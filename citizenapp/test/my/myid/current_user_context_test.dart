import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:citizenapp/my/myid/current_user_context.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/wallet/core/default_account_service.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';

const _hotAccountId =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _coldAccountId =
    '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const _hot = DefaultAccount(
  accountId: _hotAccountId,
  ss58Address: 'hot-ss58',
  accountName: '热账户',
  signMode: SignMode.hot,
  walletIndex: 1,
);
const _cold = DefaultAccount(
  accountId: _coldAccountId,
  ss58Address: 'cold-ss58',
  accountName: '冷账户',
  signMode: SignMode.cold,
  walletIndex: 2,
);

AccountDataBinding _binding(String accountId, String cidNumber) =>
    AccountDataBinding(
      genesisHash: '0x${'11' * 32}',
      cidNumber: cidNumber,
      bindingRevision: 1,
      accountId: accountId,
    );

void main() {
  tearDown(() {
    CurrentUserContext.resetDebugInstance();
  });

  test('只读取第一名默认账户的精确绑定，禁止扫描其它有 CID 的账户', () async {
    final requested = <String>[];
    final context = CurrentUserContext(
      defaultAccountReader: const _DefaultReader(_hot),
      bindingReader: (accountId) async {
        requested.add(accountId);
        return accountId == _coldAccountId
            ? _binding(_coldAccountId, 'CID-COLD')
            : null;
      },
    );

    final current = await context.resolve();

    expect(current!.accountId, _hotAccountId);
    expect(current.isRegistered, isFalse);
    expect(requested, [_hotAccountId]);
  });

  test('冷钱包可以成为当前默认用户', () async {
    final context = CurrentUserContext(
      defaultAccountReader: const _DefaultReader(_cold),
      bindingReader: (_) async => _binding(_coldAccountId, 'CID-COLD'),
    );

    final current = await context.resolve();

    expect(current!.account.isColdAccount, isTrue);
    expect(current.cidNumber, 'CID-COLD');
  });

  test('同一钱包 revision 并发读取合并且后续命中缓存', () async {
    var calls = 0;
    final completer = Completer<AccountDataBinding?>();
    final context = CurrentUserContext(
      defaultAccountReader: const _DefaultReader(_hot),
      bindingReader: (_) {
        calls++;
        return completer.future;
      },
    );

    final reads = [context.resolve(), context.resolve(), context.resolve()];
    completer.complete(_binding(_hotAccountId, 'CID-HOT'));
    final results = await Future.wait(reads);
    await context.resolve();

    expect(results.map((item) => item!.cidNumber), everyElement('CID-HOT'));
    expect(calls, 1);
  });

  test('walletsRevision 变化后精确重读当前默认账户', () async {
    var calls = 0;
    final context = CurrentUserContext(
      defaultAccountReader: const _DefaultReader(_hot),
      bindingReader: (_) async {
        calls++;
        return _binding(_hotAccountId, 'CID-HOT');
      },
    );
    await context.resolve();
    WalletManager.walletsRevision.value++;
    await context.resolve();
    expect(calls, 2);
  });

  test('显式失效不会删除绑定，只触发下一次精确重读', () async {
    var calls = 0;
    final binding = _binding(_hotAccountId, 'CID-HOT');
    final context = CurrentUserContext(
      defaultAccountReader: const _DefaultReader(_hot),
      bindingReader: (_) async {
        calls++;
        return binding;
      },
    );
    await context.resolve();
    context.invalidate();
    expect((await context.resolve())!.binding, same(binding));
    expect(calls, 2);
  });

  test('没有任何默认账户时返回 null', () async {
    final context = CurrentUserContext(
      defaultAccountReader: const _DefaultReader(null),
      bindingReader: (_) async => throw StateError('不应读取绑定'),
    );
    expect(await context.resolve(), isNull);
  });
}

class _DefaultReader implements DefaultAccountReader {
  const _DefaultReader(this.account);

  final DefaultAccount? account;

  @override
  Future<DefaultAccount?> getDefaultAccount() async => account;
}
