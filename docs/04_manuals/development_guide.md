# AI 漫导 (DirectorAI) 全平台开发指南

## 1. 基础环境配置 (所有平台)

无论开发哪个平台，以下基础环境均需配置。

### 1.1 Flutter SDK
1.  下载 [Flutter SDK (3.0+)](https://flutter.dev/docs/get-started/install)。
2.  解压并配置环境变量 `PATH` 指向 `flutter/bin`。
3.  验证安装: `flutter doctor`。

### 1.2 IDE与插件
*   **VS Code** (推荐): 安装 `Flutter` 和 `Dart` 插件。
*   或 **Android Studio**: 安装 `Flutter` 插件。

### 1.3 获取代码
```bash
git clone https://github.com/freestylefly/director_ai.git
cd director_ai
flutter pub get
```

### 1.4 API Key 配置
请参考 [配置参考手册 (Configuration Reference)](configuration_reference.md) 设置 `zhipu_api_key` 和 Tuzi API Key。

---

## 2. 平台特定配置

### 2.1 Android 开发 (Windows/Mac/Linux)
*   **要求**: Android SDK, AVD Manager, Java JDK 11+。
*   **配置**: 
    *   安装 Android Studio，勾选 SDK Platform-Tools 和 Build-Tools。
    *   配置 `ANDROID_HOME` 环境变量。
*   **运行**:
    ```bash
    flutter run -d android
    ```

### 2.2 Web 开发 (Windows/Mac/Linux)
*   **要求**: Chrome 浏览器。
*   **启用 Web 支持**:
    ```bash
    flutter config --enable-web
    ```
*   **运行**:
    ```bash
    flutter run -d chrome
    ```
*   **注意事项**:
    *   **CORS (跨域)**: 图片和视频生成 API 返回的 URL 可能会遇到跨域限制。开发时可使用 `--web-browser-flag "--disable-web-security"` (仅限调试) 或配置代理。
    *   **渲染器**: 默认使用 `html` 渲染器以获得更好的中文兼容性。若需高性能，可使用 `canvaskit`:
        ```bash
        flutter run -d chrome --web-renderer canvaskit
        ```

### 2.3 Windows 桌面开发 (仅 Windows)
*   **要求**: Visual Studio 2022。
*   **配置**:
    1.  安装 Visual Studio 2022。
    2.  安装时务必勾选 **"Desktop development with C++" (使用 C++ 的桌面开发)** 工作负载。
*   **启用 Windows 支持**:
    ```bash
    flutter config --enable-windows-desktop
    ```
*   **运行**:
    ```bash
    flutter run -d windows
    ```
*   **注意事项**:
    *   Windows版不支持部分仅限移动端的插件。本项目已做兼容性检查，大部分核心功能可用。

### 2.4 iOS 开发 (仅 macOS)
*   **要求**: macOS, Xcode, CocoaPods。
*   **配置**:
    1.  安装 Xcode (App Store)。
    2.  安装 CocoaPods: `sudo gem install cocoapods`。
    3.  进入 `ios` 目录并安装依赖:
        ```bash
        cd ios
        pod install
        cd ..
        ```
*   **运行**:
    ```bash
    flutter run -d ios
    ```
*   **签名**: 
    *   打开 `ios/Runner.xcworkspace`。
    *   在 Target -> Runner -> Signing & Capabilities 中选择你的 Team。

---

## 3. 常见问题排查

### 3.1 依赖报错
如果遇到 `pub get` 失败或版本冲突：
```bash
flutter clean
flutter pub get
```

### 3.2 Web 图片不显示
通常是 CORS 问题。
*   **解决方案 A**: 后端服务器配置允许 CORS。
*   **解决方案 B**: 使用 `flutter run -d chrome --web-renderer html` 可能会有改善，因为 `<img>` 标签比 CanvasKit 对跨域更宽容。

### 3.3 模拟器无法连接网络
*   检查宿主机的网络连接。
*   Android 模拟器有时需要冷启动 (`Cold Boot Now`)。

## 4. 调试技巧
*   **DevTools**: 运行 app 后，点击控制台的 DevTools 链接（或者在 VSCode 中按 `Ctrl+Alt+D`）打开性能和布局调试工具。
*   **ApiConfig**: 在 `lib/services/api_service.dart` 中开启 `USE_MOCK_VIDEO_API = true` 可以跳过真实的视频生成，加速 UI 开发。