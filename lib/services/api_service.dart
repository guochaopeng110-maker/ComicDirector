import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/agent_command.dart';
import '../models/character_sheet.dart';
import '../utils/duration_parser.dart';
import '../utils/app_logger.dart';
import 'api_config_service.dart';

/// 类型别名：简化 DurationParser 的引用
typedef _DurationParser = DurationParser;
typedef _SceneCountRange = SceneCountRange;

/// API 配置
class ApiConfig {
  static const String zhipuBaseUrl = 'https://open.bigmodel.cn/api/paas/v4'; // 智谱 GLM
  static const String tuziBaseUrl = 'https://api.ourzhishi.top'; // Tuzi API 基础URL (视频 & 图像)
  static const String doubaoBaseUrl = 'https://ark.cn-beijing.volces.com/api/v3'; // 豆包 ARK API

  // 各服务的 API Key（从 ApiConfigService 读取）
  static String get zhipuApiKey => ApiConfigService.getZhipuApiKey();
  static String get videoApiKey => ApiConfigService.getVideoApiKey();
  static String get imageApiKey => ApiConfigService.getImageApiKey();
  static String get doubaoApiKey => ApiConfigService.getDoubaoApiKey();

  /// 创建智谱 API Dio 实例
  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: zhipuBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加拦截器，在每次请求时动态设置 Authorization header
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 动态获取最新的 API Key
        options.headers['Authorization'] = 'Bearer $zhipuApiKey';
        return handler.next(options);
      },
    ));

    // 添加日志拦截器用于调试
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      error: true,
    ));

    return dio;
  }

  // 豆包模型配置
  // static const String doubaoImageModel = 'doubao-seed-1-8-251215'; // 支持图片的豆包模型
  static const String doubaoImageModel = 'doubao-seed-1-8-preview-251115'; // 支持图片的豆包模型

  // ==================== 功能开关 ====================
  /// 生产环境请将此值设为 false
  /// 注意：如果视频 Mock 为 false，Mock 图片 URL 必须是视频 API 可以访问的公开链接
  static const bool USE_MOCK_VIDEO_API = false;  // 视频生成 Mock 开关
  static const bool USE_MOCK_IMAGE_API = false;   // 图片生成 Mock 开关
  static const bool USE_MOCK_CHARACTER_SHEET_API = false;   // 角色三视图生成 Mock 开关（测试用）

  /// Thinking 模式开关
  /// 启用后会显示 AI 的思考过程，提升用户体验
  /// 演示时可开启，生产环境根据需求决定
  static const bool USE_THINKING_MODE = true;  // 思考过程显示开关

  // ==================== 场景配置 ====================
  /// 场景数量配置
  /// 控制大模型生成的场景数量，同时也是分镜图和分镜视频的数量
  /// 例如：设置为 2，则生成 2 个场景、2 张分镜图、2 个分镜视频
  static int sceneCount = 7;  // 默认 2 个场景

  /// 并发生成场景数量配置
  /// 控制同时生成多少个场景的图片和视频
  /// 例如：设置为 3，则每 3 个场景为一组并行处理
  /// 设置为 1 表示串行处理，设置为大数值表示全并行处理
  static int concurrentScenes = 2;  // 默认每批 3 个场景并行

  /// Mock 视频URL（用于测试）- 使用公开可访问的测试视频
  static const String MOCK_VIDEO_URL =
      'https://www.w3schools.com/html/mov_bbb.mp4';

  /// Mock 图片URL（用于测试）
  static const String MOCK_IMAGE_URL =
      'https://pro.filesystem.site/cdn/20251231/068472ac4cc0ac7a4a8bdb3dcfb693.jpeg';

  /// Mock 角色三视图URL（用于测试）
  /// 新版本：单张组合图（包含正面、侧面、背面三个视角）
  static const String MOCK_CHARACTER_COMBINED_URL =
      'https://pro.filesystem.site/cdn/20251231/068472ac4cc0ac7a4a8bdb3dcfb693.jpeg';

  /// 兼容旧版：单独的三视图URL（已废弃）
  @Deprecated('使用 MOCK_CHARACTER_COMBINED_URL 替代')
  static const String MOCK_CHARACTER_FRONT_URL =
      'https://pro.filesystem.site/cdn/20251231/068472ac4cc0ac7a4a8bdb3dcfb693.jpeg';
  @Deprecated('使用 MOCK_CHARACTER_COMBINED_URL 替代')
  static const String MOCK_CHARACTER_BACK_URL =
      'https://pro.filesystem.site/cdn/20251231/068472ac4cc0ac7a4a8bdb3dcfb693.jpeg';
  @Deprecated('使用 MOCK_CHARACTER_COMBINED_URL 替代')
  static const String MOCK_CHARACTER_SIDE_URL =
      'https://pro.filesystem.site/cdn/20251231/068472ac4cc0ac7a4a8bdb3dcfb693.jpeg';

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: zhipuBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Authorization': 'Bearer $zhipuApiKey',
        'Content-Type': 'application/json',
      },
    ));

    // 添加日志拦截器用于调试
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      error: true,
    ));

    return dio;
  }
}

/// GLM 系统提示词 - 剧本规划模式
const String _glmSystemPrompt = '''
You are DirectorAI, a SCREENPLAY CREATION AGENT for short video production.

YOUR MISSION: Convert user's creative idea into a multi-scene screenplay with exactly 3 scenes.
Each scene will be turned into: Narration (Chinese) → Image → Video.

CRITICAL OUTPUT FORMAT:
You MUST respond with ONLY a valid JSON object. No markdown, no explanations, no thinking process.

JSON SCHEMA:
{
  "task_id": "unique_task_id",
  "script_title": "剧本标题",
  "scenes": [
    {
      "scene_id": 1,
      "narration": "中文旁白，描述这一幕的内容",
      "image_prompt": "Detailed English visual description for image generation",
      "video_prompt": "English motion/description for video animation",
      "character_description": "Detailed character description for consistency across scenes",
      "image_url": null,
      "video_url": null,
      "status": "pending"
    }
  ]
}

GUIDELINES:

1. NUMBER OF SCENES: EXACTLY 3 SCENES
   - Scene 1: Introduction / Setup (establish the main character and setting)
   - Scene 2: Development / Action (the main conflict or activity)
   - Scene 3: Resolution / Ending (conclusion and aftermath)
   - Each scene must be focused on ONE key moment

2. CHARACTER CONSISTENCY (CRITICAL):
   - First scene's image_prompt MUST contain detailed character appearance description
   - The character_description field should describe the main character's appearance in detail
   - For subsequent scenes, the image_prompt should reference the same character traits
   - This ensures the same character appears across all scenes

3. NARRATION (Chinese):
   - Short, evocative descriptions
   - 1-2 sentences per scene
   - Sets the mood and context

4. IMAGE_PROMPT (English):
   - Scene 1: Establish the main character with detailed appearance (hair, clothing, face, body type, colors)
   - Scene 2+: Reference the same character using consistent descriptors from scene 1
   - CRITICAL: ALWAYS start with "anime style, manga art, 2D animation, cel shaded"
   - For human characters: specify "Asian" or "Japanese anime style" features
   - AVOID: "realistic, photorealistic, cinematic, 3D render"
   - Example scene 1: "anime style, manga art, 2D animation. A cute orange tabby cat with green eyes and white paws, sitting on grass..."
   - Example scene 2: "anime style, manga art. The same orange tabby cat with green eyes and white paws, now jumping..."

5. VIDEO_PROMPT (English):
   - Motion description: what moves, how, action
   - Keep it consistent with the image

6. CHARACTER_DESCRIPTION (English):
   - A detailed description of the main character's appearance
   - Include: species, colors, distinctive features, clothing, accessories
   - For human characters: specify "anime style, Asian features" or "Japanese anime style"
   - This description will be used to maintain consistency across all scenes

EXAMPLE INPUT: "生成一只猫打架的视频"

EXAMPLE OUTPUT:
{
  "task_id": "cat_fight_20231227",
  "script_title": "猫咪大战",
  "scenes": [
    {
      "scene_id": 1,
      "narration": "两只猫咪在草地上对峙，气氛紧张",
      "image_prompt": "Two cats facing each other on grass, tense standoff. Left: orange tabby cat with bright green eyes and white paws. Right: grey striped cat with amber eyes. Cinematic composition, golden hour lighting, 4k ultra detailed",
      "video_prompt": "Cats circling each other slowly, tails twitching, intense staring",
      "character_description": "Orange tabby cat with bright green eyes, white paws, and striped tail. Grey striped cat with amber eyes and pointed ears.",
      "image_url": null,
      "video_url": null,
      "status": "pending"
    },
    {
      "scene_id": 2,
      "narration": "突然，它们开始激烈地打斗",
      "image_prompt": "The same orange tabby cat with green eyes and white paws fighting the grey striped cat with amber eyes. Mid-action shot, dynamic pose, motion blur, professional sports photography style, dramatic lighting",
      "video_prompt": "Orange cat and grey cat jumping and pouncing, fast dynamic action, paws swiping",
      "character_description": "Orange tabby cat with bright green eyes, white paws, and striped tail. Grey striped cat with amber eyes and pointed ears.",
      "image_url": null,
      "video_url": null,
      "status": "pending"
    },
    {
      "scene_id": 3,
      "narration": "打斗结束，各自离开",
      "image_prompt": "The orange tabby cat with green eyes and white paws walking left, away from camera. The grey striped cat with amber eyes walking right. Calm aftermath, sunset lighting, peaceful atmosphere, 4k detailed",
      "video_prompt": "Orange cat and grey cat calmly walking away from each other in opposite directions, slow movement",
      "character_description": "Orange tabby cat with bright green eyes, white paws, and striped tail. Grey striped cat with amber eyes and pointed ears.",
      "image_url": null,
      "video_url": null,
      "status": "pending"
    }
  ]
}

ABSOLUTE RULES:
1. Output ONLY valid JSON - no markdown code blocks, no explanations
2. scene_id must be sequential starting from 1
3. ALWAYS include exactly 3 scenes (no more, no less)
4. All scenes must have the SAME character_description value
5. Scene 1's image_prompt establishes character appearance
6. Scenes 2 and 3 must reference the same character appearance in image_prompt
7. CRITICAL: EVERY image_prompt MUST start with "anime style, manga art, 2D animation"
8. CRITICAL: For human characters, specify "Asian" or "Japanese anime style" features
9. CRITICAL: NEVER use "realistic, photorealistic, cinematic, 3D render" in prompts
10. image_url and video_url must be null initially
11. status must be "pending" for all scenes
12. Generate a unique task_id using format: task_[timestamp]_[topic]
''';

