import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

/// 相册服务
/// 用于保存图片和视频到相册
class GalleryService {
  static final GalleryService _instance = GalleryService._internal();
  factory GalleryService() => _instance;
  GalleryService._internal();

  static const _channel = MethodChannel('com.directorai.director_ai/video_merge');
  final Dio _dio = Dio();

  /// 保存视频到相册
  ///
  /// [filePath] 本地视频文件路径
  /// 返回保存成功后的内容URI
  Future<String> saveVideoToGallery(String filePath) async {
    try {
      debugPrint('💾 保存视频到相册: $filePath');

      // 验证文件存在
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('视频文件不存在: $filePath');
      }

      // 调用原生方法保存
      final result = await _channel.invokeMethod('saveVideoToGallery', {
        'filePath': filePath,
      });

      debugPrint('✅ 视频已保存到相册: $result');
      return result as String;
    } catch (e) {
      debugPrint('❌ 保存视频失败: $e');
      rethrow;
    }
  }

  /// 保存图片到相册
  ///
  /// [filePath] 本地图片文件路径
  /// 返回保存成功后的内容URI
  Future<String> saveImageToGallery(String filePath) async {
    try {
      debugPrint('💾 保存图片到相册: $filePath');

      // 验证文件存在
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('图片文件不存在: $filePath');
      }

      // 调用原生方法保存
      final result = await _channel.invokeMethod('saveImageToGallery', {
        'filePath': filePath,
      });

      debugPrint('✅ 图片已保存到相册: $result');
      return result as String;
    } catch (e) {
      debugPrint('❌ 保存图片失败: $e');
      rethrow;
    }
  }

  /// 从网络下载图片并保存到相册
  ///
  /// [imageUrl] 图片URL
  /// [onProgress] 下载进度回调
  Future<String> downloadAndSaveImage(
    String imageUrl, {
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, '准备下载...');

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File('${tempDir.path}/$fileName');

      // 下载图片
      onProgress?.call(0.2, '下载中...');
      await _dio.download(
        imageUrl,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = 0.2 + 0.6 * (received / total);
            onProgress?.call(progress, '下载中 ${(received / total * 100).toInt()}%');
          }
        },
      );

      onProgress?.call(0.8, '保存到相册...');

      // 保存到相册
      final result = await saveImageToGallery(tempFile.path);

      // 删除临时文件
      await tempFile.delete();

      onProgress?.call(1.0, '完成');
      return result;
    } catch (e) {
      debugPrint('❌ 下载并保存图片失败: $e');
      rethrow;
    }
  }

  /// 从网络下载视频并保存到相册
  ///
  /// [videoUrl] 视频URL
  /// [onProgress] 下载进度回调
  Future<String> downloadAndSaveVideo(
    String videoUrl, {
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, '准备下载...');

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final tempFile = File('${tempDir.path}/$fileName');

      // 下载视频
      onProgress?.call(0.2, '下载中...');
      await _dio.download(
        videoUrl,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = 0.2 + 0.6 * (received / total);
            onProgress?.call(progress, '下载中 ${(received / total * 100).toInt()}%');
          }
        },
      );

      onProgress?.call(0.8, '保存到相册...');

      // 保存到相册
      final result = await saveVideoToGallery(tempFile.path);

      // 删除临时文件
      await tempFile.delete();

      onProgress?.call(1.0, '完成');
      return result;
    } catch (e) {
      debugPrint('❌ 下载并保存视频失败: $e');
      rethrow;
    }
  }
}
