# Flutter 开发环境搭建指南

## 一、安装 Flutter SDK

### 1. 下载 Flutter SDK
- 访问：https://docs.flutter.dev/get-started/install/windows
- 下载最新的稳定版 Flutter SDK zip 文件

### 2. 解压到指定目录
```powershell
# 将下载的 zip 文件解压到：
D:\Promgram Files\Code\MobileDevelopment
```

解压后目录结构应为：
```
D:\Promgram Files\Code\MobileDevelopment\flutter\
```

---

## 二、安装 Android Studio 和 SDK

### 1. 安装 Android Studio
- 下载：https://developer.android.com/studio
- 按默认选项安装

### 2. 安装 Android SDK 组件
打开 Android Studio，进入 **Tools → SDK Manager → SDK Tools**，勾选安装：

- ✅ Android SDK Command-line Tools (latest)
- ✅ Android SDK Platform-Tools
- ✅ Android SDK Build-Tools
- ✅ Android SDK Platform（选择最新稳定版，如 Android 16.0）
- ✅ Android Emulator（可选，已有 MuMu 可不装）

### 3. 记住 SDK 路径
默认路径：
```
C:\Users\Administrator\AppData\Local\Android\Sdk
```

---

## 三、配置环境变量

### 1. Flutter PATH
将以下路径添加到系统 PATH：
```
D:\Promgram Files\Code\MobileDevelopment\flutter\bin
```

### 2. Android SDK platform-tools PATH
将以下路径添加到系统 PATH：
```
C:\Users\Administrator\AppData\Local\Android\Sdk\platform-tools
```

### 3. 配置方法
1. 按 **Win + X** → **系统** → **高级系统设置**
2. 点击 **环境变量**
3. 在 **用户变量** 中找到 **Path**，双击编辑
4. 点击 **新建**，粘贴上面的路径
5. 点击 **确定** 保存
6. **重启 PowerShell** 使环境变量生效

---

## 四、配置 Flutter

### 1. 配置 Android SDK 路径
```powershell
flutter config --android-sdk "C:\Users\Administrator\AppData\Local\Android\Sdk"
```

### 2. 接受 Android licenses
```powershell
flutter doctor --android-licenses
```
按提示全部输入 `y` 接受所有许可协议。

### 3. 验证安装
```powershell
flutter doctor -v
```

检查输出，确保以下项显示为绿色勾：
- ✅ Flutter
- ✅ Android toolchain
- ✅ Android Studio
- ✅ Connected device

---

## 五、连接 MuMu 模拟器

### 1. 启动 MuMu 模拟器
确保模拟器已开启，并在设置中开启了 **USB 调试**。

### 2. 连接模拟器
```powershell
adb connect 127.0.0.1:7555
```

### 3. 验证连接
```powershell
adb devices
flutter devices
```

应该能看到模拟器出现在设备列表中。

---

## 六、创建和运行项目

### 1. 创建 Flutter 项目
```powershell
cd D:\Code\project
flutter create --project-name my_app my_app
cd my_app
```

### 2. 运行项目
```powershell
# 在模拟器上运行
flutter run -d 127.0.0.1:7555
```

### 3. 热更新
应用运行后，修改代码保存，在运行 `flutter run` 的终端按 **`r`** 即可热重载。

其他命令：
- **`R`** - 热重启（完全重新加载）
- **`q`** - 退出应用
- **`h`** - 显示所有可用命令

---

## 七、常见问题

### 1. adb 命令找不到
确保已将 `platform-tools` 添加到 PATH，并重启 PowerShell。

### 2. flutter doctor 显示 cmdline-tools 未安装
打开 Android Studio → Tools → SDK Manager → SDK Tools，勾选安装 **Android SDK Command-line Tools (latest)**。

### 3. 模拟器连接失败
- 确保 MuMu 已启动
- 确保 USB 调试已开启
- 尝试断开重连：`adb disconnect` 然后 `adb connect 127.0.0.1:7555`

### 4. 热重载不生效
某些更改（如 main() 函数、全局变量初始化）需要热重启（按 `R`）或重新运行。

---

## 八、快速参考

### 关键路径
```
Flutter SDK：D:\Promgram Files\Code\MobileDevelopment\flutter
Android SDK：C:\Users\Administrator\AppData\Local\Android\Sdk
```

### 常用命令
```powershell
# 创建项目
flutter create project_name

# 运行项目
flutter run

# 热重载（在运行的终端按 r）

# 查看连接的设备
flutter devices

# 检查环境
flutter doctor

# 构建 APK
flutter build apk --release

# 安装 APK 到设备
adb install app-release.apk
```
