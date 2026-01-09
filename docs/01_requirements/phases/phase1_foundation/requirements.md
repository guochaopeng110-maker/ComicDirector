# 第一阶段需求文档：基石 (The Foundation)

> **周期**: 4 周  
> **目标**: 技术债务清理 + 基础设施升级，为后续功能开发打下坚实基础

---

## 1. 阶段概述

第一阶段分为两个子阶段：

| 子阶段 | 名称 | 周期 | 核心目标 |
|--------|------|------|----------|
| 1A | 技术债务清理 | 2周 | 代码可维护性提升 |
| 1B | 基础设施升级 | 2周 | 跨平台能力 + 稳定性 |

---

## 2. 阶段 1A：技术债务清理 (2周)

### 2.1 任务 #1: `api_service.dart` 拆分

**优先级**: P0  
**关联**: 工程稳健性 1.4

#### 2.1.1 现状分析

- 文件路径: `lib/services/api_service.dart`
- 当前大小: ~92KB, 3000+ 行
- 问题: 
  - 所有 API 调用混杂在单一文件
  - 难以维护和测试
  - 新增模型提供商困难

#### 2.1.2 目标状态

```
lib/services/
├── api/
│   ├── api_client.dart          # 基础 HTTP 客户端封装
│   ├── api_config.dart          # API 配置管理
│   ├── interceptors/
│   │   ├── auth_interceptor.dart
│   │   ├── error_interceptor.dart
│   │   └── logging_interceptor.dart
│   ├── models/
│   │   ├── api_response.dart
│   │   └── api_error.dart
│   └── providers/
│       ├── base_provider.dart   # 抽象接口
│       ├── glm_provider.dart    # 智谱 GLM
│       ├── gemini_provider.dart # Google Gemini (图片)
│       ├── veo_provider.dart    # Google Veo (视频)
│       └── doubao_provider.dart # 字节豆包
└── api_service.dart             # 精简后的门面类
```

#### 2.1.3 验收标准

- [ ] 单个文件 < 500 行
- [ ] 每个 Provider 可独立测试
- [ ] 保持向后兼容，外部调用方式不变
- [ ] 新增模型只需添加新 Provider

#### 2.1.4 技术方案

1. **抽象接口定义**
```dart
abstract class ImageGeneratorProvider {
  Future<String> generateImage({
    required String prompt,
    String? referenceImageUrl,
    Map<String, dynamic>? options,
  });
}

abstract class VideoGeneratorProvider {
  Future<String> generateVideo({
    required String imageUrl,
    required String motionPrompt,
    Map<String, dynamic>? options,
  });
}
```

2. **Provider 实现示例**
```dart
class GeminiImageProvider implements ImageGeneratorProvider {
  final ApiClient _client;
  final String _apiKey;
  
  @override
  Future<String> generateImage({...}) async {
    // Gemini 特定实现
  }
}
```

---

### 2.2 任务 #2: `ScreenplayController` 职责分离

**优先级**: P0  
**关联**: 工程稳健性 1.3

#### 2.2.1 现状分析

- 文件路径: `lib/controllers/screenplay_controller.dart`
- 当前大小: 1040+ 行
- 问题:
  - 剧本生成、图片生成、视频生成、状态管理全部混杂
  - 难以进行单元测试
  - 错误处理逻辑重复

#### 2.2.2 目标状态

```
lib/controllers/
├── screenplay/
│   ├── screenplay_orchestrator.dart    # 流程编排 (主入口)
│   ├── script_generator.dart           # 剧本生成
│   ├── image_generator_controller.dart # 图片生成
│   ├── video_generator_controller.dart # 视频生成
│   └── generation_state_machine.dart   # 状态机
└── screenplay_controller.dart          # 保留为兼容层
```

#### 2.2.3 验收标准

- [ ] 每个控制器职责单一
- [ ] 状态变化可追踪
- [ ] 支持断点续生成 (Resumable)
- [ ] 原有外部调用保持兼容

#### 2.2.4 状态机设计

```dart
enum GenerationState {
  idle,
  scriptGenerating,
  scriptReady,
  imagesGenerating,
  imagesReady,
  videosGenerating,
  videosReady,
  merging,
  complete,
  error,
}

class GenerationStateMachine {
  GenerationState _state = GenerationState.idle;
  
  void transition(GenerationEvent event) {
    // 状态转换逻辑
  }
  
  bool canRetryFrom(GenerationState state) {
    // 支持从任意状态重试
  }
}
```

---

### 2.3 任务 #3: `chat_screen.dart` 重构

