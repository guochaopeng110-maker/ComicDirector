import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../models/conversation_message.dart';

/// Hive 数据库服务
class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  static const String _conversationsBoxName = 'conversations';
  static const String _messagesBoxName = 'messages';

  late Box<Conversation> _conversationsBox;
  late Box<ConversationMessage> _messagesBox;

  bool _isInitialized = false;

  /// 初始化 Hive
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // �始化 Hive
      final appDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter('${appDir.path}/hive_db');

      // 注册适配器
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ConversationAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ConversationMessageTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ConversationMessageAdapter());
      }

      // 打开 Box
      _conversationsBox = await Hive.openBox<Conversation>(_conversationsBoxName);
      _messagesBox = await Hive.openBox<ConversationMessage>(_messagesBoxName);

      _isInitialized = true;
      debugPrint('✅ Hive 数据库初始化完成');
    } catch (e) {
      debugPrint('❌ Hive 数据库初始化失败: $e');
      rethrow;
    }
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // ==================== 会话操作 ====================

  /// 创建新会话
  Future<void> createConversation(Conversation conversation) async {
    await _ensureInitialized();
    await _conversationsBox.put(conversation.id, conversation);
    debugPrint('📝 创建会话: ${conversation.id}');
  }

  /// 获取所有会话
  Future<List<Conversation>> getAllConversations() async {
    await _ensureInitialized();

    final conversations = _conversationsBox.values.toList();

    // 按更新时间排序（置顶的在前，然后按更新时间降序）
    conversations.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return b.isPinned ? 1 : -1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return conversations;
  }

  /// 获取单个会话
  Future<Conversation?> getConversation(String id) async {
    await _ensureInitialized();
    return _conversationsBox.get(id);
  }

  /// 更新会话
  Future<void> updateConversation(Conversation conversation) async {
    await _ensureInitialized();
    await _conversationsBox.put(conversation.id, conversation);
  }

  /// 删除会话
  Future<void> deleteConversation(String id) async {
    await _ensureInitialized();
    await _conversationsBox.delete(id);

    // 级联删除相关消息
    final messages = _messagesBox.values.where((m) => m.conversationId == id).toList();
    for (final message in messages) {
      await _messagesBox.delete(message.id);
    }

    debugPrint('🗑️ 删除会话: $id');
  }

  /// 更新会话访问时间
  Future<void> updateConversationAccess(String id) async {
    await _ensureInitialized();
    final conversation = _conversationsBox.get(id);
    if (conversation != null) {
      final updated = conversation.copyWith(lastAccessedAt: DateTime.now());
      await _conversationsBox.put(id, updated);
    }
  }

  /// 切换置顶状态
  Future<void> togglePinConversation(String id) async {
    await _ensureInitialized();
    final conversation = _conversationsBox.get(id);
    if (conversation != null) {
      final updated = conversation.copyWith(isPinned: !conversation.isPinned);
      await _conversationsBox.put(id, updated);
    }
  }

  /// 更新会话消息计数和预览
  Future<void> updateConversationStats(String id, String previewText) async {
    await _ensureInitialized();
    final conversation = _conversationsBox.get(id);
    if (conversation != null) {
      final updated = conversation.copyWith(
        messageCount: conversation.messageCount + 1,
        previewText: _generatePreviewText(previewText),
        updatedAt: DateTime.now(),
      );
      await _conversationsBox.put(id, updated);
    }
  }

  String _generatePreviewText(String content) {
    final text = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return text.length > 50 ? '${text.substring(0, 50)}...' : text;
  }

  // ==================== 消息操作 ====================

  /// 添加消息
  Future<void> addMessage(ConversationMessage message) async {
    await _ensureInitialized();
    await _messagesBox.put(message.id, message);

    // 更新会话统计
    await updateConversationStats(message.conversationId, message.content);
  }

  /// 获取会话的所有消息
  Future<List<ConversationMessage>> getMessages(String conversationId) async {
    await _ensureInitialized();

    final messages = _messagesBox.values
        .where((m) => m.conversationId == conversationId)
        .toList();

    // 按创建时间排序
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return messages;
  }

  /// 删除会话的所有消息
  Future<void> deleteMessages(String conversationId) async {
    await _ensureInitialized();

    final messages = _messagesBox.values
        .where((m) => m.conversationId == conversationId)
        .toList();

    for (final message in messages) {
      await _messagesBox.delete(message.id);
    }
  }

  /// 获取消息数量
  Future<int> getMessageCount(String conversationId) async {
    await _ensureInitialized();

    return _messagesBox.values
        .where((m) => m.conversationId == conversationId)
        .length;
  }

  // ==================== 统计操作 ====================

  /// 获取总会话数量
  int getConversationCount() {
    return _conversationsBox.length;
  }

  /// 获取总消息数量
  int getTotalMessageCount() {
    return _messagesBox.length;
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _conversationsBox.clear();
    await _messagesBox.clear();
    debugPrint('🗑️ 已清空所有数据');
  }

  /// 关闭数据库
  Future<void> close() async {
    await _conversationsBox.close();
    await _messagesBox.close();
    _isInitialized = false;
    debugPrint('🔒 Hive 数据库已关闭');
  }
}
