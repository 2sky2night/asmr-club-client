# ASMR Club Client 开发计划

## 1. 项目初始化与依赖配置
- [ ] 检查并更新 `pubspec.yaml`，添加必要依赖：
  - `sqflite`: SQLite 数据库支持
  - `path_provider`: 获取本地存储路径
  - `permission_handler`: 处理文件读取权限
  - `just_audio`: 音频播放（支持 m4s/mp3）
  - `audio_session`: 音频会话管理
  - `provider`: 状态管理

## 2. 数据库层实现
- [ ] 创建 `lib/models/music.dart`：定义 `Music` 数据模型
- [ ] 创建 `lib/services/database_service.dart`：实现 SQLite 数据库初始化、增删改查逻辑

## 3. 核心功能：媒体扫描
- [ ] 创建 `lib/services/media_scanner.dart`：
  - 实现目录选择逻辑（使用 `file_picker` 或原生集成）
  - 实现 Bilibili 缓存递归扫描逻辑（查找 `entry.json` 和 `audio.m4s`）
  - 解析 JSON 元数据并存入数据库
  - 处理去重逻辑

## 4. 页面实现
### 4.1 首页 (Home Page)
- [ ] 创建 `lib/pages/home_page.dart`：
  - 布局：顶部为播放列表，底部为迷你播放器
  - 播放列表组件：展示封面和名称，支持单击/长按交互
  - 空状态提示

### 4.2 沉浸式播放器 (Immersive Player)
- [ ] 创建 `lib/widgets/immersive_player.dart`：
  - 全屏展示，带动画过渡
  - 包含：封面图、进度条、播放控制（上一首/下一首/暂停）、播放模式切换

### 4.3 设置页面 (Settings Page)
- [ ] 创建 `lib/pages/settings_page.dart`：
  - 入口：媒体扫描、关于

### 4.4 媒体扫描页面 (Scan Page)
- [ ] 创建 `lib/pages/scan_page.dart`：
  - 目录选择器
  - 音乐类型选择（目前仅启用 Bilibili）
  - 扫描进度 Loading 界面
  - 结果反馈弹窗

### 4.5 关于页面 (About Page)
- [ ] 创建 `lib/pages/about_page.dart`：展示版本信息和仓库地址

## 5. 状态管理与逻辑整合
- [ ] 创建 `lib/providers/player_provider.dart`：
  - 管理播放列表、当前播放索引、播放状态、播放模式
  - 集成 `just_audio` 实例
- [ ] 在 `main.dart` 中配置路由和 Provider

## 6. 平台特定配置
- [ ] Android: 配置 `AndroidManifest.xml` 添加存储权限
- [ ] iOS: 配置 `Info.plist` 添加文件访问权限描述

## 7. 测试与优化
- [ ] 验证 Bilibili 缓存扫描功能
- [ ] 验证 m4s 格式音频播放
- [ ] 检查 UI 在不同尺寸手机上的适配情况