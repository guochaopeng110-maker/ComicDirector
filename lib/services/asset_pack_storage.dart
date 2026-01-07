import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset_pack.dart';
import '../utils/app_logger.dart';

/// 素材包本地存储服务
/// 使用 SharedPreferences 存储素材包数据
class AssetPackStorage {
  static const String _assetPacksKey = 'asset_packs';
  static const String _currentPackIdKey = 'current_asset_pack_id';
  static const int _maxStoredPacks = 10; // 最多保存10个素材包

  /// 保存素材包
  static Future<bool> saveAssetPack(AssetPack pack) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取现有的素材包列表
      final List<AssetPack> existingPacks = await getAssetPacks();

      // 查找是否已存在相同ID的素材包
      final updatedPacks = <AssetPack>[];
      bool found = false;

      for (final existing in existingPacks) {
        if (existing.id == pack.id) {
          updatedPacks.add(pack);
          found = true;
        } else {
          updatedPacks.add(existing);
        }
      }

      if (!found) {
        // 新素材包，添加到列表开头
        updatedPacks.insert(0, pack);
      }

      // 按更新时间排序
      updatedPacks.sort((a, b) => (b.updatedAt ?? b.createdAt)
          .compareTo(a.updatedAt ?? a.createdAt));

      // 限制存储数量
      final limitedPacks = updatedPacks.take(_maxStoredPacks).toList();

      // 转换为JSON存储
      final jsonList = limitedPacks.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_assetPacksKey, jsonList);

      // 设置为当前素材包
      await setCurrentAssetPackId(pack.id);

      AppLogger.success('AssetPackStorage', '素材包已保存: ${pack.name}');
      return true;
    } catch (e) {
      AppLogger.error('AssetPackStorage', '保存素材包失败', e);
      return false;
    }
  }

  /// 获取所有素材包
  static Future<List<AssetPack>> getAssetPacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_assetPacksKey);

      if (jsonList == null || jsonList.isEmpty) {
        return [];
      }

      final packs = <AssetPack>[];
      for (final jsonStr in jsonList) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          packs.add(AssetPack.fromJson(json));
        } catch (e) {
          AppLogger.error('AssetPackStorage', '解析素材包失败: $jsonStr', e);
        }
      }

      return packs;
    } catch (e) {
      AppLogger.error('AssetPackStorage', '获取素材包列表失败', e);
      return [];
    }
  }

  /// 获取指定ID的素材包
  static Future<AssetPack?> getAssetPack(String id) async {
    try {
      final packs = await getAssetPacks();
      return packs.cast<AssetPack?>().firstWhere(
        (p) => p?.id == id,
        orElse: () => null,
      );
    } catch (e) {
      AppLogger.error('AssetPackStorage', '获取素材包失败', e);
      return null;
    }
  }

  /// 删除素材包
  static Future<bool> deleteAssetPack(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packs = await getAssetPacks();

      final updatedPacks = packs.where((p) => p.id != id).toList();
      final jsonList = updatedPacks.map((p) => jsonEncode(p.toJson())).toList();

      await prefs.setStringList(_assetPacksKey, jsonList);

      // 如果删除的是当前素材包，清除当前ID
      final currentId = prefs.getString(_currentPackIdKey);
      if (currentId == id) {
        await prefs.remove(_currentPackIdKey);
      }

      AppLogger.success('AssetPackStorage', '素材包已删除: $id');
      return true;
    } catch (e) {
      AppLogger.error('AssetPackStorage', '删除素材包失败', e);
      return false;
    }
  }

  /// 清空所有素材包
  static Future<bool> clearAllAssetPacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_assetPacksKey);
      await prefs.remove(_currentPackIdKey);

      AppLogger.success('AssetPackStorage', '已清空所有素材包');
      return true;
    } catch (e) {
      AppLogger.error('AssetPackStorage', '清空素材包失败', e);
      return false;
    }
  }

  /// 设置当前素材包ID
  static Future<bool> setCurrentAssetPackId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentPackIdKey, id);
      return true;
    } catch (e) {
      AppLogger.error('AssetPackStorage', '设置当前素材包ID失败', e);
      return false;
    }
  }

  /// 获取当前素材包ID
  static Future<String?> getCurrentAssetPackId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentPackIdKey);
    } catch (e) {
      AppLogger.error('AssetPackStorage', '获取当前素材包ID失败', e);
      return null;
    }
  }

  /// 获取当前素材包
  static Future<AssetPack?> getCurrentAssetPack() async {
    try {
      final currentId = await getCurrentAssetPackId();
      if (currentId == null) return null;
      return await getAssetPack(currentId);
    } catch (e) {
      AppLogger.error('AssetPackStorage', '获取当前素材包失败', e);
      return null;
    }
  }

  /// 导出素材包为JSON字符串
  static String exportAssetPackToJson(AssetPack pack) {
    return jsonEncode(pack.toJson());
  }

  /// 从JSON字符串导入素材包
  static Future<AssetPack?> importAssetPackFromJson(String jsonStr) async {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final pack = AssetPack.fromJson(json);

      // 保存导入的素材包
      await saveAssetPack(pack);

      AppLogger.success('AssetPackStorage', '素材包已导入: ${pack.name}');
      return pack;
    } catch (e) {
      AppLogger.error('AssetPackStorage', '导入素材包失败', e);
      return null;
    }
  }

  /// 获取存储统计信息
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packs = await getAssetPacks();

      final totalScenes = packs.fold<int>(0, (sum, p) => sum + p.totalScenes);
      final completedScenes = packs.fold<int>(0, (sum, p) => sum + p.completedScenes);
      final totalCharacters = packs.fold<int>(0, (sum, p) => sum + p.characterSheets.length);

      return {
        'total_packs': packs.length,
        'total_scenes': totalScenes,
        'completed_scenes': completedScenes,
        'total_characters': totalCharacters,
        'storage_used': jsonEncode(packs.map((p) => p.toJson()).toList()).length,
      };
    } catch (e) {
      AppLogger.error('AssetPackStorage', '获取存储统计失败', e);
      return {};
    }
  }
}
