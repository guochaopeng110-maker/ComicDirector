import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../controllers/screenplay_controller.dart';
import '../controllers/screenplay_draft_controller.dart';
import '../models/chat_message.dart';
import '../models/screenplay_draft.dart';
import '../models/modification_plan.dart';
import '../models/script.dart';
import '../services/api_service.dart';
import '../services/api_config_service.dart';
import '../utils/app_logger.dart';
import 'conversation_provider.dart';

/// 用户上传的图片信息
class UserImage {
  final String base64;  // 移除 File 依赖，直接存储 base64
  final String? mimeType;

  UserImage({
    required this.base64,
    this.mimeType,
  });

  /// 获取用于发送给 GLM 的格式
  /// GLM API 要求纯 base64 字符串，不需要 data:image/xxx;base64, 前缀
  String toLmFormat() {
    // GLM 官方文档要求直接返回 base64 字符串
    // 参考: https://docs.bigmodel.cn/cn/guide/models/vlm/glm-4.5v
    return base64;
  }

  /// 获取 MIME 类型，默认为 image/jpeg
  String getMimeType() {
    return mimeType ?? 'image/jpeg';
  }
}

/// 管理聊天状态和剧本生成的 Provider
class ChatProvider extends ChangeNotifier {
  final ScreenplayController _screenplayController = ScreenplayController();
  final ScreenplayDraftController _draftController = ScreenplayDraftController();
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final List<ChatMessage> _messages = [];

  // 会话管理器（延迟注入）
  ConversationProvider? _conversationProvider;

  // 用户上传的参考图片（最多3张）
  final List<UserImage> _userImages = [];

  // 当前剧本草稿
  ScreenplayDraft? _currentDraft;

  bool _isProcessing = false;
  bool _isCancelling = false;
  String? _errorMessage;
  String? _taskId;
  double _progress = 0.0;
  String _progressStatus = '';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<UserImage> get userImages => List.unmodifiable(_userImages);
  ScreenplayDraft? get currentDraft => _currentDraft;
  bool get isProcessing => _isProcessing;
  bool get isCancelling => _isCancelling;
  String? get errorMessage => _errorMessage;
  String? get taskId => _taskId;
  double get progress => _progress;
  String get progressStatus => _progressStatus;
  ScreenplayController get screenplayController => _screenplayController;
  ScreenplayDraftController get draftController => _draftController;

  // 是否可以继续添加图片（最多3张）
  bool get canAddMoreImages => _userImages.length < 3;

  /// 设置会话管理器（用于持久化消息）
  void setConversationProvider(ConversationProvider? provider) {
    _conversationProvider = provider;
  }

  ChatProvider() {
    // 添加初始欢迎消息
    _addMessage(ChatMessage(
      id: 'welcome',
      role: MessageRole.agent,
      content: '欢迎使用 AI 漫导！告诉我你想创作什么样的视频，我会帮你规划剧本并生成。例如："生成一只猫打架的视频"',
      type: MessageType.text,
    ));

    // 监听剧本更新
    _screenplayController.screenplayStream.listen((screenplay) {
      // 更新或添加剧本消息
      final existingIndex = _messages.indexWhere(
        (m) => m.type == MessageType.screenplay && m.screenplay?.taskId == screenplay.taskId,
      );

      if (existingIndex >= 0) {
        _messages[existingIndex] = _messages[existingIndex].updateScreenplay(screenplay);
      } else {
        _addMessage(ChatMessage.screenplay(screenplay));
      }
      notifyListeners();
    });

    // 监听进度更新
    _screenplayController.progressStream.listen((progressData) {
      _progress = progressData.progress;
      _progressStatus = progressData.status;
      notifyListeners();
    });

    // 监听剧本草稿更新
    _draftController.draftStream.listen((draft) {
      _currentDraft = draft;
      notifyListeners();
    });

    // 监听草稿生成进度
    _draftController.progressStream.listen((progressData) {
      _progress = progressData.progress;
      _progressStatus = progressData.status;
      // 更新思考消息
      _updateThinkingMessage(progressData.status);
      notifyListeners();
    });
  }