**优先级**: P0

#### 2.3.1 现状分析

- 文件路径: `lib/screens/chat_screen.dart`
- 当前大小: ~108KB
- 问题:
  - UI 逻辑与业务逻辑耦合
  - 组件无法复用
  - 难以修改 UI 细节

#### 2.3.2 目标状态

```
lib/screens/chat/
├── chat_screen.dart                # 主屏幕 (精简)
├── widgets/
│   ├── chat_input_bar.dart         # 输入栏
│   ├── message_list.dart           # 消息列表
│   ├── message_bubble.dart         # 消息气泡
│   ├── media_preview_card.dart     # 媒体预览卡片
│   ├── generation_progress.dart    # 生成进度
│   └── screenplay_preview.dart     # 剧本预览
└── controllers/
    └── chat_view_controller.dart   # 视图控制器
```

#### 2.3.3 验收标准

- [ ] 主文件 < 300 行
- [ ] 组件可独立使用
- [ ] 支持 Widget 测试

---

### 2.4 任务 #4: 清理废弃代码

**优先级**: P1

#### 2.4.1 待清理项目

| 类型 | 位置 | 说明 |
|------|------|------|
| `@Deprecated` 属性 | 模型类 | 已标记但未删除的属性 |
| 注释依赖 | `pubspec.yaml` | 被注释的包 |
| 未使用导入 | 全局 | `dart analyze` 发现 |
| 死代码 | 多处 | 永不执行的分支 |

#### 2.4.2 操作步骤

1. 运行 `flutter analyze` 收集警告
2. 使用 IDE 的 "Organize Imports" 清理导入
3. 删除 `@Deprecated` 标记代码
4. 清理 `pubspec.yaml` 中的注释依赖

---

## 3. 阶段 1B：基础设施升级 (2周)

### 3.1 任务 #5: 视频合成引擎替换 (FFmpeg)

**优先级**: P0  
**关联**: 工程稳健性 1.1

#### 3.1.1 现状分析

- 当前方案: Android `MediaMuxer` 通过 `MethodChannel`
- 局限性:
  - 仅支持 Android
  - 功能有限 (无转场、字幕)
  - 编码格式受限

#### 3.1.2 技术选型

| 方案 | 包名 | 优点 | 缺点 |
|------|------|------|------|
| FFmpeg Kit | `ffmpeg_kit_flutter_full` | 功能完整 | 包体积较大 (~100MB) |
| FFmpeg Kit Min | `ffmpeg_kit_flutter_min` | 轻量 | 缺少部分编码器 |

**推荐**: `ffmpeg_kit_flutter_full`，完整的滤镜和编码器支持

#### 3.1.3 实现计划

```dart
class FFmpegVideoMerger implements VideoMerger {
  Future<String> mergeVideos(List<String> videoPaths, {
    TransitionType transition = TransitionType.fade,
    String? bgmPath,
    String? subtitlePath,
  }) async {
    final ffmpegCommand = _buildMergeCommand(
      inputs: videoPaths,
      transition: transition,
      bgm: bgmPath,
      subtitle: subtitlePath,
    );
    
    await FFmpegKit.execute(ffmpegCommand);
    return outputPath;
  }
}
```

#### 3.1.4 验收标准

- [ ] iOS 成功合并视频
- [ ] macOS/Windows 桌面端可用
- [ ] 合成成功率 > 99%
- [ ] 支持至少 3 种转场效果

---

### 3.2 任务 #6: 数据层重构 (SQLite/Isar)

**优先级**: P0  
**关联**: 工程稳健性 1.2

#### 3.2.1 现状分析

- 当前方案: Hive + SharedPreferences
- 局限性:
  - 复杂查询困难
  - 数据量大时性能下降
  - 无事务支持

#### 3.2.2 技术选型

| 方案 | 类型 | 优点 | 缺点 |
|------|------|------|------|
| Drift (moor) | SQLite | 强类型查询、复杂关系 | 学习曲线 |
| Isar | NoSQL | 极快、自动索引 | 关系查询弱 |

**推荐**: `Drift` (SQLite)，项目有结构化数据需求

#### 3.2.3 数据模型设计

```dart
// 项目表
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// 场景表
class Scenes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get narration => text()();
  TextColumn get imagePrompt => text()();
  TextColumn get videoPrompt => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get videoUrl => text().nullable()();
  TextColumn get status => text()();
}

// 角色表
class Characters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get sheetImageUrl => text().nullable()();
}
```

#### 3.2.4 验收标准

