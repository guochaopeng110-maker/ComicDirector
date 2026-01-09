# Tuzi API 参考手册 (Image & Video)

本文档详细介绍了通过 Tuzi 平台调用的图像和视频生成接口。

## 1. 图像生成 (Image Generation)

### 接口信息
*   **端点**: `/v1/images/generations`
*   **方法**: `POST`
*   **Content-Type**: `application/json`

### 请求参数
```json
{
  "model": "gemini-2.5-flash-image-vip", // 或其他可用模型
  "prompt": "Your image description",
  "n": 1, 
  "size": "1024x1024",
  "response_format": "url" // url 或 b64_json
}
```

### 响应示例
```json
{
  "created": 1678900000,
  "data": [
    {
      "url": "https://..."
    }
  ]
}
```

## 2. 视频生成 (Video Generation)

### 接口信息
*   **端点**: `/v1/videos`
*   **方法**: `POST`
*   **Content-Type**: `application/json` (通常使用 FormData 以支持文件上传，但在本项目中通过 JSON 传递 URL)

### 请求参数 (JSON/FormData)
```json
{
  "model": "veo3.1-components",
  "prompt": "Cinematic shot of...",
  "size": "1280x720",
  "seconds": "5", // 5S, 10S
  "image_url": "https://..." // 可选：首帧参考图
}
```

### 响应示例 (异步任务)
```json
{
  "id": "task_123456",
  "status": "queued", // queued, processing, completed, failed
  "created_at": 1678900000
}
```

### 状态查询
*   **端点**: `/v1/videos/{task_id}`
*   **方法**: `GET`
*   **说明**: 需要轮询此接口直到 `status` 变为 `completed`。完成后，响应中包含 `video_url`。

## 3. 错误处理
常见 HTTP 状态码：
*   `200`: 成功。
*   `400`: 参数错误 (如 Prompt 包含违规词)。
*   `401`: 认证失败 (Token 无效或余额不足)。
*   `500`: 服务器内部错误 (上游服务繁忙)。
