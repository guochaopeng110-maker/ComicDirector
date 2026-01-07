import 'package:hive/hive.dart';

part 'conversation_message.g.dart';

/// 消息类型枚举
@HiveType(typeId: 1)
enum ConversationMessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  thinking,
  @HiveField(2)
  error,
  @HiveField(3)
  draft,
  @HiveField(4)
  screenplay,
}

/// 会话消息数据模型
@HiveType(typeId: 2)
class ConversationMessage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String conversationId;

  @HiveField(2)
  final ConversationMessageType type;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final bool isUser;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final Map<String, dynamic>? metadata;

  ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.content,
    required this.isUser,
    required this.createdAt,
    this.metadata,
  });

  /// 复制并更新部分字段
  ConversationMessage copyWith({
    String? id,
    String? conversationId,
    ConversationMessageType? type,
    String? content,
    bool? isUser,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ConversationMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      type: type ?? this.type,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 转换为 JSON（用于调试）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'type': type.name,
      'content': content,
      'isUser': isUser,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
