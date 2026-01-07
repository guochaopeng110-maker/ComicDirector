import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../models/screenplay.dart';
import '../models/script.dart';
import '../utils/video_cache_manager.dart';
import '../services/gallery_service.dart';
import '../screens/scene_media_viewer.dart';

/// 剧本展示组件
/// 显示剧本标题、场景列表、图片和视频
class ScreenplayCard extends StatelessWidget {
  final Screenplay screenplay;
  final double? videoProgress; // API 返回的视频生成进度 (0.0 - 1.0)
  final Function(int sceneId)? onRetryScene; // 重试单个场景的回调
  final Function(int sceneId, String customPrompt)? onEditPrompt; // 编辑提示词的回调
  final Function(int sceneId)? onStartGeneration; // 🆕 手动触发单个场景生成的回调
  final VoidCallback? onStartAllGeneration; // 🆕 手动触发所有场景生成的回调
  final VoidCallback? onMergeVideos; // 🆕 合并场景视频的回调

  const ScreenplayCard({
    super.key,
    required this.screenplay,
    this.videoProgress,
    this.onRetryScene,
    this.onEditPrompt,
    this.onStartGeneration,
    this.onStartAllGeneration,
    this.onMergeVideos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        // 深色玻璃态背景
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1B2E), // 深紫色
            Color(0xFF2D2640), // 稍浅的深紫
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.2),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _buildHeader(context),

          // 进度条
          if (!screenplay.isAllCompleted) _buildProgressBar(context),

          // 场景列表（每个场景包含分镜图/视频）
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行：分镜预览 + 开始全部生成按钮
                Row(
                  children: [
                    Text(
                      '分镜预览 (${screenplay.scenes.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    // 🆕 如果有待处理的场景，显示"开始全部生成"按钮
                    if (onStartAllGeneration != null &&
                        screenplay.scenes.any((s) => s.status == SceneStatus.pending))
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onStartAllGeneration,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_outline, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    '开始全部生成',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 🆕 如果所有场景都已完成，显示"合并视频"按钮
                    if (onMergeVideos != null &&
                        screenplay.isAllCompleted &&
                        screenplay.scenes.every((s) => s.videoUrl != null))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEC4899).withOpacity(0.4),
                                offset: const Offset(0, 2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onMergeVideos,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.video_library_outlined, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '合并视频',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...screenplay.scenes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final scene = entry.value;
                  return _SceneCard(
                    screenplay: screenplay,
                    sceneIndex: index,
                    scene: scene,
                    onRetry: scene.status == SceneStatus.failed && onRetryScene != null
                        ? () => onRetryScene!(scene.sceneId)
                        : null,
                    onEditPrompt: scene.status == SceneStatus.failed && onEditPrompt != null
                        ? () => _showEditPromptDialog(context, scene.sceneId, scene.videoPrompt, scene.narration)
                        : null,
                    // 🆕 手动触发单个场景生成
                    onStartGeneration: scene.status == SceneStatus.pending && onStartGeneration != null
                        ? () => onStartGeneration!(scene.sceneId)
                        : null,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          // 电影图标带发光效果
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.movie_creation, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  screenplay.scriptTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${screenplay.taskId}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildStatusChip(),
              const SizedBox(width: 8),
              // 查看完整剧本按钮
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showFullScriptDialog(context, screenplay),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description, size: 14, color: Colors.white.withOpacity(0.8)),
                          const SizedBox(width: 4),
                          Text(
                            '剧本',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    String label;
    Color color;
    List<Color> gradientColors;

    if (screenplay.hasFailed) {
      label = '部分失败';
      color = const Color(0xFFF97316);
      gradientColors = [const Color(0xFFF97316), const Color(0xFFEA580C)];
    } else if (screenplay.isAllCompleted) {
      label = '已完成';
      color = const Color(0xFF10B981);
      gradientColors = [const Color(0xFF10B981), const Color(0xFF059669)];
    } else {
      label = '进行中';
      color = const Color(0xFF8B5CF6);
      gradientColors = [const Color(0xFF8B5CF6), const Color(0xFFEC4899)];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label == '进行中') ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final progress = screenplay.progress;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              screenplay.statusDescription,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
            ),
          ),
          // 进度百分比带渐变效果
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            ).createShader(bounds),
            child: Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示编辑提示词对话框
  void _showEditPromptDialog(BuildContext context, int sceneId, String currentPrompt, String narration) {
    final controller = TextEditingController(text: currentPrompt);
    final sceneNum = screenplay.scenes.indexWhere((s) => s.sceneId == sceneId) + 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '修改场景 $sceneNum 的视频提示词',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '场景旁白：',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    narration,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '视频提示词（英文）：',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '输入新的视频提示词...',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFC107), width: 0.5),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFF8F00)),
                      SizedBox(width: 4),
                      Text(
                        '禁用词汇',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '避免: lightning, electric, energy, fire, explosion, weapon, attack, fight, fierce, intense, violent, angry, blood, glowing eyes',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                  ),
                  Text(
                    '建议: gentle, soft, calm, peaceful, warm, bright, slowly, smoothly',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final customPrompt = controller.text.trim();
              if (customPrompt.isNotEmpty) {
                Navigator.pop(context);
                onEditPrompt?.call(sceneId, customPrompt);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            child: const Text('保存并重试'),
          ),
        ],
      ),
    );
  }
}

