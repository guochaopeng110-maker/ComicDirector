# 文档完善计划

## 1. 目标
精简并扩展 `docs/03_api` 和 `docs/04_manuals` 中的文档，以准确反映当前项目状态（Flutter + Provider + 多模型 AI 智能体）。

## 2. `docs/03_api` 改进
**目标**：从单一的“图像 API”文档转变为全面的 API 参考手册。

### 2.1 新增文件
*   **`api_architecture.md` (API 架构)**:
    *   解释 `ApiService` 类的角色。
    *   绘制交互图：`AgentController` -> `ApiService` -> 外部提供商 (智谱, Tuzi, 豆包)。
    *   解释聊天的“流式 (Stream)”处理和视频的“轮询 (Polling)”机制。
*   **`external_services.md` (外部服务)**:
    *   列出所有第三方服务：
        *   **智谱 AI (GLM-4.7)**: 用于推理和剧本生成。
        *   **Tuzi API (Gemini/Veo)**: 用于图像和视频生成。
        *   **火山引擎 (豆包)**: 用于图像理解。
    *   记录代码中使用的基础 URL 和模型名称 (`veo3.1-components`, `gemini-2.5-flash-image-vip` 等)。
*   **`data_models.md` (数据模型)**:
    *   记录核心 JSON 结构：`Screenplay`, `Scene`, `CharacterSheet`, `AgentCommand`。

### 2.2 更新
*   **`image_generation_api.md`**: 重命名为 `tuzi_api_reference.md` 并扩展内容，覆盖 Tuzi 提供的图像和视频端点。

## 3. `docs/04_manuals` 改进
**目标**：将“开发者指南”与“用户指南”分离。

### 3.1 新增文件
*   **`user_guide.md` (用户指南)**:
    *   如何使用应用：聊天、剧本预览、视频生成、画廊。
    *   为非技术用户解释“智能体”工作流。
*   **`configuration_reference.md` (配置参考)**:
    *   详细解释 `ApiConfigService`。
    *   解释内部标志，如 `concurrentScenes`, `USE_MOCK_VIDEO_API`。

### 3.2 更新
*   **`deploy/development_guide.md`**: 保留作为开发者的主要入口。链接到 `configuration_reference.md`。
*   **`deploy/api_key_setup.md`**: 合并入 `configuration_reference.md` 或保留为特定的“入门”步骤。（建议：为了清晰起见，保留为 `setup_api_keys.md`）。

## 4. 执行步骤
1.  **重构 `03_api`**:
    *   创建 `api_architecture.md`。
    *   创建 `external_services.md`。
    *   重命名并更新 `image_generation_api.md` -> `tuzi_api_reference.md`。
2.  **重构 `04_manuals`**:
    *   创建 `user_guide.md`。
    *   创建 `configuration_reference.md`。
    *   更新 `deploy/development_guide.md` 中的链接。
