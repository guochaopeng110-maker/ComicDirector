## API Key设置与管理说明
### 1. ApiConfigService.initialize() 方法的作用
- 初始化目的 ：该方法仅负责初始化 SharedPreferences 实例，确保存储服务可用
- 不设置默认值 ：代码中明确注释 // 不再设置默认值，让用户自行配置
- 存储结构 ：为每个API服务创建独立的存储键值：
  - 智谱 GLM: zhipu_api_key
  - 视频生成: video_api_key
  - 图像生成: image_api_key
  - 豆包 ARK: doubao_api_key
### 2. 设置界面的API Key配置选项
设置界面中实际上为每个API服务都提供了独立的配置选项 ：

API服务 显示名称 存储键值 设置方法 智谱 GLM-4.7 智谱 GLM-4.7 zhipu_api_key setZhipuApiKey() 视频生成 视频生成 (tuzi-api) video_api_key setVideoApiKey() 图像生成 图像生成 (tuzi-api) image_api_key setImageApiKey() 豆包 ARK 豆包 ARK (图片识别) doubao_api_key setDoubaoApiKey()

### 3. API Key的独立性
- 不同服务需要不同API Key ：每个服务都是独立的第三方API，需要各自的API Key
- 存储分离 ：每个API Key都存储在独立的键值中
- 设置独立 ：用户需要为每个服务单独设置API Key
- 使用分离 ：在API请求时，为每个服务使用对应的API Key
### 4. 为什么需要多个API Key
该应用集成了多个不同的AI服务：

- 智谱 GLM-4.7 ：用于对话和剧本生成
- Tuzi API ：用于视频和图像生成（两个不同的API Key）
- 豆包 ARK ：用于图片识别和分析
每个服务都有自己的认证机制和API Key获取方式，因此需要用户为每个服务单独配置。

### 5. 配置流程
1. 进入设置界面
2. 找到"API 配置"卡片
3. 为每个API服务单独点击编辑按钮
4. 在弹出的对话框中输入对应的API Key
5. 点击保存完成配置
这样，每个服务就会使用各自独立的API Key进行认证和请求。


          
## 各服务使用的模型分析

根据代码分析，工程中不同服务使用了不同的模型和API提供商：

### 1. 漫剧剧本生成
- **服务提供商**：智谱AI (open.bigmodel.cn)
- **API基础URL**：`https://open.bigmodel.cn/api/paas/v4`
- **使用模型**：`glm-4.7`
- **功能**：生成漫剧风格的剧本，包含多个场景和情绪弧

### 2. 图像生成
- **服务提供商**：Tuzi API (ourzhishi.top)
- **API基础URL**：`https://api.ourzhishi.top`
- **使用模型**：`gemini-2.5-flash-image-vip`
- **功能**：根据文本提示生成场景图片，支持参考图输入

### 3. 视频生成
- **服务提供商**：Tuzi API (ourzhishi.top)
- **API基础URL**：`https://api.ourzhishi.top`
- **使用模型**：`veo3.1-components`
- **功能**：根据文本提示和参考图生成视频，支持多图输入

### 技术实现细节

#### 图像生成API调用
```dart
final requestData = {
  'model': 'gemini-2.5-flash-image-vip',
  'prompt': prompt,
  'n': 1,
  'response_format': 'url',
  'size': '1024x1024',
};

final response = await _imageDio.post(
  '/v1/images/generations',
  data: requestData,
);
```

#### 视频生成API调用
```dart
final formData = FormData.fromMap({
  'model': 'veo3.1-components',  // 默认使用 veo3.1-components 支持多图
  'prompt': finalPrompt,
  'seconds': seconds,
  'size': size,
  'watermark': 'false',
});

final response = await _tuziDio.post(
  '/v1/videos',
  data: formData,
);
```

### 总结

工程采用了**多服务集成**的架构：
- **智谱GLM-4.7**：负责智能剧本创作，利用其强大的文本理解和生成能力
- **Gemini图像模型**：负责高质量图像生成，支持参考图输入
- **Veo视频模型**：负责视频生成，支持多图参考

这种架构充分利用了不同AI模型的优势，为用户提供从剧本创作到视频生成的完整流程。