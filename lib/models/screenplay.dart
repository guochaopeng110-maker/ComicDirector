import 'script.dart';

/// 剧本状态枚举
/// 用于跟踪剧本在生成流程中的阶段
enum ScreenplayStatus {
  drafting,      // 草稿阶段，等待用户确认
  confirmed,     // 用户已确认，开始生成图片/视频
  generating,    // 正在生成图片/视频
  completed,     // 全部完成
  failed,        // 生成失败
}

/// 剧本数据模型
/// 包含多个场景的完整剧本结构
class Screenplay {
  final String taskId;
  final String scriptTitle;
  final List<Scene> scenes;
  final ScreenplayStatus status; // 剧本状态

  Screenplay({
    required this.taskId,
    required this.scriptTitle,
    required this.scenes,
    this.status = ScreenplayStatus.drafting, // 默认为草稿状态
  });

  /// 从 JSON 创建 Screenplay
  factory Screenplay.fromJson(Map<String, dynamic> json) {
    final scenesList = json['scenes'] as List<dynamic>?;
    return Screenplay(
      taskId: json['task_id'] as String,
      scriptTitle: json['script_title'] as String,
      scenes: scenesList
              ?.map((sceneJson) => Scene.fromJson(sceneJson as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status'] != null
          ? _parseStatus(json['status'] as String)
          : ScreenplayStatus.drafting,
    );
  }

  /// 解析状态字符串
  static ScreenplayStatus _parseStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'drafting':
        return ScreenplayStatus.drafting;
      case 'confirmed':
        return ScreenplayStatus.confirmed;
      case 'generating':
        return ScreenplayStatus.generating;
      case 'completed':
        return ScreenplayStatus.completed;
      case 'failed':
        return ScreenplayStatus.failed;
      default:
        return ScreenplayStatus.drafting;
    }
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'script_title': scriptTitle,
      'scenes': scenes.map((scene) => scene.toJson()).toList(),
      'status': status.name,
    };
  }

  /// 获取总进度 (0.0 - 1.0)
  double get progress {
    if (scenes.isEmpty) return 0.0;
    int totalSteps = scenes.length * 2; // 每个场景: 图片 + 视频
    int completedSteps = 0;

    for (final scene in scenes) {
      switch (scene.status) {
        case SceneStatus.pending:
          break;
        case SceneStatus.imageGenerating:
          completedSteps += 1; // 图片算一半
          break;
        case SceneStatus.imageCompleted:
          completedSteps += 1;
          break;
        case SceneStatus.videoGenerating:
          completedSteps += 2; // 图片完成 + 视频一半
          break;
        case SceneStatus.completed:
          completedSteps += 2;
          break;
        case SceneStatus.failed:
          completedSteps += 0;
          break;
      }
    }

    return completedSteps / totalSteps;
  }

  /// 获取当前状态描述
  String get statusDescription {
    if (status == ScreenplayStatus.drafting) {
      return '剧本草稿，等待确认';
    }
    if (status == ScreenplayStatus.failed) {
      return '生成失败';
    }

    final pendingCount = scenes.where((s) => s.status == SceneStatus.pending).length;
    final imageGeneratingCount = scenes.where((s) => s.status == SceneStatus.imageGenerating).length;
    final videoGeneratingCount = scenes.where((s) => s.status == SceneStatus.videoGenerating).length;
    final completedCount = scenes.where((s) => s.status == SceneStatus.completed).length;
    final failedCount = scenes.where((s) => s.status == SceneStatus.failed).length;

    if (failedCount > 0) {
      return '部分场景失败 ($failedCount/${scenes.length})';
    }
    if (completedCount == scenes.length) {
      return '全部完成！';
    }
    if (videoGeneratingCount > 0) {
      return '正在生成视频 ($completedCount/${scenes.length} 完成)';
    }
    if (imageGeneratingCount > 0) {
      return '正在生成图片 ($completedCount/${scenes.length} 完成)';
    }
    if (pendingCount == scenes.length) {
      return '准备开始...';
    }
    return '处理中...';
  }

  /// 复制并更新部分字段
  Screenplay copyWith({
    String? taskId,
    String? scriptTitle,
    List<Scene>? scenes,
    ScreenplayStatus? status,
  }) {
    return Screenplay(
      taskId: taskId ?? this.taskId,
      scriptTitle: scriptTitle ?? this.scriptTitle,
      scenes: scenes ?? this.scenes,
      status: status ?? this.status,
    );
  }

  /// 更新指定场景
  Screenplay updateScene(int sceneId, Scene updatedScene) {
    final newScenes = scenes.map((scene) {
      return scene.sceneId == sceneId ? updatedScene : scene;
    }).toList();

    return copyWith(scenes: newScenes);
  }

  /// 更新剧本状态
  Screenplay updateStatus(ScreenplayStatus newStatus) {
    return copyWith(status: newStatus);
  }

  /// 获取下一个待处理的场景
  Scene? getNextPendingScene() {
    for (final scene in scenes) {
      if (scene.status == SceneStatus.pending) {
        return scene;
      }
    }
    return null;
  }

  /// 获取下一个待生成视频的场景（图片已生成）
  Scene? getNextSceneForVideo() {
    for (final scene in scenes) {
      if (scene.status == SceneStatus.imageCompleted) {
        return scene;
      }
    }
    return null;
  }

  /// 是否全部完成
  bool get isAllCompleted {
    return scenes.every((scene) => scene.status == SceneStatus.completed);
  }

  /// 是否有失败的场景
  bool get hasFailed {
    return scenes.any((scene) => scene.status == SceneStatus.failed);
  }
}
