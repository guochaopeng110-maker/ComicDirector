# 完整迁移到Google AI Studio Gemini模型的修改计划

## 1. API配置修改

### 修改 ApiConfig 类

* 添加 Google AI Studio 基础URL

* 统一使用 Google API Key

* 更新所有模型名称配置

```dart
// 添加 Google AI Studio 基础URL
static const String googleBaseUrl = 'https://generativelanguage.googleapis.com';

// 统一使用 Google API Key
static String get googleApiKey => ApiConfigService.getGoogleApiKey();

// 更新所有模型配置
static const String googleTextModel = 'gemini-2.5-flash';      // 用于漫剧剧本生成
static const String googleImageModel = 'gemini-2.5-flash';     // 用于图像生成
static const String googleVideoModel = 'veo-3.1';              // 用于视频生成
static const String googleVisionModel = 'gemini-2.5-flash';    // 用于图片理解
```

## 2. ApiConfigService 修改

### 添加 Google API Key 管理

* 添加 Google API Key 的存储键值

* 添加对应的getter和setter方法

* 更新设置界面显示

```dart
// 添加存储键值
static const String _keyGoogleApiKey = 'google_api_key';

// 添加getter方法
static String getGoogleApiKey() {
  _ensureInitialized();
  return _prefs!.getString(_keyGoogleApiKey) ?? _unconfigured;
}

// 添加setter方法
static Future<void> setGoogleApiKey(String key) async {
  _ensureInitialized();
  await _prefs!.setString(_keyGoogleApiKey, key);
  AppLogger.info('ApiConfigService', '已更新Google API Key: ${key.substring(0, 8)}...');
}

// 更新检查方法
static bool isGoogleApiKeyConfigured() {
  final key = getGoogleApiKey();
  return key.isNotEmpty && key != _unconfigured;
}
```

## 3. 漫剧剧本生成API修改

### 修改 generateDramaScreenplay 方法

* 更新API路径为 Google AI Studio 的路径

* 修改请求参数结构

* 调整响应解析逻辑

```dart
// 修改API调用路径
final response = await _googleDio.post(
  '/v1/models/${ApiConfig.googleTextModel}:generateContent',
  data: {
    'contents': [
      {
        'parts': [
          {'text': enhancedPrompt}
        ]
      }
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseSchema': {
        'type': 'OBJECT',
        'properties': {
          'task_id': {'type': 'STRING'},
          'title': {'type': 'STRING'},
          'scenes': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'scene_id': {'type': 'INTEGER'},
                'narration': {'type': 'STRING'},
                'image_prompt': {'type': 'STRING'},
                'video_prompt': {'type': 'STRING'},
                'character_description': {'type': 'STRING'}
              }
            }
          }
        }
      }
    }
  },
);

// 调整响应解析
final content = response.data['candidates'][0]['content'];
final responseJson = jsonEncode(content['parts'][0]['text']);
```

## 4. 图像生成API修改

### 修改 generateImage 方法

* 更新API路径为 Google AI Studio 的路径

* 修改请求参数结构

* 调整响应解析逻辑

```dart
// 修改API调用路径
final response = await _googleDio.post(
  '/v1/models/${ApiConfig.googleImageModel}:generateContent',
  data: {
    'contents': [
      {
        'parts': [
          {'text': prompt},
          // 如果有参考图，添加图像部分
          ...referenceImages.map((image) => {
            'image': {'source': {'imageUri': image}}
          })
        ]
      }
    ]
  },
);

// 调整响应解析
final imageUrl = response.data['candidates'][0]['content']['parts'][0]['imageUri'];
```

## 5. 视频生成API修改

### 修改 generateVideo 方法

* 更新API路径为 Google AI Studio 的路径

* 修改请求参数结构

* 调整响应解析逻辑

