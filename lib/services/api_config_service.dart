import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// API 配置服务
/// 使用 SharedPreferences 持久化存储 API Key
class ApiConfigService {
  static const String _keyZhipuApiKey = 'zhipu_api_key';
  static const String _keyVideoApiKey = 'video_api_key';
  static const String _keyImageApiKey = 'image_api_key';
  static const String _keyDoubaoApiKey = 'doubao_api_key';

  // 空字符串表示未配置
  static const String _unconfigured = '';

  static SharedPreferences? _prefs;
  static bool _initialized = false;

  /// 初始化服务
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;

      // 不再设置默认值，让用户自行配置
      AppLogger.success('ApiConfigService', 'API 配置服务初始化完成');
    } catch (e) {
      AppLogger.error('ApiConfigService', '初始化失败', e);
      rethrow;
    }
  }

  /// 获取智谱 GLM API Key
  static String getZhipuApiKey() {
    _ensureInitialized();
    return _prefs!.getString(_keyZhipuApiKey) ?? _unconfigured;
  }

  /// 设置智谱 GLM API Key
  static Future<void> setZhipuApiKey(String key) async {
    _ensureInitialized();
    await _prefs!.setString(_keyZhipuApiKey, key);
    AppLogger.info('ApiConfigService', '已更新智谱 API Key: ${key.substring(0, 8)}...');
  }

  /// 获取视频生成 API Key
  static String getVideoApiKey() {
    _ensureInitialized();
    return _prefs!.getString(_keyVideoApiKey) ?? _unconfigured;
  }

  /// 设置视频生成 API Key
  static Future<void> setVideoApiKey(String key) async {
    _ensureInitialized();
    await _prefs!.setString(_keyVideoApiKey, key);
    AppLogger.info('ApiConfigService', '已更新视频 API Key: ${key.substring(0, 8)}...');
  }

  /// 获取图像生成 API Key
  static String getImageApiKey() {
    _ensureInitialized();
    return _prefs!.getString(_keyImageApiKey) ?? _unconfigured;
  }

  /// 设置图像生成 API Key
  static Future<void> setImageApiKey(String key) async {
    _ensureInitialized();
    await _prefs!.setString(_keyImageApiKey, key);
    AppLogger.info('ApiConfigService', '已更新图像 API Key: ${key.substring(0, 8)}...');
  }

  /// 获取豆包 API Key
  static String getDoubaoApiKey() {
    _ensureInitialized();
    return _prefs!.getString(_keyDoubaoApiKey) ?? _unconfigured;
  }

  /// 设置豆包 API Key
  static Future<void> setDoubaoApiKey(String key) async {
    _ensureInitialized();
    await _prefs!.setString(_keyDoubaoApiKey, key);
    AppLogger.info('ApiConfigService', '已更新豆包 API Key: ${key.substring(0, 8)}...');
  }

  /// 检查智谱 API Key 是否已配置
  static bool isZhipuApiKeyConfigured() {
    final key = getZhipuApiKey();
    return key.isNotEmpty && key != _unconfigured;
  }

  /// 检查视频 API Key 是否已配置
  static bool isVideoApiKeyConfigured() {
    final key = getVideoApiKey();
    return key.isNotEmpty && key != _unconfigured;
  }

  /// 检查图像 API Key 是否已配置
  static bool isImageApiKeyConfigured() {
    final key = getImageApiKey();
    return key.isNotEmpty && key != _unconfigured;
  }

  /// 检查豆包 API Key 是否已配置
  static bool isDoubaoApiKeyConfigured() {
    final key = getDoubaoApiKey();
    return key.isNotEmpty && key != _unconfigured;
  }

  /// 检查所有必需的 API Key 是否已配置
  static ApiConfigStatus checkRequiredKeys() {
    final hasZhipu = isZhipuApiKeyConfigured();
    final hasVideo = isVideoApiKeyConfigured();
    final hasImage = isImageApiKeyConfigured();
    final hasDoubao = isDoubaoApiKeyConfigured();

    if (hasZhipu && hasVideo && hasImage && hasDoubao) {
      return ApiConfigStatus.allConfigured;
    }

    final missing = <String>[];
    if (!hasZhipu) missing.add('智谱 GLM (对话)');
    if (!hasVideo) missing.add('视频生成 (Tuzi Sora)');
    if (!hasImage) missing.add('图像生成 (Gemini)');
    if (!hasDoubao) missing.add('豆包 ARK (图片识别)');

    return ApiConfigStatus(
      isAllConfigured: false,
      missingKeys: missing,
    );
  }

  /// 检查聊天所需的 API Key（智谱 + 豆包可选）
  static ApiConfigStatus checkChatKeys() {
    final hasZhipu = isZhipuApiKeyConfigured();
    final hasDoubao = isDoubaoApiKeyConfigured();

    if (hasZhipu) {
      return ApiConfigStatus.allConfigured;
    }

    final missing = <String>[];
    if (!hasZhipu) missing.add('智谱 GLM (对话)');

    return ApiConfigStatus(
      isAllConfigured: false,
      missingKeys: missing,
    );
  }

  /// 检查视频生成所需的 API Key
  static ApiConfigStatus checkVideoGenerationKeys() {
    final hasZhipu = isZhipuApiKeyConfigured();
    final hasImage = isImageApiKeyConfigured();
    final hasVideo = isVideoApiKeyConfigured();

    if (hasZhipu && hasImage && hasVideo) {
      return ApiConfigStatus.allConfigured;
    }

    final missing = <String>[];
    if (!hasZhipu) missing.add('智谱 GLM (对话)');
    if (!hasImage) missing.add('图像生成 (Gemini)');
    if (!hasVideo) missing.add('视频生成 (Tuzi Sora)');

    return ApiConfigStatus(
      isAllConfigured: false,
      missingKeys: missing,
    );
  }

  /// 获取所有配置（用于显示）
  static Map<String, String> getAllConfigs() {
    _ensureInitialized();
    return {
      'zhipu': getZhipuApiKey(),
      'video': getVideoApiKey(),
      'image': getImageApiKey(),
      'doubao': getDoubaoApiKey(),
    };
  }

  /// 批量设置所有配置
  static Future<void> setAllConfigs({
    required String zhipuKey,
    required String videoKey,
    required String imageKey,
    required String doubaoKey,
  }) async {
    _ensureInitialized();
    await _prefs!.setString(_keyZhipuApiKey, zhipuKey);
    await _prefs!.setString(_keyVideoApiKey, videoKey);
    await _prefs!.setString(_keyImageApiKey, imageKey);
    await _prefs!.setString(_keyDoubaoApiKey, doubaoKey);
    AppLogger.success('ApiConfigService', '已更新所有 API Key');
  }

  /// 清空所有配置
  static Future<void> clearAll() async {
    _ensureInitialized();
    await _prefs!.remove(_keyZhipuApiKey);
    await _prefs!.remove(_keyVideoApiKey);
    await _prefs!.remove(_keyImageApiKey);
    await _prefs!.remove(_keyDoubaoApiKey);
    AppLogger.warn('ApiConfigService', '已清空所有 API Key');
  }

  /// 检查是否已初始化
  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('ApiConfigService 未初始化，请先调用 initialize()');
    }
  }

  /// 格式化 API Key 用于显示（隐藏中间部分）
  static String maskApiKey(String key) {
    if (key.isEmpty) return '未设置';
    if (key.length <= 10) return '${key.substring(0, 4)}***';
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
  }
}

/// API 配置状态
class ApiConfigStatus {
  final bool isAllConfigured;
  final List<String> missingKeys;

  const ApiConfigStatus({
    required this.isAllConfigured,
    this.missingKeys = const [],
  });

  /// 已全部配置的便捷构造
  static const allConfigured = ApiConfigStatus(isAllConfigured: true);

  /// 是否已配置
  bool get isConfigured => isAllConfigured;

  /// 获取未配置数量
  int get missingCount => missingKeys.length;

  /// 获取首个缺失的 Key
  String? get firstMissing => missingKeys.isNotEmpty ? missingKeys.first : null;

  /// 获取友好的提示消息
  String get friendlyMessage {
    if (isAllConfigured) return '所有 API Key 已配置';
    return '缺少以下 API Key：${missingKeys.join('、')}';
  }
}
