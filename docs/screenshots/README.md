# 文档截图

截图由 `tool/capture_screenshots_test.dart` 使用当前 Flutter 页面渲染生成，采用应用本身的主题和虚构条目。此工具不读取个人密码库、不写入运行时配置、不连接真实 WebDAV。

| 文件 | 页面 |
| --- | --- |
| `vault.png` | 分类与演示条目列表 |
| `unlock.png` | 主密码解锁页面 |
| `settings.png` | 同步、安全、备份及项目反馈设置 |

## 重新生成

在项目根目录执行：

```sh
flutter pub get
flutter test tool/capture_screenshots_test.dart
```

Windows 默认使用系统 `C:\Windows\Fonts\msyh.ttc`，macOS 默认尝试 `/System/Library/Fonts/PingFang.ttc`。其他系统或字体路径请通过 `PASSSTORE_SCREENSHOT_FONT` 指定本地中文字体，例如：

```powershell
$env:PASSSTORE_SCREENSHOT_FONT='C:\Windows\Fonts\msyh.ttc'
flutter test tool/capture_screenshots_test.dart
```

```sh
PASSSTORE_SCREENSHOT_FONT=/path/to/cjk-font.ttf flutter test tool/capture_screenshots_test.dart
```

系统字体不复制到仓库。不同平台字体及 Flutter 版本可能导致细微差异；重新生成后检查文字、布局和图片内容再提交。此工具单独运行，不加入默认功能测试套件，也不代表真实 WebDAV 或原生窗口集成测试。
