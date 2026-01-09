# 外部服务 (External Services)

本项目集成了三个主要的 AI 服务提供商，分别用于不同的任务。

## 1. 智谱 AI (Zhipu AI)
*   **用途**: 大脑 (Brain) - 负责逻辑推理、对话交互、剧本创作。
*   **模型**: `GLM-4.7` (最新版旗舰模型，支持更长的上下文和更强的指令遵循能力)。
*   **API 地址**: `https://open.bigmodel.cn/api/paas/v4`
*   **认证方式**: Bearer Token
*   **交互模式**: HTTP SSE (Server-Sent Events) 流式对话。

## 2. Tuzi API (代理平台)
本项目使用 Tuzi API 作为图像和视频生成的统一网关。它封装了 Google 和其他提供商的底层能力。

### 2.1 图像生成 (Image Generation)
*   **用途**: 场景分镜绘制。
*   **模型**: `gemini-2.5-flash-image-vip` (Google Gemini)。
*   **API 地址**: `https://api.tu-zi.com/v1/images/generations` (在代码中配置为 `https://api.ourzhishi.top`)
*   **特点**: 支持高分辨率生成，支持参考图 (Image-to-Image) 输入。

### 2.2 视频生成 (Video Generation)
*   **用途**: 动态视频片段生成。
*   **模型**: `veo3.1-components` (Google Veo / Sora 类模型)。
*   **API 地址**: `https://api.ourzhishi.top/v1/videos`
*   **参数**: 支持 `image_url` 作为首帧参考，支持 5-10秒 视频生成。

## 3. 火山引擎 (Volcengine)
*   **用途**: 视觉理解 (Eyes) - 解析用户上传的参考图片。
*   **模型**: `doubao-seed-1-8-preview-251115` (豆包多模态模型)。
*   **API 地址**: `https://ark.cn-beijing.volces.com/api/v3`
*   **功能**: 当用户上传图片时，系统调用此 API 分析图片中的人物特征 (Character Analysis)，并将结果反馈给 GLM 以保证生成的一致性。

---

## 敏感信息说明
所有 API Key 均存储在用户设备的本地安全存储中，不会上传到任何服务器。开发和测试时请使用自己的 API Key。
