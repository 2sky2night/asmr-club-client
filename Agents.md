# ASMR Club Client - Agent Context

## 1. 项目概述
**ASMR Club Client** 是一个基于 Flutter 开发的跨平台本地音乐播放器。其核心功能是扫描用户指定的本地目录，识别 Bilibili 视频缓存文件（`entry.json`），提取元数据并关联音频文件（`.m4s` 或 `.mp3`）进行播放。

- **核心理念**：隐私优先（不强制全盘扫描）、简洁原生 UI、支持跨平台。
- **当前状态**：已完成基础扫描、SQLite 持久化存储、音频播放及关于页面动态日志加载；扫描功能已重构为实时流式进度展示。

## 2. 技术栈
- **框架**: Flutter (Dart)
- **状态管理**: `provider` (用于 `PlayerProvider`)
- **数据库**: `sqflite` (本地音乐列表持久化)
- **音频播放**: `just_audio` + `audio_session`
- **文件系统**: `path_provider`, `file_picker`, `permission_handler`
- **原生交互**: `MethodChannel` & `EventChannel` (Android 端用于路径解析、SAF 权限适配及实时进度推送)
- **其他**: `url_launcher`, `flutter_markdown`, `package_info_plus`

## 3. 核心模块与逻辑

### 3.1 媒体扫描 (`lib/services/media_scanner.dart`)
- **架构优化**：将核心递归逻辑迁移至 Android 原生层，通过 `MethodChannel` 批量请求和 `EventChannel` 流式推送实现高性能通信。
- **识别规则**：
  1. 寻找名为 `entry.json` 的文件。
  2. 解析 JSON 获取标题 (`title`) 和作者 (`owner_name`)。
  3. **音频查找优先级**：
     - 优先查找同级目录下的 `audio.m4s`。
     - 若未找到，则查找同级目录下的任意 `.mp3` 文件。
     - 若仍未找到，进入子目录（深度限制为 2）查找 `audio.m4s` 或 `.mp3`。
- **去重机制**：通过规范化文件路径（`_normalizePath`）在内存和数据库层面进行双重去重。
- **隐私保护**：严格校验扫描路径是否以用户选择的 `rootPath` 开头，防止跳出指定目录。
- **性能保障**：使用线程池并行处理元数据读取，并通过 SAF (Storage Access Framework) 绕过 Android 11+ 的权限限制。

### 3.2 音频播放 (`lib/providers/player_provider.dart`)
- 使用 `AudioPlayer` 实例管理播放状态。
- 支持播放、暂停、跳转、切换上一首/下一首。
- 监听播放进度并更新 UI。
- **沉浸式模式**：支持底部迷你播放器与全屏沉浸式播放器切换。
- **时长格式化**：智能显示音频时长，超过 1 小时自动显示 `HH:MM:SS` 格式。

### 3.3 数据存储 (`lib/services/database_service.dart`)
- 使用 SQLite 存储音乐元数据（标题、路径、封面、作者）。
- 提供增删改查接口，确保应用重启后播放列表不丢失。

### 3.4 原生适配 (`android/app/src/main/kotlin/.../MainActivity.kt`)
- **双通道通信**：
  - `MethodChannel`: 负责发起扫描指令并返回最终统计结果。
  - `EventChannel`: 负责在后台线程中实时推送每发现一个音频文件的元数据，驱动 UI 实时更新。
- **SAF 适配**：利用 `DocumentFile` 和 `ContentResolver` 解决真机环境下深层目录访问的 `EACCES` 错误。

### 3.5 沉浸式播放器 (`lib/widgets/immersive_player.dart`)
- **跑马灯标题**：长标题自动滚动显示，支持手动拖拽交互。
- **控制控件**：播放/暂停、上一首/下一首、进度条拖拽。
- **动画过渡**：展开/收起时带有平滑的缩放动画效果。

### 3.6 应用入口 (`lib/main.dart`)
- **退出确认**：使用 `PopScope` 拦截返回键，点击退出时弹出二次确认对话框。
- **安全退出**：使用 `SystemNavigator.pop()` 正确关闭 Android 应用，避免黑屏问题。

### 4.1 版本管理
- **版本号定义**：在 `pubspec.yaml` 中定义 `version: x.y.z+build_number`。
- **Changelog 生成**：使用 `git-cliff` 工具。
  - 流程：`git tag v{x.y.z}` -> 运行 `git-cliff -o CHANGELOG.md`。
  - 配置文件：`cliff.toml`。
- **动态版本显示**：在“关于页面”通过 `package_info_plus` 读取并展示当前版本号。

### 4.2 权限配置
- **AndroidManifest.xml**: 
  - 必须包含 `MANAGE_EXTERNAL_STORAGE` 以支持 Android 11+ 的全局文件访问（调试阶段）。
  - 开启 `requestLegacyExternalStorage="true"` 以兼容 Android 10。

### 4.3 调试技巧
- **真机日志**：使用 `adb -s <device_id> logcat | Select-String "flutter"` 查看实时日志。
- **编码问题**：PowerShell 查看中文日志乱码时，执行 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`。
- **MIUI 安装限制**：真机安装失败（`INSTALL_FAILED_USER_RESTRICTED`）时，需在开发者选项中开启“USB 调试（安全设置）”。

## 5. 常见问题与避坑指南
- **全盘扫描警告**：严禁在未校验 `rootPath` 的情况下进行递归扫描，这会触发隐私合规风险。
- **路径重复**：Android 挂载点可能导致同一文件有不同路径表示（如 `/sdcard` vs `/mnt/sdcard`），务必使用 `_normalizePath` 处理。
- **音频无法播放**：
  - 检查文件路径是否正确（是否误选了 `video.m4s`）。
  - 检查 Android 权限是否已授予“所有文件访问权限”。
  - 确认 `just_audio` 是否支持该编码格式（通常 `.m4s` 需配合正确的 MIME 类型）。

## 6. 目录结构说明
- `lib/pages/`: 页面组件（首页、扫描页、设置页、关于页）。
- `lib/widgets/`: 可复用 UI 组件（沉浸式播放器、音乐列表项）。
- `lib/services/`: 业务逻辑服务（数据库、扫描器、播放器）。
- `lib/models/`: 数据模型（Music 类）。
- `android/`: Android 原生层代码（含路径解析原生实现）。
