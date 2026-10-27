import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';

extension SnackbarExt on BuildContext {
  void showSnackBar(String text) {
    final scaffold = ScaffoldMessenger.of(this);
    scaffold.removeCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }
}

/// The navigator context while the app is on screen. Null while the engine runs
/// without a visible UI (started headless by a tap or the share sheet): the
/// navigator may exist then, but showing a snackbar or page would assert or go unseen.
BuildContext? get visibleUiContext {
  final state = WidgetsBinding.instance.lifecycleState;
  if (state != AppLifecycleState.resumed && state != AppLifecycleState.inactive) {
    return null;
  }
  return Routerino.navigatorKey.currentContext;
}
