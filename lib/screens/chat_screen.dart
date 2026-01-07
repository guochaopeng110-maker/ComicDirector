import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../utils/video_cache_manager.dart';
import '../main.dart' show ScreenplayReviewScreenArgs;
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/video_merge_provider.dart';
import '../models/chat_message.dart';
import '../models/screenplay_draft.dart';
import '../models/screenplay.dart';
import '../services/video_merger_service.dart';
import '../services/gallery_service.dart';
import '../widgets/screenplay_card.dart';
import '../widgets/conversation_list_drawer.dart';

/// 视频播放器单例管理器 - 确保同时只有一个视频在初始化/播放
class VideoPlayerManager {
  static final VideoPlayerManager _instance = VideoPlayerManager._internal();
  factory VideoPlayerManager() => _instance;
  VideoPlayerManager._internal();

  _VideoPlayerState? _currentPlayer;
  bool _isInitializing = false; // 全局初始化锁
  DateTime? _lastInitTime; // 上次初始化时间
  static const _minInitInterval = Duration(milliseconds: 2000); // 最小初始化间隔 2 秒

  /// 请求独占初始化权 - 只有返回 true 时才能继续初始化
  bool requestInitialization(_VideoPlayerState player) {
    // 检查时间间隔 - 防止频繁初始化
    final now = DateTime.now();
    if (_lastInitTime != null) {
      final elapsed = now.difference(_lastInitTime!);
      if (elapsed < _minInitInterval) {
        final remaining = (_minInitInterval - elapsed).inMilliseconds;
        debugPrint('🎬 拒绝初始化请求：距离上次初始化仅 ${elapsed.inMilliseconds}ms，需等待 ${remaining}ms');
        return false;
      }
    }

    if (_isInitializing) {
      debugPrint('🎬 拒绝初始化请求：已有视频正在初始化');
      return false;
    }

    // 释放之前的播放器 - 给足够时间让硬件解码器释放
    if (_currentPlayer != null && _currentPlayer != player && _currentPlayer!.mounted) {
      debugPrint('🎬 释放之前的播放器资源，等待硬件解码器释放');
      _currentPlayer!._disposePlayer();
      // 强制延迟 500ms，确保硬件资源完全释放
      return false;
    }

    _isInitializing = true;
    _lastInitTime = now;
    _currentPlayer = player;
    debugPrint('🎬 获得初始化权限: ${player.widget.url}');
    return true;
  }

  /// 初始化完成 - 释放锁
  void completeInitialization(bool success) {
    _isInitializing = false;
    if (!success) {
      // 如果初始化失败，不更新时间戳，允许立即重试
      _lastInitTime = null;
    }
    debugPrint('🎬 初始化${success ? "完成" : "失败"}，释放锁');
  }

  void registerPlayer(_VideoPlayerState player) {
    if (_currentPlayer != null && _currentPlayer != player && _currentPlayer!.mounted) {
      _currentPlayer!._pauseVideo();
    }
    _currentPlayer = player;
  }

  void unregisterPlayer(_VideoPlayerState player) {
    if (_currentPlayer == player) {
      _currentPlayer = null;
      _isInitializing = false; // 确保释放锁
    }
  }

  void clearAll() {
    _currentPlayer = null;
    _isInitializing = false;
  }
  
