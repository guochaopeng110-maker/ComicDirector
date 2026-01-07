import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import '../models/screenplay.dart';
import '../models/script.dart';
import '../utils/video_cache_manager.dart';
import 'chat_screen.dart' show VideoPlayerManager;

/// 场景媒体查看器 - 支持左右滑动查看不同场景的图片/视频
class SceneMediaViewer extends StatefulWidget {
  final List<Scene> scenes;
  final int initialSceneIndex;
  final MediaType mediaType;

  const SceneMediaViewer({
    super.key,
    required this.scenes,
    required this.initialSceneIndex,
    required this.mediaType,
  });

  @override
  State<SceneMediaViewer> createState() => _SceneMediaViewerState();
}

enum MediaType { image, video }

class _SceneMediaViewerState extends State<SceneMediaViewer> with WidgetsBindingObserver {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _isInitializing = false; // 防止重复初始化
  String? _currentVideoUrl; // 记录当前正在播放的视频 URL
  bool _hasRequestedInit = false; // 防止 addPostFrameCallback 重复触发
  bool _wasPlayingBeforePause = false; // 记录暂停前是否在播放

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialSceneIndex;
    _pageController = PageController(initialPage: widget.initialSceneIndex);
    // 监听应用生命周期
    WidgetsBinding.instance.addObserver(this);
    