/// 单个场景卡片
class _SceneCard extends StatelessWidget {
  final Screenplay screenplay;
  final int sceneIndex;
  final Scene scene;
  final VoidCallback? onRetry;
  final VoidCallback? onEditPrompt;
  final VoidCallback? onStartGeneration; // 🆕 手动触发场景生成

  const _SceneCard({
    required this.screenplay,
    required this.sceneIndex,
    required this.scene,
    this.onRetry,
    this.onEditPrompt,
    this.onStartGeneration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // 半透明玻璃效果
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 场景标题和状态
          Row(
            children: [
              // 场景编号带渐变
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '场景 ${scene.sceneId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  scene.status.displayName,
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // 🆕 pending 状态显示"开始生成"按钮
              if (scene.status == SceneStatus.pending && onStartGeneration != null) ...[
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onStartGeneration,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              '开始生成',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // failed 状态显示"修改提示词"和"重试"按钮
              if (scene.status == SceneStatus.failed) ...[
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEditPrompt,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 12, color: Color(0xFFA78BFA)),
                            SizedBox(width: 4),
                            Text(
                              '修改提示词',
                              style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              '重试',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // 旁白 - 深色主题样式
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, size: 16, color: const Color(0xFFEC4899).withOpacity(0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scene.narration,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 媒体展示区域（视频或图片）
          _buildMediaSection(context),
          const SizedBox(height: 10),

          // 提示词展示（可折叠）
          _PromptSection(scene: scene, isDarkTheme: true),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (scene.status) {
      case SceneStatus.pending:
        return Colors.white.withOpacity(0.5);
      case SceneStatus.imageGenerating:
        return const Color(0xFF60A5FA);
      case SceneStatus.imageCompleted:
        return const Color(0xFF22D3EE);
      case SceneStatus.videoGenerating:
        return const Color(0xFFA78BFA);
      case SceneStatus.completed:
        return const Color(0xFF34D399);
      case SceneStatus.failed:
        return const Color(0xFFF87171);
    }
  }

  /// 构建媒体展示区域（图片和视频）
  Widget _buildMediaSection(BuildContext context) {
    List<Widget> children = [];

    // 添加分镜图
    if (scene.imageUrl != null && scene.imageUrl!.isNotEmpty) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片标签 - 深色主题样式
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image, color: Color(0xFFA78BFA), size: 12),
                  const SizedBox(width: 4),
                  const Text(
                    '分镜图',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 图片
            GestureDetector(
              onTap: () => _openImageViewer(context),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: scene.imageUrl!,
                      fit: BoxFit.cover,
                      height: 180,
                      width: double.infinity,
                      memCacheWidth: 800, // 限制内存缓存大小
                      memCacheHeight: 600,
                      progressIndicatorBuilder: (context, url, progress) {
                        return Container(
                          height: 180,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.progress,
                            ),
                          ),
                        );
                      },
                      errorWidget: (context, url, error) {
                        return Container(
                          height: 180,
                          width: double.infinity,
                          color: Colors.red.shade50,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.red),
                                SizedBox(height: 8),
                                Text('图片加载失败'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // 点击提示遮罩
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('点击放大', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 添加分镜视频
    if (scene.videoUrl != null && scene.videoUrl!.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: 10)); // 图片和视频之间的间距
      }
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频标签
            Row(
              children: [
                const Icon(Icons.videocam, color: Color(0xFF8B5CF6), size: 14),
                const SizedBox(width: 4),
                const Text(
                  '分镜视频',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // 视频播放器
            GestureDetector(
              onTap: () => _openVideoViewer(context),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _VideoPlayerWidget(url: scene.videoUrl!),
                  ),
                  // 点击提示遮罩
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('点击全屏', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 视频生成中状态
    if (scene.status == SceneStatus.videoGenerating) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 10));
      }
      children.add(
        Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Color(0xFFEC4899), strokeWidth: 2),
                ),
                SizedBox(height: 6),
                Text('正在生成分镜视频...', style: TextStyle(color: Color(0xFFEC4899), fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    // 图片生成中状态
    if (scene.status == SceneStatus.imageGenerating) {
      children.add(
        Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2),
                ),
                SizedBox(height: 6),
                Text('正在生成分镜图...', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    // 如果都没有内容，显示等待状态
    if (children.isEmpty) {
      children.add(
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 24),
                SizedBox(height: 4),
                Text('等待生成', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: children);
  }

  /// 打开图片查看器
  void _openImageViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SceneMediaViewer(
          scenes: screenplay.scenes,
          initialSceneIndex: sceneIndex,
          mediaType: MediaType.image,
        ),
      ),
    );
  }

  /// 打开视频查看器
  void _openVideoViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SceneMediaViewer(
          scenes: screenplay.scenes,
          initialSceneIndex: sceneIndex,
          mediaType: MediaType.video,
        ),
      ),
    );
  }
}

/// 图片预览对话框（已废弃，保留用于其他地方的引用）
class _ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;

  const _ImagePreviewDialog({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.all(16),
      child: Stack(
        children: [
          // 大图展示
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                memCacheWidth: 1920, // 大图预览使用更高缓存
                memCacheHeight: 1080,
                progressIndicatorBuilder: (context, url, progress) {
                  return Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorWidget: (context, url, error) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: Colors.white, size: 48),
                        SizedBox(height: 16),
                        Text('图片加载失败', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // 关闭按钮
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          // 底部操作栏
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ImageButton(
                  icon: Icons.download,
                  label: '下载',
                  onTap: () => _downloadImage(context),
                ),
                SizedBox(width: 16),
                _ImageButton(
                  icon: Icons.link,
                  label: '复制链接',
                  onTap: () => _copyLink(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _downloadImage(BuildContext context) async {
    try {
      // 显示加载提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('正在保存到相册...'),
              ],
            ),
            duration: Duration(seconds: 30),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 下载并保存到相册
      await GalleryService().downloadAndSaveImage(imageUrl);

      // 显示成功提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已保存到相册'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      // 显示错误提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _copyLink(BuildContext context) async {
    try {
      // 确保 imageUrl 不为空
      if (imageUrl.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图片链接为空'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await Clipboard.setData(ClipboardData(text: imageUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('链接已复制'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('复制失败: $e'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 图片操作按钮
class _ImageButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// 提示词展示区域
class _PromptSection extends StatefulWidget {
  final Scene scene;
  final bool isDarkTheme;

  const _PromptSection({required this.scene, this.isDarkTheme = false});

  @override
  State<_PromptSection> createState() => _PromptSectionState();
}

class _PromptSectionState extends State<_PromptSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkTheme;
    
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        expansionTileTheme: ExpansionTileThemeData(
          iconColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
          collapsedIconColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
        ),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(
              Icons.code,
              size: 14,
              color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 6),
            Text(
              '查看提示词',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        initiallyExpanded: false,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(10),
              border: isDark ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 人物描述（用于一致性）
                if (widget.scene.characterDescription.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: isDark ? const Color(0xFFEC4899) : const Color(0xFF8B5CF6)),
                      const SizedBox(width: 4),
                      Text(
                        '人物特征描述:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFEC4899) : const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.scene.characterDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  '图片提示词:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.scene.imagePrompt,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '视频提示词:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.scene.videoPrompt,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 简化的视频播放器组件
class _VideoPlayerWidget extends StatefulWidget {
  final String url;

  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isInitializing = false;
  bool _isDownloading = false;
  bool _shouldInit = false; // 控制是否应该初始化
  String? _errorMessage;
  bool _copied = false;

  @override
  bool get wantKeepAlive => false; // 不保持状态，让不可见的视频释放资源

  @override
  void initState() {
    super.initState();
    // 延迟更长时间初始化，使用递增延迟避免同时加载
    final delay = 500 + (widget.url.length % 1000); // 根据 URL 长度产生不同的延迟
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) {
        setState(() {
          _shouldInit = true;
        });
        _initializePlayer();
      }
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// 复制视频链接到剪贴板
  Future<void> _copyVideoUrl() async {
    try {
      // 确保 url 不为空
      if (widget.url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('视频链接为空'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await Clipboard.setData(ClipboardData(text: widget.url));
      setState(() {
        _copied = true;
      });
      // 2秒后重置复制状态
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _copied = false;
          });
        }
      });
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('复制失败: $e'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 保存视频到相册
  Future<void> _saveVideoToGallery() async {
    try {
      // 检查是否是本地文件
      String videoPath = widget.url;
      if (!videoPath.startsWith('/')) {
        // 如果是网络URL，需要先下载
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('正在下载并保存...'),
                ],
              ),
              duration: Duration(seconds: 60),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        await GalleryService().downloadAndSaveVideo(widget.url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 已保存到相册 (Movies/Movies)'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        // 本地文件，直接保存
        await GalleryService().saveVideoToGallery(videoPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 已保存到相册'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _initializePlayer() async {
    if (_isInitializing || _isInitialized) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      // 使用视频缓存管理器获取本地缓存文件
      final cacheManager = VideoCacheManager();

      // 先检查是否已缓存
      final isCached = await cacheManager.isCached(widget.url);

      File videoFile;
      if (isCached) {
        // 使用缓存文件
        videoFile = await cacheManager.getCachedVideo(widget.url);
      } else {
        // 显示下载进度
        if (mounted) {
          setState(() {
            _isDownloading = true;
          });
        }
        // 下载并缓存视频
        videoFile = await cacheManager.getCachedVideo(widget.url);
      }

      _videoController = VideoPlayerController.file(
        videoFile,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await _videoController!.initialize();

      if (!mounted) {
        _videoController?.dispose();
        _videoController = null;
        return;
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: _isDownloading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        '正在缓存视频...',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    '播放失败',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isInitializing = false;
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，因为使用了 AutomaticKeepAliveClientMixin
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          children: [
            // 视频播放器
            Container(
              color: Colors.black,
              child: _buildPlayerContent(),
            ),
            // 右上角操作按钮
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 复制链接按钮
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _copyVideoUrl,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _copied ? Icons.check : Icons.copy,
                              color: _copied ? Colors.green : Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _copied ? '已复制' : '复制链接',
                              style: TextStyle(
                                color: _copied ? Colors.green : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 保存到相册按钮
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _saveVideoToGallery,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.save_alt, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '保存到相册',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '视频加载失败\n$_errorMessage',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 8),
            Text(
              '加载视频中...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Chewie(controller: _chewieController!);
  }
}

/// 完整剧本对话框
void _showFullScriptDialog(BuildContext context, Screenplay screenplay) {
  showDialog(
    context: context,
    builder: (context) => _FullScriptDialog(screenplay: screenplay),
  );
}

class _FullScriptDialog extends StatelessWidget {
  final Screenplay screenplay;

  const _FullScriptDialog({required this.screenplay});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6), width: 0.5),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      screenplay.scriptTitle,
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8B5CF6)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 剧本信息
                    _buildInfoRow('场景数量', '${screenplay.scenes.length} 个'),
                    _buildInfoRow('状态', screenplay.statusDescription),
                    const SizedBox(height: 16),

                    // 场景列表
                    const Text(
                      '场景详情',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...screenplay.scenes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final scene = entry.value;
                      return _SceneDetailCard(
                        sceneNumber: index + 1,
                        scene: scene,
                      );
                    }),
                  ],
                ),
              ),
            ),

            // 底部复制按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                border: Border(
                  top: BorderSide(color: Color(0xFFF3F4F6), width: 0.5),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _copyFullScript(context),
                      icon: const Icon(Icons.copy),
                      label: const Text('复制完整剧本'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          Text(value, style: const TextStyle(color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }

  void _copyFullScript(BuildContext context) async {
    final buffer = StringBuffer();

    buffer.writeln('🎬 ${screenplay.scriptTitle}');
    buffer.writeln('场景数量: ${screenplay.scenes.length}');
    buffer.writeln('状态: ${screenplay.statusDescription}');
    buffer.writeln();
    buffer.writeln('─' * 40);
    buffer.writeln();

    for (var i = 0; i < screenplay.scenes.length; i++) {
      final scene = screenplay.scenes[i];
      buffer.writeln('【场景 ${i + 1}】');
      buffer.writeln('状态: ${scene.status.displayName}');
      buffer.writeln('旁白: ${scene.narration}');
      if (scene.characterDescription.isNotEmpty) {
        buffer.writeln('人物: ${scene.characterDescription}');
      }
      buffer.writeln('图片提示: ${scene.imagePrompt}');
      buffer.writeln('视频提示: ${scene.videoPrompt}');
      buffer.writeln();
      buffer.writeln('─' * 20);
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('剧本已复制到剪贴板'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

/// 场景详情卡片
class _SceneDetailCard extends StatelessWidget {
  final int sceneNumber;
  final Scene scene;

  const _SceneDetailCard({
    required this.sceneNumber,
    required this.scene,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 场景标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '场景 $sceneNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  scene.status.displayName,
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 旁白
          _buildSection('旁白', scene.narration),
          if (scene.characterDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildSection('人物', scene.characterDescription),
          ],
          const SizedBox(height: 6),
          _buildSection('图片提示', scene.imagePrompt, isSmall: true),
          const SizedBox(height: 6),
          _buildSection('视频提示', scene.videoPrompt, isSmall: true),
        ],
      ),
    );
  }

  Widget _buildSection(String label, String content, {bool isSmall = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8E8E93),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          content,
          style: TextStyle(
            fontSize: isSmall ? 11 : 12,
            color: const Color(0xFF1C1C1E),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (scene.status) {
      case SceneStatus.pending:
        return const Color(0xFF8E8E93);
      case SceneStatus.imageGenerating:
        return const Color(0xFF8B5CF6);
      case SceneStatus.imageCompleted:
        return const Color(0xFF32ADE6);
      case SceneStatus.videoGenerating:
        return const Color(0xFFEC4899);
      case SceneStatus.completed:
        return const Color(0xFF34C759);
      case SceneStatus.failed:
        return const Color(0xFFFF3B30);
    }
  }
}
