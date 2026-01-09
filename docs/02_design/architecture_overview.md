# AI Director 视频生成完整流程

> 当你输入"生成一个小姐姐做草莓蛋糕的视频"时，系统是如何工作的？

## 📋 流程图说明

```mermaid
flowchart TD
    Start([用户输入提示词<br/>生成一个小姐姐做草莓蛋糕的视频]) --> CheckIntent{是视频生成请求?}

    CheckIntent -->|是| GenerateDraft[📝 步骤1: 生成剧本草稿]
    CheckIntent -->|否| NormalChat[普通聊天对话]

    %% 剧本生成流程
    GenerateDraft --> GLMCall1[调用智谱 GLM-4.7 AI]
    GLMCall1 --> GLMReturn1[返回剧本 JSON<br/>包含7个场景]

    GLMReturn1 --> GenerateChar[🎨 步骤2: 生成角色设定]
    GenerateChar --> CharSheets[生成角色三视图<br/>正面+侧面+背面<br/>用于保持人物一致性]

    CharSheets --> ShowPreview[👀 步骤3: 展示剧本预览]
    ShowPreview --> UserConfirm{用户确认剧本?}

    UserConfirm -->|修改| BackToGLM[重新生成剧本]
    BackToGLM --> ShowPreview

    UserConfirm -->|确认| StartGeneration[🚀 步骤4: 开始生成内容]

    %% 图片和视频生成流程
    StartGeneration --> SplitScenes[分成7个场景<br/>并行处理]

    SplitScenes --> Scene1[场景1: 开始做蛋糕]
    SplitScenes --> Scene2[场景2: 准备材料]
    SplitScenes --> Scene3[场景3: 混合面粉]
    SplitScenes --> Scene4[场景4: 打发奶油]
    SplitScenes --> Scene5[场景5: 装饰草莓]
    SplitScenes --> Scene6[场景6: 切蛋糕]
    SplitScenes --> Scene7[场景7: 品尝蛋糕]

    %% 每个场景的处理
    Scene1 --> GenImg1[🖼️ 生成分镜图]
    Scene2 --> GenImg2[🖼️ 生成分镜图]
    Scene3 --> GenImg3[🖼️ 生成分镜图]
    Scene4 --> GenImg4[🖼️ 生成分镜图]
    Scene5 --> GenImg5[🖼️ 生成分镜图]
    Scene6 --> GenImg6[🖼️ 生成分镜图]
    Scene7 --> GenImg7[🖼️ 生成分镜图]

    GenImg1 --> GenVid1[🎬 生成视频]
    GenImg2 --> GenVid2[🎬 生成视频]
    GenImg3 --> GenVid3[🎬 生成视频]
    GenImg4 --> GenVid4[🎬 生成视频]
    GenImg5 --> GenVid5[🎬 生成视频]
    GenImg6 --> GenVid6[🎬 生成视频]
    GenImg7 --> GenVid7[🎬 生成视频]

    GenVid1 --> AllDone[✅ 所有场景生成完成]
    GenVid2 --> AllDone
    GenVid3 --> AllDone
    GenVid4 --> AllDone
    GenVid5 --> AllDone
    GenVid6 --> AllDone
    GenVid7 --> AllDone

    AllDone --> WantMerge{需要合并视频?}

    WantMerge -->|是| MergeVideos[🔗 步骤5: 合并视频]
    WantMerge -->|否| ShowResult[📺 查看各场景视频]

    MergeVideos --> SaveGallery[💾 保存到相册]
    ShowGallery --> SaveGallery[💾 保存到相册]
    SaveGallery --> End([流程结束])

    %% 样式定义
    classDef startEnd fill:#ec4899,stroke:#be185d,color:#fff
    classDef process fill:#3b82f6,stroke:#2563eb,color:#fff
    classDef decision fill:#f59e0b,stroke:#d97706,color:#fff
    classDef api fill:#8b5cf6,stroke:#7c3aed,color:#fff
    classDef scene fill:#10b981,stroke:#059669,color:#fff

    class Start,End startEnd
    class GenerateDraft,GenerateChar,StartGeneration,MergeVideos,SaveGallery process
    class CheckIntent,UserConfirm,WantMerge decision
    class GLMCall1,GLMReturn1,CharSheets api
    class Scene1,Scene2,Scene3,Scene4,Scene5,Scene6,Scene7 scene
```

