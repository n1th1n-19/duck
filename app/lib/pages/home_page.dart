import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  send(Icons.arrow_upward_rounded),
  receive(Icons.arrow_downward_rounded),
  settings(Icons.settings_rounded)
  ;

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        // the drop may contain a mix of files and directories
        final droppedDirectories = event.files.where((file) => Directory(file.path).existsSync()).toList();
        final droppedFiles = event.files.where((file) => !Directory(file.path).existsSync()).toList();

        for (final directory in droppedDirectories) {
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(directory.path));
        }

        if (droppedFiles.isNotEmpty) {
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(
                AddFilesAction(
                  files: droppedFiles,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        vm.changeTab(HomeTab.send);
      },
      child: ResponsiveBuilder(
        builder: (sizingInformation) {
          final settingsOnMobile = sizingInformation.isMobile && vm.currentTab == HomeTab.settings;
          return PopScope(
            canPop: !settingsOnMobile,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                vm.changeTab(vm.previousTab);
              }
            },
            child: Scaffold(
              body: Row(
                children: [
                  if (!sizingInformation.isMobile)
                    NavigationRail(
                      selectedIndex: vm.currentTab.index,
                      onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                      extended: sizingInformation.isDesktop,
                      backgroundColor: Theme.of(context).cardColorWithElevation,
                      leading: sizingInformation.isDesktop
                          ? const Column(
                              children: [
                                SizedBox(height: 20),
                                Text(
                                  'Duck Share',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 20),
                              ],
                            )
                          : null,
                      destinations: HomeTab.values.map((tab) {
                        return NavigationRailDestination(
                          icon: Icon(tab.icon),
                          label: Text(tab.label),
                        );
                      }).toList(),
                    ),
                  Expanded(
                    child: SafeArea(
                      left: sizingInformation.isMobile,
                      child: Column(
                        children: [
                          if (sizingInformation.isMobile) _MobileTopBar(vm: vm),
                          Expanded(
                            child: Stack(
                              children: [
                                PageView(
                                  controller: vm.controller,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: const [
                                    SendTab(),
                                    ReceiveTab(),
                                    SettingsTab(),
                                  ],
                                ),
                                if (_dragAndDropIndicator)
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.file_download, size: 128),
                                        const SizedBox(height: 30),
                                        Text(t.sendTab.placeItems, style: Theme.of(context).textTheme.titleLarge),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: sizingInformation.isMobile && !settingsOnMobile ? _PillNavigationBar(vm: vm) : null,
            ),
          );
        },
      ),
    );
  }
}

/// Mobile header: the page title and the gear to settings; in settings, back returns to the last tab.
class _MobileTopBar extends StatelessWidget {
  final HomePageVm vm;

  const _MobileTopBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    final inSettings = vm.currentTab == HomeTab.settings;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(inSettings ? 8 : 20, 12, 16, 8),
      child: Row(
        children: [
          if (inSettings)
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => vm.changeTab(vm.previousTab),
            ),
          Expanded(
            child: Text(vm.currentTab.label, style: Theme.of(context).textTheme.headlineMedium, overflow: TextOverflow.ellipsis),
          ),
          if (!inSettings)
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: colors.surfaceContainerHigh, foregroundColor: colors.onSurface),
              tooltip: t.settingsTab.title,
              icon: Icon(HomeTab.settings.icon),
              onPressed: () => vm.changeTab(HomeTab.settings),
            ),
        ],
      ),
    );
  }
}

/// Floating full-radius bar with the two main tabs.
class _PillNavigationBar extends StatelessWidget {
  final HomePageVm vm;

  const _PillNavigationBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [HomeTab.send, HomeTab.receive].map((tab) {
                final selected = vm.currentTab == tab;
                final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;
                return Semantics(
                  selected: selected,
                  button: true,
                  child: Material(
                    color: selected ? colors.primary : Colors.transparent,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => vm.changeTab(tab),
                      child: Container(
                        height: 48,
                        constraints: const BoxConstraints(minWidth: 116),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(tab.icon, size: 20, color: foreground),
                            const SizedBox(width: 8),
                            Text(
                              tab.label,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: foreground),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
