import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

class SABnzbdNavigationBar extends StatelessWidget {
  final List<ScrollController> scrollControllers;
  final PageController? pageController;
  final bool updateRoute;

  static const List<IconData> icons = [
    Icons.queue_play_next_rounded,
    Icons.history_rounded,
  ];

  static const List<String> titles = ['Queue', 'History'];

  static const List<String> tabKeys = ['queue', 'history'];

  const SABnzbdNavigationBar({
    super.key,
    required this.pageController,
    required this.scrollControllers,
    this.updateRoute = true,
  });

  @override
  Widget build(BuildContext context) {
    return LunaBottomNavigationBar(
      pageController: pageController,
      scrollControllers: scrollControllers,
      icons: icons,
      titles: titles,
      tabKeys: updateRoute ? tabKeys : null,
    );
  }
}
