/// 角色设定表数据模型
/// 用于确保人物一致性，包含角色的三视图（合并为单张图片）
class CharacterSheet {
  final String id;
  final String characterId;      // 角色ID（从剧本场景中提取）
  final String characterName;     // 角色名称
  final String description;       // 角色描述
  final String role;              // 角色：第一主角/第二主角/配角等

  // 三视图组合图片URL（一张图包含正面、侧面、背面三个视角）
  String? combinedViewUrl;

  // 兼容旧版：单独的三视图URL（已废弃，保留用于兼容）
  @Deprecated('使用 combinedViewUrl 替代')
  String? frontViewUrl;
  @Deprecated('使用 combinedViewUrl 替代')
  String? backViewUrl;
  @Deprecated('使用 combinedViewUrl 替代')
  String? sideViewUrl;

  // 生成状态
  CharacterSheetStatus status;

  // 生成时间
  final DateTime createdAt;
  DateTime? updatedAt;

  CharacterSheet({
    required this.id,
    required this.characterId,
    required this.characterName,
    required this.description,
    required this.role,
    this.combinedViewUrl,
    this.frontViewUrl,
    this.backViewUrl,
    this.sideViewUrl,
    this.status = CharacterSheetStatus.pending,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 从 JSON 创建
  factory CharacterSheet.fromJson(Map<String, dynamic> json) {
    return CharacterSheet(
      id: json['id'] as String,
      characterId: json['character_id'] as String,
      characterName: json['character_name'] as String,
      description: json['description'] as String,
      role: json['role'] as String,
      combinedViewUrl: json['combined_view_url'] as String?,
      frontViewUrl: json['front_view_url'] as String?,
      backViewUrl: json['back_view_url'] as String?,
      sideViewUrl: json['side_view_url'] as String?,
      status: CharacterSheetStatus.values.firstWhere(
        (e) => e.toString() == 'CharacterSheetStatus.${json['status']}',
        orElse: () => CharacterSheetStatus.pending,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'character_id': characterId,
      'character_name': characterName,
      'description': description,
      'role': role,
      'combined_view_url': combinedViewUrl,
      'front_view_url': frontViewUrl,
      'back_view_url': backViewUrl,
      'side_view_url': sideViewUrl,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// 复制并更新
  CharacterSheet copyWith({
    String? id,
    String? characterId,
    String? characterName,
    String? description,
    String? role,
    String? combinedViewUrl,
    String? frontViewUrl,
    String? backViewUrl,
    String? sideViewUrl,
    CharacterSheetStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CharacterSheet(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      characterName: characterName ?? this.characterName,
      description: description ?? this.description,
      role: role ?? this.role,
      combinedViewUrl: combinedViewUrl ?? this.combinedViewUrl,
      frontViewUrl: frontViewUrl ?? this.frontViewUrl,
      backViewUrl: backViewUrl ?? this.backViewUrl,
      sideViewUrl: sideViewUrl ?? this.sideViewUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 更新组合三视图
  CharacterSheet withCombinedView(String url) {
    return copyWith(
      combinedViewUrl: url,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新状态
  CharacterSheet withStatus(CharacterSheetStatus newStatus) {
    return copyWith(status: newStatus, updatedAt: DateTime.now());
  }

  /// 获取用于视频生成的图片 URL（优先使用组合图）
  String? get referenceImageUrl {
    if (combinedViewUrl != null && combinedViewUrl!.isNotEmpty) {
      return combinedViewUrl;
    }
    // 兼容旧版：返回正面视图
    return frontViewUrl;
  }

  /// 是否已生成三视图
  bool get isComplete => combinedViewUrl != null && combinedViewUrl!.isNotEmpty;

  /// 是否正在生成中
  bool get isGenerating =>
      status == CharacterSheetStatus.generating ||
      status == CharacterSheetStatus.partial;

  /// 生成进度百分比
  double get progress {
    if (combinedViewUrl != null && combinedViewUrl!.isNotEmpty) return 1.0;
    return 0.0;
  }
}

/// 角色设定表状态
enum CharacterSheetStatus {
  pending,      // 等待生成
  generating,   // 正在生成
  partial,      // 部分完成
  completed,    // 全部完成
  failed,       // 生成失败
}

/// 角色视图类型
enum CharacterViewType {
  front,        // 正面
  back,         // 背面
  side,         // 侧面
}

/// 扩展：获取视图显示名称
extension CharacterViewTypeExtension on CharacterViewType {
  String get displayName {
    switch (this) {
      case CharacterViewType.front:
        return '正面';
      case CharacterViewType.back:
        return '背面';
      case CharacterViewType.side:
        return '侧面';
    }
  }

  String get englishName {
    switch (this) {
      case CharacterViewType.front:
        return 'front view';
      case CharacterViewType.back:
        return 'back view';
      case CharacterViewType.side:
        return 'side view';
    }
  }
}

/// 扩展：获取状态显示名称
extension CharacterSheetStatusExtension on CharacterSheetStatus {
  String get displayName {
    switch (this) {
      case CharacterSheetStatus.pending:
        return '等待生成';
      case CharacterSheetStatus.generating:
        return '生成中';
      case CharacterSheetStatus.partial:
        return '部分完成';
      case CharacterSheetStatus.completed:
        return '已完成';
      case CharacterSheetStatus.failed:
        return '生成失败';
    }
  }

  String get icon {
    switch (this) {
      case CharacterSheetStatus.pending:
        return '⏳';
      case CharacterSheetStatus.generating:
        return '🔄';
      case CharacterSheetStatus.partial:
        return '⚡';
      case CharacterSheetStatus.completed:
        return '✅';
      case CharacterSheetStatus.failed:
        return '❌';
    }
  }
}