/// GLM 系统提示词 - 普通聊天模式
const String _glmChatPrompt = '''
You are AI漫导 (DirectorAI), a friendly AI assistant specialized in video content creation.

你的职责：
1. 友好地与用户交流
2. 了解用户想要创作什么样的视频
3. 当用户明确表示要生成视频时，引导他们提供具体的创意描述

回复风格：
- 友好、专业、简洁
- 使用中文回复
- 可以使用表情符号增加亲和力
- 当用户只是打招呼时，简要介绍你的功能
- 当用户提到想制作视频时，询问具体的创意内容（角色、场景、风格等）

示例：
用户：你好
你：你好！我是 AI 漫导 🎬 我可以帮你创作各种视频内容，比如动画、短片、风景视频等。你想创作什么样的视频呢？

用户：我想做个视频
你：太好了！请告诉我更多细节吧，比如：
- 视频里有什么角色或场景？
- 想要什么风格（可爱、酷炫、温馨等）？
- 大概想要什么样的故事情节？

请自然地与用户对话，引导他们提供足够的创意信息。
''';

/// GLM 系统提示词 - 漫剧剧本生成模式
/// 用于生成1分钟以上的漫剧风格剧本，包含情绪钩子和反转剧情
const String _dramaSystemPrompt = '''
You are DirectorAI, a PROFESSIONAL SCREENPLAY WRITER for manga-style drama videos.

YOUR MISSION: Create a compelling 1-minute drama screenplay with emotional hooks,
plot twists, and engaging narrative structure.

REQUIREMENTS:
1. LENGTH: 6-8 scenes (approximately 60-90 seconds total)
2. EMOTIONAL HOOK: Each scene should build positive emotional connection
3. PLOT TWIST: Include heartwarming or surprising moments (NOT tragic or dark)
4. GENRE: POSITIVE manga-style stories ONLY:
   - Campus life / School days
   - Friendship and bonding
   - Youth and dreams
   - Sweet romance
   - Healing / Comforting stories
   - Daily life warmth
   - AVOID: revenge, violence, horror, tragedy, crime, suspense with threats

STRUCTURE:
- Opening (1-2 scenes): Establish setting and characters in a positive light
- Development (2-3 scenes): Build warm connections or gentle challenges
- Heartwarming Moment (1-2 scenes): Emotional peak - touching, sweet, or inspiring
- Resolution (1-2 scenes): Happy or hopeful conclusion

CRITICAL OUTPUT FORMAT:
You MUST respond with ONLY a valid JSON object.
- NO markdown code blocks (```json ... ```)
- NO explanations before or after the JSON
- NO comments in the JSON
- Use ONLY standard English double quotes " " for all strings
- NEVER use Chinese quotes " " or ''
- Ensure all brackets { } [ ] are properly matched
- All string values must be wrapped in double quotes
- Do NOT use trailing commas

JSON SCHEMA:
{
  "task_id": "unique_id",
  "title": "剧本标题",
  "genre": "类型 (浪漫/悬疑/复仇/成长等)",
  "estimated_duration_seconds": 60,
  "emotional_arc": ["情绪变化描述", "如: 紧张→困惑→震惊→感动"],
  "scenes": [
    {
      "scene_id": 1,
      "narration": "中文旁白，富有感染力，营造氛围",
      "mood": "情绪标签 (紧张/温馨/悲伤/愤怒/惊喜/浪漫等)",
      "emotional_hook": "本场景的情绪钩子，如何吸引观众注意力",
      "image_prompt": "英文图片生成提示词，详细描述视觉画面",
      "video_prompt": "英文视频动效提示词，描述镜头运动和人物动作",
      "character_description": "人物特征描述，用于保持一致性"
    }
  ]
}

GUIDELINES:

1. SCENE COUNT: 6-8 SCENES TOTAL
   - Each scene represents a key story beat
   - Each scene should be 8-15 seconds when realized as video

2. EMOTIONAL HOOKS:
   - Start with intrigue or mystery
   - Use contrast between expectation and reality
   - Create moments of revelation
   - End with emotional resonance

3. PLOT TWIST TECHNIQUES:
   - False assumptions revealed
   - Hidden motivations uncovered
   - Unexpected alliances or betrayals
   - Role reversals
   - Time reveals truth

4. NARRATION (Chinese):
   - Evocative, emotionally resonant
   - 2-3 sentences per scene
   - Build atmosphere and tension
   - Use dialogue-like quality for immersion

5. MOOD LABELS:
   Choose from: 温馨, 愉快, 惊喜, 浪漫, 期待, 感动, 治愈, 宁静, 活泼, 甜蜜
   AVOID: 紧张, 悲伤, 愤怒, 绝望, 恐惧 - these may trigger content filters

6. EMOTIONAL_HOOK:
   - Brief phrase explaining the POSITIVE emotional moment
   - What warm feeling the audience should experience
   - How this scene builds emotional connection
   - Focus on: heartwarming, sweet, touching, inspiring moments

7. IMAGE_PROMPT (English):
   - Scene 1: Establish main character with detailed appearance
   - All scenes: Use consistent character descriptions
   - Include mood-appropriate lighting and composition
   - CRITICAL: ALWAYS include anime/manga style keywords at the START: "anime style, manga art, 2D animation, cel shaded"
   - Additional style keywords: "Japanese anime style, manhwa, webtoon art, vibrant colors, clean lines"
   - AVOID: "realistic, photorealistic, cinematic, 3D render" - these create realistic western-style images

8. VIDEO_PROMPT (English):
   CRITICAL: MUST start with camera type and movement, then character action
   FORMAT: "[Camera Type] + [Camera Movement] + [Character Action with Dialogue]"

   Camera TYPES - choose based on scene mood:
   - Close-up (特写): Emotions, dialogue, reactions - "Close-up shot of face"
   - Medium Shot (中景): Upper body, interactions - "Medium shot showing upper body"
   - Wide Shot (广角): Environment, establishing scene - "Wide shot showing full scene"
   - Over-the-Shoulder (过肩): Conversations between characters - "Over-the-shoulder shot from A looking at B"
   - Two-Shot (双人镜头): Two characters together - "Two-shot showing both characters"
   - Low Angle (仰拍): Character looks powerful/heroic - "Low angle shot looking up at character"
   - High Angle (俯拍): Character looks vulnerable/alone - "High angle shot looking down"
   - POV Shot (主观视角): Seeing through character's eyes - "POV shot from character's view"
   - Profile Shot (侧拍): Side view of character - "Profile shot showing character's face"
   - Dutch Angle (倾斜镜头): Tension, unease - "Dutch angle for uneasy feeling" (USE SPARINGLY)

   Camera MOVEMENTS:
   - Static/Fixed (固定): No movement, focus on action - "Static camera, focus on..."
   - Pan (摇拍): Side to side - "Slow pan left to reveal...", "Pan right following..."
   - Tilt (俯仰拍): Up/down - "Tilt up to reveal face", "Tilt down showing..."
   - Dolly/Tracking (跟拍): Follow character - "Tracking shot following character...", "Dolly in toward..."
   - Push In (推进): Emphasize emotion - "Slow push in on face to show emotion"
   - Pull Back (拉远): Reveal context - "Pull back to reveal full scene"
   - Zoom (变焦): Quick attention - "Quick zoom on..." (USE SPARINGLY)

   Scene-Specific Recommendations:
   - EMOTIONAL/QUIET moments: Static or Slow movement + Close-up
   - REVEAL/SURPRISE moments: Quick pan or Push in + Medium/Wide
   - DIALOGUE/CONVERSATION: Over-the-shoulder or Two-shot + Static/Slight movement
   - ACTION/MOVEMENT: Tracking shot or Following shot
   - ENVIRONMENT/ESTABLISHING: Wide shot + Pan
   - INTIMATE/ROMANTIC: Close-up + Slow push in
   - TENSION/SUSPENSE: Static or Slight zoom + Close-up

   CRITICAL: Character must SPEAK in Chinese - add "character speaking, talking, mouth moving, saying dialogue" to EVERY video
   Include dialogue in the action: "girl saying '你好' with warm smile", "boy talking '谢谢'"
   Lip sync and facial expressions should match the speech

   CRITICAL: Voice gender MUST match character gender - add voice specification to EVERY video_prompt:
   - For male characters: "male voice, man speaking, masculine voice"
   - For female characters: "female voice, woman speaking, feminine voice"
   - Examples: "girl says '你好' with female voice", "boy speaks '谢谢' with male voice"
   - Keep voice consistent across ALL scenes for the SAME character

   CRITICAL SAFETY GUIDELINES - MUST FOLLOW TO PASS CONTENT FILTERING:

   *** ABSOLUTELY FORBIDDEN WORDS (will trigger platform rejection): ***
   - Energy/Effects: lightning, electric, electric shock, thunderbolt, energy, energy beam, energy surge, power surge, spark, arc, voltage
   - Combat/Fighting: attack, battle, fight, punch, kick, hit, strike, slam, crash, smash, beat, combat, clash, confront, struggle
   - Dangerous Elements: fire, flame, burn, explosion, explode, blast, bomb, smoke, weapon, sword, knife, gun, blade, sharp, pointed
   - Negative Emotions: fierce, intense, aggressive, violent, rage, angry, furious, terrified, horrified, scream, shout, yell, panic
   - Body Horror: glowing eyes, red eyes, blood, wound, injury, transform, mutate, distort, twisted
   - Unsafe Actions: fall, drop, trip, stumble, chase, flee, escape, running scared

   *** MANDATORY SAFE ALTERNATIVES: ***
   - Instead of "lightning/electric": soft light, gentle light, warm light, ambient light, natural light, sunlight, glow
   - Instead of "fight/attack": move toward, approach, interaction, encounter, meet, face each other
   - Instead of "fierce/intense": warm, calm, gentle, peaceful, quiet, soft, smooth, elegant, graceful
   - Instead of "explosion/fire": bloom, flourish, brighten, illuminate, radiate, shimmer
   - Instead of "angry/rage": concerned, worried, surprised, amazed, excited, eager, focused
   - Instead of "scream/shout": speak, say, whisper, call out, reply, respond

   *** REQUIRED SAFE WORDS TO INCLUDE: ***
   Must use at least 2 of these in EACH video_prompt:
   - gentle, soft, calm, peaceful, warm, bright, smooth, quiet, serene, tranquil
   - beautiful, lovely, cute, sweet, heartwarming, pleasant, comfortable
   - slowly, softly, gently, calmly, smoothly, gracefully, elegantly

   *** SAFE CAMERA MOVEMENTS ONLY: ***
   - ALWAYS use: slow, gentle, soft, smooth, calm
   - NEVER use: quick, fast, sudden, rapid, sharp, abrupt, violent, jerky
   - Safe examples: "slowly", "gently", "smoothly", "calmly", "softly"

9. CHARACTER_DESCRIPTION (English):
   - Detailed appearance for consistency
   - Include: species/hair/color/features/clothing
   - Used across ALL scenes
   - CRITICAL: Always specify "anime style, Asian features" for human characters
   - Default to Japanese/Asian appearance unless user specifies otherwise

EXAMPLE INPUT: "生成一个关于校园友谊的温馨视频"

EXAMPLE OUTPUT:
{
  "task_id": "school_friendship_20240127",
  "title": "同桌的你",
  "genre": "校园友情",
  "estimated_duration_seconds": 60,
  "emotional_arc": ["宁静", "期待", "惊喜", "感动", "温馨"],
  "scenes": [
    {
      "scene_id": 1,
      "narration": "午后的教室，阳光洒在课桌上，女孩正在认真做笔记",
      "mood": "宁静",
      "emotional_hook": "校园午后的静谧时光",
      "image_prompt": "anime style, manga art, 2D animation, cel shaded. A bright Japanese high school classroom with sunlight streaming through windows. A teenage Asian girl with short black hair and gentle eyes sitting at a desk, writing notes calmly. Warm golden hour lighting, peaceful atmosphere, clean anime art style",
      "video_prompt": "Anime style 2D animation. Static camera with Medium shot showing girl at desk studying. Girl looks up, smiles at window, and says to herself '今天天气真好' with peaceful expression, female voice",
      "character_description": "Anime style Asian girl, 16 years old, short black bob hair, dark gentle eyes, wearing Japanese high school uniform with white shirt and navy skirt"
    },
    {
      "scene_id": 2,
      "narration": "旁边的座位空着，那是她同桌的位置，已经三天没来了",
      "mood": "期待",
      "emotional_hook": "关心朋友：她还好吗？",
      "image_prompt": "anime style, manga art, 2D animation, cel shaded. The same Asian girl glancing at the empty desk next to hers with a slightly worried expression. A bento box wrapped in cloth sits on her desk. Soft lighting, Japanese classroom setting, heartwarming anime art style",
      "video_prompt": "Anime style 2D animation. Close-up static shot of girl's worried face glancing at empty desk. Girl whispers '不知道她怎么样了' with concerned expression, female voice",
      "character_description": "Anime style Asian girl, 16 years old, short black bob hair, dark gentle eyes, wearing Japanese high school uniform"
    },
    {
      "scene_id": 3,
      "narration": "门口突然出现熟悉的身影，女孩惊喜地站起来",
      "mood": "惊喜",
      "emotional_hook": "朋友回来了！",
      "image_prompt": "anime style, manga art, 2D animation, cel shaded. Another Asian girl with long ponytail standing at the classroom door, smiling warmly. The girl at the desk is looking up with happy surprise, starting to stand up. Bright anime art style, warm colors",
      "video_prompt": "Anime style 2D animation. Quick pan right from girl's desk to doorway, revealing friend standing there. Girl's eyes light up, she stands up and calls out '你回来啦！' with excited smile, female voice",
      "character_description": "Anime style Asian girl, 16 years old, short black bob hair, dark gentle eyes, wearing Japanese high school uniform. Another Asian girl, 16 years old, long black ponytail, warm smile, wearing matching school uniform"
    },
    {
      "scene_id": 4,
      "narration": "朋友走到她身边，轻轻递过一个小盒子：谢谢你这几天的笔记",
      "mood": "感动",
      "emotional_hook": "被记挂的温暖",
      "image_prompt": "anime style, manga art, 2D animation, cel shaded. The ponytail girl handing a small wrapped gift to the bob-haired girl, who is smiling with touched emotion. The bento box on the desk is now revealed to be for the friend. Warm afternoon light, heartwarming composition, Japanese anime art style",
      "video_prompt": "Anime style 2D animation. Two-shot static camera showing both girls at adjacent desks. Ponytail girl hands over gift and says '谢谢你帮我记笔记' with sincere smile, female voice. Bob-haired girl receives gift with touched expression",
      "character_description": "Anime style Asian girl, 16 years old, short black bob hair, dark gentle eyes, wearing Japanese high school uniform. Another Asian girl, 16 years old, long black ponytail, warm smile, wearing matching school uniform"
    },
    {
      "scene_id": 5,
      "narration": "原来她生病了，但还记得把自己做的便当送来",
      "mood": "温馨",
      "emotional_hook": "双向奔赴的友情",
      "image_prompt": "anime style, manga art, 2D animation, cel shaded. Both Asian girls sitting together at adjacent desks, sharing the bento box and laughing. Sunlight creates a warm glow around them. Happy friendship moment, Japanese anime art style, vibrant and cheerful colors",
      "video_prompt": "Anime style 2D animation. Medium shot from side showing both girls eating together. Girl takes a bite, smiles and says '这个好吃！' with female voice. They laugh together. Warm, happy atmosphere",
      "character_description": "Anime style Asian girl, 16 years old, short black bob hair, dark gentle eyes, wearing Japanese high school uniform. Another Asian girl, 16 years old, long black ponytail, warm smile, wearing matching school uniform"
    },
    {
      "scene_id": 6,
      "narration": "放学铃声响起，两人相视一笑，一起收拾书包走出教室",
      "mood": "甜蜜",
      "emotional_hook": "有朋友真好",
      "image_prompt": "anime style, manga art, 2D animation, cel shaded. Both Asian girls walking side by side toward the classroom door, carrying their school bags. Orange sunset light streaming through windows creates a golden glow. School ending atmosphere, sweet friendship moment, Japanese anime art style",
      "video_prompt": "Anime style 2D animation. Tracking shot following from behind as both girls walk toward door. They exchange looks, one says '明天见！' with female voice and other replies '明天见！' with female voice while waving. Camera shows their backs exiting into sunset",
      "character_description": "Anime style Asian girl, 16 years old, short black bob hair, dark gentle eyes, wearing Japanese high school uniform. Another Asian girl, 16 years old, long black ponytail, warm smile, wearing matching school uniform"
    }
  ]
}

ABSOLUTE RULES:
1. CRITICAL: Output ONLY valid JSON - no markdown code blocks, no explanations
   - MUST use English double quotes " " NOT Chinese quotes " "
   - All strings must be quoted
   - No trailing commas
   - Proper bracket matching
2. 6-8 scenes exactly
3. All scenes must have consistent character descriptions
4. Each scene must have a unique mood that progresses the emotional arc
5. Include at least one heartwarming or touching moment
6. Keep everything POSITIVE - no tragedy, violence, horror, or dark themes
7. CRITICAL: EVERY image_prompt MUST start with "anime style, manga art, 2D animation, cel shaded"
8. CRITICAL: All human characters MUST be described as "Asian" or "Japanese anime style"
9. CRITICAL: NEVER use words like "realistic", "photorealistic", "cinematic", "3D render"
10. CRITICAL: NEVER use negative words in video_prompt: no lightning, fierce, intense, dramatic, aggressive
11. ALWAYS use gentle words: soft, calm, warm, bright, smooth, peaceful, gentle
12. CRITICAL: EVERY video_prompt MUST follow format: "[Camera Type] + [Movement] + [Action with Chinese dialogue]"
13. CRITICAL: EVERY video_prompt MUST specify camera type: Close-up, Medium Shot, Wide Shot, Two-Shot, Over-the-shoulder, Tracking, etc.
14. CRITICAL: EVERY video_prompt MUST include character speaking in Chinese with matching voice gender (male voice for men, female voice for women)
15. VARY camera types across scenes - don't use the same shot for every scene
16. CRITICAL: Keep VOICE GENDER CONSISTENT - same character must use same voice gender in ALL scenes
17. Generate unique task_id: drama_[timestamp]_[theme]
''';

