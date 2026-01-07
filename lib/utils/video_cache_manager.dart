import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// 视频缓存管理器（低内存版本）
/// 将网络视频下载到本地缓存，避免重复下载
/// 使用 LRU 策略限制缓存数量
class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  factory VideoCacheManager() => _instance;
  VideoCacheManager._internal();

  final Dio _dio = Dio();
  Directory? _cacheDir;

  // 内存缓存 - 使用 LinkedHashMap 实现 LRU
  final Map<String, File> _memoryCache = {};

  // 最大缓存数量 - 限制为 3 个视频以减少内存占用
  static const int maxCacheSize = 3;

  // URL 访问顺序列表（用于 LRU）
  final List<String> _accessOrder = [];

  /// 初始化缓存目录
  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;

    final appDocDir = await getTemporaryDirectory();
    _cacheDir = Directory('${appDocDir.path}/video_cache');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    return _cacheDir!;
  }

  /// 将 URL 转换为安全的文件名
  String _urlToFileName(String url) {
    final bytes = utf8.encode(url);
    final hash = sha256.convert(bytes);
    return 'video_$hash';
  }

  /// 获取缓存的视频文件
  /// 如果缓存不存在，则下载并缓存
  Future<File> getCachedVideo(String url) async {
    // 更新访问顺序
    _updateAccessOrder(url);

    // 检查内存缓存
    if (_memoryCache.containsKey(url)) {
      debugPrint('🎬 视频内存缓存命中: $url');
      return _memoryCache[url]!;
    }

    final cacheDir = await _getCacheDir();
    final fileName = _urlToFileName(url);
    final file = File('${cacheDir.path}/$fileName');

    if (await file.exists()) {
      debugPrint('🎬 视磁盘频缓存命中: $url');
      _memoryCache[url] = file;
      // 检查缓存大小，如果超过限制则清理最旧的
      await _evictIfNecessary();
      return file;
    }

    // 下载视频前检查是否需要清理缓存
    await _evictIfNecessary();

    // 下载视频
    debugPrint('🎬 开始下载视频: $url');
    await _downloadVideo(url, file);
    _memoryCache[url] = file;
    return file;
  }

  /// 更新访问顺序（LRU）
  void _updateAccessOrder(String url) {
    _accessOrder.remove(url);
    _accessOrder.add(url);
  }

  /// 如果缓存超过限制，删除最旧的
  Future<void> _evictIfNecessary() async {
    while (_memoryCache.length >= maxCacheSize) {
      if (_accessOrder.isEmpty) break;

      // 获取最旧的 URL
      final oldestUrl = _accessOrder.removeAt(0);

      // 从内存缓存中移除
      final file = _memoryCache.remove(oldestUrl);
      if (file != null && await file.exists()) {
        await file.delete();
        debugPrint('🎬 清理旧缓存: $oldestUrl');
      }
    }
  }

  /// 下载视频到本地
  Future<void> _downloadVideo(String url, File file) async {
    try {
      await _dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint('🎬 视频下载进度: $progress%');
          }
        },
      );
      debugPrint('🎬 视频下载完成: ${file.path}');
    } catch (e) {
      // 如果下载失败，删除不完整的文件
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  /// 检查视频是否已缓存
  Future<bool> isCached(String url) async {
    // 检查内存缓存
    if (_memoryCache.containsKey(url)) {
      return true;
    }

    final cacheDir = await _getCacheDir();
    final fileName = _urlToFileName(url);
    final file = File('${cacheDir.path}/$fileName');
    return await file.exists();
  }

  /// 清除指定视频的缓存
  Future<void> clearCache(String url) async {
    _memoryCache.remove(url);
    _accessOrder.remove(url);

    final cacheDir = await _getCacheDir();
    final fileName = _urlToFileName(url);
    final file = File('${cacheDir.path}/$fileName');

    if (await file.exists()) {
      await file.delete();
      debugPrint('🎬 已清除缓存: $url');
    }
  }

  /// 清除所有视频缓存
  Future<void> clearAllCache() async {
    _memoryCache.clear();
    _accessOrder.clear();

    final cacheDir = await _getCacheDir();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create(recursive: true);
    }
    debugPrint('🎬 已清除所有视频缓存');
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    final cacheDir = await _getCacheDir();
    if (!await cacheDir.exists()) return 0;

    int size = 0;
    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  /// 获取缓存大小的可读格式
  Future<String> getCacheSizeFormatted() async {
    final bytes = await getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
