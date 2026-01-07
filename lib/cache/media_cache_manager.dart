import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// 缓存文件信息
class CacheFileInfo {
  final String url;
  final String path;
  final int size;
  final int accessedAt;
  final String? conversationId;

  CacheFileInfo({
    required this.url,
    required this.path,
    required this.size,
    required this.accessedAt,
    this.conversationId,
  });

  factory CacheFileInfo.fromJson(Map<String, dynamic> json) {
    return CacheFileInfo(
      url: json['url'] as String,
      path: json['path'] as String,
      size: json['size'] as int,
      accessedAt: json['accessedAt'] as int,
      conversationId: json['conversationId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'path': path,
      'size': size,
      'accessedAt': accessedAt,
      if (conversationId != null) 'conversationId': conversationId,
    };
  }
}

/// 缓存元数据
class CacheMetadata {
  final int version;
  final int lastCleanup;
  final Map<String, CacheFileInfo> files;

  CacheMetadata({
    this.version = 1,
    int? lastCleanup,
    Map<String, dynamic>? files,
  })  : lastCleanup = lastCleanup ?? DateTime.now().millisecondsSinceEpoch,
        files = (files ?? {})
            .map((key, value) => MapEntry(key, CacheFileInfo.fromJson(value)));

  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    return CacheMetadata(
      version: json['version'] as int? ?? 1,
      lastCleanup: json['lastCleanup'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      files: (json['files'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, CacheFileInfo.fromJson(value))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastCleanup': lastCleanup,
      'files': files.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

/// 缓存清理结果
class CacheCleanupResult {
  final int removedCount;
  final int freedSpace;

  CacheCleanupResult({required this.removedCount, required this.freedSpace});

  String get freedSpaceFormatted {
    if (freedSpace < 1024) return '$freedSpace B';
    if (freedSpace < 1024 * 1024) return '${(freedSpace / 1024).toStringAsFixed(1)} KB';
    return '${(freedSpace / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 媒体缓存管理器
class MediaCacheManager {
  static final MediaCacheManager _instance = MediaCacheManager._internal();
  factory MediaCacheManager() => _instance;
  MediaCacheManager._internal();

  static const _cacheExpirationDays = 2;

  Directory? _cacheDir;
  File? _metadataFile;
  CacheMetadata? _metadata;
  bool _isInitialized = false;

  final Dio _dio = Dio();

  /// 初始化缓存管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/media_cache');
      _metadataFile = File('${_cacheDir!.path}/metadata.json');

      // 创建缓存目录
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
        debugPrint('📁 创建缓存目录: ${_cacheDir!.path}');
      }

      // 创建子目录
      await Directory('${_cacheDir!.path}/images').create(recursive: true);
      await Directory('${_cacheDir!.path}/videos').create(recursive: true);

      // 加载元数据
      await _loadMetadata();

      _isInitialized = true;
      debugPrint('✅ 媒体缓存管理器初始化完成');
    } catch (e) {
      debugPrint('❌ 媒体缓存管理器初始化失败: $e');
      rethrow;
    }
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// 加载元数据
  Future<void> _loadMetadata() async {
    if (_metadataFile == null) return;

    if (await _metadataFile!.exists()) {
      try {
        final json = await _metadataFile!.readAsString();
        final data = jsonDecode(json);
        _metadata = CacheMetadata.fromJson(data as Map<String, dynamic>);
        debugPrint('📋 加载缓存元数据: ${_metadata!.files.length} 个文件');
      } catch (e) {
        debugPrint('⚠️ 加载元数据失败，创建新的: $e');
        _metadata = CacheMetadata();
      }
    } else {
      _metadata = CacheMetadata();
    }
  }

  /// 保存元数据
  Future<void> _saveMetadata() async {
    if (_metadataFile == null || _metadata == null) return;

    try {
      final json = jsonEncode(_metadata!.toJson());
      await _metadataFile!.writeAsString(json);
    } catch (e) {
      debugPrint('❌ 保存元数据失败: $e');
    }
  }

  /// 生成文件缓存键（MD5哈希）
  String _generateFileKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 获取文件扩展名
  String _getFileExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.contains('.')) {
      final segments = uri.path.split('.');
      final ext = segments.last.toLowerCase();
      return '.$ext';
    }
    // 根据内容类型推断
    if (url.contains('image')) return '.jpg';
    if (url.contains('video')) return '.mp4';
    return '.bin';
  }

  /// 获取文件类型目录
  String _getFileTypeDir(String url) {
    if (url.contains('image') || url.contains('img')) return 'images';
    if (url.contains('video') || url.contains('mp4')) return 'videos';
    return 'others';
  }

  /// 缓存媒体文件
  Future<File> cacheMedia(String url, {String? conversationId}) async {
    await _ensureInitialized();

    final fileKey = _generateFileKey(url);
    final fileType = _getFileTypeDir(url);
    final ext = _getFileExtension(url);
    final fileName = '$fileKey$ext';
    final file = File('${_cacheDir!.path}/$fileType/$fileName');

    // 如果已存在，更新访问时间并返回
    if (await file.exists()) {
      debugPrint('✅ 缓存命中: $url');
      await _updateAccessTime(fileKey);
      return file;
    }

    // 下载文件
    debugPrint('📥 开始缓存: $url');
    try {
      await _dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1 && total > 0) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint('📥 缓存进度: $progress%');
          }
        },
      );

