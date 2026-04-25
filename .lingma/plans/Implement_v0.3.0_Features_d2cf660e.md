# Implement v0.3.0 Features

## 1. 集成系统媒体控制 (Audio Service)
- **添加依赖**：在 `pubspec.yaml` 中添加 `audio_service: ^0.18.12`。
- **配置 AndroidManifest**：在 `android/app/src/main/AndroidManifest.xml` 中添加 `AudioServiceActivity` 和相关服务声明，确保通知栏能正常显示。
- **重构播放器逻辑**：修改 [lib/providers/player_provider.dart](file:///d:/Code/project/asmr-club-client/lib/providers/player_provider.dart)，集成 `AudioHandler`。将播放、暂停、切歌等操作映射到系统通知栏的回调中，并同步更新标题、作者等元数据。

## 2. 实现深色模式适配
- **创建主题管理器**：新建 [lib/providers/theme_provider.dart](file:///d:/Code/project/asmr-club-client/lib/providers/theme_provider.dart)，使用 `ChangeNotifier` 管理 `ThemeMode`（浅色/深色），并利用 `shared_preferences` 实现持久化存储。
- **更新应用入口**：修改 [lib/main.dart](file:///d:/Code/project/asmr-club-client/lib/main.dart)，增加 `darkTheme` 配置，并通过 `MultiProvider` 同时管理 `PlayerProvider` 和 `ThemeProvider`。
- **UI 语义化优化**：检查 [lib/pages/home_page.dart](file:///d:/Code/project/asmr-club-client/lib/pages/home_page.dart) 和其他页面，将硬编码的颜色（如 `Colors.grey[300]`）替换为 `Theme.of(context).colorScheme` 中的语义化颜色，确保在深色模式下文字清晰可见。
- **设置页开关**：在 [lib/pages/settings_page.dart](file:///d:/Code/project/asmr-club-client/lib/pages/settings_page.dart) 中增加“深色模式”开关选项，联动 `ThemeProvider` 进行实时切换。

## 3. 验证与测试
- 运行应用，验证通知栏是否能随音乐播放正确显示并控制切歌。
- 在设置页切换深色模式，确认 UI 颜色自动适配且重启后保持选择的状态。