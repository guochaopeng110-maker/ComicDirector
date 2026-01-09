# AI漫导 Agent 项目需求说明书

> 这份需求说明书（Requirement Specification）是为 AI漫导 项目专门定制的。它既包含了业务逻辑，也为 **Claude Code** 提供了清晰的工程指令。

---

## 1. 项目概述

**AI漫导 Agent** 是一款基于 Flutter 的**跨平台应用**，旨在通过 **GLM 大模型** 作为核心决策引擎（Agent），将用户的创意文字直接转化为包含"脚本-图片-视频"的短剧流。

### 1.1 定位与愿景

**AI漫导** 是一款基于 **Agent 架构** 的多模态内容创作**跨平台应用**。它不仅仅是一个聊天工具，而是一个"AI漫导"。
该应用利用大模型（GLM）的理解与规划能力，将用户碎片化的创意（自然语言）转化为完整的视频剧本，并自动调度底层视觉模型执行"文生图"和"图生视频"的复杂流水线，最终交付成品短剧。

### 1.2 支持平台

| 平台 | 状态 | 说明 |
|------|------|------|
| **Android** | ✅ 主要平台 | 手机和平板，Android 8.0+ |
| **iOS** | ✅ 支持 | iPhone 和 iPad，iOS 12.0+ |
| **Web** | ✅ 支持 | Chrome、Firefox、Safari、Edge |
| **Windows** | ✅ 支持 | Windows 10/11 桌面应用 |
| **macOS** | 🔜 计划中 | macOS 10.14+ |
| **Linux** | 🔜 计划中 | Ubuntu 等主流发行版 |

> **注意**: 各平台功能一致性由 Flutter 框架保证，但视频合成等底层能力需要使用 FFmpeg 跨平台库实现。

### 1.3 业务价值

本项目的本质是 **"提示词自动化（Prompt Automation）"**。用户只需提供一句话需求，其余所有专业级的生图、生视频提示词均由 GLM 内部生成并自动流转。你开发的 Flutter App 则是这套 Agent 逻辑的物理载体和交互中心。

---

## 2. 技术栈核心 (Tech Stack)

* **UI 框架:** Flutter 3.0+ (声明式 UI)
* **开发语言:** Dart 3.0+ (支持强类型与 Null Safety)
* **状态管理:** Provider (类似全局上下文/依赖注入)
* **网络通信:** Dio (类似 Java 的 OkHttp/Retrofit)
* **内容渲染:** flutter_markdown (渲染大模型生成的文案)

### 2.1 技术实现架构 (面向 Java 开发者的视角)

你可以将本项目理解为一个典型的 **Controller-Service-Model** 架构，但在客户端实现：

| 模块层级 | 对应技术 | Java 开发者理解 |
| --- | --- | --- |
| **UI View** | Flutter 3.0+ | 类似于 Android XML 或 Compose，负责响应式展示进度和多模态卡片。 |
| **Logic/State** | **Provider** | 类似于 **Spring Bean (Request Scoped)**。它管理 Agent 的全生命周期状态，驱动 UI 更新。 |
| **Networking** | **Dio** | 相当于 **Retrofit/OkHttp**。负责处理与智谱 API 的所有 Restful 交互及 TaskID 轮询。 |
| **Parser** | `json_serializable` | 相当于 **Jackson/Gson**。负责将 GLM 返回的 JSON 剧本反序列化为 Dart 对象。 |
| **Agent Controller** | 自定义 Workflow Logic | 这是项目的 **Main Loop**。它控制 `GLM -> Image API -> Video API` 的顺序执行和依赖传递。 |

---

## 3. 核心业务流程 (Workflow Pipeline)

项目采用 **Agent 工作流模式**，基于 GLM 打造的 **"规划-执行-合成"** 三位一体工作流，共分为四个阶段：

### 阶段一：意图解析与脚本规划 (Planner) —— "导演构思"

* **输入:** 用户自然语言（例如："生成一个小猫打架的视频"）。
* **Agent 行为:** GLM 接收 Prompt，分析用户意图，生成结构化的 **JSON 剧本**。
* **输出内容:** 
  * **剧情大纲**：故事的起承转合。
  * **分镜参数**：为每一幕生成精准的 **Visual Prompt**（用于生图）和 **Motion Prompt**（用于控制动作）。
  * **旁白/对话**：视频的文案内容。

### 阶段二：视觉资产生成 (Image Generation) —— "美术绘制"

* **输入:** 脚本中的 `image_prompt`。
* **行为:** 调用文生图接口（如 CogView 或 SD），并行或串行生成每个分镜的关键帧图片。
* **输出:** 关键帧图片 URL 列表。这些图片将作为视频生成的视觉基座（Base Image），确保视频的第一帧符合剧本设定。

### 阶段三：动态视频合成 (Video Generation) —— "后期剪辑"

* **输入:** 关键帧图片 URL + `video_motion_prompt`。
* **行为:** 调用图生视频接口（如 CogVideo），将静态图片转化为动态短片。
* **异步跟踪:** 利用异步轮询机制监控视频渲染状态，最终获取 `.mp4` 资源。
* **输出:** 最终视频文件 URL。

