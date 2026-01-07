/// 表示来自 GLM 智能体的执行工具命令
class AgentCommand {
  final String action;
  final Map<String, dynamic> params;

  AgentCommand({
    required this.action,
    required this.params,
  });

  factory AgentCommand.fromJson(Map<String, dynamic> json) {
    // 处理简单格式: {"message": "..."} 转换为 {"action": "complete", "params": {"message": "..."}}
    if (json.containsKey('message') && !json.containsKey('action')) {
      return AgentCommand(
        action: 'complete',
        params: {'message': json['message']?.toString() ?? ''},
      );
    }

    // 标准格式: {"action": "...", "params": {...}}
    return AgentCommand(
      action: json['action'] as String? ?? 'complete',
      params: json['params'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'params': params,
    };
  }
}

/// 表示执行工具的结果
class ToolResult {
  final String toolName;
  final bool success;
  final String? result; // URL 或其他结果数据
  final String? error;

  ToolResult({
    required this.toolName,
    required this.success,
    this.result,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'tool': toolName,
      'success': success,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
    };
  }

  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      toolName: json['tool'] as String,
      success: json['success'] as bool,
      result: json['result'] as String?,
      error: json['error'] as String?,
    );
  }
}

/// GLM API 响应模型
class GLMMessage {
  final String role;
  final String content;

  GLMMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }

  factory GLMMessage.fromJson(Map<String, dynamic> json) {
    return GLMMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }
}

class GLMResponse {
  final List<GLMChoice> choices;
  final String? rawContent;

  GLMResponse({
    required this.choices,
    this.rawContent,
  });

  factory GLMResponse.fromJson(Map<String, dynamic> json) {
    final choicesList = json['choices'] as List? ?? [];
    return GLMResponse(
      choices: choicesList
          .map((c) => GLMChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
      rawContent: json['choices'] != null && json['choices'].isNotEmpty
          ? (json['choices'][0]['message']?['content']?.toString())
          : null,
    );
  }
}

class GLMChoice {
  final GLMMessage message;
  final String? finishReason;

  GLMChoice({
    required this.message,
    this.finishReason,
  });

  factory GLMChoice.fromJson(Map<String, dynamic> json) {
    return GLMChoice(
      message: GLMMessage.fromJson(json['message'] as Map<String, dynamic>),
      finishReason: json['finish_reason']?.toString(),
    );
  }
}

/// ============================================
/// 视频生成响应（Tuzi Sora API）
/// ============================================
/// 支持异步任务模式：提交任务 -> 轮询状态 -> 获取结果
class VideoGenerationResponse {
  final String? id;           // 任务唯一标识 ID
  final String? object;       // 对象类型，固定为 "video"
  final String? model;        // 所使用的模型名称
  final String? status;       // 任务状态：queued, in_progress, completed, failed
  final int? progress;        // 生成进度 (0-100)
  final int? createdAt;       // 任务创建时间戳
  final String? seconds;      // 视频生成时长
  final String? videoUrl;     // 视频生成的直链地址（完成后返回）
  final String? error;        // 错误信息（失败时返回）

  VideoGenerationResponse({
    this.id,
    this.object,
    this.model,
    this.status,
    this.progress,
    this.createdAt,
    this.seconds,
    this.videoUrl,
    this.error,
  });

  factory VideoGenerationResponse.fromJson(Map<String, dynamic> json) {
    return VideoGenerationResponse(
      id: json['id']?.toString(),
      object: json['object']?.toString(),
      model: json['model']?.toString(),
      status: json['status']?.toString(),
      progress: json['progress'] != null ? int.tryParse(json['progress'].toString()) : null,
      createdAt: json['created_at'] != null ? int.tryParse(json['created_at'].toString()) : null,
      seconds: json['seconds']?.toString(),
      videoUrl: json['video_url']?.toString() ?? json['url']?.toString(),
      error: json['error']?.toString(),
    );
  }

  /// 任务是否完成
  bool get isCompleted => status == 'completed';

  /// 任务是否失败
  bool get isFailed => status == 'failed';

  /// 任务是否正在进行
  bool get isInProgress => status == 'in_progress';

  /// 任务是否排队中
  bool get isQueued => status == 'queued';

  /// 是否有可用的视频 URL
  bool get hasVideoUrl => videoUrl != null && videoUrl!.isNotEmpty;
}

/// 图像生成 API 响应数据
class ImageData {
  final String? url;
  final String? b64Json;
  final String? revisedPrompt;

  ImageData({
    this.url,
    this.b64Json,
    this.revisedPrompt,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      url: json['url']?.toString(),
      b64Json: json['b64_json']?.toString(),
      revisedPrompt: json['revised_prompt']?.toString(),
    );
  }
}

/// Token 使用情况
class Usage {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  Usage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
      inputTokens: json['input_tokens'] as int? ?? 0,
      outputTokens: json['output_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
    );
  }
}

/// 图像生成 API 响应
class ImageGenerationResponse {
  final int created;
  final List<ImageData> data;
  final Usage? usage;

  ImageGenerationResponse({
    required this.created,
    required this.data,
    this.usage,
  });

  factory ImageGenerationResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return ImageGenerationResponse(
      created: json['created'] as int? ?? 0,
      data: dataList
          .map((item) => ImageData.fromJson(item as Map<String, dynamic>))
          .toList(),
      usage: json['usage'] != null
          ? Usage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 获取第一张图片的 URL
  String? getFirstImageUrl() {
    if (data.isEmpty) return null;
    return data[0].url;
  }
}
