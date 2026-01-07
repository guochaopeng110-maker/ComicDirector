import 'package:flutter/material.dart';
import 'screenplay.dart';
import 'screenplay_draft.dart';

enum MessageRole {
  user,
  agent,
  system,
}

enum MessageType {
  text,
  image,
  video,
  thinking,
  error,
  screenplay,  // 新增：剧本类型
  draft,      // 新增：剧本草稿类型
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final MessageType type;
  final String? mediaUrl;
  final DateTime timestamp;
  final List<ChatMessage>? subSteps; // 用于多步骤智能体流程
  final Screenplay? screenplay; // 剧本数据
  final ScreenplayDraft? draft; // 剧本草稿数据

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    DateTime? timestamp,
    this.subSteps,
    this.screenplay,
    this.draft,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    MessageType? type,
    String? mediaUrl,
    DateTime? timestamp,
    List<ChatMessage>? subSteps,
    Screenplay? screenplay,
    ScreenplayDraft? draft,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      timestamp: timestamp ?? this.timestamp,
      subSteps: subSteps ?? this.subSteps,
      screenplay: screenplay ?? this.screenplay,
      draft: draft ?? this.draft,
    );
  }

  // 用于生成唯一 ID 的计数器，避免同一毫秒内创建的消息 ID 冲突
  static int _idCounter = 0;
  
  /// 生成唯一的消息 ID
  static String _generateId(String prefix) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
  }

  /// 创建用户文本消息
  factory ChatMessage.userText(String content) {
    return ChatMessage(
      id: _generateId('user'),
      role: MessageRole.user,
      content: content,
      type: MessageType.text,
    );
  }

  /// 创建智能体思考消息
  factory ChatMessage.thinking(String content) {
    return ChatMessage(
      id: _generateId('thinking'),
      role: MessageRole.agent,
      content: content,
      type: MessageType.thinking,
    );
  }

  /// 创建智能体图片结果消息
  factory ChatMessage.imageResult(String content, String imageUrl) {
    return ChatMessage(
      id: _generateId('image'),
      role: MessageRole.agent,
      content: content,
      type: MessageType.image,
      mediaUrl: imageUrl,
    );
  }

  /// 创建智能体视频结果消息
  factory ChatMessage.videoResult(String content, String videoUrl) {
    return ChatMessage(
      id: _generateId('video'),
      role: MessageRole.agent,
      content: content,
      type: MessageType.video,
      mediaUrl: videoUrl,
    );
  }

  /// 创建错误消息
  factory ChatMessage.error(String error) {
    return ChatMessage(
      id: _generateId('error'),
      role: MessageRole.agent,
      content: '错误: $error',
      type: MessageType.error,
    );
  }

  /// 创建剧本消息
  factory ChatMessage.screenplay(Screenplay screenplay) {
    return ChatMessage(
      id: _generateId('screenplay'),
      role: MessageRole.agent,
      content: '剧本: ${screenplay.scriptTitle}',
      type: MessageType.screenplay,
      screenplay: screenplay,
    );
  }

  /// 创建剧本草稿消息
  factory ChatMessage.draft(ScreenplayDraft draft) {
    return ChatMessage(
      id: _generateId('draft'),
      role: MessageRole.agent,
      content: '剧本草稿: ${draft.title} (${draft.sceneCount}个场景)',
      type: MessageType.draft,
      draft: draft,
    );
  }

  /// 更新剧本数据
  ChatMessage updateScreenplay(Screenplay updatedScreenplay) {
    return copyWith(screenplay: updatedScreenplay);
  }

  /// 更新剧本草稿数据
  ChatMessage updateDraft(ScreenplayDraft updatedDraft) {
    return copyWith(draft: updatedDraft);
  }

  /// 根据角色获取显示颜色
  Color getRoleColor() {
    switch (role) {
      case MessageRole.user:
        return Colors.blue;
      case MessageRole.agent:
        return Colors.green;
      case MessageRole.system:
        return Colors.grey;
    }
  }

  /// 获取显示名称
  String getDisplayName() {
    switch (role) {
      case MessageRole.user:
        return '你';
      case MessageRole.agent:
        return 'AI漫导';
      case MessageRole.system:
        return '系统';
    }
  }
}
