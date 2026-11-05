# 测试说明

更新日期：2026-11-05。

## 环境与命令

安装满足 `pubspec.yaml` 约束的 Flutter SDK，在项目根目录执行：

```sh
flutter pub get
flutter analyze
flutter test
```

按层运行：

```sh
flutter test test/core
flutter test test/data
flutter test test/features test/widget_test.dart
flutter test test/windows_runner_config_test.dart
```

按名称定位场景：

```sh
flutter test test/data/vault_sync_coordinator_test.dart --plain-name "passes the downloaded etag when uploading merged vault"
```

可选覆盖率采集：

```sh
flutter test --coverage
```

输出为 `coverage/lcov.info`。当前没有覆盖率门槛，也未声称达到某个覆盖率百分比。

## 已有自动化覆盖

| 范围 | 测试 | 内容 |
| --- | --- | --- |
| 加密 | `test/core/vault_crypto_test.dart` | 正确主密码往返、错误主密码、当前封装与 KDF 参数 |
| 模型与业务 | `vault_service_test.dart`、`vault_webdav_credentials_test.dart` | 默认分类、分类删除、回收站、密码库内凭据 |
| 合并 | `test/core/vault_merge_test.dart` | 双端修改、字段变化、分类删除、永久删除及恢复 |
| 密码生成 | `test/core/strong_password_generator_test.dart` | 字符组与默认规则 |
| 设置与基线 | `test/data/*_store_test.dart` | 默认值、读写、加密基线、设置文件不保存应用密码 |
| 加密备份 | `vault_backup_service_test.dart` | 导出和读取加密封装 |
| 同步 | `vault_sync_coordinator_test.dart` | 首次上传、合并、主密码变化、ETag 传递与两条上传路径的异步失败状态 |
| WebDAV 协议 | `webdav_sync_service_test.dart` | 地址规范化、401、目录创建、下载与条件上传 |
| 界面 | `test/widget_test.dart`、`test/features/sync_ui_test.dart` | 创建/解锁、分类、弹窗、复制清除、自动锁定、密码生成、设置与同步状态 |
| Windows 配置 | `test/windows_runner_config_test.dart` | 程序命名及窗口 DPI 居中配置 |

WebDAV 使用 mock；自动化通过不等同于真实网络或双平台原生验证。配置文件测试检查源码配置，也不替代 Windows 原生构建。

当前 macOS 尚未接通备份文件选择与恢复，不能将 Windows 的恢复验证当作 macOS 已通过。导入流程目前使用已解锁库的主密码，不支持单独输入备份密码。

## 手工回归清单

使用独立系统用户或演示数据目录，禁止使用个人主密码和正式 WebDAV 账号。

### 本地与备份

- [ ] 创建、关闭、重启解锁；错误主密码显示错误且保留原文件。
- [ ] 新增、编辑、搜索条目；新增/重命名/删除自定义分类。
- [ ] 删除到回收站、恢复、永久删除并重启确认。
- [ ] 生成与复制密码；等待清除；新复制的其他内容不被误清除。
- [ ] 自动锁定、手动锁定后可解锁，数据完整。
- [ ] 在独立环境恢复加密备份，验证错误主密码和损坏备份。
- [ ] 更换主密码；新密码可解锁，旧密码不可解锁当前库，旧备份仍需旧密码。

### 同步

- [ ] 首次上传与另一台设备首次同步。
- [ ] 双端分别新增、同时编辑同条目、删除后恢复。
- [ ] 断网修改再联网；错误凭据、权限不足、服务器异常。
- [ ] 下载和上传之间远端变化，验证条件请求和重新同步。
- [ ] 单端更换主密码后另一端按提示处理。
- [ ] 同步中锁定、连续同步、修改后立即退出，检查状态与文件。

### 平台与发布

- [ ] Windows 原生 Release 构建及整目录运行。
- [ ] macOS 原生 Release 构建及 `.app` 运行。
- [ ] 显示缩放、小窗口、键盘导航、睡眠与恢复。
- [ ] 分发内容、日志和截图不含真实账号、密钥或密码库。

## 本轮验证记录

仅记录实际执行结果；未执行项目明确标记。

环境：Windows，Flutter 3.47.9，Dart 3.13.7。截图使用系统中文字体，只含虚构演示数据。

| 项目 | 状态 |
| --- | --- |
| 静态分析 | 通过，`flutter analyze --no-pub`，无问题 |
| 全部自动化测试 | 通过，`flutter test --no-pub`，92 项 |
| 文档截图生成 | 通过，单独运行截图工具并目视检查 3 张 PNG |
| Windows 原生 Release 构建 | 通过，`flutter build windows --release --no-pub`，生成 `build/windows/x64/runner/Release/PassStore.exe`；未执行正式安装验证 |
| macOS 原生构建与双设备真实同步 | 未执行，需对应平台和独立测试环境 |
