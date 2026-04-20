# ASMR Club Client

一个基于 Flutter 开发的轻量级本地音乐播放器，专注于提供简洁、清爽的音频播放体验。支持从 Bilibili 缓存视频中提取音频并建立播放列表。

## ✨ 主要功能

- **本地媒体扫描**：支持指定目录递归扫描，智能识别 Bilibili 缓存视频（`entry.json` + `audio.m4s`）。
- **隐私安全优先**：采用原生路径解析方案，严格限制扫描范围，杜绝全盘扫描风险。
- **沉浸式播放**：支持底部迷你播放器与全屏沉浸式播放模式无缝切换。
- **持久化存储**：使用 SQLite 数据库管理播放列表，支持断点续播和列表记忆。
- **多格式支持**：完美支持 `.m4s` 和 `.mp3` 等主流音频格式。
- **自动化构建**：集成 GitHub Actions，推送代码即可自动打包 APK。

## 🛠️ 技术栈

- **框架**: Flutter (Dart)
- **状态管理**: Provider
- **本地数据库**: sqflite
- **音频播放**: just_audio
- **文件处理**: file_picker, permission_handler
- **原生交互**: MethodChannel (用于精准获取 Android 存储路径)

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
├── main.dart              # 应用入口
├── models/                # 数据模型 (Music)
├── pages/                 # 页面组件
│   ├── home_page.dart     # 首页（播放列表+播放器）
│   ├── scan_page.dart     # 媒体扫描页
│   ├── settings_page.dart # 设置页
│   └── about_page.dart    # 关于页
├── providers/             # 状态管理 (PlayerProvider)
├── services/              # 业务逻辑服务
│   ├── database_service.dart # SQLite 数据库操作
│   └── media_scanner.dart    # 媒体文件扫描逻辑
└── widgets/               # 通用组件
    └── immersive_player.dart # 沉浸式播放器组件
```

## 🔒 隐私与安全

本项目高度重视用户隐私：
1. **最小权限原则**：仅访问用户明确选择的文件夹及其子目录。
2. **路径校验**：通过原生层校验真实路径，防止模拟器环境下的路径欺骗导致的越权访问。
3. **本地化处理**：所有元数据解析和播放均在本地完成，不上传任何用户数据。

## 🤝 贡献

欢迎提交 Issue 或 Pull Request！

## 📄 许可证

本项目遵循 MIT 许可证。

---
*Made with ❤️ by 2sky2night*
