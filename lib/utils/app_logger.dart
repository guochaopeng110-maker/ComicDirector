import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 应用日志工具
/// 支持控制台输出和文件保存
class AppLogger {
  static File? _logFile;
  static final _logBuffer = <String>[];
  static Timer? _flushTimer;
  static bool _initialized = false;
  static const int _maxLogFileSize = 10 * 1024 * 1024; // 10MB

  /// 初始化日志系统
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory(path.join(directory.path, 'logs'));

      // 创建日志目录
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // 生成带时间戳的日志文件名
      final timestamp = _getTimestamp();
      final logFileName = 'app_log_$timestamp.txt';
      _logFile = File(path.join(logDir.path, logFileName));

      // 写入文件头
      final header = '''
========================================
AI Director 应用日志
开始时间: ${DateTime.now().toIso8601String()}
========================================

''';
      await _logFile!.writeAsString(header, mode: FileMode.append);

      _initialized = true;

      // 启动定时刷新（每5秒写入一次）
      _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => _flush());

      print('✅ [AppLogger] 日志系统已初始化: ${_logFile!.path}');
    } catch (e) {
      print('⚠️ [AppLogger] 初始化失败: $e');
    }
  }

  /// 获取时间戳格式：yyyyMMdd_HHmmss
  static String _getTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
           '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  /// 获取当前日志时间
  static String _currentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
           '${now.minute.toString().padLeft(2, '0')}:'
           '${now.second.toString().padLeft(2, '0')}';
  }

  /// 写入日志到文件
  static void _logToFile(String message) {
    _logBuffer.add(message);

    // 如果缓冲区太大，立即写入
    if (_logBuffer.length >= 50) {
      _flush();
    }
  }

  /// 刷新缓冲区到文件
  static Future<void> _flush() async {
    if (_logBuffer.isEmpty || _logFile == null) return;

    try {
      final content = _logBuffer.join('\n');
      _logBuffer.clear();

      // 检查文件大小
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > _maxLogFileSize) {
          // 文件太大，创建新文件
          await _rotateLogFile();
        }
      }

      await _logFile!.writeAsString(content, mode: FileMode.append);
    } catch (e) {
      print('⚠️ [AppLogger] 写入文件失败: $e');
    }
  }

  /// 日志文件轮转
  static Future<void> _rotateLogFile() async {
    try {
      final directory = _logFile!.parent;
      final timestamp = _getTimestamp();
      final newFileName = 'app_log_$timestamp.txt';
      final newFile = File(path.join(directory.path, newFileName));

      await _logFile!.copy(newFile.path);
      await _logFile!.writeAsString('', mode: FileMode.write);

      print('✅ [AppLogger] 日志文件已轮转: $newFileName');
    } catch (e) {
      print('⚠️ [AppLogger] 日志轮转失败: $e');
    }
  }

  /// 获取当前日志文件路径
  static String? get currentLogPath => _logFile?.path;

  /// 获取所有日志文件
  static Future<List<File>> getLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory(path.join(directory.path, 'logs'));

      if (!await logDir.exists()) {
        return [];
      }

      final files = await logDir.list().where((entity) => entity is File).cast<File>().toList();
      // 按修改时间降序排序
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      print('⚠️ [AppLogger] 获取日志文件列表失败: $e');
      return [];
    }
  }

  /// 读取日志文件内容
  static Future<String> readLogFile(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      return '读取失败: $e';
    }
  }

  /// 删除日志文件
  static Future<bool> deleteLogFile(File file) async {
    try {
      await file.delete();
      return true;
    } catch (e) {
      print('⚠️ [AppLogger] 删除日志文件失败: $e');
      return false;
    }
  }

  /// 清空所有日志文件
  static Future<void> clearAllLogs() async {
    try {
      final files = await getLogFiles();
      for (final file in files) {
        await file.delete();
      }
      print('✅ [AppLogger] 已清空所有日志文件');
    } catch (e) {
      print('⚠️ [AppLogger] 清空日志失败: $e');
    }
  }

  /// 释放资源
  static Future<void> dispose() async {
    _flushTimer?.cancel();
    await _flush();

    if (_logFile != null) {
      final footer = '''
========================================
日志结束时间: ${DateTime.now().toIso8601String()}
========================================

''';
      await _logFile!.writeAsString(footer, mode: FileMode.append);
    }

    _initialized = false;
  }

  // ==================== 日志方法 ====================

  static void success(String tag, String message) {
    final time = _currentTime();
    final log = '✅ [$time] [$tag] $message';
    print(log);
    if (_initialized) _logToFile(log);
  }

  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    final time = _currentTime();
    final log = '❌ [$time] [$tag] $message';
    print(log);
    if (error != null) print('   错误: $error');
    if (stackTrace != null) print('   堆栈: $stackTrace');

    if (_initialized) {
      final buffer = StringBuffer(log);
      if (error != null) buffer.write('\n   错误: $error');
      if (stackTrace != null) buffer.write('\n   堆栈: $stackTrace');
      _logToFile(buffer.toString());
    }
  }

  static void info(String tag, String message) {
    final time = _currentTime();
    final log = 'ℹ️  [$time] [$tag] $message';
    print(log);
    if (_initialized) _logToFile(log);
  }

  static void warn(String tag, String message) {
    final time = _currentTime();
    final log = '⚠️  [$time] [$tag] $message';
    print(log);
    if (_initialized) _logToFile(log);
  }

  static void debug(String tag, String message) {
    final time = _currentTime();
    final log = '🐛 [$time] [$tag] $message';
    print(log);
    if (_initialized) _logToFile(log);
  }

  // ==================== API 专用日志方法 ====================

  static void api(String method, String endpoint, Map<String, dynamic>? data) {
    final time = _currentTime();
    final log = '🌐 [$time] [API请求] $method $endpoint';
    print(log);
    if (data != null && data.isNotEmpty) {
      print('   请求数据: $data');
    }
    if (_initialized) {
      final buffer = StringBuffer(log);
      if (data != null && data.isNotEmpty) {
        buffer.write('\n   请求数据: $data');
      }
      _logToFile(buffer.toString());
    }
  }

  static void apiResponse(String endpoint, dynamic data) {
    final time = _currentTime();
    final log = '📥 [$time] [API响应] $endpoint';
    print(log);
    if (data != null) {
      final dataStr = data.toString();
      final displayData = dataStr.length > 500 ? '${dataStr.substring(0, 500)}...' : dataStr;
      print('   响应数据: $displayData');
    }
    if (_initialized) {
      final buffer = StringBuffer(log);
      if (data != null) {
        final dataStr = data.toString();
        final displayData = dataStr.length > 500 ? '${dataStr.substring(0, 500)}...' : dataStr;
        buffer.write('\n   响应数据: $displayData');
      }
      _logToFile(buffer.toString());
    }
  }

  /// 打印完整的 API 请求（不截断）
  static void apiRequestRaw(String method, String endpoint, dynamic data) {
    final time = _currentTime();
    final log = '🌐 [$time] [API请求完整] $method $endpoint';
    print(log);
    if (data != null) {
      final dataStr = data is String ? data : jsonEncode(data);
      print('   请求数据: $dataStr');
    }
    if (_initialized) {
      final buffer = StringBuffer(log);
      if (data != null) {
        final dataStr = data is String ? data : jsonEncode(data);
        buffer.write('\n   请求数据: $dataStr');
      }
      _logToFile(buffer.toString());
    }
  }

  /// 打印完整的 API 响应（不截断）
  static void apiResponseRaw(String endpoint, dynamic data) {
    final time = _currentTime();
    final log = '📥 [$time] [API响应完整] $endpoint';
    print(log);
    if (data != null) {
      final dataStr = data is String ? data : jsonEncode(data);
      print('   响应数据: $dataStr');
    }
    if (_initialized) {
      final buffer = StringBuffer(log);
      if (data != null) {
        final dataStr = data is String ? data : jsonEncode(data);
        buffer.write('\n   响应数据: $dataStr');
      }
      _logToFile(buffer.toString());
    }
  }

  static void streamChunk(String tag, String content) {
    final time = _currentTime();
    final displayContent = content.length > 100 ? '${content.substring(0, 100)}...' : content;
    final log = '📦 [$time] [$tag] $displayContent';
    print(log);
    if (_initialized) _logToFile(log);
  }

  static void command(String action, Map<String, dynamic>? params) {
    final time = _currentTime();
    final log = '⚡ [$time] [命令] $action ${params ?? ''}';
    print(log);
    if (_initialized) _logToFile(log);
  }
}
