import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../models/screenplay.dart';

/// 视频合并进度回调
typedef VideoMergeProgressCallback = void Function(double progress, String status);

/// 视频合并服务
/// 使用 Mp4Parser 进行无损视频合并
class VideoMergerService {
  static final VideoMergerService _instance = VideoMergerService._internal();
  factory VideoMergerService() => _instance;
  VideoMergerService._internal();

  Directory? _outputDir;
  final Dio _dio = Dio();

  /// 是否使用 Mock 模式（模拟合并流程，实际只下载第一个视频）
  static const bool useMockMode = false;

  /// MethodChannel 用于调用 Android 原生方法
  static const _channel = MethodChannel('com.directorai.director_ai/video_merge');

  /// 初始化输出目录
  Future<void> initialize() async {
    if (_outputDir != null) return;

    final appDir = await getApplicationDocumentsDirectory();
    _outputDir = Directory('${appDir.path}/merged_videos');
    if (!await _outputDir!.exists()) {
      await _outputDir!.create(recursive: true);
      debugPrint('📁 创建合并视频目录: ${_outputDir!.path}');
    }
  }

  /// 合并场景视频为完整视频
  /// 返回合并后的视频文件路径
  Future<File> mergeSceneVideos(
    Screenplay screenplay, {
    VideoMergeProgressCallback? onProgress,
  }) async {
    await initialize();

    // 过滤出有视频的场景
    final scenesWithVideo = screenplay.scenes.where((s) => s.videoUrl != null).toList();
    if (scenesWithVideo.isEmpty) {
      throw Exception('没有可用的场景视频');
    }

    debugPrint('🎬 开始合并 ${scenesWithVideo.length} 个视频');

    // 使用 Mp4Parser 进行无损合并
    if (useMockMode) {
      return _mergeWithMock(screenplay, scenesWithVideo, onProgress);
    } else {
      return _mergeWithMp4Parser(screenplay, scenesWithVideo, onProgress);
    }
  }

  /// 使用 Mp4Parser 进行无损合并
  Future<File> _mergeWithMp4Parser(
    Screenplay screenplay,
    List<dynamic> scenesWithVideo,
    VideoMergeProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.0, '准备下载视频...');

    // 步骤 A: 下载所有视频到临时目录
    final tempDir = await getTemporaryDirectory();
    final downloadDir = Directory('${tempDir.path}/video_merge_${DateTime.now().millisecondsSinceEpoch}');
    await downloadDir.create(recursive: true);

    final downloadedFiles = <File>[];

