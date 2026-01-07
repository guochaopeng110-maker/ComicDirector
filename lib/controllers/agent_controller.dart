import 'dart:async';
import 'dart:convert';
import '../models/agent_command.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';

/// 管理 ReAct (推理 + 行动) 循环的控制器
/// 用于 AI 智能体编排
class AgentController {
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  final StreamController<List<ChatMessage>> _messagesController =
      StreamController<List<ChatMessage>>.broadcast();

  // ============================================
  // 取消控制相关
  // ============================================
  bool _isCancelled = false;  // 取消标志
  final StreamController<bool> _cancelController =
      StreamController<bool>.broadcast();

  // 最大迭代次数，防止无限循环
  static const int _maxIterations = 10;

  // 消息流，供 UI 监听
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;

  // 取消状态流，供 UI 监听
  Stream<bool> get cancelStream => _cancelController.stream;

  // 当前消息列表
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  // 是否已取消
  bool get isCancelled => _isCancelled;

  AgentController() {
    // 添加初始问候语
    _addMessage(ChatMessage(
      id: 'welcome',
      role: MessageRole.agent,
      content:
          '欢迎使用 AI 漫导！告诉我你想创作什么样的视频，我会帮你实现。例如："制作一个猫咪在草地上奔跑的视频"',
      type: MessageType.text,
    ));
  }

  /// 设置智谱 API token（已弃用，保留向后兼容）
  @Deprecated('使用 ApiConfigService.setZhipuApiKey() 方法替代')
  Future<void> setToken(String token) async {
    await _apiService.updateTokens(zhipuKey: token);
  }

