import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/screenplay_draft.dart';

/// 完整剧本预览页面（可编辑版本）
/// 整合显示所有角色、场景、提示词，支持修改
class FullScriptPreviewScreen extends StatefulWidget {
  final ScreenplayDraft draft;
  final Function(ScreenplayDraft)? onSave; // 保存回调

  const FullScriptPreviewScreen({
    super.key,
    required this.draft,
    this.onSave,
  });

  @override
  State<FullScriptPreviewScreen> createState() => _FullScriptPreviewScreenState();
}

class _FullScriptPreviewScreenState extends State<FullScriptPreviewScreen> {
  late ScreenplayDraft _draft;
  bool _isModified = false;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _titleController = TextEditingController(text: _draft.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('完整剧本预览'),
        actions: [
          if (_isModified && widget.onSave != null)
            TextButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          TextButton.icon(
            onPressed: _copyFullScript,
            icon: const Icon(Icons.copy),
            label: const Text('复制'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 剧本基本信息
          _buildScriptInfo(context),
          const SizedBox(height: 20),

          // 情绪弧线
          _buildEmotionalArc(context),
          const SizedBox(height: 20),

          // 角色设定
          if (_draft.hasCharacterSheets) ...[
            _buildCharacterSection(context),
            const SizedBox(height: 20),
          ],

          // 完整场景列表
          _buildScenesSection(context),
        ],
      ),
    );
  }

  /// 保存修改
  void _saveChanges() {
    if (widget.onSave != null) {
      widget.onSave!(_draft);
      setState(() {
        _isModified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('剧本已保存'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// 剧本基本信息
  Widget _buildScriptInfo(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink.shade100, Colors.purple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题（可编辑）
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      _updateDraft((draft) => draft.copyWith(title: value));
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () {},
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoBadge(icon: Icons.category, label: _draft.genre, color: Colors.pink),
                _InfoBadge(icon: Icons.schedule, label: '${_draft.estimatedDurationSeconds}秒', color: Colors.purple),
                _InfoBadge(icon: Icons.view_carousel, label: '${_draft.scenes.length}个场景', color: Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 情绪弧线
  Widget _buildEmotionalArc(BuildContext context) {
    if (_draft.emotionalArc.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  '情绪弧线',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8,
                children: _draft.emotionalArc.asMap().entries.map((entry) {
                  final index = entry.key;
                  final emotion = entry.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0)
                        Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade600),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple.shade300),
                        ),
                        child: Text(
                          emotion,
                          style: TextStyle(
                            color: Colors.purple.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 角色设定区域
  Widget _buildCharacterSection(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '角色设定',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._draft.characterSheets.asMap().entries.map((entry) {
              final index = entry.key;
              final sheet = entry.value;
              return _buildCharacterCard(sheet, index + 1);
            }),
          ],
        ),
      ),
    );
  }

  /// 单个角色卡片
  Widget _buildCharacterCard(dynamic sheet, int index) {
    final name = sheet.name ?? '角色$index';
    final description = sheet.description ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '角色 $index: $name',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _editCharacterDescription(sheet, index),
                color: Colors.blue,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (description.isNotEmpty)
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade800,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  /// 完整场景列表
  Widget _buildScenesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.movie, color: Colors.pink.shade700),
            const SizedBox(width: 8),
            Text(
              '场景详情 (${_draft.scenes.length}个)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._draft.scenes.asMap().entries.map((entry) {
          final index = entry.key;
          final scene = entry.value;
          return _buildFullSceneCard(scene, index + 1);
        }),
      ],
    );
  }

  /// 完整场景卡片（可编辑）
  Widget _buildFullSceneCard(dynamic scene, int sceneNum) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _getMoodColor(scene.mood), width: 2),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              _getMoodColor(scene.mood).withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 场景标题
              _buildSceneHeader(scene, sceneNum),
              const Divider(height: 24),

              // 旁白（可编辑）
              _buildEditableSection(
                icon: Icons.format_quote,
                title: '旁白',
                content: scene.narration,
                bgColor: Colors.purple.shade50,
                textColor: Colors.purple.shade900,
                onChanged: (value) => _updateSceneNarration(scene.sceneId, value),
              ),
              const SizedBox(height: 16),

