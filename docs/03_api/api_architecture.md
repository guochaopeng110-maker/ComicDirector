# API 架构文档

## 1. 概述

本项目采用 `Flutter` + `Provider` + `Dio` 的技术栈，通过 `Controller-Service-Model` 架构实现 AI 智能体应用。

`ApiService` (`lib/services/api_service.dart`) 是所有外部通信的中心枢纽，负责管理与多个 AI 服务提供商的交互。

## 2. 核心架构图

```mermaid
graph TD
    subgraph UI层
        ChatScreen[ChatScreen] --> AgentController
        ScreenplayReview[ScreenplayReview] --> ScreenplayController
    end

    subgraph Logic层
        AgentController[AgentController] --> ApiService
        ScreenplayController[ScreenplayController] --> ApiService
    end

    subgraph Service层 (ApiService)
        ApiService --> |Stream| GLMClient[智谱 GLM Client]
        ApiService --> |HTTP| TuziImageClient[Tuzi Image Client]
        ApiService --> |HTTP/Poll| TuziVideoClient[Tuzi Video Client]
        ApiService --> |HTTP| DoubaoClient[豆包 ARK Client]
    end

    subgraph 外部服务
        GLMClient --> |v4/chat/completions| Zhipu[智谱 AI]
        TuziImageClient --> |v1/images/generations| GoogleGemini[Google Gemini / Banana]
        TuziVideoClient --> |v1/videos| GoogleVeo[Google Veo / Sora]
        DoubaoClient --> |v3/chat/completions| ByteDance[火山引擎 豆包]
    end
```

## 3. 核心机制

### 3.1 智能体对话 (Chat Streams)
*   **实现**: 使用 `Stream<GLMStreamChunk>`。
*   **流程**:
    1.  UI 订阅 `AgentController` 的流。
    2.  `AgentController` 调用 `ApiService.chatWithGLM()`。
    3.  `ApiService` 通过 Dio 发送流式请求 (`responseType: ResponseType.stream`).
    4.  实时解析 SSE (Server-Sent Events) 数据块。
    5.  将 `thinking` (思考过程) 和 `content` (正文) 分发给 UI。

### 3.2 视频生成 (Asynchronous Polling)
*   **实现**: 提交任务 + 轮询 (Polling)。
*   **流程**:
    1.  调用 `generateVideo()` 提交任务，获 `task_id`。
    2.  根据 `VideoGenerationResponse` 状态判断是否立即完成。
    3.  如果未完成，启动 `pollVideoStatus()` 循环。
    4.  每隔 `2秒` 查询一次状态，直到 `completed` 或 `failed`。

### 3.3 并发控制
*   在 `ScreenplayController` 中，场景生成支持并发执行。
*   配置参数: `ApiConfig.concurrentScenes` 控制同时生成的场景数量 (默认 2)。
*   这允许应用同时生成多个场景的图片和视频，显著缩短等待时间。

## 4. 鉴权与配置
所有 API 的鉴权信息由 `ApiConfigService` 管理，持久化在本地存储中。`ApiService` 在每次请求时通过拦截器 (Interceptors) 动态注入最新的 Bearer Token。
