import 'package:flutter/material.dart';
import 'screenplay_draft.dart';
import 'screenplay.dart';
import 'character_sheet.dart';

/// 素材包数据模型
/// 包含一个项目的所有素材：剧本、角色设定、图片、视频等
class AssetPack {
  final String id;
  final String name;
  final String description;

  // 核心素材
  final ScreenplayDraft? draft;          // 剧本草稿（编辑阶段）
  final Screenplay? screenplay;          // 正式剧本（生成阶段）
  final List<CharacterSheet> characterSheets;  // 角色设定表

  // 生成的媒体资源
  final List<SceneAsset> sceneAssets;    // 场景资源（图片+视频）

  // 元数据
  final DateTime createdAt;
  final DateTime? updatedAt;
  final AssetPackStatus status;

  // 统计信息
  int get totalScenes => screenplay?.scenes.length ?? draft?.sceneCount ?? 0;
  int get completedScenes => sceneAssets.where((s) => s.isComplete).length;
  double get progress => totalScenes > 0 ? completedScenes / totalScenes : 0.0;

  AssetPack({
    required this.id,
    required this.name,
    this.description = '',
    this.draft,
    this.screenplay,
    this.characterSheets = const [],
    this.sceneAssets = const [],
    DateTime? createdAt,
    this.updatedAt,
    this.status = AssetPackStatus.drafting,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 从剧本草稿创建素材包
  factory AssetPack.fromDraft(ScreenplayDraft draft) {
    return AssetPack(
      id: 'pack_${draft.taskId}',
      name: draft.title,
      description: '《${draft.title}》素材包',
      draft: draft,
      characterSheets: draft.characterSheets,
      status: AssetPackStatus.drafting,
    );
  }

  /// 从 JSON 创建
  factory AssetPack.fromJson(Map<String, dynamic> json) {
    return AssetPack(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      draft: json['draft'] != null
          ? ScreenplayDraft.fromJson(json['draft'] as Map<String, dynamic>)
          : null,
      screenplay: json['screenplay'] != null
          ? Screenplay.fromJson(json['screenplay'] as Map<String, dynamic>)
          : null,
      characterSheets: (json['character_sheets'] as List<dynamic>?)
              ?.map((e) => CharacterSheet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sceneAssets: (json['scene_assets'] as List<dynamic>?)
              ?.map((e) => SceneAsset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      status: AssetPackStatus.values.firstWhere(
        (e) => e.toString() == 'AssetPackStatus.${json['status']}',
        orElse: () => AssetPackStatus.drafting,
      ),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'draft': draft?.toJson(),
      'screenplay': screenplay?.toJson(),
      'character_sheets': characterSheets.map((e) => e.toJson()).toList(),
      'scene_assets': sceneAssets.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'status': status.toString().split('.').last,
    };
  }

  /// 复制并更新
  AssetPack copyWith({
    String? id,
    String? name,
    String? description,
    ScreenplayDraft? draft,
    Screenplay? screenplay,
    List<CharacterSheet>? characterSheets,
    List<SceneAsset>? sceneAssets,
    DateTime? createdAt,
    DateTime? updatedAt,
    AssetPackStatus? status,
  }) {
    return AssetPack(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      draft: draft ?? this.draft,
      screenplay: screenplay ?? this.screenplay,
      characterSheets: characterSheets ?? this.characterSheets,
      sceneAssets: sceneAssets ?? this.sceneAssets,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  /// 更新角色设定表
  AssetPack withCharacterSheets(List<CharacterSheet> sheets) {
    return copyWith(
      characterSheets: sheets,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新单个场景资源
  AssetPack withSceneAsset(SceneAsset asset) {
    final updated = List<SceneAsset>.from(sceneAssets);
    final index = updated.indexWhere((s) => s.sceneId == asset.sceneId);
    if (index >= 0) {
      updated[index] = asset;
    } else {
      updated.add(asset);
    }
    return copyWith(
      sceneAssets: updated,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新状态
  AssetPack withStatus(AssetPackStatus newStatus) {
    return copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
  }

  /// 获取指定场景的资源
  SceneAsset? getSceneAsset(int sceneId) {
    try {
      return sceneAssets.firstWhere((s) => s.sceneId == sceneId);
    } catch (e) {
      return null;
    }
  }

  /// 是否可以开始生成
  bool get canStartGeneration {
    return draft != null &&
        (characterSheets.isEmpty || characterSheets.every((s) => s.isComplete));
  }

  /// 是否正在生成中
  bool get isGenerating {
    return status == AssetPackStatus.generating ||
        status == AssetPackStatus.partiallyCompleted;
  }

  /// 是否已完成
  bool get isCompleted {
    return status == AssetPackStatus.completed && progress >= 1.0;
  }
}

/// 场景资源数据模型
/// 存储单个场景的图片和视频
class SceneAsset {
  final int sceneId;
  final String? imageUrl;
  final String? videoUrl;
  final String? imagePrompt;
  final String? videoPrompt;

  // 生成状态
  bool imageGenerated;
  bool videoGenerated;

  DateTime? generatedAt;

  SceneAsset({
    required this.sceneId,
    this.imageUrl,
    this.videoUrl,
    this.imagePrompt,
    this.videoPrompt,
    this.imageGenerated = false,
    this.videoGenerated = false,
    this.generatedAt,
  });

  /// 从 JSON 创建
  factory SceneAsset.fromJson(Map<String, dynamic> json) {
    return SceneAsset(
      sceneId: json['scene_id'] as int,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      imagePrompt: json['image_prompt'] as String?,
      videoPrompt: json['video_prompt'] as String?,
      imageGenerated: json['image_generated'] as bool? ?? false,
      videoGenerated: json['video_generated'] as bool? ?? false,
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'scene_id': sceneId,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'image_prompt': imagePrompt,
      'video_prompt': videoPrompt,
      'image_generated': imageGenerated,
      'video_generated': videoGenerated,
      'generated_at': generatedAt?.toIso8601String(),
    };
  }

  /// 是否已完成（图片+视频）
  bool get isComplete => imageGenerated && videoGenerated;

  /// 进度 (0.0 - 1.0)
  double get progress {
    int completed = 0;
    if (imageGenerated) completed++;
    if (videoGenerated) completed++;
    return completed / 2;
  }

  /// 更新图片
  SceneAsset withImage(String url, String prompt) {
    return SceneAsset(
      sceneId: sceneId,
      imageUrl: url,
      videoUrl: videoUrl,
      imagePrompt: prompt,
      videoPrompt: videoPrompt,
      imageGenerated: true,
      videoGenerated: videoGenerated,
      generatedAt: DateTime.now(),
    );
  }

  /// 更新视频
  SceneAsset withVideo(String url, String prompt) {
    return SceneAsset(
      sceneId: sceneId,
      imageUrl: imageUrl,
      videoUrl: url,
      imagePrompt: imagePrompt,
      videoPrompt: prompt,
      imageGenerated: imageGenerated,
      videoGenerated: true,
      generatedAt: DateTime.now(),
    );
  }
}

/// 素材包状态
enum AssetPackStatus {
  drafting,              // 草稿阶段，正在编辑剧本
  ready,                 // 准备就绪，可以开始生成
  generating,            // 正在生成中
  partiallyCompleted,    // 部分完成
  completed,             // 全部完成
  failed,                // 生成失败
}

/// 素材包状态扩展
extension AssetPackStatusExtension on AssetPackStatus {
  String get displayName {
    switch (this) {
      case AssetPackStatus.drafting:
        return '编辑中';
      case AssetPackStatus.ready:
        return '准备就绪';
      case AssetPackStatus.generating:
        return '生成中';
      case AssetPackStatus.partiallyCompleted:
        return '部分完成';
      case AssetPackStatus.completed:
        return '已完成';
      case AssetPackStatus.failed:
        return '失败';
    }
  }

  String get icon {
    switch (this) {
      case AssetPackStatus.drafting:
        return '✏️';
      case AssetPackStatus.ready:
        return '✅';
      case AssetPackStatus.generating:
        return '🔄';
      case AssetPackStatus.partiallyCompleted:
        return '⚡';
      case AssetPackStatus.completed:
        return '🎉';
      case AssetPackStatus.failed:
        return '❌';
    }
  }

  Color get color {
    switch (this) {
      case AssetPackStatus.drafting:
        return const Color(0xFF9E9E9E);
      case AssetPackStatus.ready:
        return const Color(0xFF4CAF50);
      case AssetPackStatus.generating:
        return const Color(0xFF2196F3);
      case AssetPackStatus.partiallyCompleted:
        return const Color(0xFFFF9800);
      case AssetPackStatus.completed:
        return const Color(0xFF4CAF50);
      case AssetPackStatus.failed:
        return const Color(0xFFF44336);
    }
  }
}
