import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:citizenapp/8964/models/square_models.dart';
import 'package:citizenapp/8964/widgets/square_article_card.dart';
import 'package:citizenapp/8964/widgets/square_media_grid.dart';
import 'package:citizenapp/8964/widgets/square_post_card.dart';

SquareMediaItem _img({int? w, int? h}) => SquareMediaItem(
      mediaKind: SquareMediaKind.image,
      // 空 url → tile 走占位图标，测试不触网。
      url: '',
      width: w,
      height: h,
    );

SquareMediaItem _video({int? w, int? h}) => SquareMediaItem(
      mediaKind: SquareMediaKind.video,
      url: '',
      coverUrl: '',
      width: w,
      height: h,
    );

SquarePost _post({
  SquarePostCategory category = SquarePostCategory.normal,
  SquarePostType postType = SquarePostType.document,
  String? title,
  String text = '正文',
  List<SquareMediaItem> media = const [],
  String? campaignPosition,
  String? identityLevel = 'voting',
}) {
  return SquarePost(
    postId: 'p1',
    author: SquareAuthor(
      accountId:
          '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      displayName: '林正华',
      identityLevel: identityLevel,
    ),
    postCategory: category,
    postType: postType,
    title: title,
    text: text,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    mediaItems: media,
    campaignPosition: campaignPosition,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('SquareMediaItem.isPortrait', () {
    test('高大于宽为竖屏', () {
      expect(_img(w: 1080, h: 1920).isPortrait, isTrue);
    });
    test('宽不小于高为横屏', () {
      expect(_img(w: 1920, h: 1080).isPortrait, isFalse);
      expect(_img(w: 1000, h: 1000).isPortrait, isFalse);
    });
    test('宽高缺失按横屏兜底', () {
      expect(_img().isPortrait, isFalse);
    });
  });

  group('SquareMediaGrid 公文照片唯一布局', () {
    testWidgets('单张横图为 16:9', (tester) async {
      await _pump(
        tester,
        SquareMediaGrid(mediaItems: [_img(w: 1920, h: 1080)]),
      );
      expect(find.byType(SquareMediaTile), findsOneWidget);
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(ar.aspectRatio, closeTo(16 / 9, 0.001));
    });

    testWidgets('单张竖图仍固定为 16:9', (tester) async {
      await _pump(
        tester,
        SquareMediaGrid(mediaItems: [_img(w: 1080, h: 1920)]),
      );
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(ar.aspectRatio, closeTo(16 / 9, 0.001));
    });

    testWidgets('两张照片为两个 16:9 横向长方形且外圆内直', (tester) async {
      await _pump(
        tester,
        SquareMediaGrid(
          mediaItems: [_img(w: 1600, h: 1200), _img(w: 1600, h: 1200)],
        ),
      );
      expect(find.byType(SquareMediaTile), findsNWidgets(2));
      expect(find.textContaining('+'), findsNothing);
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(ar.aspectRatio, closeTo(32 / 9, 0.001));
      final tiles = tester
          .widgetList<SquareMediaTile>(find.byType(SquareMediaTile))
          .toList(growable: false);
      expect(tiles[0].radius.topLeft, const Radius.circular(12));
      expect(tiles[0].radius.bottomLeft, const Radius.circular(12));
      expect(tiles[0].radius.topRight, Radius.zero);
      expect(tiles[0].radius.bottomRight, Radius.zero);
      expect(tiles[1].radius.topLeft, Radius.zero);
      expect(tiles[1].radius.bottomLeft, Radius.zero);
      expect(tiles[1].radius.topRight, const Radius.circular(12));
      expect(tiles[1].radius.bottomRight, const Radius.circular(12));
      final mediaRow = tester.widget<Row>(
        find.descendant(
          of: find.byType(AspectRatio),
          matching: find.byType(Row),
        ),
      );
      expect((mediaRow.children[1] as SizedBox).width, 2);
    });

    testWidgets('四张照片只出前两张、第二张右下显示 +2', (tester) async {
      await _pump(
        tester,
        SquareMediaGrid(
          mediaItems: List.generate(4, (_) => _img(w: 1600, h: 1200)),
        ),
      );
      expect(find.byType(SquareMediaTile), findsNWidgets(2));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('九张照片只出前两张、第二张右下显示 +7', (tester) async {
      await _pump(
        tester,
        SquareMediaGrid(
          mediaItems: List.generate(9, (_) => _img(w: 1080, h: 1920)),
        ),
      );
      expect(find.byType(SquareMediaTile), findsNWidgets(2));
      expect(find.text('+7'), findsOneWidget);
    });

    testWidgets('竖屏视频继续使用 3:4 封面', (tester) async {
      await _pump(
        tester,
        SquareMediaGrid(mediaItems: [_video(w: 1080, h: 1920)]),
      );
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(ar.aspectRatio, closeTo(3 / 4, 0.001));
    });
  });

  group('SquarePostCard 身份与动态流文字', () {
    testWidgets('竞选帖显示竞选药丸和岗位', (tester) async {
      await _pump(
        tester,
        SquarePostCard(
          post: _post(
            category: SquarePostCategory.campaign,
            identityLevel: 'candidate',
            campaignPosition: '市长候选人',
          ),
        ),
      );
      expect(find.text('竞选'), findsOneWidget);
      expect(find.textContaining('市长候选人'), findsOneWidget);
    });

    testWidgets('非竞选帖不显示竞选药丸', (tester) async {
      await _pump(tester, SquarePostCard(post: _post(identityLevel: 'voting')));
      expect(find.text('竞选'), findsNothing);
    });

    testWidgets('公文竖图不再走左图右文并固定为 16:9', (tester) async {
      await _pump(
        tester,
        SquarePostCard(
          post: _post(text: '竖图说明', media: [_img(w: 1080, h: 1920)]),
        ),
      );
      expect(find.byType(SquareMediaTile), findsOneWidget);
      expect(find.text('竖图说明'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(SquareMediaTile),
          matching: find.byType(Row),
        ),
        findsNothing,
      );
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(ar.aspectRatio, closeTo(16 / 9, 0.001));
    });

    testWidgets('公文超过三行才显示展开全文且点击进入详情', (tester) async {
      var opened = false;
      await _pump(
        tester,
        SquarePostCard(
          post: _post(
            text: List<String>.filled(
              12,
              '这是用于验证公文正文真实排版溢出的内容。',
            ).join(),
          ),
          onTap: () => opened = true,
        ),
      );
      expect(find.text('展开全文'), findsOneWidget);
      final body = tester.widget<Text>(find.byKey(const ValueKey('展开全文-text')));
      expect(body.maxLines, 3);
      await tester.tap(find.byKey(const ValueKey('展开全文-action')));
      expect(opened, isTrue);
    });

    testWidgets('公文未超过三行不显示展开全文', (tester) async {
      await _pump(tester, SquarePostCard(post: _post(text: '短公文正文')));
      expect(find.text('展开全文'), findsNothing);
    });

    testWidgets('系统字体放大后仍按真实三行判断公文溢出', (tester) async {
      await _pump(
        tester,
        SquarePostCard(
          post: _post(
            text: List<String>.filled(5, '字体放大后按真实排版判断。').join(),
          ),
        ),
        textScale: 2,
      );
      expect(find.text('展开全文'), findsOneWidget);
    });

    testWidgets('视频封面在配文上方，超过两行显示展开', (tester) async {
      await _pump(
        tester,
        SquarePostCard(
          post: _post(
            postType: SquarePostType.video,
            text: List<String>.filled(
              10,
              '这是用于验证视频配文真实排版溢出的内容。',
            ).join(),
            media: [_video(w: 1920, h: 1080)],
          ),
        ),
      );
      expect(find.text('展开'), findsOneWidget);
      final body = tester.widget<Text>(find.byKey(const ValueKey('展开-text')));
      expect(body.maxLines, 2);
      expect(
        tester.getTopLeft(find.byType(SquareMediaGrid)).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('展开-text'))).dy),
      );
    });

    testWidgets('视频短配文不显示展开', (tester) async {
      await _pump(
        tester,
        SquarePostCard(
          post: _post(
            postType: SquarePostType.video,
            text: '短视频配文',
            media: [_video(w: 1920, h: 1080)],
          ),
        ),
      );
      expect(find.text('展开'), findsNothing);
      expect(find.byType(SquareNetworkVideo), findsNothing);
    });

    testWidgets('视频详情只在点击后初始化单版本 R2 播放器', (tester) async {
      await _pump(
        tester,
        SquarePostCard(
          post: _post(
            postType: SquarePostType.video,
            text: '详情配文',
            media: [_video(w: 1920, h: 1080)],
          ),
          displayMode: SquarePostCardDisplayMode.detail,
        ),
      );
      expect(find.byType(SquareNetworkVideo), findsOneWidget);
      expect(find.byType(VideoPlayer), findsNothing);
    });

    testWidgets('详情模式显示完整正文且不显示展开入口', (tester) async {
      final text = List<String>.filled(
        12,
        '这是详情页必须完整显示的公文正文。',
      ).join();
      await _pump(
        tester,
        SquarePostCard(
          post: _post(text: text),
          displayMode: SquarePostCardDisplayMode.detail,
        ),
      );
      expect(find.text(text), findsOneWidget);
      expect(find.text('展开全文'), findsNothing);
    });
  });

  group('SquareArticleCard', () {
    testWidgets('标题、正文与强制 16:9 首图并存', (tester) async {
      await _pump(
        tester,
        SquareArticleCard(
          post: _post(
            postType: SquarePostType.article,
            title: '论社区自治的三个层次',
            text: '正文摘要',
            // 竖首图也强制横屏 16:9；非空 url 使封面块渲染（加载失败走占位）。
            media: const [
              SquareMediaItem(
                mediaKind: SquareMediaKind.image,
                url: 'https://example.com/cover.jpg',
                width: 1080,
                height: 1920,
              ),
            ],
          ),
        ),
      );
      expect(find.text('论社区自治的三个层次'), findsOneWidget);
      expect(find.text('正文摘要'), findsOneWidget);
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ar.aspectRatio, closeTo(16 / 9, 0.001));
    });

    testWidgets('异常本地副本缺少可用首图时不伪造占位首图', (tester) async {
      await _pump(
        tester,
        SquareArticleCard(
          post: _post(
            postType: SquarePostType.article,
            title: '纯文字文章',
            text: '正文',
          ),
        ),
      );
      expect(find.text('纯文字文章'), findsOneWidget);
    });
  });
}
