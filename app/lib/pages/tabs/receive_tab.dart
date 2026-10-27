import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/web_share_page.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/column_list_view.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab();

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  /// Whether the advanced network info is shown
  bool _showAdvanced = false;

  Future<void> _toggleAdvanced() async {
    setState(() => _showAdvanced = !_showAdvanced);
  }

  @override
  Widget build(BuildContext context) {
    final alias = context.watch(settingsProvider.select((s) => s.alias));
    final serverState = context.watch(serverProvider);
    final localIps = context.watch(localIpProvider.select((s) => s.localIps));

    final quickSave = context.watch(settingsProvider.select((s) => s.quickSave));
    final historyCount = context.watch(receiveHistoryProvider).length;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final ip = localIps.firstOrNull;

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: ColumnListView(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InitialFadeTransition(
                          duration: const Duration(milliseconds: 300),
                          delay: const Duration(milliseconds: 200),
                          child: Consumer(
                            builder: (context, ref) {
                              final animations = ref.watch(animationProvider);
                              final activeTab = ref.watch(homePageControllerProvider.select((state) => state.currentTab));
                              return _Pond(
                                child: LocalSendLogo(
                                  withText: false,
                                  size: 180,
                                  animate: serverState != null && animations && activeTab == HomeTab.receive,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(serverState?.alias ?? alias, style: textTheme.headlineMedium),
                        ),
                        const SizedBox(height: 8),
                        InitialFadeTransition(
                          duration: const Duration(milliseconds: 300),
                          delay: const Duration(milliseconds: 500),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _toggleAdvanced,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Text(
                                serverState == null ? t.general.offline : [t.receiveTab.ready, ?ip].join(' · '),
                                style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text(t.general.quickSave, style: textTheme.titleSmall),
                          subtitle: Text(t.receiveTab.quickSaveHint, style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                          value: quickSave,
                          onChanged: (b) async => context.ref.notifier(settingsProvider).setQuickSave(b),
                        ),
                        const Divider(indent: 20, endIndent: 20),
                        _CardRow(
                          icon: Icons.history_rounded,
                          title: t.receiveHistoryPage.title,
                          subtitle: t.receiveTab.historyCount(n: historyCount),
                          onTap: () async => context.push(() => const ReceiveHistoryPage()),
                        ),
                        const Divider(indent: 20, endIndent: 20),
                        _CardRow(
                          icon: Icons.link_rounded,
                          title: t.receiveTab.link,
                          onTap: () async => context.global.dispatchAsync(NavigateAction.push(const WebSharePage())),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _InfoBox(
          serverState: serverState,
          localIps: localIps,
          showAdvanced: _showAdvanced,
        ),
      ],
    );
  }
}

/// The duck sits on a flat pond ring.
class _Pond extends StatelessWidget {
  final Widget child;

  const _Pond({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: 22,
          child: Container(
            width: 260,
            height: 68,
            decoration: ShapeDecoration(
              shape: OvalBorder(side: BorderSide(color: colors.primary.withValues(alpha: 0.3), width: 2)),
              color: colors.primary.withValues(alpha: 0.06),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: child),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _CardRow({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      shape: const RoundedRectangleBorder(),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colors.surfaceContainerHigh,
        child: Icon(icon, size: 20, color: colors.onSurface),
      ),
      title: Text(title, style: textTheme.titleSmall),
      subtitle: subtitle == null ? null : Text(subtitle!, style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.outline),
      onTap: onTap,
    );
  }
}

class _InfoBox extends StatelessWidget {
  final ServerState? serverState;
  final List<String> localIps;
  final bool showAdvanced;

  const _InfoBox({
    required this.serverState,
    required this.localIps,
    required this.showAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      crossFadeState: showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
      firstChild: Container(),
      secondChild: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: IntrinsicColumnWidth(),
                  2: IntrinsicColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.alias),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(right: 30),
                        child: SelectableText(serverState?.alias ?? '-'),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.ip),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (localIps.isEmpty) Text(t.general.unknown),
                          ...localIps.map((ip) => SelectableText(ip)),
                        ],
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.port),
                      const SizedBox(width: 10),
                      SelectableText(serverState?.port.toString() ?? '-'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
