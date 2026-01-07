import 'package:flutter/material.dart';
import '../models/screenplay_draft.dart';

/// 剧本草稿场景编辑卡片
/// 用于在剧本确认页面中展示和编辑单个场景
class SceneReviewCard extends StatefulWidget {
  final DraftScene scene;
  final int totalScenes;
  final Function(String) onNarrationChanged;
  final Function(String)? onImagePromptChanged;
  final Function(String)? onVideoPromptChanged;
  final Function(String)? onCharacterDescriptionChanged;
  final Function(String)? onEmotionalHookChanged;
  final VoidCallback? onRegenerate;

  const SceneReviewCard({
    super.key,
    required this.scene,
    required this.totalScenes,
    required this.onNarrationChanged,
    this.onImagePromptChanged,
    this.onVideoPromptChanged,
    this.onCharacterDescriptionChanged,
    this.onEmotionalHookChanged,
    this.onRegenerate,
  });

  @override
  State<SceneReviewCard> createState() => _SceneReviewCardState();
}

class _SceneReviewCardState extends State<SceneReviewCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 可点击的头部区域
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 场景标题和展开按钮
                  _buildHeader(context),
                  const SizedBox(height: 8),

                  // 情绪标签
                  _buildMoodTags(),
                  const SizedBox(height: 8),

                  // 旁白（只读，点击展开后可编辑）
                  _buildNarrationDisplay(),
                ],
              ),
            ),
          ),

          // 展开的编辑区域
          if (_isExpanded) _buildExpandedContent(context),
        ],
      ),
    );
  }

  /// 构建展开的编辑内容
  Widget _buildExpandedContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分隔线
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),

          // 旁白编辑区
          _buildNarrationEditor(context),
          const SizedBox(height: 12),

          // 情绪钩子编辑区
          if (widget.onEmotionalHookChanged != null) ...[
            _buildEmotionalHookEditor(context),
            const SizedBox(height: 12),
          ],

          // 人物描述编辑区
          if (widget.onCharacterDescriptionChanged != null) ...[
            _buildCharacterDescriptionEditor(context),
            const SizedBox(height: 12),
          ],

          // 图片提示词编辑区
          if (widget.onImagePromptChanged != null) ...[
            _buildImagePromptEditor(context),
            const SizedBox(height: 12),
          ],

          // 视频提示词编辑区
          if (widget.onVideoPromptChanged != null)
            _buildVideoPromptEditor(context),
        ],
      ),
    );
  }

  /// 构建旁白显示（只读）
  Widget _buildNarrationDisplay() {
    return Text(
      widget.scene.narration,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF6B7280),
        height: 1.5,
      ),
    );
  }

  /// 构建场景标题
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // 场景编号
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '${widget.scene.sceneId}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 场景标题
        Expanded(
          child: Text(
            '场景 ${widget.scene.sceneId} / ${widget.totalScenes}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
        ),

        // 展开/折叠按钮
        Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 20,
          color: const Color(0xFF9CA3AF),
        ),

        // 重新生成按钮
        if (widget.onRegenerate != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: widget.onRegenerate,
            tooltip: '重新生成此场景',
            color: const Color(0xFF8B5CF6),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ],
    );
  }

  /// 构建情绪标签
  Widget _buildMoodTags() {
    return Wrap(
      spacing: 6,
      children: [
        // 情绪标签
        _MoodChip(
          label: widget.scene.mood,
          color: _getMoodColor(),
        ),

        // 其他标签
        ...widget.scene.tags.take(3).map((tag) => _MoodChip(
              label: tag,
              color: const Color(0xFF9CA3AF),
            )),
      ],
    );
  }

  /// 构建情绪钩子编辑区
  Widget _buildEmotionalHookEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF5856D6)),
            const SizedBox(width: 6),
            const Text(
              '情绪钩子（可编辑）',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          maxLines: null,
          minLines: 1,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '输入情绪钩子...',
            hintStyle: TextStyle(color: Color(0x8C8C8E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Color(0xFFF3F4F6),
            isDense: true,
            contentPadding: EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 14),
          controller: TextEditingController(text: widget.scene.emotionalHook ?? '')
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: widget.scene.emotionalHook?.length ?? 0),
            ),
          onChanged: widget.onEmotionalHookChanged,
        ),
      ],
    );
  }

  /// 构建人物描述编辑区
  Widget _buildCharacterDescriptionEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person, size: 16, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            const Text(
              '人物描述（可编辑）',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          maxLines: null,
          minLines: 2,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '输入人物描述...',
            hintStyle: TextStyle(color: Color(0x8C8C8E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Color(0xFFF3F4F6),
            isDense: true,
            contentPadding: EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 14),
          controller: TextEditingController(text: widget.scene.characterDescription)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: widget.scene.characterDescription.length),
            ),
          onChanged: widget.onCharacterDescriptionChanged,
        ),
      ],
    );
  }

  /// 构建图片提示词编辑区
  Widget _buildImagePromptEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.image, size: 16, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            const Text(
              '图片生成提示词（可编辑）',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          maxLines: null,
          minLines: 2,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '输入图片生成提示词...',
            hintStyle: TextStyle(color: Color(0x8C8C8E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Color(0xFFF3F4F6),
            isDense: true,
            contentPadding: EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 13),
          controller: TextEditingController(text: widget.scene.imagePrompt)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: widget.scene.imagePrompt.length),
            ),
          onChanged: widget.onImagePromptChanged,
        ),
      ],
    );
  }

  /// 构建视频提示词编辑区
  Widget _buildVideoPromptEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.videocam, size: 16, color: Color(0xFF5856D6)),
            const SizedBox(width: 6),
            const Text(
              '视频生成提示词（可编辑）',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          maxLines: null,
          minLines: 2,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '输入视频生成提示词...',
            hintStyle: TextStyle(color: Color(0x8C8C8E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Color(0xFFF3F4F6),
            isDense: true,
            contentPadding: EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 13),
          controller: TextEditingController(text: widget.scene.videoPrompt)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: widget.scene.videoPrompt.length),
            ),
          onChanged: widget.onVideoPromptChanged,
        ),
      ],
    );
  }

  /// 构建旁白编辑器
  Widget _buildNarrationEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_note, size: 18, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            const Text(
              '旁白（可编辑）',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: null,
          minLines: 2,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '输入旁白内容...',
            hintStyle: TextStyle(color: Color(0x8C8C8E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Color(0xFFF3F4F6),
          ),
          style: const TextStyle(fontSize: 15),
          controller: TextEditingController(text: widget.scene.narration)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: widget.scene.narration.length),
            ),
          onChanged: widget.onNarrationChanged,
        ),
      ],
    );
  }

  /// 获取情绪对应的颜色
  Color _getMoodColor() {
    final colorHex = widget.scene.moodColor;
    try {
      // 移除 # 号
      final colorValue = int.parse(colorHex.replaceFirst('#', '0xFF'));
      return Color(colorValue);
    } catch (e) {
      return Colors.grey;
    }
  }
}

/// 情绪标签芯片
class _MoodChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MoodChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
