# ASMR Club Client

一个基于 Flutter 开发的轻量级本地音乐播放器，专注于提供简洁、清爽的音频播放体验。支持从 Bilibili 缓存视频中提取音频并建立播放列表。

## 产品使用说明书

| 首页（播放列表）                                             | 沉浸式播放器                                                 | 设置界面                                                     | 音频导入                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| <img src="https://raw.githubusercontent.com/2sky2night/asmr-club-client/main/docs/screenshots/Snipaste_2026-04-25_22-49-15.png" alt="首页" style="zoom:33%;" /> | <img src="https://raw.githubusercontent.com/2sky2night/asmr-club-client/main/docs/screenshots/Snipaste_2026-04-22_22-04-57.png" alt="播放器" style="zoom:33%;" /> | <img src="https://raw.githubusercontent.com/2sky2night/asmr-club-client/main/docs/screenshots/Snipaste_2026-04-25_22-49-20.png" alt="设置" style="zoom:33%;" /> | <img src="https://raw.githubusercontent.com/2sky2night/asmr-club-client/main/docs/screenshots/Snipaste_2026-04-22_22-04-42.png" alt="扫描" style="zoom:33%;" /> |

## ✨ 主要功能

- **本地媒体扫描**：支持指定目录递归扫描，智能识别 Bilibili 缓存视频（`entry.json` + `audio.m4s`），深度限制为 2 层以优化性能。
- **隐私安全优先**：采用原生路径解析方案，严格限制扫描范围，杜绝全盘扫描风险；通过 `_normalizePath` 实现路径去重。
- **沉浸式播放**：支持底部迷你播放器与全屏沉浸式播放模式无缝切换，长标题自动跑马灯显示，音频时长智能格式化（HH:MM:SS）。
- **持久化存储**：使用 SQLite 数据库管理播放列表，支持断点续播和列表记忆。
- **多格式支持**：完美支持 `.m4s` 和 `.mp3` 等主流音频格式，优先查找 `audio.m4s`，回退到 `.mp3`。
- **智能搜索**：集成 TypeAheadField 实现智能搜索建议，支持历史记录和音乐标题/作者匹配。
- **图片缓存**：使用 `cached_network_image` 优化封面加载体验，支持错误处理和占位图。
- **缓存管理**：独立的缓存管理页面，支持清理搜索历史和查看存储空间占用。
- **人性化交互**：退出应用二次确认防误触，滚动到顶部快捷按钮。
- **自动化构建**：集成 GitHub Actions，推送代码即可自动打包 APK。

## 🛠️ 技术栈

- **框架**: Flutter (Dart)
- **状态管理**: Provider
- **本地数据库**: sqflite
- **音频播放**: just_audio + audio_session
- **文件处理**: file_picker, permission_handler, path_provider
- **网络图片**: cached_network_image, flutter_cache_manager
- **智能搜索**: flutter_typeahead
- **原生交互**: MethodChannel (用于精准获取 Android 存储路径)
- **其他工具**: url_launcher, flutter_markdown, package_info_plus, text_scroll

## 🚀 快速开始

### 环境要求
- Flutter SDK >= 3.11.5
- Dart SDK >= 3.11.5
- Android Studio / VS Code

### 安装依赖
```bash
flutter pub get
```

### 运行项目
```bash
flutter run
```

### 打包 APK
**Debug 版本（用于测试）：**
```bash
flutter build apk --debug
```

**Release 版本（正式发布）：**
```bash
flutter build apk --release
```

## 📂 项目结构

```
lib/
├── main.dart              # 应用入口（含退出确认逻辑）
├── models/                # 数据模型 (Music)
├── pages/                 # 页面组件
│   ├── home_page.dart     # 首页（播放列表+迷你播放器+搜索功能）
│   ├── scan_page.dart     # 媒体扫描页
│   ├── settings_page.dart # 设置页
│   ├── about_page.dart    # 关于页（动态版本显示）
│   └── cache_management_page.dart # 缓存管理页（搜索历史清理）
├── providers/             # 状态管理 (PlayerProvider)
├── services/              # 业务逻辑服务
│   ├── database_service.dart # SQLite 数据库操作
│   └── media_scanner.dart    # 媒体文件扫描逻辑（原生层优化+路径去重）
└── widgets/               # 通用组件
    └── immersive_player.dart # 沉浸式播放器（跑马灯标题+动画过渡）
```

## 🔒 隐私与安全

本项目高度重视用户隐私：
1. **最小权限原则**：仅访问用户明确选择的文件夹及其子目录。
2. **路径校验**：通过原生层校验真实路径，防止模拟器环境下的路径欺骗导致的越权访问。
3. **本地化处理**：所有元数据解析和播放均在本地完成，不上传任何用户数据。

## 📋 版本管理规范

### 版本号格式
采用语义化版本控制（Semantic Versioning），格式为 **主版本号.次版本号.修订号+构建号**（`Major.Minor.Patch+Build`）。

- **主版本号 (Major)**：不兼容的 API 修改、重大功能重构或界面整体改版时递增。
- **次版本号 (Minor)**：新增向下兼容的功能或日常迭代优化时递增（如搜索功能、缓存管理）。
- **修订号 (Patch)**：仅修复向下兼容的 Bug 或微小调整时递增。
- **构建号 (Build)**：每次打包递增，用于 Android `versionCode` 和 iOS `CFBundleVersion`，用户不可见。

**示例：**
- `0.0.1+1` → `0.0.2+2` → `0.1.0+3` → `0.2.0+4` → `1.0.0+5`

**当前版本：** `0.2.0+4`（v0.2.0）

### 发布流程
1. **创建 Git 标签**：
   ```bash
   git tag v0.0.2
   git push origin v0.0.2
   ```

2. **生成更新日志**：
   ```bash
   git-cliff -o CHANGELOG.md
   ```

3. **更新 pubspec.yaml**：
   修改 `version: 0.0.2+2`（版本号与标签对应，构建号递增）。

4. **推送代码**：
   ```bash
   git add .
   git commit -m "chore: bump version to v0.0.2"
   git push
   ```

## 🤝 贡献

欢迎提交 Issue 或 Pull Request！

## 📄 许可证

本项目遵循 MIT 许可证。

---
*Made with ❤️ by 2sky2night*