```dart
// 修改API调用路径
final response = await _googleDio.post(
  '/v1/models/${ApiConfig.googleVideoModel}:generateContent',
  data: {
    'contents': [
      {
        'parts': [
          {'text': prompt},
          // 如果有参考图，添加图像部分
          ...imageUrls.map((url) => {
            'image': {'source': {'imageUri': url}}
          })
        ]
      }
    ],
    'generationConfig': {
      'videoDuration': '${seconds}s',
      'videoQuality': '720p'
    }
  },
);

// 调整响应解析
final videoUrl = response.data['candidates'][0]['content']['parts'][0]['videoUri'];
```

## 6. 图片理解API修改

### 修改 chatWithGLMImageSupport 方法

* 更新API路径为 Google AI Studio 的路径

* 修改请求参数结构

* 调整响应解析逻辑

```dart
// 修改API调用路径
final response = await _googleDio.post(
  '/v1/models/${ApiConfig.googleVisionModel}:generateContent',
  data: {
    'contents': [
      {
        'parts': [
          {'text': userMessage},
          {
            'image': {
              'source': {
                'data': imageBase64
              }
            }
          }
        ]
      }
    ]
  },
);

// 调整响应解析
final content = response.data['candidates'][0]['content'];
final textContent = content['parts'][0]['text'];
```

## 7. Dio实例创建修改

### 添加 Google API Dio 实例

* 创建专门的 Google API Dio 实例

* 配置正确的请求头和拦截器

```dart
/// 创建 Google API Dio 实例
static Dio createGoogleDio() {
  final dio = Dio(BaseOptions(
    baseUrl: googleBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  // 添加拦截器，在每次请求时添加 API Key 参数
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      // Google AI Studio 使用查询参数传递 API Key
      options.queryParameters['key'] = googleApiKey;
      return handler.next(options);
    },
  ));

  return dio;
}
```

## 8. ApiService 类重构

### 统一使用 Google API

* 移除对其他API服务的依赖

* 统一使用 Google API 进行所有操作

* 保持原有功能接口不变

```dart
class ApiService {
  late Dio _googleDio;  // 统一使用 Google API Dio 实例

  ApiService() {
    _googleDio = ApiConfig.createGoogleDio();
  }

  // 所有方法都使用 _googleDio 进行API调用
}
```

## 9. 设置界面修改

### 更新 API 配置卡片

* 只保留 Google API Key 配置项

* 更新显示名称和说明

```dart
// 只显示 Google API Key 配置项
_buildApiKeyRow(
  context,
  'Google AI Studio',
  ApiConfigService.maskApiKey(ApiConfigService.getGoogleApiKey()),
  Icons.cloud_outlined,
  const Color(0xFF4285F4),
  () => _showApiKeyEditDialog(
    context,
    'Google AI Studio API Key',
    ApiConfigService.getGoogleApiKey(),
    (key) => ApiConfigService.setGoogleApiKey(key),
  ),
),
```

## 10. 测试和验证

### 测试步骤

1. 备份原有的 api_service.dart 文件
2. 配置 Google API Key
3. 测试漫剧剧本生成功能
4. 测试图像生成功能
5. 测试视频生成功能
6. 测试图片理解功能
7. 验证所有功能是否正常工作

### 验证要点

* 漫剧剧本生成是否正常工作

* 图像生成是否正常工作

* 视频生成是否正常工作

* 图片理解是否正常工作

* API Key 配置是否正确

* 错误处理是否完善

* 性能是否符合预期

## 11. 兼容性考虑

### 保持接口兼容性

* 保持原有方法签名不变

* 保持返回值格式不变

* 确保现有代码无需修改

### 错误处理增强

* 添加 Google API 特定的错误处理

* 提供详细的错误信息

* 确保错误处理与原有逻辑一致

## 12. 部署和切换

### 部署步骤

1. 备份原有的 api_service.dart 文件
2. 替换为新的实现
3. 更新 ApiConfigService 和设置界面
4. 部署应用
5. 配置 Google API Key
6. 测试所有功能

### 切换策略

* 可以使用功能开关控制是否启用 Google API

* 保留原有的 API 服务作为备用

* 确保平滑过渡到新的 API 服务