import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/conversation.dart';
import '../providers/conversation_provider.dart';
import '../screens/settings_screen.dart';

/// 会话列表 Drawer
class ConversationListDrawer extends StatelessWidget {
  const ConversationListDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1B2E),
            const Color(0xFF2D2640),
          ],
        ),
      ),
      child: Consumer<ConversationProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // 头部
              _buildHeader(context, provider),

              // 会话列表
              Expanded(
                child: provider.isLoading
                    ? _buildLoadingState()
                    : provider.conversations.isEmpty
                        ? _buildEmptyState(context, provider)
                        : _buildConversationList(context, provider),
              ),

              // 底部：设置按钮
              _buildFooter(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ConversationProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // 标题
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 漫导',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '对话记录',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // 新建按钮
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _createNewConversation(context, provider),
              tooltip: '新建对话',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ConversationProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无对话记录',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _createNewConversation(context, provider),
            icon: const Icon(Icons.add),
            label: const Text('创建新对话'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(BuildContext context, ConversationProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: provider.conversations.length,
      itemBuilder: (context, index) {
        final conversation = provider.conversations[index];
        final isSelected = provider.currentConversation?.id == conversation.id;
        return ConversationItem(
          conversation: conversation,
          isSelected: isSelected,
          onTap: () => _selectConversation(context, provider, conversation.id),
          onPin: () => provider.togglePin(conversation.id),
          onDelete: () => _deleteConversation(context, provider, conversation),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: InkWell(
        onTap: () => _openSettings(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                '设置',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewConversation(BuildContext context, ConversationProvider provider) async {
    Navigator.pop(context); // 关闭 drawer
    await provider.createNewConversation();
  }

  void _selectConversation(BuildContext context, ConversationProvider provider, String conversationId) async {
    Navigator.pop(context); // 关闭 drawer
    await provider.switchConversation(conversationId);
  }

  void _deleteConversation(BuildContext context, ConversationProvider provider, Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '删除对话',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '确定要删除「${conversation.title}」吗？\n\n此操作将删除该对话的所有消息和缓存，无法恢复。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF87171),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteConversation(conversation.id);
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.pop(context); // 关闭 drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}

/// 单个会话列表项
class ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF8B5CF6).withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF8B5CF6).withOpacity(0.5)
              : Colors.transparent,
          width: isSelected ? 1.5 : 0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 封面图/图标
              _buildCover(),
              const SizedBox(width: 14),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.isPinned)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.push_pin,
                              color: Color(0xFF8B5CF6),
                              size: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 预览文本
                    if (conversation.previewText != null)
                      Text(
                        conversation.previewText!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    // 底部信息
                    Row(
                      children: [
                        Text(
                          _formatDate(conversation.updatedAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${conversation.messageCount} 条消息',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 操作按钮
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (conversation.coverImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          conversation.coverImageUrl!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
        ),
      );
    }
    return _buildDefaultCover();
  }

  Widget _buildDefaultCover() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.chat_bubble_outline,
        color: Colors.white70,
        size: 24,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Colors.white.withOpacity(0.5),
        size: 18,
      ),
      color: const Color(0xFF1E1B2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) {
        switch (value) {
          case 'pin':
            onPin();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
                color: conversation.isPinned ? const Color(0xFF8B5CF6) : Colors.white70,
              ),
              const SizedBox(width: 12),
              Text(
                conversation.isPinned ? '取消置顶' : '置顶',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF87171)),
              const SizedBox(width: 12),
              const Text('删除', style: TextStyle(color: Color(0xFFF87171))),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天 ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return '昨天 ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm').format(date);
    } else {
      return DateFormat('yy/MM/dd HH:mm').format(date);
    }
  }
}