  /// 检测用户是否想要生成视频
  bool _isVideoGenerationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    // 检测视频生成相关关键词
    final videoKeywords = [
      '生成视频', '制作视频', '视频',
      '生成动画', '制作动画',
      '帮我做', '帮我生成',
      '创建视频', 'create video',
    ];
    return videoKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// 处理普通聊天（非视频生成请求）
  /// 调用 GLM 获取 AI 的自然回复，包含思考过程
  /// 支持图片识别：如果用户上传了图片，会使用 GLM-4.5V 进行分析
  /// 在一个消息框内流式显示：思考过程 -> 最终内容
  Future<void> _handleNormalChat(String message) async {
    // 添加"思考中"消息（流式消息的初始状态）
    // 注意：必须使用 streamMessage.id，而不是另外创建 messageId
    final streamMessage = ChatMessage.thinking('💭 思考中...');
    final messageId = streamMessage.id; // 使用同一个 ID
    _addMessage(streamMessage);

    _isProcessing = true;
    notifyListeners();

    try {
      // 构建对话历史（最近几条）
      // 只获取用户之前的对话，不包含当前正在生成的消息
      final userMessages = _messages
          .where((m) =>
              m.type == MessageType.text &&
              m.role == MessageRole.user &&
              m.id != messageId)  // 排除当前正在生成的流式消息
          .take(5)
          .toList();

      final recentMessages = userMessages.map((m) => {
            'role': 'user',
            'content': m.content,
          }).toList();

      // 获取用户上传的图片（如果有）
      final userImage = _userImages.isNotEmpty ? _userImages.first : null;
      final imageBase64 = userImage?.base64;
      final imageMimeType = userImage?.getMimeType();

      // 调用支持图片识别的聊天方法
      final thinkingBuffer = StringBuffer();
      final contentBuffer = StringBuffer();

      await _apiService.chatWithGLMImageSupport(
        userMessage: message,
        imageBase64: imageBase64,
        imageMimeType: imageMimeType,
        conversationHistory: recentMessages,
      ).forEach((chunk) {
        if (chunk.isThinking) {
          thinkingBuffer.write(chunk.text);
          // 实时更新消息内容
          _updateStreamMessage(messageId, thinkingBuffer.toString(), '');
        } else if (chunk.isContent) {
          contentBuffer.write(chunk.text);
          // 实时更新消息内容（思考 + 内容）
          _updateStreamMessage(messageId, thinkingBuffer.toString(), contentBuffer.toString());
        }
      });

      // 完成后，将消息类型改为普通文本消息
      _finalizeStreamMessage(messageId, thinkingBuffer.toString(), contentBuffer.toString());

      // 注意：普通聊天模式下不自动清除用户图片，用户可能想继续问关于这张图片的问题
      // 只有在开始视频生成时才清除图片
    } catch (e) {
      // 移除流式消息
      _messages.removeWhere((m) => m.id == messageId);
      _addMessage(ChatMessage.error('回复失败: $e'));
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 更新流式消息的内容（思考过程 + 最终内容）
  void _updateStreamMessage(String messageId, String thinking, String content) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final sb = StringBuffer();

      // 添加思考过程（如果有）
      if (thinking.isNotEmpty) {
        sb.writeln('<details>');
        sb.writeln('<summary>💭 思考过程</summary>');
        sb.writeln();
        sb.writeln(thinking);
        sb.writeln();
        sb.writeln('</details>');
        sb.writeln();
      }

      // 添加分隔线（如果有思考和内容）
      if (thinking.isNotEmpty && content.isNotEmpty) {
        sb.writeln('---');
        sb.writeln();
      }

      // 添加最终内容（如果有）
      if (content.isNotEmpty) {
        sb.write(content);
      }

      // 关键：一旦有内容输出，就把类型改成 text，这样就不会被 _addMessage 误删
      final newType = content.isNotEmpty ? MessageType.text : MessageType.thinking;
      _messages[index] = ChatMessage(
        id: messageId,
        role: MessageRole.agent,
        content: sb.toString(),
        type: newType,
      );
      notifyListeners();
    }
  }

