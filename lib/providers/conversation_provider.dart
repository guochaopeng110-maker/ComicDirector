import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../cache/hive_service.dart';
import '../cache/media_cache_manager.dart';
import '../models/conversation.dart';
import '../models/conversation_message.dart';
import '../models/chat_message.dart' as chat;

/// 会话状态管理
class ConversationProvider extends ChangeNotifier {
  final HiveService _hive = HiveService();
  final MediaCacheManager _cache = MediaCacheManager();
  final Uuid _uuid = const Uuid();

  // 状态
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  List<ConversationMessage> _currentMessages = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  List<ConversationMessage> get currentMessages => _currentMessages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 初始化
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 初始化 Hive
      await _hive.initialize();

      // 初始化缓存管理器
      await _cache.initialize();

      // 加载会话列表
      await loadConversations();

      // 清理过期缓存
      await _cache.cleanExpiredCache();

      // 如果没有会话，创建默认会话
      if (_conversations.isEmpty) {
        await createNewConversation();
      } else {
        // 加载第一个会话
        await switchConversation(_conversations.first.id);
      }

      debugPrint('✅ ConversationProvider 初始化完成');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ ConversationProvider 初始化失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载会话列表
  Future<void> loadConversations() async {
    _conversations = await _hive.getAllConversations();
    notifyListeners();
  }

  /// 创建新会话
  Future<String> createNewConversation({String? title}) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    final conversation = Conversation(
      id: id,
      title: title ?? _generateTitle(),
      createdAt: now,
      updatedAt: now,
      lastAccessedAt: now,
    );

    await _hive.createConversation(conversation);
    await loadConversations();

    // 切换到新会话
    await switchConversation(id);