      // 获取文件大小
      final fileSize = await file.length();

      // 更新元数据
      _metadata!.files[fileKey] = CacheFileInfo(
        url: url,
        path: file.path,
        size: fileSize,
        accessedAt: DateTime.now().millisecondsSinceEpoch,
        conversationId: conversationId,
      );
      await _saveMetadata();

      debugPrint('✅ 缓存完成: ${file.path}');
      return file;
    } catch (e) {
      // 如果下载失败，删除不完整的文件
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('❌ 缓存失败: $e');
      rethrow;
    }
  }

  /// 获取缓存文件（如果存在且未过期）
  Future<File?> getCachedMedia(String url) async {
    await _ensureInitialized();

    final fileKey = _generateFileKey(url);
    final fileInfo = _metadata!.files[fileKey];

    if (fileInfo == null) {
      debugPrint('❌ 缓存未找到: $url');
      return null;
    }

    final file = File(fileInfo.path);
    if (!await file.exists()) {
      debugPrint('❌ 缓存文件不存在: ${fileInfo.path}');
      await _removeFile(fileKey);
      return null;
    }

    // 检查是否过期
    final lastAccessed = DateTime.fromMillisecondsSinceEpoch(fileInfo.accessedAt);
    final daysSinceAccess = DateTime.now().difference(lastAccessed).inDays;

    if (daysSinceAccess >= _cacheExpirationDays) {
      debugPrint('⏰ 缓存已过期 (${daysSinceAccess}天前): $url');
      await _removeFile(fileKey);
      return null;
    }

    // 更新访问时间
    await _updateAccessTime(fileKey);
    debugPrint('✅ 缓存有效: $url');
    return file;
  }

  /// 更新文件访问时间
  Future<void> _updateAccessTime(String fileKey) async {
    final fileInfo = _metadata!.files[fileKey];
    if (fileInfo != null) {
      _metadata!.files[fileKey] = CacheFileInfo(
        url: fileInfo.url,
        path: fileInfo.path,
        size: fileInfo.size,
        accessedAt: DateTime.now().millisecondsSinceEpoch,
        conversationId: fileInfo.conversationId,
      );
      await _saveMetadata();
    }
  }

  /// 移除文件
  Future<void> _removeFile(String fileKey) async {
    final fileInfo = _metadata!.files[fileKey];
    if (fileInfo != null) {
      final file = File(fileInfo.path);
      if (await file.exists()) {
        await file.delete();
      }
      _metadata!.files.remove(fileKey);
      await _saveMetadata();
    }
  }

  /// 清理过期缓存
  Future<CacheCleanupResult> cleanExpiredCache() async {
    await _ensureInitialized();

    int removedCount = 0;
    int freedSpace = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiredKeys = <String>[];

    _metadata!.files.forEach((key, info) {
      final daysSinceAccess = now - info.accessedAt;
      final days = Duration(milliseconds: daysSinceAccess).inDays;

      if (days >= _cacheExpirationDays) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      final info = _metadata!.files[key]!;
      final file = File(info.path);

      if (await file.exists()) {
        freedSpace += info.size;
        await file.delete();
      }

      _metadata!.files.remove(key);
      removedCount++;
    }

    await _saveMetadata();
    // 更新 lastCleanup 时间戳（now 已经是 millisecondsSinceEpoch）
    _metadata = CacheMetadata(
      version: _metadata!.version,
      lastCleanup: now,
      files: _metadata!.files,
    );

    debugPrint('🧹 清理完成: 删除 $removedCount 个文件, 释放 ${CacheCleanupResult(removedCount: removedCount, freedSpace: freedSpace).freedSpaceFormatted}');

    return CacheCleanupResult(removedCount: removedCount, freedSpace: freedSpace);
  }

  /// 清理指定会话的缓存
  Future<void> clearConversationCache(String conversationId) async {
    await _ensureInitialized();

    final keysToRemove = _metadata!.files.entries
        .where((e) => e.value.conversationId == conversationId)
        .map((e) => e.key)
        .toList();

    for (final key in keysToRemove) {
      await _removeFile(key);
    }

    await _saveMetadata();
    debugPrint('🧹 清理会话缓存: $conversationId, 删除 ${keysToRemove.length} 个文件');
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    await _ensureInitialized();

    int totalSize = 0;
    for (final info in _metadata!.files.values) {
      totalSize += info.size;
    }
    return totalSize;
  }

  /// 获取缓存文件数量
  int getCacheFileCount() {
    return _metadata?.files.length ?? 0;
  }

  /// 清空所有缓存
  Future<void> clearAllCache() async {
    await _ensureInitialized();

    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
      await Directory('${_cacheDir!.path}/images').create(recursive: true);
      await Directory('${_cacheDir!.path}/videos').create(recursive: true);
    }

    _metadata = CacheMetadata();
    await _saveMetadata();

    debugPrint('🧹 已清空所有缓存');
  }

  /// 获取缓存大小格式化字符串
  Future<String> getCacheSizeFormatted() async {
    final bytes = await getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
