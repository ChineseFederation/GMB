import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizenapp/8964/widgets/square_media_carousel.dart';

void main() {
  testWidgets('图集保留每张圆点并可左右滑动', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SquareMediaCarousel(
                children: [
                  ColoredBox(
                    key: ValueKey('gallery-page-0'),
                    color: Colors.red,
                  ),
                  ColoredBox(
                    key: ValueKey('gallery-page-1'),
                    color: Colors.green,
                  ),
                  ColoredBox(
                    key: ValueKey('gallery-page-2'),
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('square-media-carousel-dot-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('square-media-carousel-dot-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('square-media-carousel-dot-2')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('第 1 张，共 3 张'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('square-media-carousel-pages')),
      const Offset(-280, 0),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('第 2 张，共 3 张'), findsOneWidget);
  });

  testWidgets('单张图片仍显示一个圆点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SquareMediaCarousel(children: [ColoredBox(color: Colors.black)]),
      ),
    );

    expect(
      find.byKey(const ValueKey('square-media-carousel-dot-0')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('第 1 张，共 1 张'), findsOneWidget);
  });
}