  /// 完成流式消息，转为普通文本消息
  /// 注意：只保留最终内容，不保留思考过程（思考过程只是临时显示）
  void _finalizeStreamMessage(String messageId, String thinking, String content) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      // 只保留最终内容，删除思考过程
      _messages[index] = ChatMessage(
        id: messageId,
        role: MessageRole.agent,
        content: content.isEmpty ? '（无回复内容）' : content,
        type: MessageType.text,
      );
      notifyListeners();
    }
  }

  /// 发送用户消息
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    if (_isProcessing) return;

    // 检查 API Key 配置
    final apiStatus = ApiConfigService.checkChatKeys();
    if (!apiStatus.isConfigured) {
      _errorMessage = apiStatus.friendlyMessage;
      notifyListeners();
      return;
    }

    // 添加用户消息
    _addMessage(ChatMessage.userText(message));

    // 检测用户意图
    if (_isVideoGenerationRequest(message)) {
      // 视频生成请求，启动剧本生成流程
      await _handleVideoGenerationRequest(message);
      return;
    }

    // 检测是否是素材修改请求
    if (_currentDraft != null && _isAssetModificationRequest(message)) {
      await _handleAssetModification(message);
      return;
    }

    // 普通聊天，返回引导响应
    await _handleNormalChat(message);
  }

  /// 检测是否是素材修改请求
  bool _isAssetModificationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    final modificationKeywords = [
      '修改', '改', '换个', '重新生成',
      '场景', '角色', '背景',
      '调整', '优化', '换掉',
      '把', '将', '让',
    ];

    // 检查是否包含修改关键词和场景/角色相关词汇
    final hasModificationKeyword = modificationKeywords.any((keyword) => lowerMessage.contains(keyword));
    final hasSceneOrCharacter = lowerMessage.contains('场景') ||
        lowerMessage.contains('scene') ||
        lowerMessage.contains('角色') ||
        lowerMessage.contains('character') ||
        RegExp(r'[0-9]+[号场]').hasMatch(message);

    return hasModificationKeyword && (hasSceneOrCharacter || _currentDraft!.scenes.isNotEmpty);
  }

  /// 处理素材修改请求
  Future<void> _handleAssetModification(String message) async {
    _isProcessing = true;
    notifyListeners();

    try {
      // 添加"思考中"消息
      final streamMessage = ChatMessage.thinking('💭 正在分析修改请求...');
      final messageId = streamMessage.id;
      _addMessage(streamMessage);

      // 使用 AI 分析用户的修改请求
      final modificationPlan = await _analyzeModificationRequest(message);

      // 执行修改
      await _executeModification(modificationPlan, messageId);

      // 移除"思考中"消息
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      _addMessage(ChatMessage.error('修改失败: $e'));
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 分析修改请求，提取修改意图
  Future<ModificationPlan> _analyzeModificationRequest(String userRequest) async {
    // 构建提示词
    final prompt = '''
用户请求修改: $userRequest

当前剧本信息:
- 标题: ${_currentDraft!.title}
- 场景数量: ${_currentDraft!.sceneCount}

请分析用户的修改请求，返回 JSON 格式的修改计划：

{
  "type": "修改类型 (scene_narration/character_description/image_prompt/video_prompt)",
  "target": "修改目标 (场景ID 或 角色名)",
  "changes": "具体的修改内容",
  "scene_id": 场景ID (如果是场景修改，整数),
  "new_content": "新的内容"
}

如果用户没有明确指定要修改哪个场景，请根据上下文推断。
只返回 JSON，不要有其他内容。
''';

    try {
      final responseStream = _apiService.sendToGLMStream(
        [{'role': 'user', 'content': prompt}],
        systemPrompt: '''你是一个专业的剧本编辑助手。请分析用户的修改请求，返回 JSON 格式的修改计划。
只返回 JSON 对象，不要有其他内容。''',
      );

      final responseText = await responseStream
          .where((chunk) => chunk.isContent)
          .map((chunk) => chunk.text)
          .join('');

      return _parseModificationPlan(responseText);
    } catch (e) {
      debugPrint('分析修改请求失败: $e');
      // 如果 AI 解析失败，返回默认计划
      return ModificationPlan(
        type: 'unknown',
        target: 'unknown',
        changes: userRequest,
        sceneId: null,
        newContent: null,
      );
    }
  }

  /// 解析 AI 返回的修改计划
  ModificationPlan _parseModificationPlan(String response) {
    // 提取 JSON
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
    if (jsonMatch != null) {
      try {
        final jsonStr = jsonMatch.group(0)!;
        final Map<String, dynamic> json = jsonDecode(jsonStr);
        return ModificationPlan.fromJson(json);
      } catch (e) {
        debugPrint('解析修改计划失败: $e');
      }
    }

    // 默认计划
    return ModificationPlan(
      type: 'unknown',
      target: 'unknown',
      changes: response,
      sceneId: null,
      newContent: null,
    );
  }

  /// 执行修改
  Future<void> _executeModification(ModificationPlan plan, String messageId) async {
    if (plan.type == 'scene_narration' && plan.sceneId != null) {
      // 修改场景旁白
      _currentDraft = _currentDraft!.updateSceneNarration(plan.sceneId!, plan.changes);
      _draftController.updateSceneNarration(plan.sceneId!, plan.changes);

      _updateStreamMessage(messageId, '已修改场景${plan.sceneId}的旁白', plan.changes);
    } else if (plan.type == 'character_description') {
      // 修改角色描述
      _addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.agent,
        content: '已收到角色描述修改请求: ${plan.changes}\n\n注意：角色描述将在下次生成角色设定时生效。',
        type: MessageType.text,
      ));
    } else {
      // 其他类型，提示用户
      _addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.agent,
        content: '已收到修改请求: ${plan.changes}\n\n我理解您想${plan.type}，但目前支持的场景修改类型包括:\n- 修改场景旁白\n- 修改角色描述',
        type: MessageType.text,
      ));
    }

    notifyListeners();
  }

  /// 处理视频生成请求
  Future<void> _handleVideoGenerationRequest(String message) async {
    // 添加"正在规划"消息
    final planningMessage = ChatMessage.thinking('正在规划剧本...');
    _addMessage(planningMessage);

    _isProcessing = true;
    _isCancelling = false;
    _errorMessage = null;
    _progress = 0.0;
    _progressStatus = '正在规划剧本...';
    notifyListeners();

    try {
      // 准备用户图片的 base64 列表
      final userImageUrls = _userImages.map((img) => img.toLmFormat()).toList();

      // 开始生成剧本（传递用户图片）
      final screenplay = await _screenplayController.generateScreenplay(
        message,
        userImages: userImageUrls.isNotEmpty ? userImageUrls : null,
        onProgress: (progress, status) {
          _progress = progress;
          _progressStatus = status;
          _updateThinkingMessage(status);
          notifyListeners();
        },
      );

      // 移除"思考中"消息
      _messages.removeWhere((m) => m.type == MessageType.thinking);
      _taskId = screenplay.taskId;

      // 清除用户上传的参考图片
      clearUserImages();

      AppLogger.success('ChatProvider', '剧本生成完成: ${screenplay.scriptTitle}');
    } catch (e) {
      if (!_isCancelling) {
        _errorMessage = e.toString();
        _addMessage(ChatMessage.error(e.toString()));
      }
      // 移除"思考中"消息
      _messages.removeWhere((m) => m.type == MessageType.thinking);
    } finally {
      _isProcessing = false;
      _isCancelling = false;
      notifyListeners();
    }
  }

  /// 更新"思考中"消息的状态
  void _updateThinkingMessage(String status) {
    final thinkingIndex = _messages.indexWhere((m) => m.type == MessageType.thinking);
    if (thinkingIndex >= 0) {
      _messages[thinkingIndex] = ChatMessage.thinking(status);
    }
  }

  /// 取消当前操作
  void cancelProcessing() {
    if (!_isProcessing) return;

    _isCancelling = true;
    _screenplayController.cancel();
    notifyListeners();
  }

  /// 从相册选择图片
  Future<void> pickImageFromGallery() async {
    if (!canAddMoreImages) {
      _errorMessage = '最多只能添加 3 张图片';
      notifyListeners();
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);

        // 检测 MIME 类型
        String? mimeType;
        if (image.path.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (image.path.toLowerCase().endsWith('.jpg') ||
                   image.path.toLowerCase().endsWith('.jpeg')) {
          mimeType = 'image/jpeg';
        } else if (image.path.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }

        _userImages.add(UserImage(base64: base64, mimeType: mimeType));
        _errorMessage = null;
        notifyListeners();
        AppLogger.info('ChatProvider', '已添加图片，当前共 ${_userImages.length} 张');
      }
    } catch (e) {
      _errorMessage = '选择图片失败: $e';
      notifyListeners();
      AppLogger.error('ChatProvider', '选择图片失败', e);
    }
  }

  /// 拍照
  Future<void> pickImageFromCamera() async {
    if (!canAddMoreImages) {
      _errorMessage = '最多只能添加 3 张图片';
      notifyListeners();
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);

        _userImages.add(UserImage(base64: base64, mimeType: 'image/jpeg'));
        _errorMessage = null;
        notifyListeners();
        AppLogger.info('ChatProvider', '已添加拍照图片，当前共 ${_userImages.length} 张');
      }
    } catch (e) {
      _errorMessage = '拍照失败: $e';
      notifyListeners();
      AppLogger.error('ChatProvider', '拍照失败', e);
    }
  }

  /// 删除指定索引的图片
  void removeImage(int index) {
    if (index >= 0 && index < _userImages.length) {
      _userImages.removeAt(index);
      _errorMessage = null;
      notifyListeners();
      AppLogger.info('ChatProvider', '已删除图片，剩余 ${_userImages.length} 张');
    }
  }

  /// 清除所有用户图片
  void clearUserImages() {
    _userImages.clear();
    notifyListeners();
  }

  /// 重试失败的场景
  Future<void> retryFailedScenes() async {
    if (_taskId == null) {
      _errorMessage = '没有正在进行的任务';
      notifyListeners();
      return;
    }

    final screenplay = _screenplayController.currentScreenplay;
    if (screenplay == null || !screenplay.hasFailed) {
      _errorMessage = '没有失败的场景需要重试';
      notifyListeners();
      return;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _screenplayController.retryFailedScenes(
        onProgress: (progress, status) {
          _progress = progress;
          _progressStatus = status;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 重试单个失败的场景
  /// [sceneId] 要重试的场景 ID
  /// [customVideoPrompt] 用户自定义的视频提示词（可选）
  Future<void> retryScene(int sceneId, {String? customVideoPrompt}) async {
    final screenplay = _screenplayController.currentScreenplay;
    if (screenplay == null) {
      _errorMessage = '没有找到剧本';
      notifyListeners();
      return;
    }

    final scene = screenplay.scenes.firstWhere(
      (s) => s.sceneId == sceneId,
      orElse: () => throw Exception('场景 $sceneId 不存在'),
    );

    if (scene.status != SceneStatus.failed) {
      _errorMessage = '场景 $sceneId 未处于失败状态';
      notifyListeners();
      return;
    }

    // 如果提供了自定义提示词，更新场景
    if (customVideoPrompt != null && customVideoPrompt.isNotEmpty) {
      _screenplayController.updateSceneCustomPrompt(sceneId, customVideoPrompt);
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _screenplayController.retryScene(
        sceneId,
        onProgress: (progress, status) {
          _progress = progress;
          _progressStatus = '重试场景 $sceneId: $status';
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = '重试失败: $e';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 🆕 手动触发单个场景的生成
  /// 可以在任务运行期间调用（不检查 _isProcessing）
  /// [sceneId] 要生成的场景 ID
  Future<void> startSceneGeneration(int sceneId) async {
    final screenplay = _screenplayController.currentScreenplay;
    if (screenplay == null) {
      _errorMessage = '没有找到剧本';
      notifyListeners();
      return;
    }

    final scene = screenplay.scenes.firstWhere(
      (s) => s.sceneId == sceneId,
      orElse: () => throw Exception('场景 $sceneId 不存在'),
    );

    // 只有 pending 状态可以手动触发
    if (scene.status != SceneStatus.pending) {
      if (scene.status == SceneStatus.failed) {
        // 失败状态转为重试
        await retryScene(sceneId);
        return;
      }
      _errorMessage = '场景 $sceneId 无法生成（当前状态：${scene.status.displayName}）';
      notifyListeners();
      return;
    }

    // 🔑 关键：不设置 _isProcessing = true，允许与自动任务并行
    _errorMessage = null;
    notifyListeners();

    try {
      await _screenplayController.startSceneGeneration(
        sceneId,
        onProgress: (progress, status) {
          // 不更新全局进度，避免干扰自动任务的进度显示
          AppLogger.info('手动生成', '场景 $sceneId: $status');
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = '手动生成失败: $e';
      notifyListeners();
    }
  }

  /// 🆕 手动触发所有待处理场景的生成
  Future<void> startAllPendingScenesGeneration() async {
    final screenplay = _screenplayController.currentScreenplay;
    if (screenplay == null) {
      _errorMessage = '没有找到剧本';
      notifyListeners();
      return;
    }

    final hasPending = screenplay.scenes.any((s) => s.status == SceneStatus.pending);
    if (!hasPending) {
      _errorMessage = '没有待处理的场景';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      await _screenplayController.startAllPendingScenesGeneration(
        onProgress: (progress, status) {
          _progress = progress;
          _progressStatus = status;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = '手动生成失败: $e';
      notifyListeners();
    }
  }

  /// 清除对话
  void clearConversation() {
    _messages.clear();
    _errorMessage = null;
    _taskId = null;
    _progress = 0.0;
    _progressStatus = '';

    _addMessage(ChatMessage(
      id: 'welcome',
      role: MessageRole.agent,
      content: '对话已清除。请告诉我你的下一个视频创意！',
      type: MessageType.text,
    ));
    notifyListeners();
  }

  /// 清除错误消息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 设置当前剧本草稿（用于从历史记录重新打开）
  void setCurrentDraft(ScreenplayDraft draft) {
    _currentDraft = draft;
    // 同步到 ScreenplayDraftController
    _draftController.setCurrentDraft(draft);
    notifyListeners();
  }

  /// 更新剧本草稿（从完整预览页面修改后调用）
  void updateDraft(ScreenplayDraft updatedDraft) {
    _currentDraft = updatedDraft;
    // 同步到 ScreenplayDraftController
    _draftController.updateDraft(updatedDraft);
    notifyListeners();
  }

  /// 添加消息并通知监听器
  void _addMessage(ChatMessage message) {
    // 在添加非思考消息之前移除思考消息
    if (message.type != MessageType.thinking) {
      _messages.removeWhere((m) => m.type == MessageType.thinking);
    }

    _messages.add(message);
    notifyListeners();

    // 保存到会话管理器（持久化）
    if (_conversationProvider != null && message.type != MessageType.thinking) {
      _conversationProvider!.saveMessage(message);
    }
  }

  // ==================== 剧本草稿相关方法 ====================

  /// 生成剧本草稿
  Future<ScreenplayDraft> generateDraft(String userPrompt) async {
    if (_isProcessing) {
      throw StateError('正在处理中，请稍候');
    }

    // 添加用户消息
    _addMessage(ChatMessage.userText(userPrompt));

    // 添加"正在生成剧本"消息
    final planningMessage = ChatMessage.thinking('正在生成剧本...');
    _addMessage(planningMessage);

    _isProcessing = true;
    _isCancelling = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final draft = await _draftController.generateDraft(
        userPrompt,
        userImages: _userImages,
      );

      // 移除"正在生成"消息
      _messages.removeWhere((m) => m.type == MessageType.thinking);

      // 保存为当前草稿
      _currentDraft = draft;

      // 添加角色设定生成进度消息
      _addMessage(ChatMessage.thinking('正在生成角色设定...'));

      // 立即生成角色设定，这样用户在剧本确认页面就能看到
      try {
        final userImageUrls = _userImages.map((img) => img.toLmFormat()).toList();
        await _draftController.generateCharacterSheets(
          userImages: userImageUrls.isNotEmpty ? userImageUrls : null,
          onProgress: (progress, status) {
            _updateThinkingMessage(status);
            notifyListeners();
          },
        );
        // 更新当前草稿（包含角色设定）
        _currentDraft = _draftController.currentDraft;
      } catch (e) {
        AppLogger.warn('ChatProvider', '角色设定生成失败，用户可以在确认页面重新生成: $e');
        // 角色设定生成失败不影响流程
      }

      // 移除角色设定生成消息
      _messages.removeWhere((m) => m.type == MessageType.thinking);

      // 添加剧本草稿消息到聊天列表
      _addMessage(ChatMessage.draft(_currentDraft!));

      return _currentDraft!;
    } catch (e) {
      _errorMessage = e.toString();
      // 移除"正在生成"消息
      _messages.removeWhere((m) => m.type == MessageType.thinking);
      _addMessage(ChatMessage.error(e.toString()));
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 重新生成剧本草稿
  Future<ScreenplayDraft> regenerateDraft(String? feedback) async {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final newDraft = await _draftController.regenerateDraft(
        _currentDraft!.taskId,
        feedback: feedback,
      );
      // 更新当前草稿
      _currentDraft = newDraft;
      return newDraft;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 更新场景旁白
  void updateSceneNarration(int sceneId, String newNarration) {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }
    _draftController.updateSceneNarration(sceneId, newNarration);
  }

  /// 确认剧本，开始生成角色设定、图片和视频
  Future<void> confirmDraft() async {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    _isProcessing = true;
    notifyListeners();

    try {
      // 步骤1: 生成角色三视图（确保人物一致性）
      if (_currentDraft!.characterSheets.isEmpty) {
        _progressStatus = '正在生成角色设定...';
        notifyListeners();

        final userImageUrls = _userImages.map((img) => img.toLmFormat()).toList();

        try {
          await _draftController.generateCharacterSheets(
            userImages: userImageUrls.isNotEmpty ? userImageUrls : null,
            onProgress: (progress, status) {
              _progress = progress * 0.2; // 角色生成占总进度的20%
              _progressStatus = status;
              notifyListeners();
            },
          );

          // 更新当前草稿（确保获取到最新的角色设定）
          _currentDraft = _draftController.currentDraft;
          notifyListeners();
        } catch (e) {
          AppLogger.warn('ChatProvider', '角色设定生成失败，继续生成视频: $e');
          // 角色设定生成失败不影响后续流程
        }
      }

      // 步骤2: 将草稿转换为正式剧本
      _progressStatus = '正在确认剧本...';
      notifyListeners();

      final confirmedScreenplay = await _draftController.confirmDraft(_currentDraft!.taskId);

      // 步骤3: 准备用户图片的 base64 列表（用于场景1图生图）
      final userImageUrls = _userImages.map((img) => img.toLmFormat()).toList();

      // 步骤4: 提取角色组合三视图 URL（用于视频生成时保持人物一致性）
      // 新版本：每个角色只有一张组合三视图
      final List<String> characterImageUrls = [];
      if (_currentDraft!.characterSheets.isNotEmpty) {
        for (final sheet in _currentDraft!.characterSheets) {
          // 使用 referenceImageUrl getter，它优先返回 combinedViewUrl
          final refUrl = sheet.referenceImageUrl;
          if (refUrl != null && refUrl.isNotEmpty) {
            characterImageUrls.add(refUrl);
          }
        }
        AppLogger.info('ChatProvider', '提取角色组合三视图: ${characterImageUrls.length} 张');
      }

      // 步骤5: 使用 ScreenplayController 生成图片和视频
      await _screenplayController.generateFromConfirmed(
        confirmedScreenplay,
        userImages: userImageUrls.isNotEmpty ? userImageUrls : null,
        characterImageUrls: characterImageUrls.isNotEmpty ? characterImageUrls : null,
        onProgress: (progress, status) {
          _progress = 0.2 + progress * 0.8; // 视频生成占总进度的80%
          _progressStatus = status;
          notifyListeners();
        },
      );

      // 清除用户上传的参考图片
      clearUserImages();

      AppLogger.success('ChatProvider', '视频生成完成: ${confirmedScreenplay.scriptTitle}');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// 重新生成角色设定
  Future<void> regenerateCharacterSheets() async {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final userImageUrls = _userImages.map((img) => img.toLmFormat()).toList();

      await _draftController.generateCharacterSheets(
        userImages: userImageUrls.isNotEmpty ? userImageUrls : null,
        onProgress: (progress, status) {
          _progress = progress;
          _progressStatus = status;
          notifyListeners();
        },
      );

      // 更新当前草稿（确保获取到最新的角色设定）
      _currentDraft = _draftController.currentDraft;

      AppLogger.success('ChatProvider', '角色设定重新生成完成');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _screenplayController.dispose();
    _draftController.dispose();
    super.dispose();
  }
}
