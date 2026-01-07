import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/screenplay_draft.dart';
import '../utils/app_logger.dart';
import '../models/screenplay.dart';
import '../models/script.dart';
import '../models/character_sheet.dart';
import '../services/api_service.dart';
import '../providers/chat_provider.dart' show UserImage;

/// 剧本草稿生成进度数据
class DraftProgress {
  final double progress;
  final String status;
  final DateTime timestamp;

  DraftProgress({
    required this.progress,
    required this.status,
    required this.timestamp,
  });
}

/// 剧本草稿控制器
/// 负责生成和管理剧本草稿，支持用户确认和重新生成
class ScreenplayDraftController extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // 当前剧本草稿
  ScreenplayDraft? _currentDraft;

  // 生成状态
  bool _isGenerating = false;
  bool _isCancelling = false;

  // 进度流
  final StreamController<DraftProgress> _progressController =
      StreamController<DraftProgress>.broadcast();
  final StreamController<ScreenplayDraft> _draftController =
      StreamController<ScreenplayDraft>.broadcast();

  // 用户图片（用于人物一致性）
  List<UserImage>? _userImages;

  ScreenplayDraft? get currentDraft => _currentDraft;
  bool get isGenerating => _isGenerating;
  bool get isCancelling => _isCancelling;
  Stream<DraftProgress> get progressStream => _progressController.stream;
  Stream<ScreenplayDraft> get draftStream => _draftController.stream;

  /// 生成剧本草稿
  Future<ScreenplayDraft> generateDraft(
    String userPrompt, {
    List<UserImage>? userImages,
  }) async {
    if (_isGenerating) {
      throw StateError('剧本正在生成中');
    }

    _isGenerating = true;
    _isCancelling = false;
    _userImages = userImages;
    notifyListeners();

    try {
      // 步骤1: 分析用户图片（如果有）
      _emitProgress(0.0, '准备生成剧本...');
      String? characterAnalysis;

      if (userImages != null && userImages.isNotEmpty) {
        _emitProgress(0.1, '分析参考图片...');
        characterAnalysis = await _analyzeUserImage(userImages.first);

        if (_isCancelling) {
          throw Exception('用户取消操作');
        }
      }

      // 步骤2: 生成剧本
      _emitProgress(0.2, '正在创作剧本...');
      final screenplayJson = await _apiService.generateDramaScreenplay(
        userPrompt,
        characterAnalysis: characterAnalysis,
      );

      if (_isCancelling) {
        throw Exception('用户取消操作');
      }

      // 步骤3: 解析剧本
      _emitProgress(0.8, '解析剧本结构...');
      final draft = _parseDraft(screenplayJson);

      _currentDraft = draft;
      _draftController.add(draft);
      _emitProgress(1.0, '剧本生成完成！');

      return draft;
    } catch (e) {
      _emitProgress(0.0, '生成失败: $e');
      rethrow;
    } finally {
      _isGenerating = false;
      _isCancelling = false;
      notifyListeners();
    }
  }

  /// 重新生成剧本
  Future<ScreenplayDraft> regenerateDraft(
    String taskId, {
    String? feedback,
  }) async {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    final previousDraft = _currentDraft!;

    _isGenerating = true;
    _isCancelling = false;
    notifyListeners();

    try {
      _emitProgress(0.0, '准备重新生成...');

      // 重新生成剧本
      _emitProgress(0.3, '正在调整剧本...');
      final screenplayJson = await _apiService.generateDramaScreenplay(
        previousDraft.title, // 使用原标题作为提示
        characterAnalysis: null,
        previousFeedback: feedback,
      );

      if (_isCancelling) {
        throw Exception('用户取消操作');
      }

      // 解析新剧本
      _emitProgress(0.8, '解析新剧本...');
      final newDraft = _parseDraft(screenplayJson);

      // 保存历史
      final draftWithHistory = newDraft.withHistory(previousDraft);

      _currentDraft = draftWithHistory;
      _draftController.add(draftWithHistory);
      _emitProgress(1.0, '重新生成完成！');

      return draftWithHistory;
    } catch (e) {
      _emitProgress(0.0, '重新生成失败: $e');
      rethrow;
    } finally {
      _isGenerating = false;
      _isCancelling = false;
      notifyListeners();
    }
  }

  /// 更新场景旁白
  void updateSceneNarration(int sceneId, String newNarration) {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    _currentDraft = _currentDraft!.updateSceneNarration(sceneId, newNarration);
    _draftController.add(_currentDraft!);
    notifyListeners();
  }

  /// 更新场景情绪钩子
  void updateSceneEmotionalHook(int sceneId, String newHook) {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    final newScenes = _currentDraft!.scenes.map((scene) {
      return scene.sceneId == sceneId
          ? scene.copyWith(emotionalHook: newHook)
          : scene;
    }).toList();

    _currentDraft = _currentDraft!.copyWith(scenes: newScenes);
    _draftController.add(_currentDraft!);
    notifyListeners();
  }

  /// 更新场景人物描述
  void updateSceneCharacterDescription(int sceneId, String newDesc) {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    final newScenes = _currentDraft!.scenes.map((scene) {
      return scene.sceneId == sceneId
          ? scene.copyWith(characterDescription: newDesc)
          : scene;
    }).toList();

    _currentDraft = _currentDraft!.copyWith(scenes: newScenes);
    _draftController.add(_currentDraft!);
    notifyListeners();
  }

  /// 更新场景图片提示词
  void updateSceneImagePrompt(int sceneId, String newPrompt) {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    final newScenes = _currentDraft!.scenes.map((scene) {
      return scene.sceneId == sceneId
          ? scene.copyWith(imagePrompt: newPrompt)
          : scene;
    }).toList();

    _currentDraft = _currentDraft!.copyWith(scenes: newScenes);
    _draftController.add(_currentDraft!);
    notifyListeners();
  }

  /// 更新场景视频提示词
  void updateSceneVideoPrompt(int sceneId, String newPrompt) {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    final newScenes = _currentDraft!.scenes.map((scene) {
      return scene.sceneId == sceneId
          ? scene.copyWith(videoPrompt: newPrompt)
          : scene;
    }).toList();

    _currentDraft = _currentDraft!.copyWith(scenes: newScenes);
    _draftController.add(_currentDraft!);
    notifyListeners();
  }

  /// 设置当前剧本草稿（用于从历史记录恢复）
  void setCurrentDraft(ScreenplayDraft draft) {
    _currentDraft = draft;
    _draftController.add(_currentDraft!);
    notifyListeners();
  }

  /// 更新剧本草稿（从完整预览页面修改后调用）
  void updateDraft(ScreenplayDraft updatedDraft) {
    _currentDraft = updatedDraft;
    _draftController.add(_currentDraft!);
    notifyListeners();
  }

  /// 确认剧本，转换为正式剧本用于图片/视频生成
  Future<Screenplay> confirmDraft(String taskId) async {
    if (_currentDraft == null || _currentDraft!.taskId != taskId) {
      throw StateError('剧本不存在或ID不匹配');
    }

    final draft = _currentDraft!;

    // 将 DraftScene 转换为 Scene
    final scenes = draft.scenes.map((draftScene) {
      return Scene(
        sceneId: draftScene.sceneId,
        narration: draftScene.narration,
        imagePrompt: draftScene.imagePrompt,
        videoPrompt: draftScene.videoPrompt,
        characterDescription: draftScene.characterDescription,
        imageUrl: null,
        videoUrl: null,
        status: SceneStatus.pending,
      );
    }).toList();

    // 创建正式剧本
    final screenplay = Screenplay(
      taskId: draft.taskId,
      scriptTitle: draft.title,
      scenes: scenes,
      status: ScreenplayStatus.confirmed,
    );

    return screenplay;
  }

  /// 生成角色设定表（三视图）
  /// 在剧本确认后调用，生成主要角色的三视图以确保人物一致性
  Future<List<CharacterSheet>> generateCharacterSheets({
    List<String>? userImages,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (_currentDraft == null) {
      throw StateError('没有当前剧本');
    }

    final draft = _currentDraft!;

    // 从场景中提取主要角色
    final characters = _extractMainCharacters(draft);

    if (characters.isEmpty) {
      debugPrint('没有检测到角色，跳过角色设定生成');
      return [];
    }

    AppLogger.info('ScreenplayDraftController', '检测到 ${characters.length} 个角色，开始生成三视图...');

    onProgress?.call(0.0, '准备生成角色设定...');

    final sheets = await _apiService.generateMultipleCharacterSheets(
      characters,
      referenceImages: userImages,
      onProgress: onProgress,
    );

    // 更新草稿的角色设定表
    _currentDraft = draft.withCharacterSheets(sheets);
    notifyListeners();

    AppLogger.success('ScreenplayDraftController', '角色设定生成完成: ${sheets.length} 个角色');
    return sheets;
  }

  /// 从剧本场景中提取主要角色
  /// 分析场景中的 characterDescription，提取前两个主要角色
  List<Map<String, String>> _extractMainCharacters(ScreenplayDraft draft) {
    // 获取第一个非空的 characterDescription
    String? characterDesc;
    for (final scene in draft.scenes) {
      final desc = scene.characterDescription.trim();
      if (desc.isNotEmpty) {
        characterDesc = desc;
        break;
      }
    }

    if (characterDesc == null || characterDesc.isEmpty) {
      debugPrint('没有找到角色描述');
      return [];
    }

    debugPrint('原始角色描述: $characterDesc');

    // 尝试从描述中分割出多个角色
    // 常见分隔符：句号后跟大写字母、分号、" and "、换行
    final List<String> characterDescriptions = [];

    // 方法1: 尝试按句号分割（每个角色描述通常以句号结尾）
    // 匹配模式：句号后跟空格和大写字母（新角色开始）
    final sentencePattern = RegExp(r'\.(?=\s+[A-Z])');
    final sentences = characterDesc.split(sentencePattern);

    if (sentences.length >= 2) {
      // 成功分割出多个角色
      for (var s in sentences) {
        final trimmed = s.trim();
        if (trimmed.isNotEmpty && trimmed.length > 10) {
          characterDescriptions.add(trimmed.endsWith('.') ? trimmed : '$trimmed.');
        }
      }
    } else {
      // 方法2: 尝试按分号分割
      final semiParts = characterDesc.split(';');
      if (semiParts.length >= 2) {
        for (var s in semiParts) {
          final trimmed = s.trim();
          if (trimmed.isNotEmpty && trimmed.length > 10) {
            characterDescriptions.add(trimmed);
          }
        }
      } else {
        // 方法3: 尝试按 " and " 或中文逗号分割（如果描述很长）
        if (characterDesc.contains(' and ') && characterDesc.length > 100) {
          final andParts = characterDesc.split(' and ');
          for (var s in andParts) {
            final trimmed = s.trim();
            if (trimmed.isNotEmpty && trimmed.length > 10) {
              characterDescriptions.add(trimmed);
            }
          }
        }
      }
    }

    // 如果还是没有分割成功，把整个描述作为一个角色
    if (characterDescriptions.isEmpty) {
      characterDescriptions.add(characterDesc);
    }

    debugPrint('分割后的角色数量: ${characterDescriptions.length}');

    // 构建角色列表
    final List<Map<String, String>> characters = [];
    for (int i = 0; i < characterDescriptions.length && i < 2; i++) {
      final desc = characterDescriptions[i];

      // 尝试从描述中提取角色名
      String name;
      if (desc.contains(':') || desc.contains('：')) {
        final separator = desc.contains(':') ? ':' : '：';
        final parts = desc.split(separator);
        if (parts.length >= 2 && parts[0].trim().length <= 15) {
          name = parts[0].trim();
        } else {
          name = '角色${i + 1}';
        }
      } else {
        name = '角色${i + 1}';
      }

      characters.add({
        'name': name,
        'description': desc,
        'role': i == 0 ? '主角' : '第二主角',
      });
    }

    debugPrint('提取的角色: ${characters.map((c) => c['name']).join(', ')}');
    return characters;
  }

  /// 分析用户图片
  Future<String> _analyzeUserImage(UserImage userImage) async {
    try {
      final analysis = await _apiService.analyzeImageForCharacter(
        userImage.base64,
      );
      return analysis;
    } catch (e) {
      // 图片分析失败不影响整体流程，只记录警告
      debugPrint('图片分析失败: $e');
      return '';
    }
  }

  /// 解析剧本JSON为Draft对象
  ScreenplayDraft _parseDraft(String jsonStr) {
    final Map<String, dynamic> json = _decodeJson(jsonStr);

    // 解析场景列表
    final scenesList = json['scenes'] as List<dynamic>?;
    final scenes = scenesList?.map((sceneJson) {
      return DraftScene(
        sceneId: sceneJson['scene_id'] as int,
        narration: sceneJson['narration'] as String,
        mood: sceneJson['mood'] as String? ?? '中性',
        emotionalHook: sceneJson['emotional_hook'] as String?,
        tags: [], // 可以后续从解析
        imagePrompt: sceneJson['image_prompt'] as String,
        videoPrompt: sceneJson['video_prompt'] as String,
        characterDescription: sceneJson['character_description'] as String? ?? '',
      );
    }).toList();

    // 解析情绪弧线
    final emotionalArc = json['emotional_arc'] as List<dynamic>?;
    final arcList = emotionalArc
        ?.map((e) => e.toString())
        .toList() ??
        [];

    return ScreenplayDraft(
      id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      taskId: json['task_id'] as String,
      title: json['title'] as String,
      genre: json['genre'] as String? ?? '剧情',
      estimatedDurationSeconds:
          json['estimated_duration_seconds'] as int? ?? 60,
      emotionalArc: arcList,
      scenes: scenes ?? [],
      createdAt: DateTime.now(),
    );
  }

  /// 解析JSON字符串
  Map<String, dynamic> _decodeJson(String str) {
    // 移除可能的markdown代码块标记
    String cleaned = str.trim();
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.length > 1) {
        lines.removeAt(0); // 移除第一行 ```
        if (lines.last.startsWith('```')) {
          lines.removeLast(); // 移除最后一行 ```
        }
        cleaned = lines.join('\n').trim();
      }
    }

    // 尝试查找JSON对象
    final startIndex = cleaned.indexOf('{');
    if (startIndex == -1) {
      throw FormatException('未找到有效的JSON');
    }

    // 找到匹配的结束括号
    int braceCount = 0;
    int endIndex = startIndex;
    for (int i = startIndex; i < cleaned.length; i++) {
      if (cleaned[i] == '{') braceCount++;
      if (cleaned[i] == '}') braceCount--;
      if (braceCount == 0) {
        endIndex = i + 1;
        break;
      }
    }

    if (braceCount != 0) {
      throw FormatException('JSON格式不完整');
    }

    final jsonStr = cleaned.substring(startIndex, endIndex);
    return _jsonDecode(jsonStr);
  }

  /// JSON解码（支持测试模式）
  Map<String, dynamic> _jsonDecode(String str) {
    // 使用dart:convert的jsonDecode
    final dynamic decoded = JsonDecoder().convert(str);
    return decoded as Map<String, dynamic>;
  }

  /// 发送进度更新
  void _emitProgress(double progress, String status) {
    _progressController.add(DraftProgress(
      progress: progress,
      status: status,
      timestamp: DateTime.now(),
    ));
  }

  /// 取消生成
  void cancel() {
    if (_isGenerating) {
      _isCancelling = true;
      _emitProgress(0.0, '正在取消...');
    }
  }

  /// 清理资源
  @override
  void dispose() {
    _progressController.close();
    _draftController.close();
    super.dispose();
  }
}
