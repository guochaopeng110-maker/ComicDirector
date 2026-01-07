import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/character_sheet.dart';

/// 角色设定卡片组件
/// 显示角色的组合三视图（一张图包含正面、侧面、背面三个视角）
class CharacterSheetCard extends StatelessWidget {
  final CharacterSheet sheet;
  final VoidCallback? onRegenerate;
  final bool isGenerating;

  const CharacterSheetCard({
    super.key,
    required this.sheet,
    this.onRegenerate,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.pink.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _buildHeader(context),
          const SizedBox(height: 8),

          // 角色描述
          if (sheet.description.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sheet.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 组合三视图
          _buildCombinedView(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade400, Colors.pink.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getRoleIcon(),
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheet.characterName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    sheet.role,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${sheet.status.icon} ${sheet.status.displayName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onRegenerate != null && !isGenerating)
          IconButton(
            onPressed: onRegenerate,
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: '重新生成',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: IconButton.styleFrom(
              backgroundColor: Colors.purple.shade100,
              foregroundColor: Colors.purple.shade700,
            ),
          ),
        if (isGenerating)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.purple,
            ),
          ),
      ],
    );
  }

  /// 构建组合三视图显示（一张图包含三个视角）- 可点击放大
  Widget _buildCombinedView(BuildContext context) {
    final imageUrl = sheet.referenceImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签带渐变效果
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.pink.shade500],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_carousel, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              const Text(
                '角色三视图（正面 | 侧面 | 背面）',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 10, color: Colors.white70),
                      SizedBox(width: 2),
                      Text(
                        '点击放大',
                        style: TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 图片展示区域 - 可点击放大
        GestureDetector(
          onTap: imageUrl != null ? () => _showImageFullscreen(context, imageUrl) : null,
          child: Container(
            width: double.infinity,
            height: 160, // 增大展示区域
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.purple.shade300 : Colors.grey.shade300,
                width: hasImage ? 2 : 1,
              ),
              boxShadow: hasImage
                  ? [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: hasImage
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          memCacheWidth: 800,
                          memCacheHeight: 600,
                          progressIndicatorBuilder: (context, url, progress) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      value: progress.progress,
                                      strokeWidth: 3,
                                      backgroundColor: Colors.purple.shade100,
                                      color: Colors.purple.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '加载中 ${((progress.progress ?? 0) * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.purple.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          errorWidget: (context, url, error) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade300, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    '图片加载失败',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton.icon(
                                    onPressed: () {
                                      // 可以触发重新加载
                                    },
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('重试'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // 悬浮放大提示
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '待生成三视图',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// 显示全屏图片查看器
  void _showImageFullscreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenImageViewer(
            imageUrl: imageUrl,
            characterName: sheet.characterName,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  IconData _getRoleIcon() {
    switch (sheet.role) {
      case '第一主角':
      case '主角':
        return Icons.star;
      case '第二主角':
        return Icons.star_half;
      case '配角':
        return Icons.person_outline;
      default:
        return Icons.person;
    }
  }

  Color _getStatusColor() {
    switch (sheet.status) {
      case CharacterSheetStatus.pending:
        return Colors.grey.shade600;
      case CharacterSheetStatus.generating:
        return Colors.blue.shade600;
      case CharacterSheetStatus.partial:
        return Colors.orange.shade600;
      case CharacterSheetStatus.completed:
        return Colors.green.shade600;
      case CharacterSheetStatus.failed:
        return Colors.red.shade600;
    }
  }
}

/// 全屏图片查看器
class _FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String characterName;

  const _FullscreenImageViewer({
    required this.imageUrl,
    required this.characterName,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _currentScale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 点击背景关闭
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
          // 图片可缩放查看
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              onInteractionEnd: (details) {
                setState(() {
                  _currentScale = _transformationController.value.getMaxScaleOnAxis();
                });
              },
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                progressIndicatorBuilder: (context, url, progress) {
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.progress,
                      color: Colors.white,
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 48),
                  );
                },
              ),
            ),
          ),
          // 顶部工具栏
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 关闭按钮
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      iconSize: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 角色名称
                  Expanded(
                    child: Text(
                      widget.characterName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  // 缩放比例指示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${(_currentScale * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 重置缩放按钮
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: _resetZoom,
                      icon: const Icon(Icons.fit_screen, color: Colors.white),
                      iconSize: 22,
                      tooltip: '重置缩放',
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部提示
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '双指缩放 · 双击重置',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 角色设定列表组件
/// 显示多个角色的三视图
class CharacterSheetsList extends StatelessWidget {
  final List<CharacterSheet> sheets;
  final Function(CharacterSheet)? onRegenerate;
  final Function()? onRegenerateAll;
  final Set<String> generatingIds;

  const CharacterSheetsList({
    super.key,
    required this.sheets,
    this.onRegenerate,
    this.onRegenerateAll,
    this.generatingIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (sheets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              '暂无角色设定',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '确认剧本后将自动生成角色三视图',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.purple.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                '角色设定 (${sheets.length}人)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade900,
                ),
              ),
              const Spacer(),
              if (onRegenerateAll != null)
                TextButton.icon(
                  onPressed: onRegenerateAll,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('重新生成全部', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        // 角色卡片列表
        ...sheets.map((sheet) => CharacterSheetCard(
              sheet: sheet,
              onRegenerate: onRegenerate != null
                  ? () => onRegenerate!(sheet)
                  : null,
              isGenerating: generatingIds.contains(sheet.id),
            )),
      ],
    );
  }
}