  /// 释放所有视频播放器资源（用于其他页面需要硬件资源时，如录屏）
  void releaseAllResources() {
    if (_currentPlayer != null && _currentPlayer!.mounted) {
      _currentPlayer!._disposePlayer();
      debugPrint('🎬 VideoPlayerManager: 已释放当前视频播放器资源');
    }
    _currentPlayer = null;
    _isInitializing = false;
    _lastInitTime = null;
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  int _previousMessageCount = 0;
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    // 初始化会话管理器并设置到 ChatProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      conversationProvider.initialize();
      chatProvider.setConversationProvider(conversationProvider);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // 只在新增消息时滚动到底部
  void _scrollOnNewMessage(int currentMessageCount) {
    // 如果消息数量增加了且有新消息，才滚动到底部
    if (currentMessageCount > _previousMessageCount) {
      // 检查用户是否正在滚动或者不在底部
      final isNearBottom = _scrollController.hasClients &&
          (_scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels)
              < 100;

      // 只有当用户不在手动滚动，或者接近底部时才自动滚动
      if (!_isUserScrolling || isNearBottom) {
        _scrollToBottom();
      }
      _previousMessageCount = currentMessageCount;
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ChatProvider>();

    // 检测是否是视频生成请求
    final isVideoRequest = _isVideoGenerationRequest(text);

    if (isVideoRequest) {
      // 新流程：先生成剧本草稿，然后跳转到确认页面
      // 注意：这里不需要调用 sendMessage，因为 generateDraft 内部会处理
      _messageController.clear();

      try {
        // 生成剧本草稿（会自动添加用户消息）
        final draft = await provider.generateDraft(text);
        _scrollToBottom();

        // 跳转到剧本确认页面
        if (mounted) {
          // 取消输入框焦点，防止键盘弹出
          _focusNode.unfocus();

          await Navigator.pushNamed(
            context,
            '/screenplay-review',
            arguments: ScreenplayReviewScreenArgs(
              draft: draft,
              onConfirm: (_) async {
                // 先返回聊天页面
                if (context.mounted) {
                  Navigator.pop(context);
                }
                // 然后在后台开始生成图片和视频
                // 不使用 await，让用户在聊天页面查看进度
                provider.confirmDraft().catchError((e) {
                  // 错误已经由 Provider 内部处理
                });
              },
              onRegenerate: (feedback) async {
                return await provider.regenerateDraft(feedback);
              },
              onRegenerateCharacterSheets: () async {
                await provider.regenerateCharacterSheets();
              },
            ),
          );
        }
      } catch (e) {
        // 错误已经由 Provider 处理
        _scrollToBottom();
      }
    } else {
      // 普通聊天
      provider.sendMessage(text);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  /// 检测是否是视频生成请求
  bool _isVideoGenerationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    final videoKeywords = [
      '生成视频', '制作视频', '视频',
      '生成动画', '制作动画',
      '帮我做', '帮我生成',
      '创建视频', 'create video',
    ];
    return videoKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FC),
      drawer: const ConversationListDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAF9FC), Color(0xFFF5F4F8)],
          ),
        ),
        child: Column(
            children: [
              // AppBar
              _buildModernAppBar(context),

              // 错误消息横幅
              Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  if (provider.errorMessage != null) {
                    final isApiKeyError = provider.errorMessage!.contains('API Key');
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: isApiKeyError ? const Color(0xFFFFF7ED) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isApiKeyError ? const Color(0xFFFED7AA) : const Color(0xFFFECACA),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isApiKeyError ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isApiKeyError ? Icons.settings_outlined : Icons.error_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isApiKeyError ? '需要配置 API Key' : '出错了',
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  provider.errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isApiKeyError)
                            TextButton(
                              onPressed: () {
                                provider.clearError();
                                Navigator.pushNamed(context, '/settings');
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF92400E),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('去设置', style: TextStyle(fontSize: 13)),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => provider.clearError(),
                              color: const Color(0xFF991B1B),
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // 消息列表
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scrollNotification) {
                    if (scrollNotification is ScrollStartNotification) {
                      _isUserScrolling = true;
                    } else if (scrollNotification is ScrollEndNotification) {
                      _isUserScrolling = false;
                    }
                    return false;
                  },
                  child: Consumer<ChatProvider>(
                    builder: (context, provider, child) {
                      _scrollOnNewMessage(provider.messages.length);
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, index) {
                          final message = provider.messages[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: _MessageBubble(
                              message: message,
                              onMergeVideos: (screenplay) => _showMergeDialog(context, screenplay),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // 进度追踪器 + 输入框
              _buildProgressTracker(context),
              _buildInputArea(context),
            ],
          ),
      ),
    );
  }

  /// 现代风格 AppBar
  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1C1C1E)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Consumer<ConversationProvider>(
          builder: (context, provider, child) {
            final title = provider.currentConversation?.title ?? 'AI漫导';
            return Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1C1C1E),
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            );
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          onPressed: () => _showSettingsDialog(context),
          color: const Color(0xFF8B5CF6),
        ),
        IconButton(
          icon: const Icon(Icons.bug_report_outlined, size: 22),
          onPressed: () => Navigator.pushNamed(context, '/logs'),
          color: const Color(0xFF8B5CF6),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 22),
          onPressed: () => _showClearDialog(context),
          color: const Color(0xFF8B5CF6),
        ),
      ],
      ),
    );
  }


  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, -2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // 图片预览区域
            Consumer<ChatProvider>(
              builder: (context, provider, child) {
                if (provider.userImages.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.userImages.length + (provider.canAddMoreImages ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 添加图片按钮
                      if (index == provider.userImages.length) {
                        return _buildAddImageButton(context);
                      }
                      // 已选择的图片
                      final userImage = provider.userImages[index];
                      return Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(userImage.base64),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 64,
                                    height: 64,
                                    color: const Color(0xFFF3F4F6),
                                    child: const Icon(Icons.broken_image, size: 24, color: Color(0xFF8E8E93)),
                                  );
                                },
                              ),
                            ),
                            // 删除按钮
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => provider.removeImage(index),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1C1C1E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // 输入行
            Consumer<ChatProvider>(
              builder: (context, provider, child) {
                return Row(
                  children: [
                    // 图片选择按钮
                    if (!provider.isProcessing)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // 相册按钮
                            if (provider.userImages.isEmpty)
                              IconButton(
                                onPressed: provider.pickImageFromGallery,
                                icon: const Icon(Icons.photo_library_outlined, size: 20),
                                tooltip: '从相册选择',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                color: const Color(0xFF6B7280),
                              ),
                            // 分隔线
                            if (provider.userImages.isEmpty && provider.canAddMoreImages)
                              Container(
                                width: 0.5,
                                height: 20,
                                color: const Color(0xFFE5E7EB),
                              ),
                            // 拍照按钮
                            if (provider.userImages.isEmpty)
                              IconButton(
                                onPressed: provider.pickImageFromCamera,
                                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                                tooltip: '拍照',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                color: const Color(0xFF6B7280),
                              ),
                            // 添加更多图片按钮
                            if (provider.userImages.isNotEmpty && provider.canAddMoreImages)
                              _buildAddImageButtonSmall(context, provider),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: provider.userImages.isNotEmpty
                                ? '已选择 ${provider.userImages.length}/3 张参考图片'
                                : '描述你的视频创意...',
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 15,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSendButton(context, provider),
                  ],
                );
              },
            ),
          ],
        ),
    );
  }

  /// 发送/取消按钮 - 现代风格
  Widget _buildSendButton(BuildContext context, ChatProvider provider) {
    final isProcessing = provider.isProcessing;
    final isCancelling = provider.isCancelling;

    return GestureDetector(
      onTap: isProcessing ? provider.cancelProcessing : _sendMessage,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isProcessing && !isCancelling ? const Color(0xFF9CA3AF) : const Color(0xFF8B5CF6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.25),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: isProcessing
              ? isCancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.close, color: Colors.white, size: 22)
              : const Icon(Icons.arrow_upward, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  /// 进度追踪器 - 现代风格
  Widget _buildProgressTracker(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        // 只在有进度状态(视频生成中)或有失败场景时显示
        final hasProgress = provider.progressStatus.isNotEmpty;
        final hasFailed = provider.screenplayController.currentScreenplay?.hasFailed ?? false;

        if (!hasProgress && !hasFailed) {
          return const SizedBox.shrink();
        }

        final progress = provider.progress;
        final status = provider.progressStatus;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: hasFailed ? const Color(0xFFFEE2E2) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hasFailed ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              // 活动指示器
              if (provider.isProcessing)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: hasFailed ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasFailed ? Icons.error_outline : Icons.movie_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(width: 12),
              // 状态文本
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasFailed ? '部分场景失败，可点击重试' : status,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 现代风格进度条
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8B5CF6),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 百分比 - 现代风格标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final tokenController = TextEditingController();
    tokenController.text = 'YOUR_TOKEN_PLACEHOLDER';
    bool obscureText = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '设置',
            style: TextStyle(
              color: Color(0xFFFFB8D1),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('API 令牌：'),
              const SizedBox(height: 8),
              TextField(
                controller: tokenController,
                decoration: InputDecoration(
                  hintText: '输入你的 API 令牌',
                  filled: true,
                  fillColor: const Color(0xFFFFEFF4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFFFB8D1), width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFFFFB8D1),
                    ),
                    onPressed: () {
                      setState(() {
                        obscureText = !obscureText;
                      });
                    },
                  ),
                ),
                obscureText: obscureText,
              ),
              const SizedBox(height: 16),
              const Text(
                '输入你的 API Bearer 令牌。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('令牌当前硬编码在代码中，暂不支持UI修改')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB8D1),
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '清除对话',
          style: TextStyle(
            color: Color(0xFFFFB8D1),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text('确定要清除所有消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<ChatProvider>().clearConversation();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB8D1),
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  /// 显示视频合并对话框
  void _showMergeDialog(BuildContext context, Screenplay screenplay) {
    // 检查是否有足够的场景视频
    final scenesWithVideo = screenplay.scenes.where((s) => s.videoUrl != null).length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.video_library_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('合并场景视频'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('剧本: ${screenplay.scriptTitle}'),
            const SizedBox(height: 8),
            Text('场景总数: ${screenplay.scenes.length}'),
            const SizedBox(height: 4),
            Text('已生成视频: $scenesWithVideo 个'),
            const SizedBox(height: 16),
            const Text(
              '是否将这些场景视频合并为完整视频？',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // 显示合并进度对话框
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _MergeProgressDialog(screenplay: screenplay),
              );
              // 开始合并
              context.read<VideoMergeProvider>().mergeVideos(screenplay);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
            ),
            child: const Text('开始合并'),
          ),
        ],
      ),
    );
  }

  /// 添加图片按钮（用于预览区域）
  Widget _buildAddImageButton(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showImageSourceDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.grey.shade600, size: 28),
              const SizedBox(height: 4),
              Text(
                '添加',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 小型添加图片按钮（用于输入框旁）
  Widget _buildAddImageButtonSmall(BuildContext context, ChatProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.add_photo_alternate, color: Color(0xFF6B4CE6)),
      tooltip: '添加图片',
      onSelected: (choice) {
        if (choice == 'gallery') {
          provider.pickImageFromGallery();
        } else if (choice == 'camera') {
          provider.pickImageFromCamera();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'gallery',
          child: Row(
            children: [
              Icon(Icons.photo_library),
              SizedBox(width: 12),
              Text('从相册选择'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'camera',
          child: Row(
            children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 12),
              Text('拍照'),
            ],
          ),
        ),
      ],
    );
  }

  /// 显示图片来源选择对话框
  void _showImageSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                context.read<ChatProvider>().pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                context.read<ChatProvider>().pickImageFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(Screenplay)? onMergeVideos;

  const _MessageBubble({
    required this.message,
    this.onMergeVideos,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 发送者名称
          Text(
            message.getDisplayName(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isUser ? Colors.blue : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // 消息内容
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                // AI头像 - 现代风格
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Flexible(
                child: _buildMessageBubble(context, isUser, message),
              ),

              if (isUser) ...[
                const SizedBox(width: 8),
                // 用户头像 - 现代风格
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.25),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),

          // 时间戳
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 40),
            child: Text(
              _formatTime(message.timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 现代消息气泡 - AI消息带渐变边框，用户消息带渐变背景
  Widget _buildMessageBubble(BuildContext context, bool isUser, ChatMessage message) {
    Color textColor;
    BorderRadiusGeometry borderRadius = BorderRadius.circular(20);

    if (message.type == MessageType.thinking) {
      // 思考中 - 柔和的动态效果
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F7FC),
          borderRadius: borderRadius,
          border: Border.all(
            color: const Color(0xFFE5E1F5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF8B5CF6).withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              message.content,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    } else if (message.type == MessageType.error) {
      textColor = const Color(0xFF991B1B);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEE2E2), Color(0xFFFECACA)],
          ),
          borderRadius: borderRadius,
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
        ),
        child: _buildMessageContent(context, message, isUser, textColor),
      );
    } else if (isUser) {
      // 用户消息 - 紫色渐变背景
      textColor = Colors.white;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(6),
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          ),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: _buildMessageContent(context, message, isUser, textColor),
      );
    } else {
      // AI消息 - 玻璃态 + 渐变边框
      textColor = const Color(0xFF1C1C1E);
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(20),
      );
      // 使用渐变边框效果
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.15),
              offset: const Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(1.5), // 边框宽度
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
          ),
          child: _buildMessageContent(context, message, isUser, textColor),
        ),
      );
    }
  }

  Widget _buildMessageContent(BuildContext context, ChatMessage message, bool isUser, Color textColor) {
    switch (message.type) {
      case MessageType.text:
      case MessageType.thinking:
      case MessageType.error:
        // 清理HTML标签（如<details>、<summary>等），Flutter Markdown不支持
        final cleanedContent = _cleanHtmlTags(message.content);
        return SelectionArea(
          child: MarkdownBody(
            data: cleanedContent,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: textColor,
                fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.content.isNotEmpty)
              SelectionArea(
                child: Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (message.mediaUrl != null)
              GestureDetector(
                onTap: () => _showImageViewer(context, message.mediaUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                    memCacheWidth: 800,
                    memCacheHeight: 600,
                    progressIndicatorBuilder: (context, url, progress) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.progress,
                          ),
                        ),
                      );
                    },
                    errorWidget: (context, url, error) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.red.shade100,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(height: 8),
                              Text('图片加载失败'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );

      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectionArea(
              child: Text(
                message.content,
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ),
            const SizedBox(height: 8),
            if (message.mediaUrl != null)
              _VideoPlayer(url: message.mediaUrl!),
          ],
        );

      case MessageType.draft:
        if (message.draft != null) {
          return GestureDetector(
            onTap: () => _openDraftReviewScreen(context, message.draft!),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                // 更专业的渐变背景
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFDF2F8), // 浅粉
                    Color(0xFFFCE7F3), // 粉色
                    Color(0xFFF5D0FE), // 淡紫
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFEC4899).withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_stories, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '剧本草稿',
                        style: TextStyle(
                          color: Color(0xFF831843),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '点击编辑',
                              style: TextStyle(
                                color: const Color(0xFFEC4899),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios, color: Color(0xFFEC4899), size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 标题
                  Text(
                    message.draft!.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 信息标签
                  Row(
                    children: [
                      _buildInfoTag(Icons.view_carousel, '${message.draft!.sceneCount}个场景'),
                      const SizedBox(width: 8),
                      _buildInfoTag(Icons.category, message.draft!.genre),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 情绪弧线标签 - 带动画渐变
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.draft!.emotionalArc.asMap().entries.map((entry) {
                      final index = entry.key;
                      final emotion = entry.value;
                      // 不同索引使用不同的渐变色
                      final colors = _getEmotionGradient(index);
                      return _EmotionChip(
                        emotion: emotion,
                        gradientColors: colors,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }
        return const Text('草稿数据加载中...');

      case MessageType.screenplay:
        if (message.screenplay != null) {
          // 从 ChatProvider 获取视频生成进度
          final provider = Provider.of<ChatProvider>(context, listen: false);
          // 当视频正在生成时（进度大于70%），计算视频进度
          // 视频生成进度范围是 70%-100%，转换为 0-1
          double? videoProgress;
          if (provider.progress > 0.7 && provider.isProcessing) {
            // 添加一个小的容错值避免浮点数精度问题
            double rawProgress = (provider.progress - 0.7) / 0.3;
            // 限制在 0-1 范围内，并四舍五入到两位小数
            videoProgress = double.parse(rawProgress.toStringAsFixed(2));
            // 确保不小于0且不大于1
            if (videoProgress < 0) videoProgress = 0;
            if (videoProgress > 1) videoProgress = 1;
          }
          return ScreenplayCard(
            screenplay: message.screenplay!,
            videoProgress: videoProgress,
            onRetryScene: (sceneId) {
              final provider = Provider.of<ChatProvider>(context, listen: false);
              provider.retryScene(sceneId);
            },
            onEditPrompt: (sceneId, customPrompt) {
              final provider = Provider.of<ChatProvider>(context, listen: false);
              provider.retryScene(sceneId, customVideoPrompt: customPrompt);
            },
            // 🆕 手动触发单个场景生成
            onStartGeneration: (sceneId) {
              final provider = Provider.of<ChatProvider>(context, listen: false);
              provider.startSceneGeneration(sceneId);
            },
            // 🆕 手动触发所有待处理场景生成
            onStartAllGeneration: () {
              final provider = Provider.of<ChatProvider>(context, listen: false);
              provider.startAllPendingScenesGeneration();
            },
            // 🆕 合并场景视频
            onMergeVideos: onMergeVideos != null
                ? () => onMergeVideos!(message.screenplay!)
                : null,
          );
        }
        return Text('剧本数据加载中...');
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 清理HTML标签，将<details>/<summary>等转换为可读格式
  String _cleanHtmlTags(String content) {
    String cleaned = content;
    
    // 处理 <details><summary>思考过程</summary>...</details> 格式
    // 提取summary标题和内容
    final detailsRegex = RegExp(
      r'<details>\s*<summary>(.*?)</summary>([\s\S]*?)</details>',
      multiLine: true,
    );
    
    cleaned = cleaned.replaceAllMapped(detailsRegex, (match) {
      final title = match.group(1)?.trim() ?? '详情';
      final body = match.group(2)?.trim() ?? '';
      // 转换为markdown折叠格式（使用引用块样式）
      return '\n> **$title**\n>\n> ${body.replaceAll('\n', '\n> ')}\n';
    });
    
    // 清理其他HTML标签
    cleaned = cleaned.replaceAll(RegExp(r'<details>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'</details>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'<summary>'), '**');
    cleaned = cleaned.replaceAll(RegExp(r'</summary>'), '**\n');
    
    // 清理可能残留的其他HTML标签
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');
    
    return cleaned.trim();
  }

  /// 构建信息标签
  Widget _buildInfoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFEC4899)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF831843),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取情绪标签的渐变颜色
  List<Color> _getEmotionGradient(int index) {
    final gradients = [
      [const Color(0xFFEC4899), const Color(0xFFF472B6)], // 粉色
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)], // 紫色
      [const Color(0xFF06B6D4), const Color(0xFF22D3EE)], // 青色
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)], // 橙色
      [const Color(0xFF10B981), const Color(0xFF34D399)], // 绿色
      [const Color(0xFF6366F1), const Color(0xFF818CF8)], // 靛蓝
      [const Color(0xFFEF4444), const Color(0xFFF87171)], // 红色
    ];
    return gradients[index % gradients.length];
  }

  /// 显示图片全屏查看器
  void _showImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ImageViewerDialog(imageUrl: imageUrl),
    );
  }

  /// 打开剧本草稿审核页面（从历史记录）
  void _openDraftReviewScreen(BuildContext context, ScreenplayDraft draft) {
    // 更新 provider 的当前草稿
    final provider = Provider.of<ChatProvider>(context, listen: false);
    provider.setCurrentDraft(draft);

    // 导航到审核页面
    Navigator.pushNamed(
      context,
      '/screenplay-review',
      arguments: ScreenplayReviewScreenArgs(
        draft: draft,
        onConfirm: (confirmedDraft) async {
          // 确认后开始生成图片和视频
          await provider.confirmDraft();
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
        onRegenerate: (feedback) async {
          return await provider.regenerateDraft(feedback);
        },
        onRegenerateCharacterSheets: () async {
          await provider.regenerateCharacterSheets();
        },
      ),
    );
  }
}