### 阶段四：交互式引导与反馈 (User Interface)

* **行为:** 整个过程通过对话框展现，使用 Markdown 实时流式输出剧本，并在生成图片/视频后自动插入到对话流中。

---

## 4. 功能模块划分 (Functional Modules)

### 4.1 智能对话模块 (Chat & Agent)

* 支持文本输入。
* **流式输出 (Streaming):** GLM 生成剧本时，前端实时用 Markdown 渲染，提升用户体验。
* **指令注入:** 隐藏的 System Prompt，约束大模型必须返回符合协议的 JSON。

### 4.2 任务状态追踪器 (Job Tracker)

* **UI 表现:** 在界面上方或消息卡片上显示当前进度：`规划中` -> `正在生成第 N 张图` -> `视频合成中` -> `渲染完成`。
* **异常处理:** 针对 API 超时、审核未通过等情况提供"重试"按钮。

### 4.3 多模态展示卡片 (Media Components)

* **Markdown 视图:** 展示剧本旁白。
* **图片网格:** 展示生成的分镜图，支持点击放大。
* **视频播放器:** 集成 `video_player`，生成后自动播放。

---

## 5. 关键功能特性

* **结构化 Prompt 工程**：通过系统级的提示词约束，使 GLM 强制输出 JSON 格式，解决 Agent 在流水线中"胡言乱语"导致程序崩溃的问题。
* **异步任务管理**：针对视频生成动辄 1-2 分钟的耗时，设计了非阻塞的任务队列。用户可以在等待视频生成的同时，通过 `flutter_markdown` 先行阅读生成的剧本文字。
* **多模态混合渲染**：聊天界面不仅支持文本，还支持 Markdown 格式的剧本排版、图片预览组件以及视频播放组件的动态嵌入。
* **容错与重试逻辑**：每一幕的生成都是独立的（Scene-based）。如果某一幕图片生成失败，Agent 可以单独针对该场景进行重试，而无需从头开始。

---

## 6. 数据协议定义 (Data Protocol)

为了确保开发的模型类能对接 GLM 的输出，定义如下 POJO (Dart Class) 结构：

```json
{
  "task_id": "string",
  "script_title": "string",
  "scenes": [
    {
      "scene_id": 1,
      "narration": "中文旁白内容",
      "image_prompt": "High quality, 4k, cinematic shot of...",
      "video_prompt": "The cats are jumping and fighting...",
      "image_url": "", 
      "video_url": "",
      "status": "pending" 
    }
  ]
}
```

---

## 7. 平台特定注意事项

### 7.1 Android 平台

* **最低版本**: Android 8.0 (API 26)
* **权限**: 存储读写、网络访问、相机（可选）
* **视频合成**: 使用 FFmpeg 或原生 MediaMuxer
* **分享**: 集成微信、抖音等 SDK

### 7.2 iOS 平台

* **最低版本**: iOS 12.0
* **权限**: 相册访问、网络访问
* **视频合成**: 使用 FFmpeg (ffmpeg_kit_flutter)
* **注意**: 需要 Apple Developer 证书进行签名

### 7.3 Web 平台

* **支持浏览器**: Chrome 88+, Firefox 78+, Safari 14+, Edge 88+
* **CORS**: 需要处理跨域资源访问
* **视频合成**: 使用 FFmpeg WASM 版本
* **限制**: 无法直接访问本地文件系统，需使用 File API

### 7.4 Windows 平台

* **最低版本**: Windows 10 (1809+)
* **前置要求**: Visual Studio 2022 (C++ 开发负载)
* **视频合成**: 使用 FFmpeg 本地库
* **路径**: 注意 Windows 路径分隔符 (`\\`)

---

## 8. 非功能性需求

### 8.1 性能要求

| 指标 | 目标值 |
|------|--------|
| 应用启动时间 | < 3 秒 |
| 剧本生成响应 | 首字符 < 2 秒 |
| 图片生成 | 单张 < 30 秒 |
| 视频合成 | 10 秒视频 < 2 分钟 |

### 8.2 安全要求

* API Token 使用安全存储（`flutter_secure_storage`）
* 网络请求使用 HTTPS
* 敏感数据不进行明文日志输出

### 8.3 可维护性要求

* 单文件代码行数 < 500 行
* 核心流程测试覆盖率 > 50%
* 代码通过 `flutter analyze` 无严重警告

---

## 9. 相关文档

* [项目路线图](../roadmap/roadmap.md) - 深度完善与扩展计划
* [阶段一需求](../phases/phase1_foundation.md) - 基石阶段（技术债务清理）
* [阶段二需求](../phases/phase2_senses.md) - 感官阶段（音频字幕）
* [阶段三需求](../phases/phase3_brain.md) - 智慧阶段（角色一致性）
* [阶段四需求](../phases/phase4_experience.md) - 体验阶段（用户体验）
* [阶段五需求](../phases/phase5_business.md) - 商业阶段（商业模式）

