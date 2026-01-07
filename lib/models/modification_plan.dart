import 'dart:convert';

/// 素材修改计划数据模型
/// 用于存储 AI 分析后的修改意图
class ModificationPlan {
  final String type;        // 修改类型
  final String target;      // 修改目标
  final String changes;     // 修改内容描述
  final int? sceneId;       // 场景ID（如果是场景修改）
  final String? newContent;  // 新的内容

  ModificationPlan({
    required this.type,
    required this.target,
    required this.changes,
    this.sceneId,
    this.newContent,
  });

  /// 从 JSON 创建
  factory ModificationPlan.fromJson(Map<String, dynamic> json) {
    return ModificationPlan(
      type: json['type'] as String? ?? 'unknown',
      target: json['target'] as String? ?? 'unknown',
      changes: json['changes'] as String? ?? '',
      sceneId: json['scene_id'] as int?,
      newContent: json['new_content'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'target': target,
      'changes': changes,
      if (sceneId != null) 'scene_id': sceneId,
      if (newContent != null) 'new_content': newContent,
    };
  }

  /// 是否是场景旁白修改
  bool get isSceneNarration => type == 'scene_narration';

  /// 是否是角色描述修改
  bool get isCharacterDescription => type == 'character_description';

  /// 是否是图片提示词修改
  bool get isImagePrompt => type == 'image_prompt';

  /// 是否是视频提示词修改
  bool get isVideoPrompt => type == 'video_prompt';

  @override
  String toString() {
    return 'ModificationPlan(type: $type, target: $target, sceneId: $sceneId)';
  }
}
