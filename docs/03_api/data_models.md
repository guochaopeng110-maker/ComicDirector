# 核心数据模型 (Data Models)

本文档描述了应用中的核心数据结构，主要位于 `lib/models/` 目录下。

## 1. 剧本结构 (Screenplay)
剧本是应用的核心对象，贯穿整个生成生命周期。

```json
{
  "task_id": "string (唯一任务ID)",
  "script_title": "string (剧本标题)",
  "status": "enum (drafting | confirmed | generating | completed | failed)",
  "scenes": [
    // 场景列表，见下方 Scene 定义
  ]
}
```

### 状态流转
`drafting` (草稿) -> `confirmed` (已确认) -> `generating` (生成中) -> `completed` (完成)

## 2. 场景 (Scene)
每个场景代表视频中的一个镜头。

```json
{
  "scene_id": "int (场景序号, 从1开始)",
  "narration": "string (中文旁白)",
  "image_prompt": "string (英文绘图提示词)",
  "video_prompt": "string (英文视频提示词)",
  "character_description": "string (角色特征描述，用于一致性)",
  "image_url": "string? (生成的图片URL)",
  "video_url": "string? (生成的视频URL)",
  "status": "enum (pending | imageGenerating | imageCompleted | videoGenerating | completed | failed)"
}
```

## 3. 智能体命令 (AgentCommand)
GLM 智能体返回的结构化指令，用于驱动前端执行操作。

```json
{
  "action": "string",
  "params": {
    // 动态参数
  }
}
```

### 常见 Action
*   `generate_image`: 生成图片
    *   params: `{ "prompt": "..." }`
*   `generate_video`: 生成视频
    *   params: `{ "prompt": "...", "image_url": "..." }`
*   `complete`: 完成对话
    *   params: `{ "message": "..." }`

## 4. 角色卡 (CharacterSheet)
用于保持多镜头间人物一致性的辅助数据结构。虽然代码中有定义，但在新版逻辑中，主要通过在 Prompt 中携带 `character_description` 或使用首图作为 Reference 来实现一致性。

```json
{
  "character_id": "string",
  "name": "string",
  "description": "string",
  "image_urls": ["string"] // 正面、侧面、背面视图
}
```