/// 图片全屏查看对话框
class _ImageViewerDialog extends StatefulWidget {
  final String imageUrl;

  const _ImageViewerDialog({required this.imageUrl});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  bool _isDownloading = false;
  String? _downloadProgress;

  Future<void> _downloadImage() async {
    setState(() => _isDownloading = true);
    _downloadProgress = '准备下载...';

    try {
      print('📥 开始下载图片: ${widget.imageUrl}');

      final dio = Dio();
      // 设置更长的超时时间（图片可能比较大）
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 60);
      dio.options.sendTimeout = const Duration(seconds: 30);

      // ============================================
      // 使用 Downloads 目录（用户可访问）
      // ============================================
      final downloadDir = await getExternalStorageDirectory();
      if (downloadDir == null) {
        throw Exception('无法访问外部存储');
      }

      // 创建 AI漫导 子目录
      final appDir = Directory('${downloadDir.path}/AI漫导');
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      print('📁 保存目录: ${appDir.path}');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // 从 URL 中提取文件扩展名，如果没有则使用 .png
      String extension = '.png';
      try {
        final uri = Uri.parse(widget.imageUrl);
        final path = uri.path;
        if (path.contains('.')) {
          extension = '.${path.split('.').last}';
        }
      } catch (_) {
        extension = '.png';
      }

      final filename = 'image_$timestamp$extension';
      final filePath = '${appDir.path}/$filename';
      print('📄 目标文件: $filePath');

      setState(() => _downloadProgress = '下载中...');

      await dio.download(
        widget.imageUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            setState(() => _downloadProgress = '下载中: $progress%');
            print('📊 下载进度: $progress% ($received/${total} bytes)');
          } else {
            setState(() => _downloadProgress = '下载中: ${received} bytes');
          }
        },
      );

      print('✅ 下载成功: $filePath');

      if (mounted) {
        setState(() => _downloadProgress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片已保存到:\n存储/AI漫导/\n$filename'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '确定',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ 下载失败: $e');
      if (mounted) {
        setState(() => _downloadProgress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '关闭',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // 背景点击关闭
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black.withOpacity(0.9),
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // 图片内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 图片
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    memCacheWidth: 1920,
                    memCacheHeight: 1080,
                    errorWidget: (context, url, error) {
                      return Container(
                        width: 300,
                        height: 300,
                        color: Colors.grey.shade800,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            SizedBox(height: 16),
                            Text('图片加载失败', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // 操作按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 下载按钮
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB8D1), Color(0xFFFFD4E3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB8D1).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: _isDownloading
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_downloadProgress != null) ...[
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _downloadProgress!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ] else
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : IconButton(
                                onPressed: _downloadImage,
                                icon: const Icon(Icons.download, color: Colors.white),
                              ),
                      ),

                      // 关闭按钮
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 视频播放器组件
class _VideoPlayer extends StatefulWidget {
  final String url;
  final VoidCallback? onVideoEnded;

  const _VideoPlayer({Key? key, required this.url, this.onVideoEnded}) : super(key: key);

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isDownloading = false;
  bool _isVisible = false;
  bool _hasAttemptedInit = false;
  bool _hasEndedCallbackFired = false;  // 新增：防止回调重复触发

  @override
  void initState() {
    super.initState();
    // 不再自动初始化，等待用户手动点击播放
  }

  /// 暂停视频（供管理器调用）
  void _pauseVideo() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }
  }

  /// 完全释放播放器资源（用于节省内存）
  void _disposePlayer() {
    try {
      _chewieController?.dispose();
      _chewieController = null;
      _videoController?.dispose();
      _videoController = null;
      _isInitialized = false;
      _hasAttemptedInit = false; // 允许重新初始化
      _hasError = false;
      _errorMessage = null;
      debugPrint('🎬 已释放视频播放器资源: ${widget.url}');
    } catch (e) {
      debugPrint('🎬 释放播放器失败: $e');
    }
  }

  Future<void> _initializePlayer() async {
    if (_hasAttemptedInit) return;

    // 请求独占初始化权 - 如果已有视频在初始化，则放弃本次初始化
    if (!VideoPlayerManager().requestInitialization(this)) {
      // 重置标记，允许稍后重试
      _hasAttemptedInit = false;
      debugPrint('🎬 放弃初始化：已有其他视频正在初始化或需要等待');
      return;
    }

    _hasAttemptedInit = true;
    bool initSuccess = false;

    try {
      print('🎬 初始化视频播放器: ${widget.url}');

      File videoFile;

      // 判断是本地文件还是网络 URL
      if (widget.url.startsWith('/') || widget.url.startsWith('file://')) {
        // 本地文件路径，直接使用
        print('🎬 检测到本地文件路径');
        videoFile = File(widget.url.startsWith('file://') ? widget.url.replaceFirst('file://', '') : widget.url);
      } else {
        // 网络 URL，使用缓存管理器
        print('🎬 检测到网络 URL');
        final cacheManager = VideoCacheManager();

        // 先检查是否已缓存
        final isCached = await cacheManager.isCached(widget.url);
        print('🎬 视频缓存状态: ${isCached ? "已缓存" : "未缓存"}');

        if (isCached) {
          // 使用缓存文件
          videoFile = await cacheManager.getCachedVideo(widget.url);
        } else {
          // 显示下载进度
          if (mounted) {
            setState(() {
              _isDownloading = true;
            });
          }

          // 下载并缓存视频
          videoFile = await cacheManager.getCachedVideo(widget.url);
        }
      }

      // 使用本地文件初始化播放器（低内存配置）
      _videoController = VideoPlayerController.file(
        videoFile,
        videoPlayerOptions: VideoPlayerOptions(
          // 减少缓冲区大小以降低内存占用
          mixWithOthers: false, // 不与其他音频混合
          allowBackgroundPlayback: false, // 不允许后台播放
        ),
      );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        showControls: true,
        // 添加进度条但简化其他控件
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: false, // 禁用速度调节减少UI
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: _isDownloading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        '正在缓存视频...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    '播放失败',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isDownloading = false;
        });
      }
      print('✅ 视频播放器初始化成功');

      // 重置结束标志
      _hasEndedCallbackFired = false;

      // 监听视频播放结束事件
      _videoController!.addListener(() {
        if (!_hasEndedCallbackFired &&
            _videoController!.value.isInitialized &&
            widget.onVideoEnded != null) {
          final position = _videoController!.value.position;
          final duration = _videoController!.value.duration;

          // 当播放位置接近结束时（允许100ms的误差）
          if (position >= duration - const Duration(milliseconds: 100)) {
            _hasEndedCallbackFired = true;
            print('🎬 视频播放结束，触发回调 (position: $position, duration: $duration)');
            // 使用 Future.microtask 延迟执行，避免在监听器中直接调用 setState
            Future.microtask(() {
              if (widget.onVideoEnded != null) {
                widget.onVideoEnded!();
              }
            });
          }
        }
      });

      initSuccess = true;
    } catch (e) {
      print('❌ 视频播放器初始化失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isDownloading = false;
        });
      }
      initSuccess = false;
    } finally {
      // 释放初始化锁，传入成功状态
      VideoPlayerManager().completeInitialization(initSuccess);
    }
  }

  @override
  void dispose() {
    // 从管理器中注销
    VideoPlayerManager().unregisterPlayer(this);
    // 释放资源
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('视频链接已复制'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-detector-${widget.url}'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (visiblePercentage > 20 && !_isVisible) {
          setState(() {
            _isVisible = true;
          });
          // 不再自动初始化，等待用户点击
        } else if (visiblePercentage < 10 && _isVisible) {
          // 视频变得不可见 - 立即释放资源
          setState(() {
            _isVisible = false;
          });
          _disposePlayer(); // 完全释放播放器，不仅仅是暂停
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频播放器
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 200,
              width: double.infinity,
              color: Colors.black,
              child: _buildPlayerContent(),
            ),
          ),
        
        // 视频链接和复制按钮
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '视频链接: ${widget.url}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _copyUrl,
                icon: const Icon(Icons.copy, size: 16),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(36, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF8B5CF6),
                ),
                tooltip: '复制视频链接',
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '视频加载失败\n$_errorMessage',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _errorMessage = null;
                });
                _initializePlayer();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_isDownloading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 8),
            Text(
              '缓存视频中...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      // 显示播放按钮占位符
      return GestureDetector(
        onTap: _initializePlayer,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '点击播放视频',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Chewie(controller: _chewieController!);
  }
}