              // 情绪标签
              _buildMoodInfo(scene),
              const SizedBox(height: 16),

              // 情绪钩子（可编辑）
              if (scene.emotionalHook != null && scene.emotionalHook.isNotEmpty)
                _buildEditableSection(
                  icon: Icons.auto_awesome,
                  title: '情绪钩子',
                  content: scene.emotionalHook,
                  bgColor: Colors.orange.shade50,
                  textColor: Colors.orange.shade900,
                  onChanged: (value) => _updateSceneEmotionalHook(scene.sceneId, value),
                ),
              const SizedBox(height: 16),

              // 图片提示词（可编辑）
              _buildEditableSection(
                icon: Icons.image,
                title: '图片生成提示词',
                content: scene.imagePrompt,
                bgColor: Colors.blue.shade50,
                textColor: Colors.blue.shade900,
                onChanged: (value) => _updateSceneImagePrompt(scene.sceneId, value),
              ),
              const SizedBox(height: 16),

              // 视频提示词（可编辑）
              _buildEditableSection(
                icon: Icons.videocam,
                title: '视频生成提示词',
                content: scene.videoPrompt,
                bgColor: Colors.green.shade50,
                textColor: Colors.green.shade900,
                onChanged: (value) => _updateSceneVideoPrompt(scene.sceneId, value),
              ),
              const SizedBox(height: 16),

