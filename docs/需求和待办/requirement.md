这份需求说明书（Requirement Specification）是为你专门定制的。它既包含了业务逻辑，也为 **Claude Code** 提供了清晰的工程指令。你可以将其存为 `docs/requirement.md`，开发时直接让 Claude 读取。

---

# AI漫导 Agent 项目需求说明书

## 1. 项目概述

**AI漫导 Agent** 是一款基于 Flutter 的移动端应用，旨在通过 **GLM 大模型** 作为核心决策引擎（Agent），将用户的创意文字直接转化为包含“脚本-图片-视频”的短剧流。

## 2. 技术栈核心 (Tech Stack)

* **UI 框架:** Flutter 3.0+ (声明式 UI)
* **开发语言:** Dart 3.0+ (支持强类型与 Null Safety)
* **状态管理:** Provider (类似全局上下文/依赖注入)
* **网络通信:** Dio (类似 Java 的 OkHttp/Retrofit)
* **内容渲染:** flutter_markdown (渲染大模型生成的文案)

---

## 3. 核心业务流程 (Workflow Pipeline)

项目采用 **Agent 工作流模式**，共分为四个阶段：

### 阶段一：意图解析与脚本规划 (Planner)

* **输入:** 用户自然语言（例如：“生成一个小猫打架的视频”）。
* **Agent 行为:** GLM 接收 Prompt，分析用户意图，生成结构化的 **JSON 剧本**。
* **输出内容:** 剧本大纲、分镜描述（Image Prompt）、视频动效描述（Video Prompt）。

### 阶段二：视觉资产生成 (Image Generation)

* **输入:** 脚本中的 `image_prompt`。
* **行为:** 调用文生图接口（如 CogView 或 SD），并行或串行生成每个分镜的关键帧图片。
* **输出:** 关键帧图片 URL 列表。

### 阶段三：动态视频合成 (Video Generation)

* **输入:** 关键帧图片 URL + `video_motion_prompt`。
* **行为:** 调用图生视频接口（如 CogVideo），将静态图片转化为动态短片。
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
* **异常处理:** 针对 API 超时、审核未通过等情况提供“重试”按钮。

### 4.3 多模态展示卡片 (Media Components)

* **Markdown 视图:** 展示剧本旁白。
* **图片网格:** 展示生成的分镜图，支持点击放大。
* **视频播放器:** 集成 `video_player`，生成后自动播放。

---

## 5. 数据协议定义 (Data Protocol)

为了确保 Claude Code 开发的模型类能对接 GLM 的输出，定义如下 POJO (Dart Class) 结构：

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

## 6. 面向 Claude Code 的开发任务建议 (Implementation Steps)


