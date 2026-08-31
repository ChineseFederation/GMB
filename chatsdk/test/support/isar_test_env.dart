import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gmb_chat_sdk/chat_sdk.dart';
import 'package:gmb_chat_sdk/src/storage/isar_core_bootstrap.dart';

final Map<ChatStorageKeyPurpose, Uint8List> _fixedStorageKeys =
    <ChatStorageKeyPurpose, Uint8List>{
      for (final purpose in ChatStorageKeyPurpose.values)
        purpose: Uint8List.fromList(
          List<int>.generate(
            32,
            (index) => (index * 17 + purpose.index * 29 + 1) % 256,
          ),
        ),
    };

/// Gives each test library its own physical ChatSDK database and deterministic
/// storage keys while exercising the real encryption and Isar paths.
void useIsolatedChatIsar() {
  late Directory directory;
  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('chat_sdk_test_');
    IsarCoreBootstrap.debugTestDirectoryOverride = directory.path;
    ChatCrypto.debugFixedKeys = _fixedStorageKeys;
    await IsarCoreBootstrap.ensureTestCoreInitialized();
  });
  setUp(() => ChatIsar.instance.resetForTest());
  tearDown(() => ChatIsar.instance.resetForTest());
  tearDownAll(() async {
    await ChatIsar.instance.resetForTest();
    IsarCoreBootstrap.debugTestDirectoryOverride = null;
    ChatCrypto.debugFixedKeys = null;
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
}
