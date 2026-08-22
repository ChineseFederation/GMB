import 'package:flutter/material.dart';

import 'package:citizenapp/ui/app_layout.dart';

/// 广场文章编辑与公开阅读共用的媒体轮播。
///
/// 调用方负责提供本地或网络媒体画面；本组件唯一负责横向分页、当前页状态和底部圆点，
/// 保证编辑预览与发布后的图集关系使用同一套交互。
class SquareMediaCarousel extends StatefulWidget {
  const SquareMediaCarousel({
    super.key,
    required this.children,
    this.aspectRatio = 16 / 9,
  });

  final List<Widget> children;
  final double aspectRatio;

  @override
  State<SquareMediaCarousel> createState() => _SquareMediaCarouselState();
}

class _SquareMediaCarouselState extends State<SquareMediaCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(covariant SquareMediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.isEmpty) {
      _currentIndex = 0;
      return;
    }
    if (_currentIndex < widget.children.length) return;
    _currentIndex = widget.children.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpToPage(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: '第 ${_currentIndex + 1} 张，共 ${widget.children.length} 张',
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: const ValueKey('square-media-carousel-pages'),
              controller: _controller,
              itemCount: widget.children.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (_, index) => widget.children[index],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppLayout.scaled(context, 8),
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < widget.children.length; index++)
                      AnimatedContainer(
                        key: ValueKey('square-media-carousel-dot-$index'),
                        duration: const Duration(milliseconds: 160),
                        width: AppLayout.scaled(context, 6),
                        height: AppLayout.scaled(context, 6),
                        margin: EdgeInsets.symmetric(
                          horizontal: AppLayout.scaled(context, 3),
                        ),
                        decoration: BoxDecoration(
                          color: index == _currentIndex
                              ? Colors.white
                              : Colors.white.withAlpha(0x77),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withAlpha(0x44),
                            width: AppLayout.scaled(context, 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