              // 人物描述（可编辑）
              if (scene.characterDescription != null && scene.characterDescription.isNotEmpty)
                _buildEditableSection(
                  icon: Icons.person_outline,
                  title: '人物描述',
                  content: scene.characterDescription,
                  bgColor: Colors.teal.shade50,
                  textColor: Colors.teal.shade900,
                  onChanged: (value) => _updateSceneCharacterDescription(scene.sceneId, value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 场景标题
  Widget _buildSceneHeader(dynamic scene, int sceneNum) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getMoodColor(scene.mood),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$sceneNum',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '场景 $sceneNum',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                scene.mood,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 情绪信息
  Widget _buildMoodInfo(dynamic scene) {
    final tags = scene.tags ?? [];
    return Wrap(
      spacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getMoodColor(scene.mood).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getMoodColor(scene.mood)),
          ),
          child: Text(
            scene.mood,
            style: TextStyle(
              color: _getMoodColor(scene.mood).withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...tags.take(3).map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            )),
      ],
    );
  }

  /// 可编辑内容区域
  Widget _buildEditableSection({
    required IconData icon,
    required String title,
    required String content,
    required Color bgColor,
    required Color textColor,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const Spacer(),
            Icon(Icons.edit, size: 16, color: textColor.withOpacity(0.6)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bgColor.withOpacity(0.5)),
          ),
          child: TextField(
            controller: TextEditingController(text: content),
            maxLines: null,
            minLines: 2,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.9),
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// 获取情绪颜色
  Color _getMoodColor(String mood) {
    final moodLower = mood.toLowerCase();
    if (moodLower.contains('温馨') || moodLower.contains('幸福') || moodLower.contains('甜蜜')) {
      return Colors.orange;
    } else if (moodLower.contains('紧张') || moodLower.contains('悬疑')) {
      return Colors.red;
    } else if (moodLower.contains('浪漫')) {
      return Colors.pink;
    } else if (moodLower.contains('感动') || moodLower.contains('治愈')) {
      return Colors.purple;
    } else if (moodLower.contains('宁静')) {
      return Colors.teal;
    } else if (moodLower.contains('惊喜') || moodLower.contains('愉快')) {
      return Colors.amber;
    } else {
      return Colors.blue;
    }
  }

  /// 更新剧本并标记为已修改
  void _updateDraft(ScreenplayDraft Function(ScreenplayDraft) updater) {
    setState(() {
      _draft = updater(_draft);
      _isModified = true;
    });
  }

  /// 更新场景旁白
  void _updateSceneNarration(int sceneId, String value) {
    _updateDraft((draft) {
      final newScenes = draft.scenes.map((scene) {
        return scene.sceneId == sceneId
            ? scene.copyWith(narration: value)
            : scene;
      }).toList();
      return draft.copyWith(scenes: newScenes);
    });
  }

  /// 更新情绪钩子
  void _updateSceneEmotionalHook(int sceneId, String value) {
    _updateDraft((draft) {
      final newScenes = draft.scenes.map((scene) {
        return scene.sceneId == sceneId
            ? scene.copyWith(emotionalHook: value)
            : scene;
      }).toList();
      return draft.copyWith(scenes: newScenes);
    });
  }

  /// 更新图片提示词
  void _updateSceneImagePrompt(int sceneId, String value) {
    _updateDraft((draft) {
      final newScenes = draft.scenes.map((scene) {
        return scene.sceneId == sceneId
            ? scene.copyWith(imagePrompt: value)
            : scene;
      }).toList();
      return draft.copyWith(scenes: newScenes);
    });
  }

  /// 更新视频提示词
  void _updateSceneVideoPrompt(int sceneId, String value) {
    _updateDraft((draft) {
      final newScenes = draft.scenes.map((scene) {
        return scene.sceneId == sceneId
            ? scene.copyWith(videoPrompt: value)
            : scene;
      }).toList();
      return draft.copyWith(scenes: newScenes);
    });
  }

  /// 更新人物描述
  void _updateSceneCharacterDescription(int sceneId, String value) {
    _updateDraft((draft) {
      final newScenes = draft.scenes.map((scene) {
        return scene.sceneId == sceneId
            ? scene.copyWith(characterDescription: value)
            : scene;
      }).toList();
      return draft.copyWith(scenes: newScenes);
    });
  }

  /// 编辑角色描述
  void _editCharacterDescription(dynamic sheet, int index) {
    final controller = TextEditingController(text: sheet.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑角色 ${sheet.name ?? index}'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '输入角色描述...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 更新角色描述（这里需要通过回调通知外部）
              _showCharacterUpdateHint();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示角色更新提示
  void _showCharacterUpdateHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('角色描述修改功能需要通过返回页面修改'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 复制完整剧本
  void _copyFullScript() {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('《${_draft.title}》完整剧本');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('类型: ${_draft.genre}');
    buffer.writeln('时长: ${_draft.estimatedDurationSeconds}秒');
    buffer.writeln('场景数: ${_draft.scenes.length}');
    if (_draft.emotionalArc.isNotEmpty) {
      buffer.writeln('情绪弧线: ${_draft.emotionalArc.join(' → ')}');
    }
    buffer.writeln();

    // 角色设定
    if (_draft.hasCharacterSheets) {
      buffer.writeln('─────────────────────────────────────');
      buffer.writeln('角色设定');
      buffer.writeln('─────────────────────────────────────');
      for (var i = 0; i < _draft.characterSheets.length; i++) {
        final sheet = _draft.characterSheets[i];
        buffer.writeln('角色 ${i + 1}: ${sheet.characterName}');
        buffer.writeln('  ${sheet.description}');
        buffer.writeln();
      }
    }

    // 场景详情
    buffer.writeln('─────────────────────────────────────');
    buffer.writeln('场景详情');
    buffer.writeln('─────────────────────────────────────');
    buffer.writeln();

    for (var i = 0; i < _draft.scenes.length; i++) {
      final scene = _draft.scenes[i];
      buffer.writeln('【场景 ${i + 1}/${_draft.scenes.length}】${scene.mood}');
      buffer.writeln('═══════════════════════════════════════');
      buffer.writeln('旁白: ${scene.narration}');
      if (scene.emotionalHook != null) {
        buffer.writeln('情绪钩子: ${scene.emotionalHook}');
      }
      buffer.writeln();
      buffer.writeln('图片提示: ${scene.imagePrompt}');
      buffer.writeln();
      buffer.writeln('视频提示: ${scene.videoPrompt}');
      if (scene.characterDescription != null && scene.characterDescription.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('人物描述: ${scene.characterDescription}');
      }
      buffer.writeln();
      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('完整剧本已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// 信息徽章
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