---

## 🔍 详细步骤说明

### 步骤 1️⃣: 生成剧本草稿
**AI 思考**: "用户想要一个关于做蛋糕的视频，我需要设计一个完整的故事"

| 操作 | 说明 |
|------|------|
| 输入 | "生成一个小姐姐做草莓蛋糕的视频" |
| 调用 | 智谱 GLM-4.7 AI |
| 输出 | 7个场景的剧本，每个场景包含：<br>- 中文旁白<br>- 情绪描述<br>- 图片生成提示词<br>- 视频动效提示词 |

**剧本示例**:
```json
{
  "title": "草莓蛋糕制作",
  "scenes": [
    {
      "scene_id": 1,
      "narration": "今天要做美味的草莓蛋糕",
      "image_prompt": "A cute girl in kitchen, preparing to make strawberry cake",
      "video_prompt": "Girl tying apron, smiling at camera"
    },
    // ... 更多场景
  ]
}
```

---

### 步骤 2️⃣: 生成角色设定
**目标**: 确保所有场景中的"小姐姐"长得一样

| 操作 | 说明 |
|------|------|
| 技术方案 | 生成一张"角色三视图"图片<br/>（正面 + 侧面 + 背面） |
| 作用 | 后续所有场景都用这张图做参考<br/>实现"图生图"保持人物一致 |

```
┌─────────────────────────────────────┐
│     角色三视图参考图                 │
│  ┌──────┐  ┌──────┐  ┌──────┐      │
│  │ 正面 │  │ 侧面 │  │ 背面 │      │
│  │      │  │      │  │      │      │
│  └──────┘  └──────┘  └──────┘      │
└─────────────────────────────────────┘
```

---

### 步骤 3️⃣: 展示剧本预览
**用户可以**:
- ✅ 确认剧本，开始生成
- ✏️ 修改某些场景
- 🔄 重新生成整个剧本

---

### 步骤 4️⃣: 开始生成内容

#### 4.1 生成分镜图
每个场景独立生成图片：

| 场景 | 图片内容 | 技术说明 |
|------|----------|----------|
| 场景1 | 小姐姐走进厨房，系上围裙 | 使用角色三视图做参考 |
| 场景2 | 准备面粉、鸡蛋、草莓 | 使用角色三视图做参考 |
| 场景3 | 混合材料，搅拌均匀 | 使用角色三视图做参考 |
| 场景4 | 打发奶油 | 使用角色三视图做参考 |
| 场景5 | 装饰草莓 | 使用角色三视图做参考 |
| 场景6 | 切开蛋糕 | 使用角色三视图做参考 |
| 场景7 | 品尝蛋糕，露出满意的笑容 | 使用角色三视图做参考 |

**并发处理**: 同时生成2个场景的图片，提高速度

#### 4.2 生成视频
将每张分镜图变成动态视频：

| 操作 | 说明 |
|------|------|
| 输入 | 分镜图 + 视频动效提示词 |
| 调用 | Tuzi Sora AI 视频生成 |
| 时长 | 每个视频约5秒 |
| 等待 | 轮询查询生成状态（约1-2分钟） |

**视频生成参考图**:
- 角色三视图（保持人物一致）
- 当前场景的分镜图
- 最多支持3张参考图

---

### 步骤 5️⃣: 合并视频（可选）
**技术方案**: Android 原生方法使用 Mp4Parser

```
场景1视频 (5秒) ──┐
场景2视频 (5秒) ──┤
场景3视频 (5秒) ──┤
场景4视频 (5秒) ──┼──► [无损合并] ──► 完整视频 (35秒)
场景5视频 (5秒) ──┤
场景6视频 (5秒) ──┤
场景7视频 (5秒) ──┘
```

**特点**:
- ✅ 无损合并，不重新编码
- ✅ 保持原始画质
- ✅ 完美衔接各场景

---

### 保存到相册
合并后的视频保存到手机的 `Movies/Movies` 文件夹

---

## 🎬 技术架构图