    for (int i = 0; i < scenesWithVideo.length; i++) {
      final scene = scenesWithVideo[i];
      final videoUrl = scene.videoUrl!;
      final fileName = 'scene_${scene.sceneId}_$i.mp4';
      final outputFile = File('${downloadDir.path}/$fileName');

      final downloadProgress = 0.1 + (0.5 * i / scenesWithVideo.length);
      onProgress?.call(downloadProgress, '下载场景 ${i + 1}/${scenesWithVideo.length}...');

      debugPrint('📥 下载场景 ${i + 1} 视频: $videoUrl');

      await _dio.download(
        videoUrl,
        outputFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = downloadProgress + (0.5 / scenesWithVideo.length) * (received / total);
            onProgress?.call(progress, '下载场景 ${i + 1} ${(received / total * 100).toStringAsFixed(0)}%...');
          }
        },
      );

      downloadedFiles.add(outputFile);
    }

    onProgress?.call(0.6, '准备合并视频...');

    // 步骤 B: 调用 Android 原生方法进行合并
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${_outputDir!.path}/merged_${screenplay.taskId}_$timestamp.mp4';

    final inputPaths = downloadedFiles.map((f) => f.path).toList();

    debugPrint('🔧 调用原生方法合并视频');
    debugPrint('📂 输入文件: $inputPaths');
    debugPrint('📂 输出文件: $outputPath');

    onProgress?.call(0.7, '合并视频中...');

    try {
      final result = await _channel.invokeMethod('mergeVideosLossless', {
        'inputPaths': inputPaths,
        'outputPath': outputPath,
      });

      onProgress?.call(0.95, '清理临时文件...');

      // 步骤 C: 清理临时文件
      await downloadDir.delete(recursive: true);

      onProgress?.call(1.0, '合并完成！');

      final mergedFile = File(outputPath);
      debugPrint('✅ 视频合并完成: ${mergedFile.path}');
      debugPrint('📊 文件大小: ${await mergedFile.length()} bytes');

      return mergedFile;

    } catch (e) {
      debugPrint('❌ 原生方法调用失败: $e');
      // 清理临时文件
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  /// Mock 模式合并（仅用于测试）
  Future<File> _mergeWithMock(
    Screenplay screenplay,
    List<dynamic> scenesWithVideo,
    VideoMergeProgressCallback? onProgress,
  ) async {
    debugPrint('🎬 [Mock模式] 开始模拟合并 ${scenesWithVideo.length} 个视频');

    // 阶段1: 准备
    onProgress?.call(0.05, '准备视频文件...');
    await Future.delayed(const Duration(milliseconds: 500));

    // 阶段2: 下载/检查每个视频
    for (int i = 0; i < scenesWithVideo.length; i++) {
      final progress = 0.1 + (0.3 * i / scenesWithVideo.length);
      onProgress?.call(progress, '检查视频 ${i + 1}/${scenesWithVideo.length}...');
      debugPrint('📥 检查视频 ${i + 1}: ${scenesWithVideo[i].videoUrl}');
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 阶段3: 标准化
    onProgress?.call(0.4, '标准化视频格式...');
    await Future.delayed(const Duration(milliseconds: 800));

    for (int i = 0; i < scenesWithVideo.length; i++) {
      final progress = 0.4 + (0.2 * i / scenesWithVideo.length);
      onProgress?.call(progress, '处理视频 ${i + 1}/${scenesWithVideo.length}...');
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // 阶段4: 合并
    onProgress?.call(0.6, '合并视频中...');
    await Future.delayed(const Duration(milliseconds: 500));

    onProgress?.call(0.7, '写入视频流...');
    await Future.delayed(const Duration(milliseconds: 600));

    onProgress?.call(0.8, '编码输出...');

    // 下载所有场景视频到本地
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mergedDir = Directory('${_outputDir!.path}/merged_${screenplay.taskId}_$timestamp');
    if (!await mergedDir.exists()) {
      await mergedDir.create(recursive: true);
    }

    final List<File> downloadedFiles = [];

    for (int i = 0; i < scenesWithVideo.length; i++) {
      final scene = scenesWithVideo[i];
      final videoUrl = scene.videoUrl!;
      final fileName = 'scene_${scene.sceneId}_${i + 1}.mp4';
      final outputFile = File('${mergedDir.path}/$fileName');

      debugPrint('📥 [Mock模式] 下载场景 ${i + 1} 视频: $videoUrl');

      final downloadStartProgress = 0.8 + (0.15 * i / scenesWithVideo.length);
      final downloadEndProgress = 0.8 + (0.15 * (i + 1) / scenesWithVideo.length);

      await _dio.download(
        videoUrl,
        outputFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final downloadProgress = received / total;
            final overallProgress = downloadStartProgress + (downloadEndProgress - downloadStartProgress) * downloadProgress;
            onProgress?.call(overallProgress, '下载场景 ${i + 1} 视频 ${(downloadProgress * 100).toStringAsFixed(0)}%...');
          }
        },
      );

      downloadedFiles.add(outputFile);
    }

    // 创建一个索引文件，记录所有场景视频的顺序
    final indexFile = File('${mergedDir.path}/index.json');
    final indexData = {
      'task_id': screenplay.taskId,
      'script_title': screenplay.scriptTitle,
      'total_scenes': scenesWithVideo.length,
      'scenes': downloadedFiles.asMap().entries.map((entry) {
        final idx = entry.key;
        final file = entry.value;
        final scene = scenesWithVideo[idx];
        return {
          'scene_id': scene.sceneId,
          'scene_index': idx + 1,
          'video_path': file.path,
          'narration': scene.narration,
        };
      }).toList(),
    };
    await indexFile.writeAsString(JsonEncoder.withIndent('  ').convert(indexData));

    debugPrint('✅ [Mock模式] 下载了 ${downloadedFiles.length} 个场景视频');

    // 阶段5: 清理
    onProgress?.call(0.95, '清理临时文件...');
    await Future.delayed(const Duration(milliseconds: 300));

    onProgress?.call(1.0, '合并完成！');
    debugPrint('✅ [Mock模式] 视频合并完成: ${mergedDir.path}');

    // 返回索引文件
    return indexFile;
  }

  /// 获取合并视频列表
  Future<List<File>> getMergedVideos() async {
    await initialize();

    if (!await _outputDir!.exists()) {
      return [];
    }

    final files = await _outputDir!.list().where((entity) => entity.path.endsWith('.mp4')).toList();
    return files.cast<File>();
  }

  /// 清理所有合并视频
  Future<void> clearMergedVideos() async {
    await initialize();

    if (!await _outputDir!.exists()) {
      return;
    }

    await _outputDir!.delete(recursive: true);
    await _outputDir!.create(recursive: true);

    debugPrint('🧹 已清理所有合并视频');
  }

  /// 获取合并视频目录大小
  Future<int> getMergedVideosSize() async {
    await initialize();

    if (!await _outputDir!.exists()) {
      return 0;
    }

    int totalSize = 0;
    await for (final entity in _outputDir!.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  /// 获取合并视频数量
  Future<int> getMergedVideosCount() async {
    final videos = await getMergedVideos();
    return videos.length;
  }
}