/// Pop Art 背景绘制器
class _PopArtBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFFFF0F5)
      ..style = PaintingStyle.fill;

    // 填充背景
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 绘制速度线
    _drawSpeedLines(canvas, size);

    // 绘制半调圆点
    _drawHalftoneDots(canvas, size);

    // 绘制漫画放射线
    _drawRadialLines(canvas, size);
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFFF69B4).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 对角线速度线
    for (int i = -200; i < size.width.toInt() + 200; i += 40) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble() + 100, size.height),
        linePaint,
      );
    }
  }

  void _drawHalftoneDots(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFFFF69B4).withOpacity(0.06)
      ..style = PaintingStyle.fill;

    // 角落的半调圆点
    _drawDotPattern(canvas, Offset(0, 0), 150, 150, dotPaint);
    _drawDotPattern(canvas, Offset(size.width - 150, 0), 150, 150, dotPaint);
    _drawDotPattern(canvas, Offset(0, size.height - 150), 150, 150, dotPaint);
    _drawDotPattern(canvas, Offset(size.width - 150, size.height - 150), 150, 150, dotPaint);
  }

  void _drawDotPattern(Canvas canvas, Offset offset, double width, double height, Paint paint) {
    const dotSpacing = 12.0;
    const dotRadius = 2.0;

    for (double x = offset.dx; x < offset.dx + width; x += dotSpacing) {
      for (double y = offset.dy; y < offset.dy + height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  void _drawRadialLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF1A1A1A).withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width * 0.8, size.height * 0.2);

    for (int i = 0; i < 360; i += 15) {
      final angle = i * 3.14159 / 180;
      final endX = center.dx + cos(angle) * 300;
      final endY = center.dy + sin(angle) * 300;

      canvas.drawLine(center, Offset(endX, endY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 情绪标签组件 - 带渐变和微动画效果
class _EmotionChip extends StatefulWidget {
  final String emotion;
  final List<Color> gradientColors;

  const _EmotionChip({
    required this.emotion,
    required this.gradientColors,
  });

  @override
  State<_EmotionChip> createState() => _EmotionChipState();
}

class _EmotionChipState extends State<_EmotionChip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradientColors.first.withOpacity(_isPressed ? 0.5 : 0.3),
                    blurRadius: _isPressed ? 12 : 8,
                    offset: Offset(0, _isPressed ? 4 : 2),
                  ),
                ],
              ),
              child: Text(
                widget.emotion,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 视频合并进度对话框
class _MergeProgressDialog extends StatelessWidget {
  final Screenplay screenplay;

  const _MergeProgressDialog({required this.screenplay});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.video_library_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('合并视频', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Consumer<VideoMergeProvider>(
          builder: (context, mergeProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 剧本标题
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.movie_creation_outlined, color: Color(0xFFEC4899), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          screenplay.scriptTitle,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 进度信息
                if (mergeProvider.status == MergeStatus.merging) ...[
                  // 进度条
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: mergeProvider.progress,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFEC4899),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 状态文本
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mergeProvider.statusMessage,
                          style: const TextStyle(color: Color(0xFFB8B8D1)),
                        ),
                      ),
                      Text(
                        '${(mergeProvider.progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xFFEC4899),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ] else if (mergeProvider.status == MergeStatus.completed) ...[
                  // 完成状态
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          mergeProvider.mergedVideoFile != null ? '视频合并完成！' : '已下载 ${mergeProvider.totalScenes} 个场景视频！',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  // 显示合并后的视频播放按钮或场景列表
                  if (mergeProvider.mergedVideoFile != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.video_library, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '合并后的视频已就绪',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mergeProvider.mergedVideoFile!.path.split('/').last,
                                  style: const TextStyle(color: Color(0xFFB8B8D1), fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (mergeProvider.scenes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // 场景列表
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list, color: Color(0xFF8B5CF6), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '场景列表 (${mergeProvider.totalScenes})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...mergeProvider.scenes.map((scene) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${scene.sceneIndex}',
                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        scene.narration.isEmpty ? '场景 ${scene.sceneIndex}' : scene.narration,
                                        style: TextStyle(color: Color(0xFFB8B8D1), fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ] else if (mergeProvider.status == MergeStatus.error) ...[
                  // 错误状态
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mergeProvider.errorMessage ?? '合并失败',
                            style: const TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        Consumer<VideoMergeProvider>(
          builder: (context, mergeProvider, child) {
            if (mergeProvider.status == MergeStatus.merging) {
              // 合并中 - 取消按钮
              return TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('后台运行', style: TextStyle(color: Color(0xFFB8B8D1))),
              );
            } else if (mergeProvider.status == MergeStatus.completed) {
              // 合并完成 - 多个操作按钮
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 第一行：播放和保存按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (mergeProvider.mergedVideoFile != null)
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showMergedVideoPlayer(context, mergeProvider.mergedVideoFile!.path);
                          },
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('播放视频'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          await _saveMergedVideoToGallery(context, mergeProvider.mergedVideoFile!.path);
                        },
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('保存到相册'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 第二行：完成按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<VideoMergeProvider>().reset();
                        },
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ],
              );
            } else if (mergeProvider.status == MergeStatus.error) {
              // 错误状态 - 重试和关闭按钮
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<VideoMergeProvider>().reset();
                    },
                    child: const Text('关闭', style: TextStyle(color: Color(0xFFB8B8D1))),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      context.read<VideoMergeProvider>().mergeVideos(screenplay);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('重试'),
                  ),
                ],
              );
            }

            // 默认关闭按钮
            return TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('关闭', style: TextStyle(color: Color(0xFFB8B8D1))),
            );
          },
        ),
      ],
    );
  }

  /// 显示合并后的视频播放器
  void _showMergedVideoPlayer(BuildContext context, String videoPath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            // 视频播放器
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.6,
              child: _VideoPlayer(url: videoPath),
            ),
            // 关闭按钮
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存合并后的视频到相册
  Future<void> _saveMergedVideoToGallery(BuildContext context, String videoPath) async {
    try {
      // 显示保存中提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('正在保存到相册...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      await GalleryService().saveVideoToGallery(videoPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已保存到相册 (Movies/Movies)'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
