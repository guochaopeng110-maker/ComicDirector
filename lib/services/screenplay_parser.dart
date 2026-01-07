import 'dart:convert';
import '../models/screenplay.dart';
import '../utils/app_logger.dart';
import 'api_service.dart';

/// 剧本解析器
/// 负责解析 GLM 返回的 JSON 剧本数据
class ScreenplayParser {
  /// 从 GLM 响应中解析剧本
  static Screenplay parse(String glmResponse) {
    AppLogger.info('剧本解析', '开始解析剧本，原始长度: ${glmResponse.length}');

    try {
      // 清理响应内容
      String cleaned = _cleanResponse(glmResponse);

      // 提取 JSON
      final jsonString = _extractJson(cleaned);
      if (jsonString == null) {
        throw Exception('无法从响应中提取有效的 JSON');
      }

      AppLogger.info('剧本解析', '提取的 JSON: ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}...');

      // 解析 JSON
      final Map<String, dynamic> json = jsonDecode(jsonString);
      final screenplay = Screenplay.fromJson(json);

      // 校验剧本
      _validateScreenplay(screenplay);

      AppLogger.success('剧本解析', '剧本解析成功: ${screenplay.scriptTitle}, ${screenplay.scenes.length} 个场景');
      return screenplay;
    } catch (e) {
      AppLogger.error('剧本解析', '解析失败', e, StackTrace.current);
      throw Exception('剧本解析失败: $e');
    }
  }

  /// 清理响应内容，移除 markdown 代码块等
  static String _cleanResponse(String response) {
    String cleaned = response.trim();

    // 移除 markdown 代码块标记
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      final lastBackticks = cleaned.lastIndexOf('```');
      if (firstNewline > 0 && lastBackticks > firstNewline) {
        cleaned = cleaned.substring(firstNewline + 1, lastBackticks).trim();
      }
    }

    // 修复中文冒号问题 - GLM 有时会返回中文冒号导致 JSON 解析失败
    // 但要小心不要替换字符串值中的中文冒号，只替换 JSON 键值对中的冒号
    // 策略：将 "key": 模式中的中文冒号替换为英文冒号
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'"\s*[a-zA-Z_][a-zA-Z0-9_]*"\s*：'),
      (match) => match.group(0)!.replaceAll('：', ':'),
    );
    // 直接替换所有中文冒号为英文冒号（备选方案，更激进但更可靠）
    cleaned = cleaned.replaceAll('：', ':');

    return cleaned;
  }

  /// 从文本中提取 JSON 对象
  static String? _extractJson(String text) {
    // 策略1: 查找包含 "task_id" 的 JSON（最可靠）
    final taskIdIndex = text.indexOf('"task_id"');
    if (taskIdIndex >= 0) {
      final json = _extractJsonContaining(text, '"task_id"');
      if (json != null) return json;
    }

    // 策略2: 查找包含 "scenes" 的 JSON
    final scenesIndex = text.indexOf('"scenes"');
    if (scenesIndex >= 0) {
      final json = _extractJsonContaining(text, '"scenes"');
      if (json != null) return json;
    }

    // 策略3: 查找包含 "script_title" 的 JSON
    final titleIndex = text.indexOf('"script_title"');
    if (titleIndex >= 0) {
      final json = _extractJsonContaining(text, '"script_title"');
      if (json != null) return json;
    }

    // 策略4: 提取最后一个完整的 JSON 对象
    return _extractLastCompleteJson(text);
  }

  /// 提取包含特定关键字的 JSON 对象
  static String? _extractJsonContaining(String text, String keyword) {
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

  /// 提取最后一个完整的 JSON 对象
  static String? _extractLastCompleteJson(String text) {
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

  /// 校验剧本数据
  static void _validateScreenplay(Screenplay screenplay) {
    // 检查必要字段
    if (screenplay.taskId.isEmpty) {
      throw Exception('剧本缺少 task_id');
    }
    if (screenplay.scriptTitle.isEmpty) {
      throw Exception('剧本缺少 script_title');
    }
    if (screenplay.scenes.isEmpty) {
      throw Exception('剧本没有场景');
    }

    // 检查场景数量
    if (screenplay.scenes.length < 2 || screenplay.scenes.length > 4) {
      AppLogger.warn('剧本解析', '场景数量异常: ${screenplay.scenes.length} (期望 2-4)');
    }

    // 检查每个场景的必要字段
    for (final scene in screenplay.scenes) {
      if (scene.narration.isEmpty) {
        throw Exception('场景 ${scene.sceneId} 缺少 narration');
      }
      if (scene.imagePrompt.isEmpty) {
        throw Exception('场景 ${scene.sceneId} 缺少 image_prompt');
      }
      if (scene.videoPrompt.isEmpty) {
        throw Exception('场景 ${scene.sceneId} 缺少 video_prompt');
      }
    }

    AppLogger.success('剧本解析', '剧本校验通过');
  }
}