```mermaid
graph TB
    subgraph 用户界面
        ChatScreen[ChatScreen<br/>聊天界面]
        ScreenplayReview[剧本预览页面]
        ScenePlayer[场景播放器]
    end

    subgraph 状态管理
        ChatProvider[ChatProvider<br/>协调整体流程]
        VideoMergeProvider[VideoMergeProvider<br/>视频合并状态]
    end

    subgraph 业务逻辑
        DraftController[DraftController<br/>剧本生成]
        ScreenplayController[ScreenplayController<br/>场景生成]
        VideoMergerService[VideoMergerService<br/>视频合并]
    end

    subgraph API服务
        GLM[智谱 GLM-4.7<br/>剧本生成]
        Gemini[Gemini AI<br/>图片生成]
        Sora[Tuzi Sora<br/>视频生成]
        Doubao[豆包 ARK<br/>图片识别]
    end

    subgraph 原生能力
        MediaMuxer[Android MediaMuxer<br/>视频合并]
        MediaStore[MediaStore<br/>相册保存]
    end

    ChatScreen --> ChatProvider
    ScreenplayReview --> ChatProvider
    ScenePlayer --> VideoMergeProvider

    ChatProvider --> DraftController
    ChatProvider --> ScreenplayController
    ChatProvider --> VideoMergerService

    DraftController --> GLM
    ScreenplayController --> Gemini
    ScreenplayController --> Sora
    DraftController --> Doubao

    VideoMergerService --> MediaMuxer
    VideoMergerService --> MediaStore

    classDef ui fill:#ec4899,stroke:#be185d,color:#fff
    classDef state fill:#3b82f6,stroke:#2563eb,color:#fff
    classDef logic fill:#f59e0b,stroke:#d97706,color:#fff
    classDef api fill:#8b5cf6,stroke:#7c3aed,color:#fff
    classDef native fill:#10b981,stroke:#059669,color:#fff

    class ChatScreen,ScreenplayReview,ScenePlayer ui
    class ChatProvider,VideoMergeProvider state
    class DraftController,ScreenplayController,VideoMergerService logic
    class GLM,Gemini,Sora,Doubao api
    class MediaMuxer,MediaStore native
```

---

## 🔄 数据流转

```mermaid
sequenceDiagram
    participant U as 👤 用户
    participant C as 📱 ChatScreen
    participant P as 🎛️ ChatProvider
    participant D as 📝 DraftController
    participant G as 🤖 GLM-4.7
    participant S as 🎨 ScreenplayController
    participant I as 🖼️ Gemini
    participant V as 🎬 Sora

    U->>C: 输入: "生成做蛋糕视频"
    C->>P: generateDraft()
    P->>D: generateDraft()
    D->>G: 请求剧本生成
    G-->>D: 返回剧本 JSON
    D-->>P: 剧本草稿
    P-->>C: 展示预览

    U->>C: 确认剧本
    C->>P: confirmDraft()
    P->>S: generateFromConfirmed()

    loop 每个场景
        S->>I: 生成场景图片
        I-->>S: 图片URL
        S->>V: 生成视频
        V-->>S: 轮询:处理中
        V-->>S: 轮询:完成
    end

    S-->>P: 所有场景完成
    P-->>C: 展示结果
```

---

## 📊 关键数据模型

### 剧本 (Screenplay)
```dart
{
  "taskId": "唯一ID",
  "scriptTitle": "草莓蛋糕制作",
  "status": "completed",
  "scenes": [
    {
      "sceneId": 1,
      "narration": "今天要做美味的草莓蛋糕",
      "imageUrl": "https://...",
      "videoUrl": "https://...",
      "status": "completed"
    }
  ]
}
```

### 角色设定 (CharacterSheet)
```dart
{
  "characterId": "char_001",
  "characterName": "草莓女孩",
  "combinedViewUrl": "https://...", // 三视图图片
  "referenceImageUrl": "https://..." // 用于图生图
}
```

---

## ⚙️ 配置说明

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 场景数量 | 7 | 每个剧本包含的场景数 |
| 并发生成数 | 2 | 同时生成的场景数量 |
| 视频时长 | 5秒 | 每个场景视频的时长 |
| 轮询超时 | 10分钟 | 视频生成最长等待时间 |

---

## 🎯 总结

整个流程就像一个**数字化的电影制作团队**：

1. **编剧** (GLM-4.7): 编写剧本
2. **美术设计** (Gemini): 设计分镜图
3. **摄影师** (Sora): 拍摄视频片段
4. **剪辑师** (MediaMuxer): 合成完整视频
5. **发行商** (MediaStore): 保存到相册

你只需要一句话，AI 就能完成从创意到成片的全部工作！🎬
