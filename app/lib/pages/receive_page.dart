import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/receive_options_page.dart';
import 'package:localsend_app/pages/verify_page.dart';
import 'package:localsend_app/pages/web_share_page.dart';
import 'package:localsend_app/provider/device_trust_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceivePageVm {
  final SessionStatus? status;
  final Device sender;

  /// Show verify button and device model.
  final bool showSenderInfo;
  final List<FileDto> files;
  final String? message;
  final bool isLink;
  final void Function() onAccept;
  final void Function() onDecline;
  final void Function() onClose;

  ReceivePageVm({
    required this.status,
    required this.sender,
    required this.showSenderInfo,
    required this.files,
    required this.message,
    required this.onAccept,
    required this.onDecline,
    required this.onClose,
  }) : isLink = message != null && !message.trim().contains(RegExp(r'\s')) && (Uri.tryParse(message.trim())?.isAbsolute ?? false);
}

class ReceivePage extends StatefulWidget {
  final ViewProvider<ReceivePageVm> vm;

  const ReceivePage(this.vm);

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> with Refena {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch(
      widget.vm,
      listener: (prev, next) {
        if (prev.status != next.status) {
          // ignore: discarded_futures
          TaskbarHelper.visualizeStatus(next.status);
        }
      },
    );

    if (vm.status == null && vm.message == null) {
      return const Scaffold(
        body: SizedBox(),
      );
    }

    final senderFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(vm.sender)));

    return ViewModelBuilder(
      provider: (ref) => widget.vm,
      dispose: (ref) {
        ref.dispose(widget.vm);
        unawaited(TaskbarHelper.clearProgressBar());
      },
      builder: (context, vm) {
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              vm.onDecline();
            }
          },
          canPop: true,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
                  child: Builder(
                    builder: (context) {
                      final height = MediaQuery.of(context).size.height;
                      final smallUi = vm.message != null && height < 600;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: smallUi ? 20 : 30),
                        child: Column(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      if (vm.showSenderInfo && !smallUi)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: CircleAvatar(
                                            radius: 44,
                                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                                            child: Icon(vm.sender.deviceType.icon, size: 40, color: Theme.of(context).colorScheme.onSurface),
                                          ),
                                        ),
                                      Builder(
                                        builder: (context) {
                                          final alias = senderFavoriteEntry?.alias ?? vm.sender.alias;
                                          if (alias.isEmpty) {
                                            return Text('', style: Theme.of(context).textTheme.headlineMedium);
                                          }
                                          return FittedBox(
                                            child: Text(
                                              alias,
                                              style: smallUi ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.headlineMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                          );
                                        },
                                      ),
                                      if (vm.showSenderInfo && vm.sender.deviceModel != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          vm.sender.deviceModel!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                      // Only a certificate-backed identity can be trusted.
                                      if (vm.showSenderInfo && vm.sender.https && senderFavoriteEntry == null && vm.status == SessionStatus.waiting)
                                        _TrustCard(vm: vm),
                                    ],
                                  ),

                                  Column(
                                    children: [
                                      Text(
                                        vm.message != null
                                            ? (vm.isLink ? t.receivePage.subTitleLink : t.receivePage.subTitleMessage)
                                            : t.receivePage.subTitle(n: vm.files.length),
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (vm.showSenderInfo && vm.message == null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              TextButton.icon(
                                                onPressed: !vm.sender.https
                                                    ? null
                                                    : () async => await context.push(
                                                        () => VerifyPage(
                                                          fingerprint: CombinedFingerprint.load(context, vm.sender.fingerprint),
                                                        ),
                                                      ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                                ),
                                                icon: Icon(Icons.verified_user),
                                                label: Text(t.verifyPage.title),
                                              ),
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                                ),
                                                onPressed: () async {
                                                  await context.push(() => ReceiveOptionsPage(vm));
                                                },
                                                icon: const Icon(Icons.settings),
                                                label: Text(t.receiveOptionsPage.title),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (vm.message != null)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 20),
                                              child: SizedBox(
                                                height: 100,
                                                child: Card(
                                                  child: SingleChildScrollView(
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(10),
                                                      child: SelectableText(
                                                        vm.message!,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              alignment: WrapAlignment.center,
                                              spacing: 20,
                                              runSpacing: 10,
                                              children: [
                                                if (vm.showSenderInfo)
                                                  ElevatedButton.icon(
                                                    onPressed: () async => await context.push(
                                                      () => VerifyPage(
                                                        fingerprint: CombinedFingerprint.load(context, vm.sender.fingerprint),
                                                      ),
                                                    ),
                                                    icon: Icon(Icons.verified_user),
                                                    label: Text(t.verifyPage.title),
                                                  ),
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    unawaited(
                                                      Clipboard.setData(ClipboardData(text: vm.message!)),
                                                    );
                                                    if (checkPlatformIsDesktop()) {
                                                      context.showSnackBar(t.general.copiedToClipboard);
                                                    }
                                                    vm.onAccept();
                                                    context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
                                                  },
                                                  icon: Icon(Icons.copy),
                                                  label: Text(t.general.copy),
                                                ),
                                                if (vm.isLink)
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                    onPressed: () {
                                                      // ignore: discarded_futures
                                                      launchUrl(Uri.parse(vm.message!), mode: LaunchMode.externalApplication);
                                                      vm.onAccept();
                                                      context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
                                                    },
                                                    icon: Icon(Icons.open_in_new),
                                                    label: Text(t.general.open),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _Actions(vm),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  final ReceivePageVm vm;

  const _Actions(this.vm);

  @override
  Widget build(BuildContext context) {
    final selectedFiles = context.watch(selectedReceivingFilesProvider);

    if (vm.message != null) {
      return Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            vm.onAccept();
            context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
          },
          icon: const Icon(Icons.close),
          label: Text(t.general.close),
        ),
      );
    }

    if (vm.status == SessionStatus.canceledBySender) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              t.receivePage.canceled,
              style: TextStyle(color: Theme.of(context).colorScheme.warning),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                vm.onClose();
                context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
              },
              icon: const Icon(Icons.check_circle),
              label: Text(t.general.close),
            ),
          ),
        ],
      );
    }

    void decline() {
      vm.onDecline();
      context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
    }

    final onAccept = selectedFiles.isEmpty ? null : vm.onAccept;

    return Column(
      children: [
        Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            final keyboard = HardwareKeyboard.instance;
            if (event is! KeyDownEvent || keyboard.isControlPressed || keyboard.isShiftPressed || keyboard.isAltPressed || keyboard.isMetaPressed) {
              return KeyEventResult.ignored;
            }
            switch (event.logicalKey) {
              case LogicalKeyboardKey.escape:
                decline();
                return KeyEventResult.handled;
              // Only while no button is focused, so that Enter still activates the focused button.
              case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter when node.hasPrimaryFocus:
                onAccept?.call();
                return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: decline,
                  child: Text(t.general.decline),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(t.general.accept),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Asks once whether to trust an unknown sender. Trusted devices are never asked again.
class _TrustCard extends StatelessWidget {
  final ReceivePageVm vm;

  const _TrustCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerHigh,
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(Icons.shield_outlined, size: 20, color: colors.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(t.trust.question(alias: vm.sender.alias), style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(t.trust.explanation, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: colors.error),
                  onPressed: () async {
                    await context.global.dispatchAsync(BlockDeviceAction(vm.sender));
                    vm.onDecline();
                    if (context.mounted) {
                      context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
                    }
                  },
                  child: Text(t.trust.block),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    await context.global.dispatchAsync(TrustDeviceAction(vm.sender));
                    vm.onAccept();
                  },
                  child: Text(t.trust.alwaysAllow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
