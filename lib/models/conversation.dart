import 'package:hive/hive.dart';

part 'conversation.g.dart';

/// 会话数据模型
@HiveType(typeId: 0)
class Conversation {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  @HiveField(4)
  final DateTime lastAccessedAt;

  @HiveField(5)
  final int messageCount;

  @HiveField(6)
  final String? previewText;

  @HiveField(7)
  final bool isPinned;

  @HiveField(8)
  final String? coverImageUrl;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.lastAccessedAt,
    this.messageCount = 0,
    this.previewText,
    this.isPinned = false,
    this.coverImageUrl,
  });

  /// 是否过期（2天未访问）
  bool get isExpired {
    final daysSinceAccess = DateTime.now().difference(lastAccessedAt).inDays;
    return daysSinceAccess >= 2;
  }

  /// 复制并更新部分字段
  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    int? messageCount,
    String? previewText,
    bool? isPinned,
    String? coverImageUrl,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      messageCount: messageCount ?? this.messageCount,
      previewText: previewText ?? this.previewText,
      isPinned: isPinned ?? this.isPinned,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }

  /// 转换为 JSON（用于调试）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      'messageCount': messageCount,
      'previewText': previewText,
      'isPinned': isPinned,
      'coverImageUrl': coverImageUrl,
    };
  }
}