    return id;
  }

  /// 切换会话
  Future<void> switchConversation(String id) async {
    if (_currentConversation?.id == id) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 更新访问时间
      await _hive.updateConversationAccess(id);

      // 获取会话
      final conversation = await _hive.getConversation(id);
      if (conversation == null) {
        throw Exception('会话不存在');
      }

      _currentConversation = conversation;

      // 加载消息
      _currentMessages = await _hive.getMessages(id);

      debugPrint('📂 切换到会话: ${conversation.title}');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ 切换会话失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存消息
  Future<void> saveMessage(chat.ChatMessage chatMessage) async {
    if (_currentConversation == null) return;

    final id = _uuid.v4();
    final now = DateTime.now();

    // 构建 metadata
    final metadata = <String, dynamic>{
      if (chatMessage.mediaUrl != null) 'mediaUrl': chatMessage.mediaUrl,
      if (chatMessage.screenplay != null) 'screenplayTaskId': chatMessage.screenplay!.taskId,
    };

    final message = ConversationMessage(
      id: id,
      conversationId: _currentConversation!.id,
      type: _convertMessageType(chatMessage.type),
      content: chatMessage.content,
      isUser: chatMessage.role == chat.MessageRole.user,
      createdAt: now,
      metadata: metadata.isNotEmpty ? metadata : null,
    );

    await _hive.addMessage(message);

    // 添加到当前消息列表
    _currentMessages.add(message);

    // 更新当前会话
    final updatedConv = _currentConversation!.copyWith(
      messageCount: _currentMessages.length,
      previewText: _generatePreviewText(chatMessage.content),
      updatedAt: now,
    );
    _currentConversation = updatedConv;
    await _hive.updateConversation(updatedConv);

    await loadConversations();
    notifyListeners();

    // 缓存媒体文件（后台）
    _cacheMessageMedia(message);
  }

  /// 删除会话
  Future<void> deleteConversation(String id) async {
    // 清理缓存
    await _cache.clearConversationCache(id);

    // 删除数据库记录
    await _hive.deleteConversation(id);

    // 如果是当前会话，清空并切换
    if (_currentConversation?.id == id) {
      _currentConversation = null;
      _currentMessages = [];

      // 如果还有其他会话，切换到第一个
      if (_conversations.isNotEmpty) {
        final remaining = _conversations.where((c) => c.id != id).toList();
        if (remaining.isNotEmpty) {
          await switchConversation(remaining.first.id);
        }
      }
    }

    await loadConversations();
    notifyListeners();
  }

  /// 切换置顶状态
  Future<void> togglePin(String id) async {
    await _hive.togglePinConversation(id);
    await loadConversations();
    notifyListeners();
  }

  /// 更新会话标题
  Future<void> updateConversationTitle(String id, String newTitle) async {
    final conversation = await _hive.getConversation(id);
    if (conversation != null) {
      final updated = conversation.copyWith(title: newTitle);
      await _hive.updateConversation(updated);

      if (_currentConversation?.id == id) {
        _currentConversation = updated;
      }

      await loadConversations();
      notifyListeners();
    }
  }

  /// 获取缓存统计
  Future<CacheStats> getCacheStats() async {
    final size = await _cache.getCacheSize();
    final fileCount = _cache.getCacheFileCount();

    return CacheStats(
      totalSize: size,
      fileCount: fileCount,
      imageCount: _countImages(),
      videoCount: _countVideos(),
    );
  }

  /// 清理所有缓存
  Future<CacheCleanupResult> clearAllCache() async {
    return await _cache.cleanExpiredCache();
  }

  /// 清空所有缓存
  Future<void> clearAllCacheForce() async {
    await _cache.clearAllCache();
    notifyListeners();
  }

  // ==================== 私有方法 ====================

  /// 生成会话标题
  String _generateTitle() {
    final count = _conversations.where((c) => c.title.startsWith('新对话')).length;
    return '新对话${count > 0 ? ' ${count + 1}' : ''}';
  }

  /// 转换消息类型
  ConversationMessageType _convertMessageType(chat.MessageType type) {
    switch (type) {
      case chat.MessageType.text:
        return ConversationMessageType.text;
      case chat.MessageType.image:
        return ConversationMessageType.text; // 图片消息存储为文本类型
      case chat.MessageType.video:
        return ConversationMessageType.text; // 视频消息存储为文本类型
      case chat.MessageType.thinking:
        return ConversationMessageType.thinking;
      case chat.MessageType.error:
        return ConversationMessageType.error;
      case chat.MessageType.draft:
        return ConversationMessageType.draft;
      case chat.MessageType.screenplay:
        return ConversationMessageType.screenplay;
    }
  }

  /// 生成预览文本
  String _generatePreviewText(String content) {
    final text = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return text.length > 50 ? '${text.substring(0, 50)}...' : text;
  }

  /// 缓存消息中的媒体文件（后台）
  Future<void> _cacheMessageMedia(ConversationMessage message) async {
    // 从 content 或 metadata 中提取 URL 并缓存
    // 这里简单实现：如果是 draft 或 screenplay 类型，提取图片 URL
    if (message.metadata != null) {
      final metadata = message.metadata!;
      if (metadata['imageUrl'] is String) {
        try {
          await _cache.cacheMedia(
            metadata['imageUrl'] as String,
            conversationId: message.conversationId,
          );
        } catch (e) {
          debugPrint('⚠️ 缓存图片失败: $e');
        }
      }
      if (metadata['videoUrl'] is String) {
        try {
          await _cache.cacheMedia(
            metadata['videoUrl'] as String,
            conversationId: message.conversationId,
          );
        } catch (e) {
          debugPrint('⚠️ 缓存视频失败: $e');
        }
      }
    }
  }

  int _countImages() {
    int count = 0;
    for (final message in _currentMessages) {
      if (message.metadata != null && message.metadata!['imageUrl'] != null) {
        count++;
      }
    }
    return count;
  }

  int _countVideos() {
    int count = 0;
    for (final message in _currentMessages) {
      if (message.metadata != null && message.metadata!['videoUrl'] != null) {
        count++;
      }
    }
    return count;
  }
}

/// 缓存统计
class CacheStats {
  final int totalSize;
  final int fileCount;
  final int imageCount;
  final int videoCount;

  CacheStats({
    required this.totalSize,
    required this.fileCount,
    required this.imageCount,
    required this.videoCount,
  });

  String get totalSizeFormatted {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
