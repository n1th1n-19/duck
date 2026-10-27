# Duck Share

[English](../../README.md) • 中文

Duck Share 可以在局域网内与附近的设备分享文件和消息，无需互联网连接，也无需账号。在 Android 上，**把两部手机背靠背贴在一起**即可发送文件，类似 AirDrop 或 Quick Share——即使两部手机上的 Duck Share 都处于关闭状态。

Duck Share 是 [LocalSend](https://github.com/localsend/localsend) 的分支，使用相同的协议，因此可以与 Windows、macOS、Linux、iOS 和 Android 上的所有 LocalSend 设备互通。

## 碰一碰分享（Android）

需要两部支持 NFC（主机卡模拟）的 Android 手机，并连接同一个 Wi-Fi。

1. 在任意应用中点击 **分享 → Duck Share**，底部会弹出"Hold near another phone"。
2. 将两部手机背靠背贴在一起，两部手机振动后即可分开。底部弹窗会显示发送进度；点击 **Hide** 可在后台继续发送。
3. 文件通过 Wi-Fi 传输；接收方会收到"已接收"通知，点击即可打开文件。

不确定 NFC 在哪里？在 设置 → 碰一碰分享 → *Where is NFC on my phone?* 中可以查看手机背面的感应位置。

**Pixel 手机：** Google 自带的 *Tap to Share*（Quick Share）会占用 NFC，如果碰一碰不稳定，请在 Quick Share 设置中将其关闭。

## 受信任与已屏蔽的设备

未知设备首次发送时，接收界面会询问是否信任该设备。受信任的设备无需确认、可跳过 PIN，分享的文字会直接复制到剪贴板；已屏蔽的设备的请求会被自动拒绝。

## 从源码构建

1. 安装 [Flutter](https://flutter.dev)（推荐使用 [fvm](https://fvm.app)，版本见 [.fvmrc](../../.fvmrc)）和 [Rust](https://www.rust-lang.org/tools/install)
2. `cd app`
3. `fvm flutter pub get`
4. `fvm flutter run`

更多信息（防火墙设置、故障排除、构建命令）请参阅[英文 README](../../README.md)。

## 致谢与许可证

Duck Share 基于 Tien Do Nam 及贡献者开发的 [LocalSend](https://github.com/localsend/localsend)，与原项目一样采用 [Apache License 2.0](../../LICENSE) 许可证。Duck Share 与 LocalSend 项目无关联，也未获其认可。
