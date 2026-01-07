import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'utils/app_logger.dart';
import 'providers/chat_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/video_merge_provider.dart';
import 'models/screenplay_draft.dart';
import 'screens/chat_screen.dart';
import 'screens/screenplay_review_screen.dart';
import 'screens/log_viewer_screen.dart';
import 'screens/settings_screen.dart';
import 'services/api_config_service.dart';

void main() async {
  // 确保 Flutter 绑定初始化（必须在所有插件操作之前）
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  await AppLogger.initialize();

  // 初始化 API 配置服务
  await ApiConfigService.initialize();

  runApp(const DirectorAIApp());

  // 监听应用生命周期
  WidgetsBinding.instance.addObserver(AppLifecycleObserver(
    onDetached: () async {
      await AppLogger.dispose();
    },
  ));
}

/// 应用生命周期观察者
class AppLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onDetached;

  AppLifecycleObserver({required this.onDetached});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      onDetached();
    }
  }
}

class DirectorAIApp extends StatelessWidget {
  const DirectorAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => VideoMergeProvider()),
      ],
      child: MaterialApp(
        title: 'AI漫导',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          // 动漫创作风格主题 - 紫色系
          primaryColor: const Color(0xFF8B5CF6), // 创意紫
          scaffoldBackgroundColor: const Color(0xFFF8F7FC), // 浅紫灰背景
          brightness: Brightness.light,

          // 动漫风格颜色方案
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF8B5CF6), // 创意紫
            secondary: Color(0xFFEC4899), // 动漫粉
            tertiary: Color(0xFFF59E0B), // 活力金
            surface: Color(0xFFFFFFFF), // 白色卡片
            background: Color(0xFFF8F7FC), // 浅紫灰背景
            error: Color(0xFFEF4444),
            onPrimary: Colors.white,
            onSurface: Color(0xFF1C1C1E),
            onBackground: Color(0xFF1C1C1E),
          ),

          // AppBar - 毛玻璃效果
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white.withOpacity(0.85),
            foregroundColor: const Color(0xFF8B5CF6),
            titleTextStyle: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
            iconTheme: const IconThemeData(color: Color(0xFF8B5CF6)),
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
            ),
          ),

          // 卡片样式
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide.none,
            ),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
          ),

          // 输入框样式
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
            ),
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 16,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),

          // 按钮样式
          filledButtonTheme: FilledButtonThemeData(
            style: ButtonStyle(
              backgroundColor: const WidgetStatePropertyAll(Color(0xFF8B5CF6)),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // 文本按钮样式
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              foregroundColor: const WidgetStatePropertyAll(Color(0xFF8B5CF6)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // 图标样式
          iconTheme: const IconThemeData(
            color: Color(0xFF8B5CF6),
            size: 24,
          ),

          // FloatingActionButton
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          // 分割线样式
          dividerTheme: const DividerThemeData(
            color: Color(0xFFE5E7EB),
            thickness: 1,
          ),

          // iOS 文字样式
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: Color(0xFF1C1C1E),
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: Color(0xFF1C1C1E),
            ),
            titleLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Color(0xFF1C1C1E),
            ),
            titleMedium: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Color(0xFF1C1C1E),
            ),
            bodyLarge: TextStyle(
              fontSize: 17,
              letterSpacing: -0.4,
              color: Color(0xFF1C1C1E),
            ),
            bodyMedium: TextStyle(
              fontSize: 15,
              letterSpacing: -0.2,
              color: Color(0xFF1C1C1E),
            ),
            bodySmall: TextStyle(
              fontSize: 13,
              letterSpacing: -0.1,
              color: Color(0xFF8E8E93),
            ),
          ),

          // iOS 列表样式
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            titleTextStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1C1C1E),
            ),
            subtitleTextStyle: TextStyle(
              fontSize: 15,
              color: Color(0xFF8E8E93),
            ),
          ),

          // iOS 对话框
          dialogTheme: const DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
          ),

          // 底部表单样式
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFFF3F4F6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
        ),
        home: const ChatScreen(),
        routes: {
          '/settings': (context) => const SettingsScreen(),
          '/screenplay-review': (context) {
            // 从路由参数获取剧本草稿
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is ScreenplayReviewScreenArgs) {
              return ScreenplayReviewScreen(
                draft: args.draft,
                onConfirm: args.onConfirm,
                onRegenerate: args.onRegenerate,
                onRegenerateCharacterSheets: args.onRegenerateCharacterSheets,
              );
            }
            // 兼容旧版本，从 Provider 获取
            final provider = context.read<ChatProvider>();
            if (provider.currentDraft != null) {
              return ScreenplayReviewScreen(
                draft: provider.currentDraft!,
                onConfirm: (draft) async {
                  await provider.confirmDraft();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                onRegenerate: (feedback) async {
                  return await provider.regenerateDraft(feedback);
                },
                onRegenerateCharacterSheets: () async {
                  await provider.regenerateCharacterSheets();
                },
              );
            }
            return const Scaffold(body: Center(child: Text('没有找到剧本')));
          },
          '/logs': (context) => const LogViewerScreen(),
        },
      ),
    );
  }
}

/// 剧本确认页面的路由参数
class ScreenplayReviewScreenArgs {
  final ScreenplayDraft draft;
  final Function(ScreenplayDraft) onConfirm;
  final Future<ScreenplayDraft> Function(String? feedback)? onRegenerate;
  final Future<void> Function()? onRegenerateCharacterSheets; // 新增

  ScreenplayReviewScreenArgs({
    required this.draft,
    required this.onConfirm,
    this.onRegenerate,
    this.onRegenerateCharacterSheets,
  });
}
