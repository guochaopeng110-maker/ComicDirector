import 'character_sheet.dart';

/// 剧本草稿数据模型
/// 用于剧本确认和编辑阶段
class ScreenplayDraft {
  final String id;
  final String taskId;
  final String title;
  final String genre;
  final int estimatedDurationSeconds;
  final List<String> emotionalArc;
  final List<DraftScene> scenes;
  final DateTime createdAt;
  final String? userFeedback;
  final List<ScreenplayDraft> history;

  // 角色设定表（用于人物一致性）
  final List<CharacterSheet> characterSheets;

  ScreenplayDraft({
    required this.id,
    required this.taskId,
    required this.title,
    required this.genre,
    required this.estimatedDurationSeconds,
    required this.emotionalArc,
    required this.scenes,
    required this.createdAt,
    this.userFeedback,
    this.history = const [],
    this.characterSheets = const [],
  });

  /// 从 JSON 创建 ScreenplayDraft
  factory ScreenplayDraft.fromJson(Map<String, dynamic> json) {
    final scenesList = json['scenes'] as List<dynamic>?;
    final historyList = json['history'] as List<dynamic>?;
    final charSheetsList = json['character_sheets'] as List<dynamic>?;

    return ScreenplayDraft(
      id: json['id'] as String? ??
          'draft_${DateTime.now().millisecondsSinceEpoch}',
      taskId: json['task_id'] as String,
      title: json['title'] as String,
      genre: json['genre'] as String? ?? '剧情',
      estimatedDurationSeconds:
          json['estimated_duration_seconds'] as int? ?? 60,
      emotionalArc: (json['emotional_arc'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      scenes: scenesList
              ?.map((sceneJson) =>
                  DraftScene.fromJson(sceneJson as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      userFeedback: json['user_feedback'] as String?,
      history: historyList
              ?.map((h) => ScreenplayDraft.fromJson(h as Map<String, dynamic>))
              .toList() ??
          [],
      characterSheets: charSheetsList
              ?.map((sheetJson) =>
                  CharacterSheet.fromJson(sheetJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'title': title,
      'genre': genre,
      'estimated_duration_seconds': estimatedDurationSeconds,
      'emotional_arc': emotionalArc,
      'scenes': scenes.map((scene) => scene.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'user_feedback': userFeedback,
      'history': history.map((h) => h.toJson()).toList(),
      'character_sheets': characterSheets.map((sheet) => sheet.toJson()).toList(),
    };
  }

  /// 复制并更新部分字段
  ScreenplayDraft copyWith({
    String? id,
    String? taskId,
    String? title,
    String? genre,
    int? estimatedDurationSeconds,
    List<String>? emotionalArc,
    List<DraftScene>? scenes,
    DateTime? createdAt,
    String? userFeedback,
    List<ScreenplayDraft>? history,
    List<CharacterSheet>? characterSheets,
  }) {
    return ScreenplayDraft(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      estimatedDurationSeconds:
          estimatedDurationSeconds ?? this.estimatedDurationSeconds,
      emotionalArc: emotionalArc ?? this.emotionalArc,
      scenes: scenes ?? this.scenes,
      createdAt: createdAt ?? this.createdAt,
      userFeedback: userFeedback ?? this.userFeedback,
      history: history ?? this.history,
      characterSheets: characterSheets ?? this.characterSheets,
    );
  }

  /// 更新指定场景的旁白
  ScreenplayDraft updateSceneNarration(int sceneId, String newNarration) {
    final newScenes = scenes.map((scene) {
      return scene.sceneId == sceneId
          ? scene.copyWith(narration: newNarration)
          : scene;
    }).toList();

    return copyWith(scenes: newScenes);
  }

  /// 添加历史记录
  ScreenplayDraft withHistory(ScreenplayDraft previousDraft) {
    final newHistory = [previousDraft, ...history];
    return copyWith(history: newHistory.take(5).toList()); // 最多保留5个版本
  }

  /// 更新角色设定表
  ScreenplayDraft withCharacterSheets(List<CharacterSheet> sheets) {
    return copyWith(characterSheets: sheets);
  }

  /// 更新单个角色设定表
  ScreenplayDraft updateCharacterSheet(CharacterSheet updatedSheet) {
    final updated = List<CharacterSheet>.from(characterSheets);
    final index = updated.indexWhere((s) => s.id == updatedSheet.id);
    if (index >= 0) {
      updated[index] = updatedSheet;
    } else {
      updated.add(updatedSheet);
    }
    return copyWith(characterSheets: updated);
  }

  /// 获取场景数量
  int get sceneCount => scenes.length;

  /// 是否为空
  bool get isEmpty => scenes.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => scenes.isNotEmpty;

  /// 是否有角色设定表
  bool get hasCharacterSheets => characterSheets.isNotEmpty;

  /// 主要角色列表（前两个主角）
  List<CharacterSheet> get mainCharacters => characterSheets.take(2).toList();
}

/// 剧本草稿场景数据模型
class DraftScene {
  final int sceneId;
  final String narration;
  final String mood;
  final String? emotionalHook;
  final List<String> tags;
  final String imagePrompt;
  final String videoPrompt;
  final String characterDescription;

  DraftScene({
    required this.sceneId,
    required this.narration,
    required this.mood,
    this.emotionalHook,
    this.tags = const [],
    required this.imagePrompt,
    required this.videoPrompt,
    required this.characterDescription,
  });

  /// 从 JSON 创建 DraftScene
  factory DraftScene.fromJson(Map<String, dynamic> json) {
    return DraftScene(
      sceneId: json['scene_id'] as int,
      narration: json['narration'] as String,
      mood: json['mood'] as String? ?? '中性',
      emotionalHook: json['emotional_hook'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      imagePrompt: json['image_prompt'] as String,
      videoPrompt: json['video_prompt'] as String,
      characterDescription: json['character_description'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'scene_id': sceneId,
      'narration': narration,
      'mood': mood,
      'emotional_hook': emotionalHook,
      'tags': tags,
      'image_prompt': imagePrompt,
      'video_prompt': videoPrompt,
      'character_description': characterDescription,
    };
  }

  /// 复制并更新部分字段
  DraftScene copyWith({
    int? sceneId,
    String? narration,
    String? mood,
    String? emotionalHook,
    List<String>? tags,
    String? imagePrompt,
    String? videoPrompt,
    String? characterDescription,
  }) {
    return DraftScene(
      sceneId: sceneId ?? this.sceneId,
      narration: narration ?? this.narration,
      mood: mood ?? this.mood,
      emotionalHook: emotionalHook ?? this.emotionalHook,
      tags: tags ?? this.tags,
      imagePrompt: imagePrompt ?? this.imagePrompt,
      videoPrompt: videoPrompt ?? this.videoPrompt,
      characterDescription: characterDescription ?? this.characterDescription,
    );
  }

  /// 获取情绪颜色
  String get moodColor {
    switch (mood.toLowerCase()) {
      case '紧张':
      case '悬疑':
        return '#FF5252';
      case '温馨':
      case '幸福':
        return '#FFB74D';
      case '悲伤':
        return '#78909C';
      case '愤怒':
        return '#F44336';
      case '惊喜':
        return '#E040FB';
      case '浪漫':
        return '#F06292';
      default:
        return '#9E9E9E';
    }
  }

  /// 是否有情绪钩子
  bool get hasHook => emotionalHook != null && emotionalHook!.isNotEmpty;
}