- [ ] 现有数据迁移成功
- [ ] 支持多项目管理
- [ ] 历史记录可搜索
- [ ] 列表加载 < 100ms

---

### 3.3 任务 #7: 测试框架搭建

**优先级**: P1  
**关联**: 工程稳健性 1.5

#### 3.3.1 测试策略

| 测试类型 | 覆盖范围 | 目标覆盖率 |
|----------|----------|------------|
| 单元测试 | 控制器、服务、模型 | 80% |
| Widget 测试 | 关键 UI 组件 | 60% |
| 集成测试 | 核心流程 | 关键路径 |

#### 3.3.2 测试目录结构

```
test/
├── unit/
│   ├── controllers/
│   ├── services/
│   └── models/
├── widget/
│   └── screens/
├── integration/
│   └── generation_flow_test.dart
├── mocks/
│   ├── mock_api_service.dart
│   └── mock_providers.dart
└── fixtures/
    └── sample_screenplay.json
```

#### 3.3.3 关键测试用例

```dart
// 剧本解析测试
void main() {
  group('ScreenplayParser', () {
    test('should parse valid JSON', () {
      final json = fixture('sample_screenplay.json');
      final screenplay = ScreenplayParser.parse(json);
      
      expect(screenplay.scenes.length, 7);
      expect(screenplay.title, isNotEmpty);
    });
    
    test('should throw on invalid JSON', () {
      expect(
        () => ScreenplayParser.parse('invalid'),
        throwsA(isA<ParseException>()),
      );
    });
  });
}
```

#### 3.3.4 验收标准

- [ ] 单元测试覆盖率 > 50%
- [ ] CI 集成测试通过
- [ ] 测试可在本地运行 `flutter test`

---

### 3.4 任务 #8: 安全存储升级

**优先级**: P1  
**关联**: 工程稳健性 1.7

#### 3.4.1 现状分析

- 当前方案: `SharedPreferences` 明文存储 API Token
- 风险: 设备 root 后可读取敏感数据

#### 3.4.2 技术方案

```dart
class SecureTokenStorage {
  final FlutterSecureStorage _storage;
  
  Future<void> saveToken(String key, String token) async {
    await _storage.write(
      key: key,
      value: token,
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }
  
  Future<String?> readToken(String key) async {
    return await _storage.read(key: key);
  }
}
```

#### 3.4.3 迁移计划

1. 添加 `flutter_secure_storage` 依赖
2. 创建 `SecureTokenStorage` 服务
3. 首次启动时从 SharedPreferences 迁移
4. 删除旧的明文存储
5. 确保日志不打印敏感信息

#### 3.4.4 验收标准

- [ ] Token 加密存储
- [ ] 旧数据迁移成功
- [ ] 日志无敏感信息

---

## 4. 里程碑与成功指标

| 子阶段 | 里程碑 | 成功指标 |
|--------|--------|----------|
| 1A | 代码库可维护性提升 | 单文件 < 500 行 |
| 1A | 测试框架就绪 | 测试覆盖率 > 50% |
| 1B | iOS 版本可运行 | FFmpeg 视频合成成功率 > 99% |
| 1B | 数据层现代化 | 列表加载 < 100ms |

---

## 5. 技术依赖

### 5.1 新增依赖

```yaml
dependencies:
  # 1B: FFmpeg
  ffmpeg_kit_flutter_full: ^6.0.3
  
  # 1B: 数据库
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.18
  
  # 1B: 安全存储
  flutter_secure_storage: ^9.0.0

dev_dependencies:
  # 1A & 1B: 测试
  mockito: ^5.4.4
  build_runner: ^2.4.8
  drift_dev: ^2.14.0
```

### 5.2 移除依赖

- 无 (保持向后兼容)

---

## 6. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| FFmpeg 包体积过大 | 应用体积增加 100MB+ | 提供精简版本选项 |
| 数据迁移失败 | 用户数据丢失 | 保留旧存储作为备份 |
| 测试覆盖不足 | 后续开发信心不足 | 重点覆盖核心流程 |

---

## 7. 验收清单

### 阶段 1A 完成标准
- [ ] `api_service.dart` 拆分为 < 500 行的模块
- [ ] `ScreenplayController` 职责分离完成
- [ ] `chat_screen.dart` 组件化重构完成
- [ ] `flutter analyze` 无严重警告
- [ ] 代码 Review 通过

### 阶段 1B 完成标准
- [ ] FFmpeg 视频合成在 iOS 上运行
- [ ] Drift 数据库迁移成功
- [ ] 单元测试覆盖率 > 50%
- [ ] Token 安全存储验证通过
