import 'package:flutter/material.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:refena_flutter/refena_flutter.dart';

class HomePageVm {
  final PageController controller;
  final HomeTab currentTab;

  /// The tab before the current one; settings returns there on mobile.
  final HomeTab previousTab;
  final void Function(HomeTab) changeTab;

  HomePageVm({
    required this.controller,
    required this.currentTab,
    required this.previousTab,
    required this.changeTab,
  });
}

final homePageControllerProvider = ReduxProvider<HomePageController, HomePageVm>(
  (ref) => HomePageController(),
);

class HomePageController extends ReduxNotifier<HomePageVm> {
  @override
  HomePageVm init() {
    return HomePageVm(
      controller: PageController(),
      currentTab: HomeTab.send,
      previousTab: HomeTab.send,
      changeTab: (tab) => redux.dispatch(ChangeTabAction(tab)),
    );
  }
}

class ChangeTabAction extends ReduxAction<HomePageController, HomePageVm> {
  final HomeTab tab;

  ChangeTabAction(this.tab);

  @override
  HomePageVm reduce() {
    state.controller.jumpToPage(tab.index);
    return HomePageVm(
      controller: state.controller,
      currentTab: tab,
      previousTab: state.currentTab == HomeTab.settings ? state.previousTab : state.currentTab,
      changeTab: state.changeTab,
    );
  }
}