    // 🔑 关键：释放其他页面的视频播放器资源，确保录屏等功能有足够的硬件资源
    VideoPlayerManager().releaseAllResources();
    debugPrint('🎬 SceneMediaViewer 打开，已释放其他视频播放器资源');
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用进入后台或不活跃时，暂停视频释放硬件资源
    // 这样录屏等操作可以获取到编解码器资源
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wasPlayingBeforePause = _videoController?.value.isPlaying ?? false;
      _videoController?.pause();
      debugPrint('🎬 应用进入后台，暂停视频播放以释放硬件资源');
    } else if (state == AppLifecycleState.resumed) {
      // 恢复时如果之前在播放，则继续播放
      if (_wasPlayingBeforePause && _videoController != null) {
        _videoController!.play();
        debugPrint('🎬 应用恢复前台，继续视频播放');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    // 同步释放，不等待延迟
    _disposeVideoControllerSync();
    super.dispose();
  }
  
  /// 同步释放（用于 dispose）
  void _disposeVideoControllerSync() {
    try {
      _chewieController?.pause();
      _chewieController?.dispose();
      _chewieController = null;
    } catch (e) {
      debugPrint('🎬 释放 ChewieController 失败: $e');
    }
    try {
      _videoController?.pause();
      _videoController?.dispose();
      _videoController = null;
    } catch (e) {
      debugPrint('🎬 释放 VideoController 失败: $e');
    }
    _isVideoInitialized = false;
    _currentVideoUrl = null;
  }

  /// 异步释放（用于切换视频时等待硬件释放）
  Future<void> _disposeVideoController() async {
    _disposeVideoControllerSync();
    
    // 等待硬件解码器释放 - 增加到 500ms 以确保资源完全释放
    // 这对于录屏等需要编解码器资源的功能很重要
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _initializeVideo(String url) async {
    // 如果正在初始化，跳过
    if (_isInitializing) {
      debugPrint('🎬 跳过初始化：已有视频正在初始化');
      return;
    }
    
    // 如果是同一个视频且已初始化，跳过
    if (_currentVideoUrl == url && _isVideoInitialized) {
      debugPrint('🎬 跳过初始化：同一视频已初始化');
      return;
    }
    
    _isInitializing = true;
    
    try {
      // 先释放之前的播放器，并等待硬件解码器释放
      await _disposeVideoController();
      
      // 再次检查是否还在当前页面（防止快速滑动导致的问题）
      if (!mounted) {
        _isInitializing = false;
        return;
      }
      
      debugPrint('🎬 开始初始化视频: $url');
      
      final cacheManager = VideoCacheManager();
      final isCached = await cacheManager.isCached(url);

      File videoFile;
      if (isCached) {
        videoFile = await cacheManager.getCachedVideo(url);
      } else {
        // 显示下载中状态
        if (mounted) {
          setState(() => _isVideoInitialized = false);
        }
        videoFile = await cacheManager.getCachedVideo(url);
      }

      // 再次检查 mounted 状态
      if (!mounted) {
        _isInitializing = false;
        return;
      }

      _videoController = VideoPlayerController.file(videoFile);
      await _videoController!.initialize();
      
      _currentVideoUrl = url;

      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: true,
          showControls: true,
          aspectRatio: _videoController!.value.aspectRatio,
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF8B5CF6),
            handleColor: const Color(0xFFEC4899),
            backgroundColor: const Color(0xFFE5E7EB),
            bufferedColor: const Color(0xFFD1D5DB),
          ),
        );
        
        setState(() => _isVideoInitialized = true);
        debugPrint('🎬 视频初始化成功: $url');
      }
    } catch (e) {
      debugPrint('视频初始化失败: $e');
      if (mounted) {
        setState(() => _isVideoInitialized = false);
      }
    } finally {
      _isInitializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // PageView for swiping
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _hasRequestedInit = false; // 重置初始化请求标记
              });
              // 如果是视频模式，初始化当前场景的视频
              if (widget.mediaType == MediaType.video) {
                final scene = widget.scenes[index];
                if (scene.videoUrl != null && scene.videoUrl!.isNotEmpty) {
                  // 延迟一点再初始化，确保之前的视频已释放
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted && _currentIndex == index) {
                      _initializeVideo(scene.videoUrl!);
                    }
                  });
                }
              }
            },
            itemCount: widget.scenes.length,
            itemBuilder: (context, index) {
              final scene = widget.scenes[index];
              return _buildSceneMedia(scene);
            },
          ),

          // 底部指示器
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildIndicator(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Text(
        '场景 ${_currentIndex + 1} / ${widget.scenes.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      centerTitle: true,
      actions: [
        if (widget.mediaType == MediaType.video && _chewieController != null)
          IconButton(
            icon: Icon(
              _chewieController!.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                if (_chewieController!.isPlaying) {
                  _chewieController!.pause();
                } else {
                  _chewieController!.play();
                }
              });
            },
          ),
      ],
    );
  }

  Widget _buildSceneMedia(Scene scene) {
    if (widget.mediaType == MediaType.image) {
      return _buildImageMedia(scene);
    } else {
      return _buildVideoMedia(scene);
    }
  }

  Widget _buildImageMedia(Scene scene) {
    // 检查图片状态
    if (scene.status == SceneStatus.imageGenerating) {
      return _buildLoadingWidget('正在生成分镜图...', const Color(0xFF8B5CF6), scene);
    }

    if (scene.imageUrl == null || scene.imageUrl!.isEmpty) {
      return _buildPlaceholderWidget('等待生成图片', scene);
    }

    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: scene.imageUrl!,
          fit: BoxFit.contain,
          memCacheWidth: 1920,
          memCacheHeight: 1080,
          progressIndicatorBuilder: (context, url, progress) {
            return Center(
              child: CircularProgressIndicator(
                value: progress.progress,
                color: const Color(0xFF8B5CF6),
              ),
            );
          },
          errorWidget: (context, url, error) {
            return _buildErrorWidget('图片加载失败');
          },
        ),
      ),
    );
  }

  Widget _buildVideoMedia(Scene scene) {
    // 检查视频状态
    if (scene.status == SceneStatus.videoGenerating || scene.status == SceneStatus.imageGenerating) {
      return _buildLoadingWidget('正在生成分镜视频...', const Color(0xFFEC4899), scene);
    }

    if (scene.videoUrl == null || scene.videoUrl!.isEmpty) {
      if (scene.status == SceneStatus.imageCompleted) {
        return _buildLoadingWidget('等待生成视频...', const Color(0xFFEC4899), scene);
      }
      return _buildPlaceholderWidget('等待生成视频', scene);
    }

    // 检查是否是当前页面的视频
    final isCurrentPage = widget.scenes.indexOf(scene) == _currentIndex;
    
    // 只有当前页面才初始化视频
    if (!_isVideoInitialized || _chewieController == null || _currentVideoUrl != scene.videoUrl) {
      // 只在当前页面且未请求过初始化时触发
      if (isCurrentPage && !_hasRequestedInit && !_isInitializing) {
        _hasRequestedInit = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scene.videoUrl != null && scene.videoUrl!.isNotEmpty) {
            _initializeVideo(scene.videoUrl!).then((_) {
              _hasRequestedInit = false;
            });
          } else {
            _hasRequestedInit = false;
          }
        });
      }
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF8B5CF6)),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }

  Widget _buildLoadingWidget(String message, Color color, Scene scene) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: color, strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '场景 ${scene.sceneId}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderWidget(String message, Scene scene) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported,
            color: Colors.white.withOpacity(0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '场景 ${scene.sceneId}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.scenes.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentIndex == index
                ? const Color(0xFF8B5CF6)
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
