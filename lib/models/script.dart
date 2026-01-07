/// 剧本场景数据模型
class Scene {
  final int sceneId;
  final String narration; // 中文旁白
  final String imagePrompt; // 生图提示词（英文）
  final String videoPrompt; // 视频动效提示词（英文）
  final String characterDescription; // 人物特征描述（用于保持一致性）
  String? imageUrl; // 生成的图片 URL
  String? videoUrl; // 生成的视频 URL
  SceneStatus status;
  String? customVideoPrompt; // 用户自定义的视频提示词（用于重试时调整）

  Scene({
    required this.sceneId,
    required this.narration,
    required this.imagePrompt,
    required this.videoPrompt,
    required this.characterDescription,
    this.imageUrl,
    this.videoUrl,
    this.status = SceneStatus.pending,
    this.customVideoPrompt,
  });

  /// 从 JSON 创建 Scene
  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      sceneId: json['scene_id'] as int,
      narration: json['narration'] as String,
      imagePrompt: json['image_prompt'] as String,
      videoPrompt: json['video_prompt'] as String,
      characterDescription: json['character_description'] as String? ??
          (json['characterDescription'] as String? ?? ''), // 兼容驼峰命名
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      status: _parseStatus(json['status'] as String? ?? 'pending'),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'scene_id': sceneId,
      'narration': narration,
      'image_prompt': imagePrompt,
      'video_prompt': videoPrompt,
      'character_description': characterDescription,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'status': status.value,
    };
  }

  /// 复制并更新部分字段
  Scene copyWith({
    int? sceneId,
    String? narration,
    String? imagePrompt,
    String? videoPrompt,
    String? characterDescription,
    String? imageUrl,
    String? videoUrl,
    SceneStatus? status,
    String? customVideoPrompt,
  }) {
    return Scene(
      sceneId: sceneId ?? this.sceneId,
      narration: narration ?? this.narration,
      imagePrompt: imagePrompt ?? this.imagePrompt,
      videoPrompt: videoPrompt ?? this.videoPrompt,
      characterDescription: characterDescription ?? this.characterDescription,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      status: status ?? this.status,
      customVideoPrompt: customVideoPrompt ?? this.customVideoPrompt,
    );
  }

  static SceneStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return SceneStatus.pending;
      case 'image_generating':
        return SceneStatus.imageGenerating;
      case 'image_completed':
        return SceneStatus.imageCompleted;
      case 'video_generating':
        return SceneStatus.videoGenerating;
      case 'completed':
        return SceneStatus.completed;
      case 'failed':
        return SceneStatus.failed;
      default:
        return SceneStatus.pending;
    }
  }
}

/// 场景状态枚举
enum SceneStatus {
  pending,          // 等待处理
  imageGenerating,  // 正在生成图片
  imageCompleted,   // 图片生成完成
  videoGenerating,  // 正在生成视频
  completed,        // 全部完成
  failed,           // 失败
}

extension SceneStatusExtension on SceneStatus {
  String get value {
    switch (this) {
      case SceneStatus.pending:
        return 'pending';
      case SceneStatus.imageGenerating:
        return 'image_generating';
      case SceneStatus.imageCompleted:
        return 'image_completed';
      case SceneStatus.videoGenerating:
        return 'video_generating';
      case SceneStatus.completed:
        return 'completed';
      case SceneStatus.failed:
        return 'failed';
    }
  }

  String get displayName {
    switch (this) {
      case SceneStatus.pending:
        return '等待中';
      case SceneStatus.imageGenerating:
        return '生成图片中';
      case SceneStatus.imageCompleted:
        return '图片已完成';
      case SceneStatus.videoGenerating:
        return '生成视频中';
      case SceneStatus.completed:
        return '已完成';
      case SceneStatus.failed:
        return '失败';
    }
  }
}
