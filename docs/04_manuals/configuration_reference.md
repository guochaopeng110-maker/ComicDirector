# 配置参考手册 (Configuration Reference)

本文档主要面向开发者，详细介绍了应用的配置项和内部开关。主要的配置逻辑位于 `lib/services/api_config.dart` 和 `lib/services/api_config_service.dart`。

## 1. 核心 API 配置 (ApiConfigService)

`ApiConfigService` 使用 `shared_preferences` 在本地持久化存储敏感的 API Key。

| 存储键名 (Key) | 说明 | 对应服务 |
| :--- | :--- | :--- |
| `zhipu_api_key` | 智谱 AI 平台 Key | 对话、剧本规划 |
| `video_api_key` | Tuzi 视频 API Key | 视频生成 (Veo/Sora) |
| `image_api_key` | Tuzi 图像 API Key | 图像生成 (Gemini) |
| `doubao_api_key` | 豆包 ARK API Key | 图像理解 (多模态) |

**注意**：这些 Key 需要在应用启动后的“设置”页面手动配置，代码中不再包含默认值。

## 2. 运行时标志 (ApiConfig)

位于 `lib/services/api_service.dart` 中的 `ApiConfig` 类包含了一些静态常量，用于控制开发调试行为。

### 2.1 功能开关

```dart
// 生产环境请将此值设为 false
static const bool USE_MOCK_VIDEO_API = false;  // 视频生成 Mock 开关
static const bool USE_MOCK_IMAGE_API = false;  // 图片生成 Mock 开关
static const bool USE_THINKING_MODE = true;    // 是否显示 GLM 的思考过程
```

*   **Mock 模式**: 当开启 (`true`) 时，系统不会通过网络调用真实的 Tuzi API，而是直接返回写死的测试 URL。这在开发 UI 或节省 Token 时非常有用。

### 2.2 性能配置

```dart
// 场景数量配置 (控制生成规模)
static int sceneCount = 7;  // 默认生成的场景数

// 并发控制
static int concurrentScenes = 2; // 同时并行生成的场景数
```

*   `concurrentScenes`: 决定了同时有多少个 HTTP 请求发送给 Tuzi API。
    *   **建议**: 保持在 2-3 之间。
    *   **原因**: 设置过高可能导致 API Rate Limit (速率限制) 或手机发热严重。

## 3. 模型参数配置

### 3.1 视频生成模型
目前硬编码为使用 Tuzi 平台的 `veo3.1-components` 模型。
*   路径: `ApiService._createTuziDio` 附近。
*   参数: `seconds` 默认为 5秒。

### 3.2 图像与多模态
*   图像生成: `gemini-2.5-flash-image-vip`
*   图像理解: `doubao-seed-1-8-preview-251115`
