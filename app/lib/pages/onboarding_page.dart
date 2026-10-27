import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/tap_share_provider.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/nfc_spot_guide.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// First start on Android: welcome, NFC spot, permissions, name and Quick Settings tile.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage();

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with Refena, WidgetsBindingObserver {
  final _pages = PageController();
  late final _alias = TextEditingController(text: ref.read(settingsProvider).alias);
  int _page = 0;
  bool _notifications = false;
  bool _nfcOn = false;
  bool _tileAdded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    _alias.dispose();
    super.dispose();
  }

  /// Back from the system settings (NFC): show the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermissions());
    }
  }

  Future<void> _refreshPermissions() async {
    final notifications = await Permission.notification.isGranted;
    final nfcOn = await isNfcOnAndroid();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _nfcOn = nfcOn;
      });
    }
  }

  bool get _tapShare => ref.read(tapShareProvider).available;

  List<Widget Function()> get _steps => [
    _welcome,
    if (_tapShare) _spot,
    _permissions,
    _name,
  ];

  void _next() {
    if (_page < _steps.length - 1) {
      unawaited(_pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic));
    } else {
      unawaited(_finish());
    }
  }

  Future<void> _finish() async {
    final alias = _alias.text.trim();
    if (alias.isNotEmpty && alias != ref.read(settingsProvider).alias) {
      await ref.notifier(settingsProvider).setAlias(alias);
      await ref.notifier(serverProvider).restartServerFromSettings();
    }
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _page = page),
                  children: steps.map((step) => Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: step())).toList(),
                ),
              ),
              _Dots(count: steps.length, current: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(switch (_page) {
                      0 => t.onboarding.welcome.start,
                      _ when _page == steps.length - 1 => t.onboarding.name.finish,
                      _ => t.onboarding.next,
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LocalSendLogo(withText: false, animate: context.watch(animationProvider), size: 180),
        const SizedBox(height: 16),
        Text('Duck Share', style: textTheme.displaySmall),
        const SizedBox(height: 12),
        _Lead(t.onboarding.welcome.text),
      ],
    );
  }

  Widget _spot() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Title(t.onboarding.spot.title),
        const SizedBox(height: 12),
        _Lead(t.onboarding.spot.hint),
        const SizedBox(height: 32),
        const NfcSpotGuide(height: 300, withCaption: false),
      ],
    );
  }

  Widget _permissions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(t.onboarding.permissions.title),
        const SizedBox(height: 12),
        _Lead(t.onboarding.permissions.text),
        const SizedBox(height: 32),
        _PermissionTile(
          icon: Icons.notifications_rounded,
          title: t.onboarding.permissions.notifications,
          subtitle: t.onboarding.permissions.notificationsHint,
          granted: _notifications,
          action: t.onboarding.permissions.allow,
          onTap: () async {
            await Permission.notification.request();
            await _refreshPermissions();
          },
        ),
        if (_tapShare) ...[
          const SizedBox(height: 12),
          _PermissionTile(
            icon: Icons.nfc_rounded,
            title: t.onboarding.permissions.nfc,
            subtitle: t.onboarding.permissions.nfcHint,
            granted: _nfcOn,
            action: t.onboarding.permissions.turnOn,
            onTap: openNfcSettingsAndroid,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          t.onboarding.permissions.later,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _name() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(t.onboarding.name.title),
        const SizedBox(height: 12),
        _Lead(t.onboarding.name.text),
        const SizedBox(height: 24),
        TextField(controller: _alias, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (_tapShare) ...[
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.tapShare.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(t.onboarding.name.tileText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _tileAdded
                        ? null
                        : () async {
                            final added = await requestTapShareTileAndroid();
                            if (mounted) {
                              setState(() => _tileAdded = added);
                            }
                          },
                    icon: Icon(_tileAdded ? Icons.check_rounded : Icons.add_rounded),
                    label: Text(_tileAdded ? t.onboarding.name.tileAdded : t.onboarding.name.addTile),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center);
}

class _Lead extends StatelessWidget {
  final String text;

  const _Lead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      textAlign: TextAlign.center,
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final String action;
  final Future<void> Function() onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            if (granted) Icon(Icons.check_circle_rounded, color: colors.primary) else FilledButton.tonal(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == current ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == current ? colors.primary : colors.outlineVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
