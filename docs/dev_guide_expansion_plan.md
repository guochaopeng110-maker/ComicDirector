# 开发指南完善计划 (Development Guide Expansion Plan)

## 1. 目标
扩展 `docs/04_manuals/development_guide.md`，使其不仅涵盖 Android 开发环境，还包括 Web、Windows 和 iOS 的开发配置与运行指南，实现真正的“跨平台”开发指导。

## 2. 新增内容规划

### 2.1 Web 开发环境
*   **兼容性**: 任何安装了 Chrome 的电脑。
*   **命令**: `flutter run -d chrome`
*   **注意事项**:
    *   CORS 问题（图片/视频资源的跨域访问）。
    *   Web 不支持 `dart:io`，需检查代码中是否混用了平台特定代码。
    *   Renderer 选择 (`html` vs `canvaskit`)。

### 2.2 Windows 开发环境
*   **前置要求**: Visual Studio 2022 (需安装 "Desktop development with C++" 负载)。
*   **命令**: `flutter run -d windows`
*   **注意事项**:
    *   插件兼容性 (部分移动端插件可能不支持 Windows)。
    *   文件系统路径差异 (`\` vs `/`)。

### 2.3 iOS 开发环境 (仅 macOS)
*   **前置要求**: macOS, Xcode, CocoaPods。
*   **命令**: `flutter run -d ios`
*   **注意事项**:
    *   Signing & Capabilities (签名配置)。
    *   Podfile 配置。

## 3. 文档结构调整
建议将 `development_guide.md` 重组为以下结构：

```markdown
# AI 漫导 (DirectorAI) 全平台开发指南

## 1. 基础环境配置 (所有平台)
   - Flutter SDK
   - VS Code / Plugins
   - Git & Repo Setup

## 2. 平台特定配置
   ### 2.1 Android 开发 (Windows/Mac/Linux)
   ### 2.2 Web 开发 (Windows/Mac/Linux)
   ### 2.3 Windows 桌面开发 (Windows Only)
   ### 2.4 iOS 开发 (macOS Only)

## 3. 运行与调试
   - 常用命令
   - 常见报错速查
```

## 4. 执行步骤
1.  **重构现有的 Android部分**: 将当前 `development_guide.md` 中的 Android 内容移动到 `2.1` 节。
2.  **编写新章节**: 依次补充 Web, Windows, iOS 的配置步骤。
3.  **验证**: 确保所有命令准确无误。