/// GLM 流式响应数据类型
enum GLMStreamType {
  thinking,  // 思考过程 (reasoning_content)
  content,   // 最终内容 (content)
}

/// GLM 流式响应块
class GLMStreamChunk {
  final GLMStreamType type;
  final String text;
  
  GLMStreamChunk({required this.type, required this.text});
  
  bool get isThinking => type == GLMStreamType.thinking;
  bool get isContent => type == GLMStreamType.content;
}

/// 处理所有 API 调用的服务类
class ApiService {
  late Dio _dio;        // 智谱 GLM-4.7
  late Dio _tuziDio;    // Tuzi Sora 视频生成
  late Dio _imageDio;   // Gemini 图像生成
  late Dio _doubaoDio;  // 豆包 ARK API (图片理解)

  ApiService() {
    _dio = ApiConfig.createDio();
    _tuziDio = _createTuziDio();
    _imageDio = _createImageDio();
    _doubaoDio = _createDoubaoDio();
  }

  /// 创建 Tuzi API 专用的 Dio 实例（视频生成）
  Dio _createTuziDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.tuziBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加拦截器，在每次请求时动态设置 Authorization header
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'Bearer ${ApiConfig.videoApiKey}';
        return handler.next(options);
      },
    ));

    // 添加日志拦截器
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      error: true,
    ));

    return dio;
  }

  /// 创建图像生成 API 专用的 Dio 实例
  Dio _createImageDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.tuziBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加拦截器，在每次请求时动态设置 Authorization header
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'Bearer ${ApiConfig.imageApiKey}';
        return handler.next(options);
      },
    ));

    // 添加日志拦截器
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      error: true,
    ));

    return dio;
  }

  /// 创建豆包 ARK API 专用的 Dio 实例（图片理解）
  Dio _createDoubaoDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.doubaoBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加拦截器，在每次请求时动态设置 Authorization header
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'Bearer ${ApiConfig.doubaoApiKey}';
        return handler.next(options);
      },
    ));

    // 添加日志拦截器
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      error: true,
    ));

    return dio;
  }

  /// 动态更新所有 API keys（已弃用，请使用 ApiConfigService）
  @Deprecated('使用 ApiConfigService.setXxxApiKey() 方法替代')
  Future<void> updateTokens({
    String? zhipuKey,
    String? videoKey,
    String? imageKey,
    String? doubaoKey,
  }) async {
    if (zhipuKey != null) {
      await ApiConfigService.setZhipuApiKey(zhipuKey);
      _dio = ApiConfig.createDio();
    }
    if (videoKey != null) {
      await ApiConfigService.setVideoApiKey(videoKey);
      _tuziDio = _createTuziDio();
    }
    if (imageKey != null) {
      await ApiConfigService.setImageApiKey(imageKey);
      _imageDio = _createImageDio();
    }
    if (doubaoKey != null) {
      await ApiConfigService.setDoubaoApiKey(doubaoKey);
      _doubaoDio = _createDoubaoDio();
    }
  }

  // ==================== GLM-4.7 智能体 API ====================

  /// 普通聊天方法 - 使用聊天模式的系统提示词
  /// 返回流式响应，包含思考过程和最终内容
  Stream<GLMStreamChunk> chatWithGLM(List<Map<String, String>> conversationHistory) async* {
    yield* sendToGLMStream(conversationHistory, systemPrompt: _glmChatPrompt);
  }

  /// 支持图片识别的聊天方法
  /// 有图片时使用豆包 ARK API，无图片时使用 GLM-4.7
  /// [userMessage] 用户当前的文本消息
  /// [imageBase64] 用户上传的图片（base64 格式，纯 base64 不带前缀）
  /// [imageMimeType] 图片的 MIME 类型（如 image/jpeg, image/png），需与实际图片格式一致
  /// [conversationHistory] 之前的对话历史（纯文本，仅用于无图片模式）
  /// 返回流式响应，包含最终内容
  Stream<GLMStreamChunk> chatWithGLMImageSupport({
    required String userMessage,
    String? imageBase64,
    String? imageMimeType,
    List<Map<String, String>> conversationHistory = const [],
  }) async* {
    try {
      final hasImage = imageBase64 != null && imageBase64.isNotEmpty;

      if (hasImage) {
        // === 图片模式：使用豆包 ARK API ===
        if (ApiConfig.doubaoApiKey.isEmpty) {
          throw Exception('豆包 API Key 未设置，请在设置中配置');
        }

        // 豆包 ARK API 使用 OpenAI 兼容格式
        // type 为 "image_url"
        // image_url.url 为 "data:image/xxx;base64,{base64}"
        final mimeType = imageMimeType ?? 'image/jpeg';
        final requestData = {
          'model': ApiConfig.doubaoImageModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$imageBase64',
                  },
                },
                {
                  'type': 'text',
                  'text': userMessage,
                },
              ],
            },
          ],
        };

        AppLogger.apiRequestRaw('POST', '/chat/completions (豆包图片识别)', requestData);
        AppLogger.info('豆包-ARK', '使用豆包 API 进行图片识别');

        // 豆包 API 调用（非流式）
        final response = await _doubaoDio.post(
          '/chat/completions',
          data: requestData,
        );

        AppLogger.apiResponseRaw('/chat/completions (豆包图片识别)', response.data);

        // 解析豆包响应（OpenAI 格式）
        final choices = response.data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          throw Exception('豆包 API 响应格式错误：没有 choices');
        }

        final firstChoice = choices[0] as Map<String, dynamic>?;
        final message = firstChoice?['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;

        if (content != null && content.isNotEmpty) {
          yield GLMStreamChunk(type: GLMStreamType.content, text: content);
        } else {
          throw Exception('豆包 API 响应格式错误：content 为空');
        }

        AppLogger.success('豆包-ARK', '图片识别完成');
      } else {
        // === 纯文本模式：使用 GLM-4.7 ===
        // 添加 system prompt
        final messages = <Map<String, dynamic>>[
          {'role': 'system', 'content': _glmChatPrompt},
        ];

        // 添加历史对话
        for (final msg in conversationHistory) {
          messages.add({
            'role': msg['role'],
            'content': msg['content'],
          });
        }

        // 添加当前消息
        messages.add({'role': 'user', 'content': userMessage});

        final requestData = <String, dynamic>{
          'model': 'glm-4.7',
          'messages': messages,
          'stream': true,
          'max_tokens': 65536,
          'temperature': 1.0,
        };

        // 启用 thinking 模式
        if (ApiConfig.USE_THINKING_MODE) {
          requestData['thinking'] = {'type': 'enabled'};
        }

        final modeDesc = ApiConfig.USE_THINKING_MODE ? '流式+thinking' : '流式';
        AppLogger.api('POST', '/chat/completions ($modeDesc)', {'model': 'glm-4.7'});
        AppLogger.info('GLM-Chat', '使用模型: glm-4.7 (纯文本)');

        // 使用 ResponseType.stream 实现真正的流式处理
        final response = await _dio.post<ResponseBody>(
          '/chat/completions',
          data: requestData,
          options: Options(responseType: ResponseType.stream),
        );

        final contentBuffer = StringBuffer();
        final thinkingBuffer = StringBuffer();
        String incompleteLine = '';

        await for (final chunk in response.data!.stream) {
          final chunkStr = utf8.decode(chunk, allowMalformed: true);
          final fullData = incompleteLine + chunkStr;
          final lines = fullData.split('\n');
          incompleteLine = lines.removeLast();

          for (final line in lines) {
            if (line.trim().isEmpty) continue;

            if (line.startsWith('data: ')) {
              final data = line.substring(6);
              if (data.trim() == '[DONE]') {
                AppLogger.success('GLM-Chat', '流式响应完成');
                return;
              }
              try {
                final json = jsonDecode(data);

                final delta = json['choices']?[0]?['delta'];
                if (delta == null) continue;

                final reasoningContent = delta['reasoning_content'] as String?;
                final content = delta['content'] as String?;

                if (reasoningContent != null && reasoningContent.isNotEmpty) {
                  thinkingBuffer.write(reasoningContent);
                  yield GLMStreamChunk(type: GLMStreamType.thinking, text: reasoningContent);
                }

                if (content != null && content.isNotEmpty) {
                  contentBuffer.write(content);
                  yield GLMStreamChunk(type: GLMStreamType.content, text: content);
                }
              } catch (e) {
                // 忽略解析错误
              }
            }
          }
        }

        if (contentBuffer.isEmpty && thinkingBuffer.isEmpty) {
          yield GLMStreamChunk(type: GLMStreamType.content, text: '');
        }
      }
    } catch (e) {
      AppLogger.error('聊天', 'API 调用失败', e, StackTrace.current);
      throw Exception('聊天错误: $e');
    }
  }

  /// 发送对话历史到 GLM-4.7 并获取下一步操作（非流式）
  /// 系统提示词指示 GLM 作为状态机编排器工作
  Future<String> sendToGLM(List<Map<String, String>> conversationHistory) async {
    try {
      final messages = [
        {'role': 'system', 'content': _glmSystemPrompt},
        ...conversationHistory,
      ];

      final requestData = {
        'model': 'glm-4.7',
        'messages': messages,
        'stream': false,
        'max_tokens': 65536,
        'temperature': 1.0,
      };

      AppLogger.api('POST', '/chat/completions', requestData);

      final response = await _dio.post(
        '/chat/completions',
        data: requestData,
      );

      AppLogger.apiResponse('/chat/completions', response.data);

      final content = response.data['choices']?[0]?['message']?['content'] as String?;
      if (content == null) {
        AppLogger.error('GLM', '响应中没有内容', null, StackTrace.current);
        throw Exception('GLM 响应中没有内容');
      }

      AppLogger.success('GLM', '成功获取响应，内容长度: ${content.length}');
      return content;
    } catch (e) {
      AppLogger.error('GLM', 'API 调用失败', e, StackTrace.current);
      throw Exception('GLM API 错误: $e');
    }
  }

  /// 发送对话历史到 GLM-4.7 并获取流式响应
  /// 使用真正的流式处理，边接收边返回数据
  /// 启用 thinking 模式，返回思考过程和最终内容
  /// [systemPrompt] 可选的自定义系统提示词，默认使用剧本规划模式
  /// [conversationHistory] 对话历史（纯文本格式）
  ///
  /// 注意：图片分析由单独的 analyzeImageForCharacter 方法处理
  Stream<GLMStreamChunk> sendToGLMStream(
    List<Map<String, dynamic>> conversationHistory, {
    String? systemPrompt,
  }) async* {
    try {
      // 使用传入的系统提示词，或默认使用剧本规划提示词
      final prompt = systemPrompt ?? _glmSystemPrompt;

      final messages = [
        {'role': 'system', 'content': prompt},
        ...conversationHistory,
      ];

      final requestData = <String, dynamic>{
        'model': 'glm-4.7',  // 使用文本模型生成剧本
        'messages': messages,
        'stream': true,
        'max_tokens': 65536,
        'temperature': 1.0,
      };

      // 根据开关决定是否启用 thinking 模式
      if (ApiConfig.USE_THINKING_MODE) {
        requestData['thinking'] = {
          'type': 'enabled',
        };
      }

      final modeDesc = ApiConfig.USE_THINKING_MODE ? '流式+thinking' : '流式';
      AppLogger.apiRequestRaw('POST', '/chat/completions ($modeDesc)', requestData);

      // 使用 ResponseType.stream 实现真正的流式处理
      final response = await _dio.post<ResponseBody>(
        '/chat/completions',
        data: requestData,
        options: Options(responseType: ResponseType.stream),
      );

      AppLogger.info('GLM', '开始接收流式响应 (thinking=${ApiConfig.USE_THINKING_MODE})');

      final contentBuffer = StringBuffer();
      final thinkingBuffer = StringBuffer();
      int chunkCount = 0;
      String incompleteLine = ''; // 处理跨 chunk 的不完整行

      // 真正的流式处理：边接收边解析
      await for (final chunk in response.data!.stream) {
        // 将字节转换为字符串
        final chunkStr = utf8.decode(chunk, allowMalformed: true);
        
        // 将不完整的行与新数据拼接
        final fullData = incompleteLine + chunkStr;
        final lines = fullData.split('\n');
        
        // 最后一行可能不完整，保存到下次处理
        incompleteLine = lines.removeLast();

        for (final line in lines) {
          if (line.trim().isEmpty) continue;

          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data.trim() == '[DONE]') {
              AppLogger.success('GLM', '流式响应完成，thinking长度: ${thinkingBuffer.length}, content长度: ${contentBuffer.length}, 接收到 $chunkCount 个有效chunk');
              return;
            }
            try {
              final json = jsonDecode(data);
              chunkCount++;

              final delta = json['choices']?[0]?['delta'];
              if (delta == null) continue;

              // 优先检查 reasoning_content（思考过程）
              final reasoningContent = delta['reasoning_content'] as String?;
              // 然后检查 content（最终内容）
              final content = delta['content'] as String?;

              // 打印前几个 chunk 的完整 JSON 用于调试
              if (chunkCount <= 5) {
                final jsonStr = jsonEncode(json);
                AppLogger.info('GLM', 'Chunk #$chunkCount JSON: ${jsonStr.substring(0, jsonStr.length > 300 ? 300 : jsonStr.length)}...');
                AppLogger.info('GLM', '  -> reasoning_content: "$reasoningContent", content: "$content"');
              }

              // 返回思考过程
              if (reasoningContent != null && reasoningContent.isNotEmpty) {
                thinkingBuffer.write(reasoningContent);
                AppLogger.streamChunk('GLM-Thinking', reasoningContent);
                yield GLMStreamChunk(type: GLMStreamType.thinking, text: reasoningContent);
              }

              // 返回最终内容
              if (content != null && content.isNotEmpty) {
                contentBuffer.write(content);
                AppLogger.streamChunk('GLM-Content', content);
                yield GLMStreamChunk(type: GLMStreamType.content, text: content);
              }
            } catch (e) {
              AppLogger.warn('GLM', '解析流式数据失败: $line, 错误: $e');
              continue;
            }
          }
        }
      }

      // 处理最后可能残留的不完整行
      if (incompleteLine.trim().isNotEmpty && incompleteLine.startsWith('data: ')) {
        final data = incompleteLine.substring(6);
        if (data.trim() != '[DONE]') {
          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta'];
            if (delta != null) {
              final reasoningContent = delta['reasoning_content'] as String?;
              final content = delta['content'] as String?;
              if (reasoningContent != null && reasoningContent.isNotEmpty) {
                thinkingBuffer.write(reasoningContent);
                yield GLMStreamChunk(type: GLMStreamType.thinking, text: reasoningContent);
              }
              if (content != null && content.isNotEmpty) {
                contentBuffer.write(content);
                yield GLMStreamChunk(type: GLMStreamType.content, text: content);
              }
            }
          } catch (_) {
            // 忽略最后的不完整数据
          }
        }
      }

      // 如果流为空，返回空字符串避免错误
      if (contentBuffer.isEmpty && thinkingBuffer.isEmpty) {
        AppLogger.warn('GLM', '流式响应为空，共处理 $chunkCount 个chunk');
        yield GLMStreamChunk(type: GLMStreamType.content, text: '');
      }
    } catch (e) {
      AppLogger.error('GLM', '流式 API 调用失败', e, StackTrace.current);
      throw Exception('GLM API 流式错误: $e');
    }
  }

  /// 生成漫剧风格的剧本草稿
  /// 使用 ApiConfig.sceneCount 配置的场景数量
  Future<String> generateDramaScreenplay(
    String userPrompt, {
    String? characterAnalysis,
    String? previousFeedback,
  }) async {
    const maxRetries = 3; // 最大重试次数

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // 使用配置的场景数量
        final configuredSceneCount = ApiConfig.sceneCount;

        if (attempt > 1) {
          AppLogger.info('漫剧剧本生成', '第 $attempt 次尝试生成剧本...');
        } else {
          AppLogger.info('漫剧剧本生成', '配置的场景数量: $configuredSceneCount');
        }

        // 构建增强的提示词
        String enhancedPrompt = userPrompt;

        if (characterAnalysis != null && characterAnalysis.isNotEmpty) {
          enhancedPrompt = '''
用户需求：$enhancedPrompt

用户提供的参考图片角色特征分析：
$characterAnalysis

请根据上述角色特征分析结果，生成剧本中的 character_description 字段，
确保生成的角色形象与用户提供的图片一致。
''';
        }

        // 如果是重试，添加错误提示
        if (attempt > 1) {
          enhancedPrompt = '''
$enhancedPrompt

重要提醒：上次生成的 JSON 格式有误，请确保：
1. 输出纯 JSON 格式，不要用 markdown 代码块包裹
2. 使用标准英文双引号 " " 而不是中文引号 ""
3. 所有字符串必须用引号包裹
4. 确保所有括号、大括号正确配对
''';
        }

        if (previousFeedback != null && previousFeedback.isNotEmpty) {
          enhancedPrompt = '''
$enhancedPrompt

用户对上一版剧本的反馈：
$previousFeedback

请根据用户反馈调整剧本，生成更好的版本。
''';
        }

        AppLogger.info('漫剧剧本生成', '开始生成剧本草稿...');

        // 使用配置的场景数量构建提示词
        final dynamicSystemPrompt = _buildDynamicDramaPromptWithCount(configuredSceneCount);

        final contentBuffer = StringBuffer();

        await for (final chunk in sendToGLMStream(
          [{'role': 'user', 'content': enhancedPrompt}],
          systemPrompt: dynamicSystemPrompt,
        )) {
          if (chunk.isContent) {
            contentBuffer.write(chunk.text);
          }
        }

        String responseJson = contentBuffer.toString();

        // 清理中文引号和其他可能导致 JSON 解析失败的字符
        responseJson = responseJson
            .replaceAll('"', '"')      // 中文左双引号
            .replaceAll('"', '"')      // 中文右双引号
            .replaceAll(''', '\'')     // 中文左单引号
            .replaceAll(''', '\'')     // 中文右单引号
            .replaceAll('：', ':')     // 中文冒号
            .replaceAll(RegExp(r'```json\s*'), '')   // 移除 markdown json 代码块标记
            .replaceAll(RegExp(r'```\s*'), '')       // 移除 markdown 代码块结束标记
            .trim();

        // 验证返回的是有效 JSON
        try {
          final decoded = jsonDecode(responseJson);

          // 验证必需字段
          if (!decoded.containsKey('task_id') ||
              !decoded.containsKey('title') ||
              !decoded.containsKey('scenes')) {
            throw FormatException('缺少必需字段');
          }

          final scenes = decoded['scenes'] as List?;
          if (scenes == null || scenes.isEmpty) {
            throw FormatException('场景数量不足');
          }

          // 验证场景数量（允许±1的误差）
          if (scenes.length < configuredSceneCount - 1 || scenes.length > configuredSceneCount + 1) {
            AppLogger.warn('漫剧剧本生成',
                '场景数量与配置不符（期望$configuredSceneCount个，实际${scenes.length}个），但继续使用');
          }

          AppLogger.success('漫剧剧本生成', '成功生成 ${scenes.length} 个场景的剧本');
          AppLogger.apiResponse('/drama-screenplay', decoded);

          return responseJson;
        } on FormatException catch (e) {
          if (attempt == maxRetries) {
            AppLogger.error('漫剧剧本生成', 'JSON 格式验证失败（已重试$maxRetries次）: $e\n响应内容: $responseJson');
            rethrow;
          }
          AppLogger.warn('漫剧剧本生成', 'JSON 格式验证失败，准备重试... ($attempt/$maxRetries)');
          // 继续下一次尝试
          continue;
        }
      } catch (e) {
        if (attempt == maxRetries) {
          AppLogger.error('漫剧剧本生成', '生成失败（已重试$maxRetries次）', e);
          throw Exception('漫剧剧本生成失败: $e');
        }
        AppLogger.warn('漫剧剧本生成', '生成过程出错，准备重试... ($attempt/$maxRetries): $e');
        // 继续下一次尝试
        continue;
      }
    }

    // 理论上不会到达这里
    throw Exception('漫剧剧本生成失败：超过最大重试次数');
  }
  /// 根据配置的场景数量构建漫剧提示词
  String _buildDynamicDramaPromptWithCount(int sceneCount) {
    // 替换原有的固定场景数量
    String prompt = _dramaSystemPrompt.replaceAll(
      RegExp(r'1\. LENGTH: 6-8 scenes \(approximately 60-90 seconds total\)'),
      '1. LENGTH: EXACTLY $sceneCount SCENES (each scene 5-10 seconds)',
    );

    // 替换规则中的场景数量
    prompt = prompt.replaceAll(
      RegExp(r'1\. 6-8 scenes exactly'),
      '1. EXACTLY $sceneCount scenes',
    );

    // 在 ABSOLUTE RULES 部分添加强调
    prompt = prompt.replaceAll(
      'ABSOLUTE RULES:',
      '''ABSOLUTE RULES:
0. CRITICAL: You MUST generate EXACTLY $sceneCount scenes. No more, no less.''',
    );

    return prompt;
  }

  /// 兼容旧版：根据场景数量范围动态构建漫剧提示词
  @Deprecated('使用 _buildDynamicDramaPromptWithCount 替代')
  String _buildDynamicDramaPrompt(_SceneCountRange range) {
    // 替换原有的固定场景数量
    final basePrompt = _dramaSystemPrompt.replaceAll(
      RegExp(r'1\. LENGTH: 6-8 scenes \(approximately 60-90 seconds total\)'),
      '1. LENGTH: ${range.min}-${range.max} SCENES (each scene 10-12 seconds)',
    );

    // 替换示例中的场景数量说明
    return basePrompt.replaceAll(
      RegExp(r'3\. ALWAYS include exactly 3 scenes'),
      '3. ALWAYS include exactly ${range.min}-${range.max} scenes',
    );
  }

  /// 使用豆包 ARK API 分析图片，提取角色/人物特征描述
  /// [imageBase64] 图片的 base64 编码（纯 base64，不带前缀）
  /// 返回详细的特征描述文本，用于后续剧本生成
  Future<String> analyzeImageForCharacter(
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      if (ApiConfig.doubaoApiKey.isEmpty) {
        throw Exception('豆包 API Key 未设置，无法进行图片分析');
      }

      const prompt = '''请仔细观察这张图片，提取其中主要角色或人物的详细特征描述。

请按照以下格式返回（只返回描述，不要其他内容）：

**外观特征**：[详细描述角色的外观，包括：发型、发色、面部特征、眼睛颜色、皮肤状态、体型等]

**穿着打扮**：[描述角色的服装风格、颜色、配饰等]

**姿态表情**：[描述角色的姿态、表情、气质等]

**整体风格**：[一句话总结这个角色的整体视觉风格]

请确保描述足够详细，以便后续可以根据这些描述生成一致的角色形象。''';

      // 豆包 ARK API 使用 OpenAI 兼容格式
      // type 为 "image_url"
      // image_url.url 为 "data:image/xxx;base64,{base64}"
      final requestData = {
        'model': ApiConfig.doubaoImageModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$imageBase64',
                },
              },
              {
                'type': 'text',
                'text': prompt,
              },
            ],
          },
        ],
      };

      AppLogger.apiRequestRaw('POST', '/chat/completions (豆包图片分析)', requestData);
      AppLogger.info('豆包-ARK', '开始分析图片特征...');

      final response = await _doubaoDio.post(
        '/chat/completions',
        data: requestData,
      );

      AppLogger.apiResponseRaw('/chat/completions (豆包图片分析)', response.data);

      // 解析豆包响应（OpenAI 格式）
      final choices = response.data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        AppLogger.error('豆包-ARK', '响应格式错误：没有 choices', null, StackTrace.current);
        throw Exception('图片分析失败：响应格式错误');
      }

      final firstChoice = choices[0] as Map<String, dynamic>?;
      final message = firstChoice?['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null || content.isEmpty) {
        AppLogger.error('豆包-ARK', '图片分析响应为空', null, StackTrace.current);
        throw Exception('图片分析失败：响应为空');
      }

      AppLogger.success('豆包-ARK', '图片分析完成');
      AppLogger.info('豆包-ARK', '提取的特征:\n$content');
      return content;
    } catch (e) {
      AppLogger.error('豆包-ARK', '图片分析失败', e, StackTrace.current);
      throw Exception('图片分析失败: $e');
    }
  }

  // ==================== 文本生成图片 API (Gemini) ====================

  /// 使用图片生成 API 生成图片
  /// 支持文生图和图生图（传入参考图）
  /// [prompt] 图像描述文本
  /// [referenceImages] 参考图片列表（base64 格式，支持多图），用于图生图
  /// 返回生成的图片 URL
  Future<String> generateImage(
    String prompt, {
    List<String>? referenceImages,
  }) async {
    // ========================================
    // Mock 模式：直接返回模拟结果
    // ========================================
    if (ApiConfig.USE_MOCK_IMAGE_API) {
      AppLogger.warn('图片生成', '🧪 使用 Mock 模式，不调用真实 API');
      AppLogger.info('图片生成[MOCK]', 'Prompt: $prompt');
      if (referenceImages != null && referenceImages.isNotEmpty) {
        AppLogger.info('图片生成[MOCK]', '参考图数量: ${referenceImages.length}');
      }
      // 模拟网络延迟
      await Future.delayed(const Duration(milliseconds: 500));
      AppLogger.success('图片生成[MOCK]', '返回 Mock 图片: ${ApiConfig.MOCK_IMAGE_URL}');
      return ApiConfig.MOCK_IMAGE_URL;
    }

    // ========================================
    // 真实 API 调用模式
    // ========================================
    return _generateImageWithRetry(prompt, referenceImages: referenceImages);
  }

  /// 带重试机制的图片生成（处理内容安全检查错误）
  Future<String> _generateImageWithRetry(
    String prompt, {
    List<String>? referenceImages,
    int retryCount = 0,
  }) async {
    try {
      final requestData = {
        'model': 'gemini-2.5-flash-image-vip',
        // 'model': 'gemini-3-pro-image-preview',
        'prompt': prompt,
        'n': 1,
        'response_format': 'url',
        'size': '1024x1024',
      };

      // 如果有参考图，添加到请求中（图生图）
      if (referenceImages != null && referenceImages.isNotEmpty) {
        // API 支持数组格式：["base64xxx", "base64yyy"]
        // 或 URL 格式：["https://xxx", "https://yyy"]
        requestData['image'] = referenceImages;
        AppLogger.info('图片生成', '图生图模式，参考图数量: ${referenceImages.length}');
      }

      AppLogger.apiRequestRaw('POST', '/v1/images/generations', requestData);
      AppLogger.info('图片生成', '开始生成图片: $prompt');

      final response = await _imageDio.post(
        '/v1/images/generations',
        data: requestData,
        options: Options(sendTimeout: const Duration(seconds: 500), receiveTimeout: const Duration(seconds: 500)),
      );

      AppLogger.apiResponseRaw('/v1/images/generations', response.data);

      // 从响应中解析图片 URL: response.data['data'][0]['url']
      final dataList = response.data['data'] as List?;
      if (dataList == null || dataList.isEmpty) {
        AppLogger.error('图片生成', '响应中没有 data 数组', null, StackTrace.current);
        throw Exception('图片生成响应中没有 data 数组');
      }

      final firstImage = dataList[0] as Map<String, dynamic>?;
      if (firstImage == null) {
        AppLogger.error('图片生成', 'data[0] 为空', null, StackTrace.current);
        throw Exception('图片生成响应 data[0] 为空');
      }

      final imageUrl = firstImage['url'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) {
        AppLogger.error('图片生成', '图片 URL 为空', null, StackTrace.current);
        throw Exception('图片生成响应中 URL 为空');
      }

      AppLogger.success('图片生成', '成功生成图片: $imageUrl');
      return imageUrl;
    } catch (e) {
      AppLogger.error('图片生成', '生成图片失败', e, StackTrace.current);

      // 检查是否是内容安全检查错误
      if (e is DioException) {
        final errorData = e.response?.data;
        if (errorData is Map) {
          final message = errorData['message']?.toString() ?? '';
          if (message.contains('PUBLIC_ERROR_UNSAFE_GENERATION') ||
              message.contains('generation_failed')) {
            // 如果还没重试过，则清理提示词后重试
            if (retryCount == 0) {
              AppLogger.warn('图片生成', '触发内容安全检查，正在调整提示词并重试...');
              final sanitizedPrompt = _sanitizePrompt(prompt);
              return _generateImageWithRetry(
                sanitizedPrompt,
                referenceImages: referenceImages,
                retryCount: retryCount + 1,
              );
            } else {
              AppLogger.error('图片生成', '调整后仍无法通过安全检查，放弃重试', null, StackTrace.current);
            }
          }
        }
      }

      throw Exception('图片生成错误: $e');
    }
  }

  /// 清理提示词，移除可能触发内容安全检查的内容
  String _sanitizePrompt(String prompt) {
    // 移除或替换可能导致安全检查失败的敏感词汇
    final sanitized = prompt
        // 移除过于暴露的描述
        .replaceAll(RegExp(r'\b(sexy|nude|naked|breast|underwear|lingerie|intimate|suggestive)\b', caseSensitive: false), 'beautiful')
        // 移除暴力相关词汇
        .replaceAll(RegExp(r'\b(violence|blood|kill|death|weapon|gore)\b', caseSensitive: false), 'dramatic')
        // 移除其他可能的敏感词
        .replaceAll(RegExp(r'\b(disturbing|shocking|offensive)\b', caseSensitive: false), 'artistic')
        // 简化过于复杂的描述
        .replaceAll(RegExp(r'\b(highly detailed|extreme|intense|realistic skin|anatomically correct)\b', caseSensitive: false), 'detailed')
        // 保留核心内容，添加安全的艺术描述
        .trim();

    final result = sanitized.isEmpty
        ? 'Beautiful artistic scene, professional photography, high quality, cinematic lighting'
        : '$sanitized, professional photography, high quality, cinematic lighting';

    AppLogger.info('提示词清理', '原提示词: $prompt');
    AppLogger.info('提示词清理', '清理后: $result');

    return result;
  }

  /// 清理视频提示词，移除可能触发 reCAPTCHA/内容安全检查的敏感元素
  /// 视频生成对提示词更敏感，需要更积极的处理
  String _sanitizeVideoPrompt(String prompt) {
    AppLogger.info('视频提示词清理', '原始提示词: $prompt');

    // 移除或替换可能导致视频生成失败的敏感词汇
    String sanitized = prompt;

    // 移除暴力/危险相关元素（这些会触发 reCAPTCHA）
    final violentPatterns = [
      r'lightning\s+effects?', // 闪电效果
      r'glowing\s+(eyes|hands|body)', // 发光的眼睛/手/身体
      r'electric\s+\w+', // 电流相关
      r'energy\s+swirl', // 能量旋涡
      r'powerful?\s+\w+', // 强力/强大的
      r'explosion', // 爆炸
      r'fire\s+\w+', // 火焰
      r'violent?\s+\w+', // 暴力
      r'attack\s+\w+', // 攻击
      r'battle\s+\w+', // 战斗
      r'fight\s+\w+', // 打斗
      r'weapon', // 武器
      r'danger', // 危险
      r'threaten', // 威胁
      r'aggressive', // 激进
      r'intense', // 强烈（可能被误判）
      r'dramatic\s+lightning', // 戏剧性闪电
      r'fierce', // 凶猛
      r'determination\s*\([^)]*\)', // 坚定的（可能带眼睛描述）
      r'sweating', // 流汗（紧张氛围）
      r'trembling\s+spoon', // 颤抖的勺子
      r'gripping\s+spoon', // 紧握勺子
    ];

    for (final pattern in violentPatterns) {
      sanitized = sanitized.replaceAll(RegExp(pattern, caseSensitive: false), 'gentle');
    }

    // 替换为积极正向的词汇
    final replacements = {
      'lightning': 'soft light',
      'glowing': 'bright',
      'energy': 'atmosphere',
      'swirl': 'flow',
      'powerful': 'beautiful',
      'strong': 'elegant',
      'fierce': 'calm',
      'intense': 'warm',
      'dramatic': 'peaceful',
      'action': 'scene',
      'dynamic': 'smooth',
      'gripping': 'holding',
      'trembling': 'gentle',
    };

    for (final entry in replacements.entries) {
      sanitized = sanitized.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }

    // 添加安全的前缀和后缀
    final result = 'Peaceful anime style scene. $sanitized. Calm and positive atmosphere.';

    AppLogger.info('视频提示词清理', '清理后提示词: $result');

    return result;
  }

  /// 使用 AI 重写视频提示词，保留原意但使用安全的表达方式
  /// 用于重试失败的视频生成任务
  Future<String> rewriteVideoPromptForSafety({
    required String originalPrompt,
    required String sceneNarration, // 场景旁白，帮助理解上下文
  }) async {
    AppLogger.info('提示词重写', '原始提示词: $originalPrompt');
    AppLogger.info('提示词重写', '场景旁白: $sceneNarration');

    final rewritePrompt = '''
你是一个专业的视频提示词优化专家。你的任务是将视频提示词重写为100%安全的表达方式，确保通过平台的内容审核。

**原始场景旁白**:
$sceneNarration

**原始视频提示词**:
$originalPrompt

*** 关键：必须严格避免以下所有禁用词汇 ***

绝对禁止的词汇（会导致平台拒绝）:
- 能量/特效类: lightning, electric, thunderbolt, energy, power surge, spark, voltage, current
- 战斗/冲突类: attack, battle, fight, punch, kick, hit, strike, slam, crash, smash, beat, combat, clash, struggle
- 危险元素: fire, flame, burn, explosion, explode, blast, bomb, smoke, weapon, sword, knife, gun
- 负面情绪: fierce, intense, aggressive, violent, rage, angry, furious, terrified, scream, shout, yell, panic
- 身体恐怖: glowing eyes, red eyes, blood, wound, injury, transform, mutate, distort, twisted
- 危险动作: fall, drop, trip, stumble, chase, flee, escape, running

安全替代词汇（必须使用）:
- lightning/electric → soft light, warm light, gentle light, ambient light
- fight/attack → move toward, approach, face each other, interaction
- fierce/intense → warm, calm, gentle, peaceful, soft
- explosion/fire → bloom, brighten, illuminate, radiate
- angry/rage → concerned, surprised, amazed, excited

每个提示词必须包含至少2个安全词汇:
gentle, soft, calm, peaceful, warm, bright, smooth, quiet, serene, beautiful, lovely, sweet, slowly, smoothly, gracefully

镜头移动必须使用: slowly, gently, softly, calmly
绝不能使用: quick, fast, sudden, rapid, sharp, violent

请直接输出重写后的英文提示词，不要有任何解释。确保提示词50词以内，包含场景的核心动作和情感。
''';

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'glm-4-flash', // 使用快速模型
          'messages': [
            {'role': 'user', 'content': rewritePrompt}
          ],
          'temperature': 0.7,
        },
      );

      AppLogger.apiResponseRaw('/chat/completions (提示词重写)', response.data);

      // 解析 GLM 响应（OpenAI 格式）
      final choices = response.data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('GLM API 响应格式错误：没有 choices');
      }

      final firstChoice = choices[0] as Map<String, dynamic>?;
      final message = firstChoice?['message'] as Map<String, dynamic>?;
      final rewrittenPrompt = message?['content'] as String?;

      if (rewrittenPrompt == null || rewrittenPrompt.isEmpty) {
        throw Exception('GLM API 响应中没有内容');
      }

      final cleaned = rewrittenPrompt.trim();

      AppLogger.success('提示词重写', '重写后提示词: $cleaned');
      return cleaned;
    } catch (e) {
      AppLogger.error('提示词重写', 'AI重写失败，使用简单过滤', e);
      // 降级到简单过滤
      return _sanitizeVideoPrompt(originalPrompt);
    }
  }

  // ==================== Chat 格式图生图 API (角色一致性) ====================

  /// 使用 chat 格式图生图 API 生成图片（支持传入角色参考图 URL）
  /// 用于场景2+的图片生成，通过传入角色三视图保持人物一致性
  /// [prompt] 场景描述文本
  /// [characterImageUrls] 角色参考图 URL 列表（三视图）
  /// 返回生成的图片 URL
  Future<String> generateImageWithCharacterReference(
    String prompt, {
    required List<String> characterImageUrls,
  }) async {
    // Mock 模式
    if (ApiConfig.USE_MOCK_IMAGE_API) {
      AppLogger.warn('图生图(角色)', '🧪 使用 Mock 模式');
      AppLogger.info('图生图(角色)[MOCK]', 'Prompt: $prompt');
      AppLogger.info('图生图(角色)[MOCK]', '参考图数量: ${characterImageUrls.length}');
      await Future.delayed(const Duration(milliseconds: 500));
      return ApiConfig.MOCK_IMAGE_URL;
    }

    AppLogger.info('图生图(角色)', '开始生成，参考图数量: ${characterImageUrls.length}');
    AppLogger.info('图生图(角色)', 'Prompt: $prompt');

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.tuziBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 500),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.imageApiKey}',
          'Content-Type': 'application/json',
        },
      ));

      // 构建 content 数组：文本 + 多张参考图
      final List<Map<String, dynamic>> contentItems = [];

      // 添加文本提示
      contentItems.add({
        'type': 'text',
        'text': prompt,
      });

      // 添加角色参考图（三视图）
      for (final imageUrl in characterImageUrls) {
        if (imageUrl.isNotEmpty) {
          contentItems.add({
            'type': 'image_url',
            'image_url': {
              'url': imageUrl,
            },
          });
        }
      }

      final requestBody = {
        'model': 'gpt-4o-image-vip',
        'stream': false,
        'messages': [
          {
            'role': 'user',
            'content': contentItems,
          }
        ],
      };

      AppLogger.apiRequestRaw('POST', '/v1/chat/completions (图生图)', requestBody);
      AppLogger.info('图生图(角色)', '发送请求...');
      final response = await dio.post(
        '/v1/chat/completions',
        data: requestBody,
      );

      AppLogger.apiResponseRaw('/v1/chat/completions (图生图)', response.data);

      if (response.statusCode == 200) {
        final data = response.data;

        // 解析响应获取图片 URL
        // 响应格式: { choices: [{ message: { content: "url" } }] }
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'];
          final content = message['content'];

          // content 可能是字符串 URL 或包含图片的结构
          String? imageUrl;
          if (content is String) {
            // 直接是 URL 字符串
            if (content.startsWith('http')) {
              imageUrl = content;
            } else {
              // 可能是 Markdown 格式的复杂响应，需要提取图片 URL
              try {
                final parsed = content;

                // 策略1: 优先匹配 markdown 图片格式 ![alt](url)
                final markdownImageMatch = RegExp(r'!\[.*?\]\((https://pro\.filesystem\.site/cdn/[^\)]+)\)').firstMatch(parsed);
                if (markdownImageMatch != null) {
                  imageUrl = markdownImageMatch.group(1);
                  AppLogger.info('图生图(角色)', '从 Markdown 图片格式提取 URL: $imageUrl');
                }

                // 策略2: 如果没找到，匹配 pro.filesystem.site 的图片 URL
                if (imageUrl == null) {
                  final cdnUrlMatch = RegExp(r'https://pro\.filesystem\.site/cdn/[^\s\])"]+').firstMatch(parsed);
                  if (cdnUrlMatch != null) {
                    imageUrl = cdnUrlMatch.group(0);
                    AppLogger.info('图生图(角色)', '从 CDN URL 提取: $imageUrl');
                  }
                }

                // 策略3: 兜底 - 提取所有 URL 并过滤预览页面
                if (imageUrl == null) {
                  final allUrls = RegExp(r'https?://[^\s\])"]+').allMatches(parsed).map((m) => m.group(0)!).toList();
                  AppLogger.info('图生图(角色)', '找到的所有 URL: $allUrls');
                  // 过滤掉 pro.asyncdata.net/web 预览链接
                  for (final url in allUrls) {
                    if (!url.contains('pro.asyncdata.net/web')) {
                      imageUrl = url;
                      break;
                    }
                  }
                }
              } catch (e) {
                AppLogger.error('图生图(角色)', '解析 URL 失败: $e', e, StackTrace.current);
              }
            }
          } else if (content is List) {
            // content 是数组，查找图片类型
            for (final item in content) {
              if (item['type'] == 'image_url') {
                imageUrl = item['image_url']?['url'];
                break;
              }
            }
          }

          if (imageUrl != null && imageUrl.isNotEmpty) {
            AppLogger.success('图生图(角色)', '图片生成成功: $imageUrl');
            return imageUrl;
          }
        }

        AppLogger.error('图生图(角色)', '响应中未找到图片 URL', null, StackTrace.current);
        throw Exception('响应中未找到图片 URL');
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('图生图(角色)', '生成失败: $e', e, StackTrace.current);

      // 如果新接口失败，降级使用原有的文本生成方式
      AppLogger.warn('图生图(角色)', '降级到文本生成模式');
      return generateImage(prompt);
    }
  }

  // ==================== 角色三视图生成 API ====================

  /// 为角色生成组合三视图（一张图包含正面、侧面、背面三个视角）
  /// 新版本：生成单张组合图，用于视频生成时保持人物一致性
  /// [characterName] 角色名称
  /// [description] 角色描述
  /// [referenceImages] 参考图片（用户上传的角色参考图）
  /// [onProgress] 进度回调 (0.0 - 1.0)
  /// 返回 CharacterSheet 对象，包含组合三视图 URL
  Future<CharacterSheet> generateCharacterSheets(
    String characterName,
    String description, {
    List<String>? referenceImages,
    void Function(double progress, String status)? onProgress,
  }) async {
    AppLogger.info('角色三视图', '开始生成角色 $characterName 的组合三视图');

    // ========================================
    // Mock 模式：直接返回模拟结果
    // ========================================
    if (ApiConfig.USE_MOCK_CHARACTER_SHEET_API) {
      AppLogger.warn('角色三视图', '🧪 使用 Mock 模式，不调用真实 API');
      AppLogger.info('角色三视图[MOCK]', '角色名: $characterName');
      AppLogger.info('角色三视图[MOCK]', '描述: $description');
      if (referenceImages != null && referenceImages.isNotEmpty) {
        AppLogger.info('角色三视图[MOCK]', '参考图数量: ${referenceImages.length}');
      }

      onProgress?.call(0.0, '准备生成角色组合三视图...');

      // 模拟网络延迟
      await Future.delayed(const Duration(milliseconds: 500));

      onProgress?.call(0.5, '生成组合三视图...');
      await Future.delayed(const Duration(milliseconds: 500));
      AppLogger.success('角色三视图[MOCK]', '组合三视图生成完成: ${ApiConfig.MOCK_CHARACTER_COMBINED_URL}');

      final sheetId = 'char_${DateTime.now().millisecondsSinceEpoch}';
      final characterId = 'char_${characterName.hashCode}';

      final completedSheet = CharacterSheet(
        id: sheetId,
        characterId: characterId,
        characterName: characterName,
        description: description,
        role: '主角',
        combinedViewUrl: ApiConfig.MOCK_CHARACTER_COMBINED_URL,
        status: CharacterSheetStatus.completed,
      );

      onProgress?.call(1.0, '角色组合三视图生成完成！');
      AppLogger.success('角色三视图[MOCK]', '角色 $characterName 的组合三视图生成完成');

      return completedSheet;
    }

    // ========================================
    // 真实 API 调用模式
    // ========================================

    // 创建角色设定表对象
    final sheetId = 'char_${DateTime.now().millisecondsSinceEpoch}';
    final characterId = 'char_${characterName.hashCode}';

    onProgress?.call(0.0, '准备生成角色组合三视图...');

    try {
      // 生成组合三视图（一张图包含正面、侧面、背面）
      onProgress?.call(0.2, '生成组合三视图...');
      final combinedPrompt = _buildCombinedViewPrompt(description);
      final combinedUrl = await generateImage(
        combinedPrompt,
        referenceImages: referenceImages,
      );
      AppLogger.success('角色三视图', '组合三视图生成完成: $combinedUrl');

      // 创建完成的角色设定表
      final completedSheet = CharacterSheet(
        id: sheetId,
        characterId: characterId,
        characterName: characterName,
        description: description,
        role: '主角',
        combinedViewUrl: combinedUrl,
        status: CharacterSheetStatus.completed,
      );

      onProgress?.call(1.0, '角色组合三视图生成完成！');
      AppLogger.success('角色三视图', '角色 $characterName 的组合三视图生成完成');

      return completedSheet;
    } catch (e) {
      AppLogger.error('角色三视图', '生成角色组合三视图失败', e, StackTrace.current);
      throw Exception('角色组合三视图生成失败: $e');
    }
  }

  /// 构建组合三视图的提示词
  /// 生成一张图片，包含角色的正面、侧面、背面三个视角
  String _buildCombinedViewPrompt(String description) {
    // 基础描述
    final baseDesc = description.isNotEmpty
        ? description
        : 'A character in anime/manga style';

    // 组合三视图提示词
    return '''
Character turnaround sheet with three views side by side:
LEFT: Front view (facing forward)
CENTER: Side view (profile, facing right)
RIGHT: Back view (showing the back)

Character: $baseDesc

Layout: Three full body shots arranged horizontally in a single image
Style: anime/manga art style, clean line art, flat colors, professional character design sheet, character reference sheet
Quality: high quality, detailed, 4k, consistent proportions across all views
Background: plain white or light gray background
Composition: all three views same size, equal spacing, full body visible, neutral standing pose, T-pose or A-pose preferred
'''.trim();
  }

  /// 兼容旧版：构建单视图提示词
  @Deprecated('使用 _buildCombinedViewPrompt 替代')
  String _buildCharacterViewPrompt(String description, CharacterViewType viewType) {
    // 基础描述
    final baseDesc = description.isNotEmpty
        ? description
        : 'A character in anime/manga style';

    // 根据视图类型添加特定描述
    final viewDesc = viewType == CharacterViewType.front
        ? 'front view, facing forward, full body shot, standing pose'
        : viewType == CharacterViewType.back
            ? 'back view, showing the back of the character, full body shot, standing pose'
            : 'side view, profile view, full body shot, standing pose';

    // 组合提示词
    return '''
$viewDesc

Character: $baseDesc

Style: anime/manga art style, clean line art, flat colors, professional character design sheet
Quality: high quality, detailed, 4k
Background: plain white or light gray background for character reference
Composition: centered, full body visible, neutral standing pose
'''.trim();
  }

  /// 批量生成多个角色的三视图
  /// [characters] 角色列表，格式为 {'name': '角色名', 'description': '描述'}
  /// [referenceImages] 参考图片
  /// [onProgress] 进度回调 (overall 0.0 - 1.0)
  /// 返回角色设定表列表
  Future<List<CharacterSheet>> generateMultipleCharacterSheets(
    List<Map<String, String>> characters, {
    List<String>? referenceImages,
    void Function(double progress, String status)? onProgress,
  }) async {
    final List<CharacterSheet> sheets = [];

    for (int i = 0; i < characters.length; i++) {
      final char = characters[i];
      final name = char['name'] ?? '角色${i + 1}';
      final desc = char['description'] ?? '';

      final overallProgress = i / characters.length;
      onProgress?.call(
        overallProgress,
        '正在生成 $name 的三视图 (${i + 1}/${characters.length})...',
      );

      final sheet = await generateCharacterSheets(
        name,
        desc,
        referenceImages: referenceImages,
        onProgress: (viewProgress, viewStatus) {
          // 将单角色进度转换为总进度
          final currentOverall = (i + viewProgress) / characters.length;
          onProgress?.call(currentOverall, viewStatus);
        },
      );

      sheets.add(sheet);
    }

    onProgress?.call(1.0, '所有角色三视图生成完成！');
    return sheets;
  }

  // ==================== 图片生成视频 API (Tuzi Sora) ====================

  /// 从 URL 下载图片到本地临时文件
  Future<File> _downloadImage(String imageUrl) async {
    try {
      // 下载图片
      final response = await _dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();

      // 生成唯一文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageUrl).isNotEmpty
          ? path.extension(imageUrl)
          : '.png';
      final filename = 'temp_image_$timestamp$extension';
      final filePath = path.join(tempDir.path, filename);

      // 写入文件
      final file = File(filePath);
      await file.writeAsBytes(response.data as List<int>);

      return file;
    } catch (e) {
      throw Exception('图片下载错误: $e');
    }
  }

  /// 使用 Tuzi 视频生成 API 从图片生成视频（异步任务模式）
  ///
  /// 支持的模型:
  /// - veo3.1: Google Veo 3.1 (单图片，首帧)
  /// - veo3.1-components: 支持多图片输入（最多3张参考图，URL字符串数组）
  /// - sora-1: OpenAI Sora 1
  /// - sora-2-pro: OpenAI Sora 2 Pro
  ///
  /// 工作流程：
  /// 1. 提交任务到 POST /v1/videos，获取 task_id
  /// 2. 使用 [pollVideoStatus] 轮询任务状态
  /// 3. 当 status 为 completed 时获取 video_url
  Future<VideoGenerationResponse> generateVideo({
    required String prompt,
    List<String> imageUrls = const [], // 多张参考图URL（直接传URL字符串）
    String seconds = '10',
    String model = 'veo3.1-components',  // 默认使用 veo3.1-components 支持多图
    String size = '1280x720',
    bool sanitizePrompt = false, // 是否清理提示词（重试时使用）
  }) async {
    // 如果启用清理，对提示词进行安全处理
    final finalPrompt = sanitizePrompt ? _sanitizeVideoPrompt(prompt) : prompt;

    // ========================================
    // Mock 模式：直接返回模拟结果
    // ========================================
    if (ApiConfig.USE_MOCK_VIDEO_API) {
      AppLogger.warn('视频生成', '🧪 使用 Mock 模式，不调用真实 API');
      AppLogger.info('视频生成', '参考图数量: ${imageUrls.length}');

      await Future.delayed(const Duration(seconds: 2)); // 模拟网络延迟

      return VideoGenerationResponse(
        id: 'mock_task_${DateTime.now().millisecondsSinceEpoch}',
        object: 'video',
        model: model,
        status: 'completed',
        progress: 100,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        seconds: seconds,
        videoUrl: ApiConfig.MOCK_VIDEO_URL,
      );
    }

    // ========================================
    // 生产模式：调用真实 Tuzi Sora API
    // ========================================
    try {
      AppLogger.info('视频生成', '开始生成视频: $finalPrompt, 时长: ${seconds}秒, 模型: $model');
      AppLogger.info('视频生成', '参考图数量: ${imageUrls.length}');
      AppLogger.info('视频生成', '参考图URL: $imageUrls');

      // 步骤 1: 准备 FormData 请求数据（API 要求 multipart/form-data 格式）
      final formData = FormData.fromMap({
        'model': model,
        'prompt': finalPrompt,
        'seconds': seconds,
        'size': size,
        'watermark': 'false',
      });

      // 如果有参考图，每张图片作为单独的 input_reference 字段添加
      // multipart/form-data 格式支持同名多值
      for (final imageUrl in imageUrls) {
        formData.fields.add(MapEntry('input_reference', imageUrl));
      }

      AppLogger.apiRequestRaw('POST', '/v1/videos', {
        'model': model,
        'prompt': finalPrompt,
        'seconds': seconds,
        'size': size,
        'watermark': 'false',
        'input_reference': imageUrls,
      });

      // 步骤 2: 提交任务
      final response = await _tuziDio.post(
        '/v1/videos',
        data: formData,
      );

      AppLogger.apiResponseRaw('/v1/videos', response.data);

      final result = VideoGenerationResponse.fromJson(response.data);

      if (result.isCompleted && result.hasVideoUrl) {
        AppLogger.success('视频生成', '视频生成成功: ${result.videoUrl}');
      } else if (result.isFailed) {
        AppLogger.error('视频生成', '视频生成失败: ${result.error}', null, StackTrace.current);
      } else {
        AppLogger.info('视频生成', '任务已提交: ${result.id}, 状态: ${result.status}');
      }

      return result;
    } catch (e) {
      AppLogger.error('视频生成', '生成视频失败', e, StackTrace.current);
      throw Exception('视频生成错误: $e');
    }
  }

  /// 轮询视频生成任务状态，直到完成或失败
  ///
  /// 参数:
  /// - [taskId] 任务 ID
  /// - [timeout] 超时时间（默认 10 分钟）
  /// - [interval] 轮询间隔（默认 2 秒）
  /// - [onProgress] 进度回调，每次轮询时调用
  ///
  /// 返回: 完成状态的 VideoGenerationResponse
  Future<VideoGenerationResponse> pollVideoStatus({
    required String taskId,
    Duration timeout = const Duration(minutes: 10),
    Duration interval = const Duration(seconds: 2),
    void Function(int progress, String status)? onProgress,
    bool Function()? isCancelled, // 取消检查回调
  }) async {
    // ========================================
    // Mock 模式：直接返回模拟完成状态
    // ========================================
    if (ApiConfig.USE_MOCK_VIDEO_API) {
      AppLogger.warn('视频轮询', '🧪 Mock 模式，模拟轮询过程');

      // 模拟进度变化
      for (int progress = 0; progress <= 100; progress += 25) {
        // 检查取消
        if (isCancelled?.call() == true) {
          throw Exception('操作已取消');
        }
        await Future.delayed(const Duration(milliseconds: 500)); // Mock模式用更短延迟
        AppLogger.info('视频轮询', '模拟进度: $progress%');
        onProgress?.call(progress, 'in_progress');
      }

      return VideoGenerationResponse(
        id: taskId,
        object: 'video',
        model: 'veo3.1',
        status: 'completed',
        progress: 100,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        seconds: '10',
        videoUrl: ApiConfig.MOCK_VIDEO_URL,
      );
    }

    // ========================================
    // 生产模式：真实轮询
    // ========================================
    final startTime = DateTime.now();
    AppLogger.info('视频轮询', '开始轮询任务: $taskId');

    try {
      while (true) {
        // 检查取消（在每次循环开始时检查）
        if (isCancelled?.call() == true) {
          AppLogger.warn('视频轮询', '用户取消操作');
          throw Exception('操作已取消');
        }

        // 检查超时
        if (DateTime.now().difference(startTime) > timeout) {
          throw Exception('视频生成超时（超过 ${timeout.inMinutes} 分钟）');
        }

        // 查询状态
        final response = await _tuziDio.get('/v1/videos/$taskId');
        final result = VideoGenerationResponse.fromJson(response.data);

        AppLogger.apiResponseRaw('/v1/videos/$taskId', response.data);
        AppLogger.info('视频轮询', '状态: ${result.status}, 进度: ${result.progress ?? 0}%');

        // 回调进度更新
        onProgress?.call(result.progress ?? 0, result.status ?? 'unknown');

        // 检查是否完成
        if (result.isCompleted) {
          if (result.hasVideoUrl) {
            AppLogger.success('视频轮询', '视频生成完成: ${result.videoUrl}');
            return result;
          } else {
            throw Exception('任务已完成但没有视频 URL');
          }
        }

        // 检查是否失败
        if (result.isFailed) {
          throw Exception('视频生成失败: ${result.error ?? "未知错误"}');
        }

        // 等待后继续轮询 - 分片等待以更快响应取消
        final waitSteps = 5; // 将等待分成5段，每段0.4秒（总共2秒）
        for (int i = 0; i < waitSteps; i++) {
          await Future.delayed(interval ~/ waitSteps);
          // 每小段都检查取消，提高响应速度
          if (isCancelled?.call() == true) {
            AppLogger.warn('视频轮询', '等待期间用户取消操作');
            throw Exception('操作已取消');
          }
        }
      }
    } catch (e) {
      AppLogger.error('视频轮询', '轮询失败', e, StackTrace.current);
      rethrow;
    }
  }

  // ==================== 工具方法 ====================

  /// 下载任何文件到临时目录
  Future<File> downloadFile(String url, {String? filename}) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final tempDir = await getTemporaryDirectory();
      final finalFilename = filename ??
          'file_${DateTime.now().millisecondsSinceEpoch}${path.extension(url)}';
      final filePath = path.join(tempDir.path, finalFilename);

      final file = File(filePath);
      await file.writeAsBytes(response.data as List<int>);

      return file;
    } catch (e) {
      throw Exception('文件下载错误: $e');
    }
  }
}
