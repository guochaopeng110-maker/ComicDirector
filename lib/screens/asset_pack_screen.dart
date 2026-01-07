import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/asset_pack.dart';
import '../models/screenplay_draft.dart';
import '../models/character_sheet.dart';
import '../widgets/character_sheet_card.dart';

/// 素材包管理页面
/// 统一管理剧本、角色设定、场景资源等
class AssetPackScreen extends StatefulWidget {
  final AssetPack pack;
  final Function(AssetPack)? onUpdate;

  const AssetPackScreen({
    super.key,
    required this.pack,
    this.onUpdate,
  });

  @override
  State<AssetPackScreen> createState() => _AssetPackScreenState();
}

class _AssetPackScreenState extends State<AssetPackScreen> {
  late AssetPack _pack;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _pack = widget.pack;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 素材包信息卡片
          _buildPackInfoCard(),

          // Tab栏
          _buildTabBar(),

          // 内容区域
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_pack.name),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: _showEditNameDialog,
          tooltip: '编辑名称',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showMoreOptions,
          tooltip: '更多选项',
        ),
      ],
    );
  }

  Widget _buildPackInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.pink.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态和进度
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _pack.status.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _pack.status.color),
                ),
                child: Row(
                  children: [
                    Text('${_pack.status.icon} ', style: const TextStyle(fontSize: 12)),
                    Text(
                      _pack.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _pack.status.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '完成进度',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _pack.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(_pack.status.color),
                      minHeight: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(_pack.progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _pack.status.color,
                ),
              ),
            ],
          ),

          // 统计信息
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            children: [
              _StatItem(
                icon: Icons.movie,
                label: '场景',
                value: '${_pack.completedScenes}/${_pack.totalScenes}',
              ),
              _StatItem(
                icon: Icons.people,
                label: '角色',
                value: '${_pack.characterSheets.length}',
              ),
              _StatItem(
                icon: Icons.image,
                label: '图片',
                value: '${_pack.sceneAssets.where((s) => s.imageGenerated).length}',
              ),
              _StatItem(
                icon: Icons.video_library,
                label: '视频',
                value: '${_pack.sceneAssets.where((s) => s.videoGenerated).length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildTab(0, Icons.description, '剧本'),
          _buildTab(1, Icons.people, '角色'),
          _buildTab(2, Icons.photo_library, '素材'),
          _buildTab(3, Icons.chat, '对话'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple.shade50 : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.purple.shade700 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.purple.shade700 : Colors.grey.shade600),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.purple.shade700 : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildScreenplayTab();
      case 1:
        return _buildCharactersTab();
      case 2:
        return _buildAssetsTab();
      case 3:
        return _buildChatTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // 剧本标签页
  Widget _buildScreenplayTab() {
    final draft = _pack.draft;
    if (draft == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('暂无剧本', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: draft.scenes.length,
      itemBuilder: (context, index) {
        final scene = draft.scenes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Text('${scene.sceneId}', style: TextStyle(color: Colors.purple.shade900)),
            ),
            title: Text('场景 ${scene.sceneId}'),
            subtitle: Text(scene.mood),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow('旁白', scene.narration),
                    const SizedBox(height: 8),
                    if (scene.emotionalHook != null) _InfoRow('情绪钩子', scene.emotionalHook!),
                    const SizedBox(height: 8),
                    _InfoRow('图片提示', scene.imagePrompt, maxLines: 2),
                    const SizedBox(height: 8),
                    _InfoRow('视频提示', scene.videoPrompt, maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 角色标签页
  Widget _buildCharactersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: CharacterSheetsList(
        sheets: _pack.characterSheets,
      ),
    );
  }

  // 素材标签页
  Widget _buildAssetsTab() {
    if (_pack.sceneAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('暂无素材', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('确认剧本后开始生成素材', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _pack.sceneAssets.length,
      itemBuilder: (context, index) {
        final asset = _pack.sceneAssets[index];
        return _SceneAssetCard(asset: asset);
      },
    );
  }

  // 对话标签页（AI对话修改素材）
  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5, // 示例对话
            itemBuilder: (context, index) {
              return _ChatBubble(
                isUser: index % 2 == 0,
                message: index % 2 == 0
                    ? '帮我修改第1个场景的背景'
                    : '好的，我可以帮你修改场景1的背景。请描述你想要的背景风格...',
              );
            },
          ),
        ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '描述你想要的修改...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () {},
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_selectedTab == 1 && _pack.characterSheets.isEmpty) {
      return FloatingActionButton.extended(
        onPressed: _generateCharacterSheets,
        icon: const Icon(Icons.people),
        label: const Text('生成角色设定'),
        backgroundColor: Colors.purple.shade700,
      );
    }
    if (_selectedTab == 2 && _pack.canStartGeneration) {
      return FloatingActionButton.extended(
        onPressed: _startGeneration,
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始生成'),
        backgroundColor: Colors.pink.shade700,
      );
    }
    return null;
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _pack.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '素材包名称',
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
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _pack = _pack.copyWith(name: controller.text.trim());
                });
                widget.onUpdate?.call(_pack);
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导出素材包'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 导出功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享素材包'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 分享功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('删除素材包'),
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除素材包'),
        content: Text('确定要删除「${_pack.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // 返回删除标志
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _generateCharacterSheets() {
    // TODO: 调用API生成角色设定
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成角色设定...')),
    );
  }

  void _startGeneration() {
    // TODO: 开始生成素材
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开始生成素材...')),
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.purple.shade700),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final int? maxLines;

  const _InfoRow(this.label, this.value, {this.maxLines});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 场景资源卡片
class _SceneAssetCard extends StatelessWidget {
  final SceneAsset asset;

  const _SceneAssetCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片预览
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade200,
              child: asset.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: asset.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      memCacheHeight: 400,
                      progressIndicatorBuilder: (context, url, progress) {
                        return Center(
                          child: CircularProgressIndicator(value: progress.progress),
                        );
                      },
                      errorWidget: (context, url, error) {
                        return Center(
                          child: Icon(Icons.error, color: Colors.red.shade300),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, size: 32, color: Colors.grey.shade400),
                          const SizedBox(height: 4),
                          Text('场景 ${asset.sceneId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
            ),
          ),
          // 状态信息
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo, size: 14, color: asset.imageGenerated ? Colors.green : Colors.grey),
                    const SizedBox(width: 4),
                    Icon(Icons.videocam, size: 14, color: asset.videoGenerated ? Colors.green : Colors.grey),
                    const Spacer(),
                    Text('${(asset.progress * 100).round()}%', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 聊天气泡
class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String message;

  const _ChatBubble({
    required this.isUser,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.purple.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
