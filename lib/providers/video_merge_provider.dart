import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/video_merger_service.dart';
import '../models/screenplay.dart';

/// 场景视频信息
class SceneVideoInfo {
  final int sceneId;
  final int sceneIndex;
  final String videoPath;
  final String narration;

  SceneVideoInfo({
    required this.sceneId,
    required this.sceneIndex,
    required this.videoPath,
    required this.narration,
  });

  factory SceneVideoInfo.fromJson(Map<String, dynamic> json) {
    return SceneVideoInfo(
      sceneId: json['scene_id'] as int,
      sceneIndex: json['scene_index'] as int,
      videoPath: json['video_path'] as String,
      narration: json['narration'] as String? ?? '',
    );
  }
}

/// 视频合并状态
enum MergeStatus {
  idle,
  preparing,
  downloading,
  merging,
  completed,
  error,
}

/// 视频合并状态管理
class VideoMergeProvider extends ChangeNotifier {
  final VideoMergerService _merger = VideoMergerService();

  // 状态
  MergeStatus _status = MergeStatus.idle;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;
  File? _mergedVideoFile; // 合并后的视频文件
  List<SceneVideoInfo> _scenes = []; // 场景视频列表（用于 Mock 模式）
  Screenplay? _currentScreenplay;

  // 统计
  int _mergedVideosCount = 0;
  int _mergedVideosSize = 0;

  // Getters
  MergeStatus get status => _status;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  File? get mergedVideoFile => _mergedVideoFile;
  List<SceneVideoInfo> get scenes => _scenes;
  int get totalScenes => _scenes.length;
  bool get isMerging => _status != MergeStatus.idle && _status != MergeStatus.completed && _status != MergeStatus.error;
  bool get hasError => _status == MergeStatus.error;
  bool get isCompleted => _status == MergeStatus.completed;
  int get mergedVideosCount => _mergedVideosCount;
  int get mergedVideosSize => _mergedVideosSize;
  bool get hasMergedVideo => _mergedVideoFile != null;

  /// 格式化视频大小显示
  String get mergedVideosSizeFormatted {
    if (_mergedVideosSize < 1024) {
      return '${_mergedVideosSize} B';
    } else if (_mergedVideosSize < 1024 * 1024) {
      return '${(_mergedVideosSize / 1024).toStringAsFixed(1)} KB';
    } else if (_mergedVideosSize < 1024 * 1024 * 1024) {
      return '${(_mergedVideosSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(_mergedVideosSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 初始化
  Future<void> initialize() async {
    await _merger.initialize();
    await _loadStatistics();
    notifyListeners();
  }

  /// 加载统计信息
  Future<void> _loadStatistics() async {
    _mergedVideosCount = await _merger.getMergedVideosCount();
    _mergedVideosSize = await _merger.getMergedVideosSize();
  }

  /// 合并视频
  Future<void> mergeVideos(Screenplay screenplay) async {
    if (isMerging) {
      throw StateError('正在合并中，请稍候');
    }

    _currentScreenplay = screenplay;
    _status = MergeStatus.preparing;
    _progress = 0.0;
    _statusMessage = '准备中...';
    _errorMessage = null;
    _mergedVideoFile = null;
    _scenes.clear();
    notifyListeners();

    try {
      final resultFile = await _merger.mergeSceneVideos(
        screenplay,
        onProgress: (progress, message) {
          _progress = progress;
          _statusMessage = message;

          // 更新状态
          if (progress < 0.1) {
            _status = MergeStatus.preparing;
          } else if (progress < 0.6) {
            _status = MergeStatus.downloading;
          } else if (progress < 0.95) {
            _status = MergeStatus.merging;
          }

          notifyListeners();
        },
      );

      // 判断是否是 Mp4Parser 合并的视频还是 Mock 模式的索引文件
      if (resultFile.path.endsWith('.mp4')) {
        // Mp4Parser 合并模式：返回的是合并后的视频文件
        _mergedVideoFile = resultFile;
        _status = MergeStatus.completed;
        _statusMessage = '视频合并完成！';
      } else if (resultFile.path.endsWith('.json')) {
        // Mock 模式：解析索引文件
        final indexContent = await resultFile.readAsString();
        final indexData = jsonDecode(indexContent) as Map<String, dynamic>;

        _scenes = (indexData['scenes'] as List)
            .map((scene) => SceneVideoInfo.fromJson(scene as Map<String, dynamic>))
            .toList();

        _status = MergeStatus.completed;
        _statusMessage = '下载了 ${_scenes.length} 个场景视频！';
      }

      _progress = 1.0;

      // 更新统计
      await _loadStatistics();

      notifyListeners();
    } catch (e) {
      _status = MergeStatus.error;
      _errorMessage = e.toString();
      _statusMessage = '合并失败';
      notifyListeners();
      debugPrint('❌ 视频合并失败: $e');
    }
  }

  /// 取消合并
  Future<void> cancelMerge() async {
    if (!isMerging) return;

    _status = MergeStatus.idle;
    _progress = 0.0;
    _statusMessage = '已取消';
    _mergedVideoFile = null;
    _scenes.clear();
    notifyListeners();
  }

  /// 重置状态
  void reset() {
    _status = MergeStatus.idle;
    _progress = 0.0;
    _statusMessage = '';
    _errorMessage = null;
    _mergedVideoFile = null;
    _scenes.clear();
    _currentScreenplay = null;
    notifyListeners();
  }

  /// 清理所有合并视频
  Future<void> clearAllMergedVideos() async {
    await _merger.clearMergedVideos();
    await _loadStatistics();
    notifyListeners();
  }
}