  /// ============================================
  /// 取消当前操作
  /// ============================================
  /// 由 ChatProvider 调用，中断正在执行的 ReAct 循环
  void cancel() {
    AppLogger.warn('AgentController', '用户请求取消操作');
    _isCancelled = true;
    _cancelController.add(true);

    // 移除"思考中..."状态
    _messages.removeWhere((m) => m.type == MessageType.thinking);
    _messagesController.add(List.from(_messages));

    // 添加取消通知消息
    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.agent,
      content: '操作已取消',
      type: MessageType.text,
    ));
  }

  /// 重置取消状态（在开始新操作前调用）
  void _resetCancelState() {
    _isCancelled = false;
  }

  /// 通过 ReAct 循环处理用户消息
  Future<void> processUserMessage(String userMessage) async {
    AppLogger.info('AgentController', '处理用户消息: $userMessage');

    // 重置取消状态
    _resetCancelState();

    // 添加用户消息到历史记录
    _addMessage(ChatMessage.userText(userMessage));

    try {
      // 运行 ReAct 循环
      await _runReActLoop();
    } catch (e) {
      // 如果是因为取消而抛出的异常，不显示错误
      if (!_isCancelled) {
        AppLogger.error('AgentController', '处理消息失败', e, StackTrace.current);
        _addMessage(ChatMessage.error(e.toString()));
      }
    }
  }

  /// 核心 ReAct 循环：发送历史 -> 获取命令 -> 执行工具 -> 重复
  Future<void> _runReActLoop() async {
    int iteration = 0;
    AppLogger.info('ReAct', '开始 ReAct 循环');

    while (iteration < _maxIterations) {
      // ============================================
      // 检查是否已取消
      // ============================================
      if (_isCancelled) {
        AppLogger.warn('ReAct', '操作已取消，退出循环');
        return;
      }

      iteration++;
      AppLogger.info('ReAct', '迭代 #$iteration');

      // 步骤 1: 发送对话历史到 GLM 并获取下一步命令（流式）
      _updateThinkingStatus('🤔 思考中...');

      try {
        // 使用流式 API，根据开关决定是否显示思考过程
        final contentBuffer = StringBuffer();
        final thinkingBuffer = StringBuffer();
        final showThinking = ApiConfig.USE_THINKING_MODE;
        
        await _apiService.sendToGLMStream(_buildGLMHistory()).forEach((chunk) {
          // 在流式接收过程中也检查取消
          if (_isCancelled) {
            AppLogger.warn('ReAct', '接收 GLM 响应时取消');
            throw Exception('操作已取消');
          }
          
          if (chunk.isThinking && showThinking) {
            // 累积思考内容并实时更新 UI（仅在开关开启时显示）
            thinkingBuffer.write(chunk.text);
            // 显示思考过程（限制长度避免 UI 过长）
            String thinkingText = thinkingBuffer.toString();
            if (thinkingText.length > 200) {
              // 只显示最后200个字符
              thinkingText = '...' + thinkingText.substring(thinkingText.length - 200);
            }
            _updateThinkingStatus('💭 $thinkingText');
          } else if (chunk.isContent) {
            // 累积最终内容
            contentBuffer.write(chunk.text);
          }
        });

        // 再次检查是否在接收响应期间被取消
        if (_isCancelled) {
          AppLogger.warn('ReAct', '接收 GLM 响应后被取消');
          return;
        }

        final commandJson = contentBuffer.toString();

        // 检查是否为空
        if (commandJson.trim().isEmpty) {
          AppLogger.error('ReAct', 'GLM 返回空响应', null, StackTrace.current);
          throw Exception('GLM 返回空响应');
        }

        AppLogger.info('ReAct', 'GLM 响应: ${commandJson.substring(0, commandJson.length > 200 ? 200 : commandJson.length)}...');

        // 移除"思考中..."状态
        _messages.removeWhere((m) => m.type == MessageType.thinking);
        _messagesController.add(List.from(_messages));

        // 步骤 2: 解析命令
        final command = _parseCommand(commandJson);
        AppLogger.command(command.action, command.params);

        // 再次检查是否已取消（在执行命令前）
        if (_isCancelled) {
          AppLogger.warn('ReAct', '执行命令前被取消');
          return;
        }

        // 步骤 3: 执行命令
        final result = await _executeCommand(command);

        // 执行命令后再次检查取消状态
        if (_isCancelled) {
          AppLogger.warn('ReAct', '执行命令后被取消');
          return;
        }

        if (result.success) {
          AppLogger.success('ReAct', '命令执行成功: ${result.result ?? ""}');
        } else {
          AppLogger.error('ReAct', '命令执行失败: ${result.error}');
          // 将错误添加到消息历史，让下次迭代时 GLM 能知道失败了
          _addMessage(ChatMessage.error('${command.action} 失败: ${result.error}'));
          // 继续下一次迭代，让 GLM 决定如何处理
          continue;
        }

        // 步骤 4: 检查是否应该停止
        if (command.action == 'complete') {
          // 添加完成消息
          _addMessage(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: MessageRole.agent,
            content: result.result ?? '任务完成！',
            type: MessageType.text,
          ));
          AppLogger.success('ReAct', '任务完成');
          break;
        }

        // 步骤 5: 将工具结果添加到历史记录供下一次迭代使用
      } catch (e) {
        // 如果是取消操作，不记录错误
        if (_isCancelled) {
          AppLogger.warn('ReAct', '操作已取消');
          return;
        }
        AppLogger.error('ReAct', '迭代失败', e, StackTrace.current);
        // 清理"思考中..."状态
        _messages.removeWhere((m) => m.type == MessageType.thinking);
        _messagesController.add(List.from(_messages));
        rethrow;
      }
    }

    if (iteration >= _maxIterations) {
      AppLogger.error('ReAct', '达到最大迭代次数');
      _addMessage(ChatMessage.error('达到最大迭代次数。请重试。'));
    }
  }

  /// 构建 GLM API 的对话历史
  /// 将 ChatMessages 转换为 GLM 期望的格式
  List<Map<String, String>> _buildGLMHistory() {
    final List<Map<String, String>> history = [];

    // 1. 添加最新的用户消息（只取最后一条用户请求，避免累积）
    ChatMessage? latestUserMessage;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == MessageRole.user) {
        latestUserMessage = _messages[i];
        break;
      }
    }

    if (latestUserMessage != null) {
      history.add({
        'role': 'user',
        'content': latestUserMessage.content,
      });
    }

    // 2. 检查最新状态：是否有视频？是否有图片？
    ChatMessage? latestVideo;
    ChatMessage? latestImage;
    ChatMessage? latestError;

    // 倒序遍历找最新消息
    for (int i = _messages.length - 1; i >= 0; i--) {
      final msg = _messages[i];
      if (latestVideo == null && msg.type == MessageType.video && msg.mediaUrl != null) {
        latestVideo = msg;
      }
      if (latestImage == null && msg.type == MessageType.image && msg.mediaUrl != null) {
        latestImage = msg;
      }
      if (latestError == null && msg.type == MessageType.error) {
        latestError = msg;
      }

      // 找到所有需要的就停止
      if (latestVideo != null && latestImage != null) {
        break;
      }
    }

    // 3. 检测用户是否想要视频
    final userWantsVideo = latestUserMessage != null &&
        (latestUserMessage.content.contains('视频') ||
         latestUserMessage.content.contains('video') ||
         latestUserMessage.content.contains('制作') ||
         latestUserMessage.content.contains('动画') ||
         latestUserMessage.content.contains('生成视频'));

    // 4. 添加工具执行历史和结果（模拟完整对话，让 GLM 知道之前做了什么）
    if (latestError != null) {
      // 有错误，判断是哪个阶段的错误
      if (latestImage != null) {
        // 图片已生成但有错误 = 视频生成失败
        history.add({
          'role': 'assistant',
          'content': '{"action": "generate_image", "params": {"prompt": "..."}}',
        });
        history.add({
          'role': 'user',
          'content': 'TOOL_RESULT: Image generated successfully at ${latestImage.mediaUrl}.',
        });
        history.add({
          'role': 'assistant',
          'content': '{"action": "generate_video", "params": {"image_url": "${latestImage.mediaUrl}", "prompt": "...", "seconds": "8"}}',
        });
        history.add({
          'role': 'user',
          'content': 'ERROR: Video generation failed - ${latestError.content}. '
              'You should call "complete" action to inform the user that video generation failed. '
              'Message should be in Chinese explaining the error.',
        });
        AppLogger.info('History', '视频生成失败: ${latestError.content}');
      } else {
        // 图片生成失败
        history.add({
          'role': 'assistant',
          'content': '{"action": "generate_image", "params": {"prompt": "..."}}',
        });
        history.add({
          'role': 'user',
          'content': 'ERROR: Image generation failed - ${latestError.content}. '
              'You can try generate_image again with a different prompt, or call "complete" to inform the user.',
        });
        AppLogger.info('History', '图片生成失败: ${latestError.content}');
      }
    } else if (latestVideo != null) {
      // 视频已生成，应该调用 complete
      history.add({
        'role': 'assistant',
        'content': '{"action": "generate_image", "params": {"prompt": "..."}}',
      });
      history.add({
        'role': 'user',
        'content': 'TOOL_RESULT: Image generated successfully: ${latestImage?.mediaUrl ?? "unknown"}',
      });
      history.add({
        'role': 'assistant',
        'content': '{"action": "generate_video", "params": {"image_url": "${latestImage?.mediaUrl ?? ""}", "prompt": "...", "seconds": "8"}}',
      });
      history.add({
        'role': 'user',
        'content': 'TOOL_RESULT: Video generated successfully: ${latestVideo.mediaUrl}. '
            'The task is complete. You MUST now call "complete" action to finish and inform the user.',
      });
      AppLogger.info('History', '视频已生成，等待完成: ${latestVideo.mediaUrl}');
    } else if (latestImage != null) {
      // 图片已生成，根据用户意图决定下一步
      // 关键：添加之前的 assistant 响应，让 GLM 知道它已经执行过 generate_image
      history.add({
        'role': 'assistant',
        'content': '{"action": "generate_image", "params": {"prompt": "generated image for user request"}}',
      });

      if (userWantsVideo) {
        // 用户想要视频，必须调用 generate_video
        history.add({
          'role': 'user',
          'content': 'TOOL_RESULT: Image generated successfully at ${latestImage.mediaUrl}. '
              'The user wants a VIDEO. You have already generated the image. '
              'NOW you MUST call "generate_video" with image_url="${latestImage.mediaUrl}". '
              'Do NOT call generate_image again!',
        });
        AppLogger.info('History', '图片已生成，用户需要视频: ${latestImage.mediaUrl}');
      } else {
        // 用户只想要图片，调用 complete
        history.add({
          'role': 'user',
          'content': 'TOOL_RESULT: Image generated successfully at ${latestImage.mediaUrl}. '
              'The user only wanted an IMAGE. Task is complete. '
              'You MUST now call "complete" action.',
        });
        AppLogger.info('History', '图片已生成，用户只要图片: ${latestImage.mediaUrl}');
      }
    }
    // 如果没有任何结果，不添加额外内容，让 GLM 从头开始规划

    AppLogger.info('History', '构建历史完成，共 ${history.length} 条消息');
    for (int i = 0; i < history.length; i++) {
      AppLogger.info('History', '消息 #$i [${history[i]['role']}]: ${history[i]['content']?.substring(0, history[i]['content']!.length > 100 ? 100 : history[i]['content']!.length)}...');
    }
    return history;
  }

  /// 从 GLM 响应中解析 JSON 命令
  AgentCommand _parseCommand(String jsonStr) {
    try {
      AppLogger.info('命令解析', '原始响应长度: ${jsonStr.length} 字符');
      AppLogger.info('命令解析', '原始响应前300字符: ${jsonStr.substring(0, jsonStr.length > 300 ? 300 : jsonStr.length)}...');

      // GLM 可能返回思考过程 + JSON，需要提取最后的 JSON 部分
      String cleaned = jsonStr.trim();

      // 策略1: 查找所有可能的 JSON 对象，验证并选择最后一个有效的
      String? extractedJson = _extractAllValidJsons(cleaned).lastOrNull;

      // 策略2: 如果没找到，尝试查找包含 "action" 的 JSON
      if (extractedJson == null) {
        extractedJson = _extractJsonContaining(cleaned, '"action"');
      }

      // 策略3: 如果还是没找到 action，尝试查找其他命令标识
      if (extractedJson == null) {
        for (final keyword in ['generate_image', 'generate_video', 'complete']) {
          extractedJson = _extractJsonContaining(cleaned, '"$keyword"');
          if (extractedJson != null) break;
        }
      }

      // 策略4: 最后尝试找最后一个完整的 JSON 对象
      if (extractedJson == null) {
        extractedJson = _extractLastCompleteJson(cleaned);
      }

      if (extractedJson == null) {
        throw Exception('无法从响应中提取有效的 JSON 命令。原始响应: $jsonStr');
      }

      cleaned = extractedJson;
      AppLogger.info('命令解析', '提取的 JSON: $cleaned');

      // 如果还存在 markdown 代码块，则移除
      if (cleaned.startsWith('```')) {
        final firstNewline = cleaned.indexOf('\n');
        final lastBackticks = cleaned.lastIndexOf('```');
        if (firstNewline > 0 && lastBackticks > firstNewline) {
          cleaned = cleaned.substring(firstNewline + 1, lastBackticks).trim();
        }
      }

      final Map<String, dynamic> json = jsonDecode(cleaned);
      final command = AgentCommand.fromJson(json);

      AppLogger.success('命令解析', '成功解析命令: ${command.action}');
      if (command.params.isNotEmpty) {
        AppLogger.info('命令解析', '参数: ${command.params}');
      }
      return command;
    } catch (e) {
      AppLogger.error('命令解析', '解析失败', e, StackTrace.current);
      throw Exception('从 GLM 解析命令失败。错误: $e');
    }
  }

  /// 提取包含特定关键字的 JSON 对象
  String? _extractJsonContaining(String text, String keyword) {
    final keywordIndex = text.indexOf(keyword);
    if (keywordIndex < 0) return null;

    // 从关键字位置向前找对应的 {
    int startIndex = -1;
    for (int i = keywordIndex; i >= 0; i--) {
      if (text[i] == '{') {
        startIndex = i;
        break;
      }
    }

    if (startIndex < 0) return null;

    // 从 { 开始，找匹配的 }
    String potentialJson = text.substring(startIndex);
    int braceCount = 0;
    int endIndex = -1;
    for (int i = 0; i < potentialJson.length; i++) {
      if (potentialJson[i] == '{') braceCount++;
      else if (potentialJson[i] == '}') {
        braceCount--;
        if (braceCount == 0) {
          endIndex = i + 1;
          break;
        }
      }
    }

    if (endIndex > 0) {
      return potentialJson.substring(0, endIndex);
    }
    return null;
  }

  /// 提取文本中所有有效的 JSON 对象
  List<String> _extractAllValidJsons(String text) {
    final List<String> validJsons = [];
    int i = 0;

    while (i < text.length) {
      // 跳过非 { 字符
      if (text[i] != '{') {
        i++;
        continue;
      }

      // 找到了 {，尝试提取完整的 JSON 对象
      int braceCount = 0;
      int startIndex = i;
      int endIndex = -1;

      for (int j = i; j < text.length; j++) {
        if (text[j] == '{') braceCount++;
        else if (text[j] == '}') {
          braceCount--;
          if (braceCount == 0) {
            endIndex = j + 1;
            break;
          }
        }
      }

      if (endIndex > 0) {
        final potentialJson = text.substring(startIndex, endIndex);
        // 验证是否是有效的 JSON
        try {
          jsonDecode(potentialJson);
          validJsons.add(potentialJson);
        } catch (_) {
          // 不是有效 JSON，继续
        }
        i = endIndex;
      } else {
        i++;
      }
    }

    return validJsons;
  }

  /// 提取最后一个完整的 JSON 对象
  String? _extractLastCompleteJson(String text) {
    final lastBraceIndex = text.lastIndexOf('{');
    if (lastBraceIndex < 0 || lastBraceIndex >= text.length - 10) return null;

    String potentialJson = text.substring(lastBraceIndex);
    int braceCount = 0;
    int endIndex = -1;
    for (int i = 0; i < potentialJson.length; i++) {
      if (potentialJson[i] == '{') braceCount++;
      else if (potentialJson[i] == '}') {
        braceCount--;
        if (braceCount == 0) {
          endIndex = i + 1;
          break;
        }
      }
    }

    if (endIndex > 0) {
      final json = potentialJson.substring(0, endIndex);
      // 验证是否是有效的 JSON
      try {
        jsonDecode(json);
        return json;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 通过调用相应的工具执行命令
  Future<ToolResult> _executeCommand(AgentCommand command) async {
    switch (command.action) {
      case 'generate_image':
        return await _executeGenerateImage(command);

      case 'generate_video':
        return await _executeGenerateVideo(command);

      case 'complete':
        return ToolResult(
          toolName: 'complete',
          success: true,
          result: command.params['message']?.toString() ?? '任务完成！',
        );

      default:
        return ToolResult(
          toolName: command.action,
          success: false,
          error: '未知操作: ${command.action}',
        );
    }
  }

  /// 执行图片生成
  Future<ToolResult> _executeGenerateImage(AgentCommand command) async {
    final prompt = command.params['prompt']?.toString();

    if (prompt == null || prompt.isEmpty) {
      return ToolResult(
        toolName: 'generate_image',
        success: false,
        error: '缺少提示参数',
      );
    }

    _updateThinkingStatus('正在生成图片: "$prompt"...');

    try {
      final imageUrl = await _apiService.generateImage(prompt);

      // 添加图片消息到聊天
      _addMessage(ChatMessage.imageResult(
        '我为你生成了图片！',
        imageUrl,
      ));

      return ToolResult(
        toolName: 'generate_image',
        success: true,
        result: imageUrl,
      );
    } catch (e) {
      return ToolResult(
        toolName: 'generate_image',
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 执行视频生成（使用 Tuzi Sora API 异步任务模式）
  Future<ToolResult> _executeGenerateVideo(AgentCommand command) async {
    final imageUrl = command.params['image_url']?.toString();
    final prompt = command.params['prompt']?.toString() ?? '';
    final seconds = command.params['seconds']?.toString() ?? '10';

    if (imageUrl == null || imageUrl.isEmpty) {
      return ToolResult(
        toolName: 'generate_video',
        success: false,
        error: '缺少图片链接参数',
      );
    }

    _updateThinkingStatus('正在提交视频生成任务...');

    try {
      // 步骤 1: 提交任务
      final taskResponse = await _apiService.generateVideo(
        imageUrls: [imageUrl], // 单张图片作为数组
        prompt: prompt,
        seconds: seconds,
      );

      // 检查取消状态
      if (_isCancelled) {
        AppLogger.warn('视频生成', '用户取消操作');
        return ToolResult(
          toolName: 'generate_video',
          success: false,
          error: '操作已取消',
        );
      }

      // 步骤 2: 如果任务未完成，轮询等待
      VideoGenerationResponse finalResponse = taskResponse;
      if (!taskResponse.isCompleted && !taskResponse.isFailed) {
        _updateThinkingStatus('视频生成中... (进度: ${taskResponse.progress ?? 0}%)');

        // 轮询直到完成，带进度回调
        finalResponse = await _apiService.pollVideoStatus(
          taskId: taskResponse.id!,
          timeout: const Duration(minutes: 5),
          interval: const Duration(seconds: 2),
          onProgress: (progress, status) {
            // 更新 UI 显示进度
            _updateThinkingStatus('视频生成中... (进度: $progress%)');
          },
          isCancelled: () => _isCancelled, // 传递取消检查
        );

        // 轮询期间可能被取消
        if (_isCancelled) {
          AppLogger.warn('视频生成', '轮询期间用户取消操作');
          return ToolResult(
            toolName: 'generate_video',
            success: false,
            error: '操作已取消',
          );
        }
      }

      // 步骤 3: 检查最终结果
      if (finalResponse.isCompleted && finalResponse.hasVideoUrl) {
        // 添加视频消息到聊天
        _addMessage(ChatMessage.videoResult(
          '你的视频已准备好了！',
          finalResponse.videoUrl!,
        ));

        return ToolResult(
          toolName: 'generate_video',
          success: true,
          result: finalResponse.videoUrl,
        );
      } else if (finalResponse.isFailed) {
        return ToolResult(
          toolName: 'generate_video',
          success: false,
          error: '视频生成失败: ${finalResponse.error ?? "未知错误"}',
        );
      } else {
        // 异常情况：轮询完成但没有视频
        return ToolResult(
          toolName: 'generate_video',
          success: false,
          error: '视频生成异常：未获取到视频链接',
        );
      }
    } catch (e) {
      // 如果是取消操作，返回特定消息
      if (_isCancelled) {
        return ToolResult(
          toolName: 'generate_video',
          success: false,
          error: '操作已取消',
        );
      }
      return ToolResult(
        toolName: 'generate_video',
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 更新或添加"思考中"状态消息
  void _updateThinkingStatus(String status) {
    // 移除现有的思考消息（如果有）
    _messages.removeWhere((m) => m.type == MessageType.thinking);

    // 添加新的思考消息
    _addMessage(ChatMessage.thinking(status));
  }

  /// 添加消息到历史记录并通知监听器
  void _addMessage(ChatMessage message) {
    // 在添加非思考消息之前移除思考消息
    if (message.type != MessageType.thinking) {
      _messages.removeWhere((m) => m.type == MessageType.thinking);
    }

    _messages.add(message);
    _messagesController.add(List.from(_messages));
  }

  /// 清除所有消息（欢迎消息除外）
  void clearMessages() {
    _messages.clear();
    _addMessage(ChatMessage(
      id: 'welcome',
      role: MessageRole.agent,
      content: '对话已清除。请告诉我你的下一个视频创意！',
      type: MessageType.text,
    ));
  }

  /// 释放资源
  void dispose() {
    _messagesController.close();
    _cancelController.close();
  }
}
