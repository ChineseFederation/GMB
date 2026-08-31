import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmb_chat_sdk/chat_sdk.dart';

void main() {
  test('conversation timestamps use local calendar buckets', () {
    final now = DateTime(2026, 8, 30, 18);
    expect(
      chatConversationTime(DateTime(2026, 8, 30, 9, 5), now: now),
      '09:05',
    );
    expect(chatConversationTime(DateTime(2026, 8, 29, 9), now: now), '昨天');
  });

  test('empty state is hidden during loading and errors', () {
    expect(shouldShowChatEmptyState(loading: false, error: null), isTrue);
    expect(shouldShowChatEmptyState(loading: true, error: null), isFalse);
    expect(
      shouldShowChatEmptyState(loading: false, error: 'integrity error'),
      isFalse,
    );
  });

  testWidgets('conversation overview renders cards and unread badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatConversationOverview(
            header: const SizedBox(height: 20),
            onRefresh: () async {},
            onSearch: () {},
            items: [
              ChatConversationListItem(
                id: 'direct-a-b',
                title: 'Alice',
                subtitle: 'Hello',
                updatedAt: DateTime(2026, 8, 30, 9),
                unreadCount: 2,
                leading: const CircleAvatar(child: Text('A')),
                onTap: () {},
                onDelete: () async {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-conversation-direct-a-b')),
      findsOneWidget,
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('search view renders injected sections', (tester) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatSearchView(
          controller: controller,
          query: 'hello',
          onQueryChanged: (_) {},
          onClear: () {},
          sections: [
            ChatSearchSection(
              title: '聊天记录',
              items: [
                ChatSearchItem(
                  key: const ValueKey('result-1'),
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: 'hello',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('聊天记录'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-1')), findsOneWidget);
  });

  testWidgets('group creation reports generic user selection', (tester) async {
    final controller = TextEditingController(text: 'Group');
    addTearDown(controller.dispose);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatGroupCreateView(
          nameController: controller,
          users: const [
            ChatSelectableUser(userId: 'alice', displayName: 'Alice'),
          ],
          selectedUserIds: const <String>{},
          onSelectionChanged: (userId, value) {
            if (value) selected = userId;
          },
          canCreate: false,
          onCreate: () {},
        ),
      ),
    );

    await tester.tap(find.byType(CheckboxListTile));
    expect(selected, 'alice');
  });
}
