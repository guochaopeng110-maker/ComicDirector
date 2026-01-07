/// 时长识别工具类
/// 从用户输入中提取时长信息，并计算相应的场景数量
class DurationParser {
  /// 解析用户输入，返回时长（秒）
  /// 支持格式：
  /// - "30秒" / "30s" / "30 seconds"
  /// - "1分钟" / "1min" / "1 minute"
  /// - "1分30秒" / "90秒"
  static int parseDuration(String input) {
    final text = input.toLowerCase();

    int totalSeconds = 0;

    // 匹配分钟：1分钟, 1min, 1m, 1 minute
    final minuteRegex = RegExp(r'(\d+)\s*(分钟|min|分|m|minute|minutes)');
    final minuteMatches = minuteRegex.allMatches(text);
    for (final match in minuteMatches) {
      final minutes = int.parse(match.group(1)!);
      totalSeconds += minutes * 60;
    }

    // 匹配秒：30秒, 30s, 30 second
    final secondRegex = RegExp(r'(\d+)\s*(秒|s|second|seconds)');
    final secondMatches = secondRegex.allMatches(text);
    for (final match in secondMatches) {
      final seconds = int.parse(match.group(1)!);
      totalSeconds += seconds;
    }

    // 如果没有找到明确的时长，返回0
    return totalSeconds;
  }

  /// 根据时长计算建议的场景数量
  /// 每个场景约10-12秒
  static int calculateSceneCount(int durationSeconds) {
    if (durationSeconds <= 0) {
      // 默认6-8个场景（约60-90秒）
      return 6;
    }

    // 每个场景约10-12秒，计算需要的场景数
    final sceneCount = (durationSeconds / 11).round();

    // 确保场景数在合理范围内
    return _clampSceneCount(sceneCount);
  }

  /// 限制场景数量在合理范围内
  static int _clampSceneCount(int count) {
    if (count < 2) return 2;  // 最少2个场景
    if (count > 15) return 15; // 最多15个场景
    return count;
  }

  /// 获取场景数量的范围（最小值和最大值）
  /// 给AI一些灵活空间
  static SceneCountRange getSceneCountRange(int durationSeconds) {
    if (durationSeconds <= 0) {
      // 默认：6-8个场景
      return SceneCountRange(min: 6, max: 8);
    }

    final baseCount = calculateSceneCount(durationSeconds);

    // 给AI±1的灵活空间
    final minCount = _clampSceneCount(baseCount - 1);
    final maxCount = _clampSceneCount(baseCount + 1);

    return SceneCountRange(min: minCount, max: maxCount);
  }

  /// 生成时长描述文本
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}秒';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (remainingSeconds == 0) {
      return '${minutes}分钟';
    }

    return '${minutes}分${remainingSeconds}秒';
  }
}

/// 场景数量范围
class SceneCountRange {
  final int min;
  final int max;

  SceneCountRange({required this.min, required this.max});

  @override
  String toString() => '$min-$max';
}
