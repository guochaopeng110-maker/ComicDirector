# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI漫导 (DirectorAI) is a Flutter mobile app that generates AI-powered comic/manga-style videos. Users describe their creative idea in text, and the app orchestrates multiple AI models to produce a complete video with consistent characters across scenes.

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app (requires connected device/emulator)
flutter run

# Analyze code for issues
flutter analyze

# Run tests
flutter test

# Generate Hive adapters (after modifying models with @HiveType)
flutter pub run build_runner build

# Hot reload during development: press 'r' in terminal
# Hot restart: press 'R' in terminal
```

## Architecture

### ReAct Agent Loop
The app uses a ReAct (Reasoning + Acting) architecture where GLM-4.7 acts as the orchestrator:
1. User input → GLM-4.7 understands intent
2. GLM returns JSON commands for next action
3. Execute tool calls (image/video generation)
4. Feed results back to GLM
5. Repeat until task complete

### Key Layers

**Controllers** (`lib/controllers/`)
- `ScreenplayDraftController` - Generates screenplay drafts and character sheets (three-view reference images)
- `ScreenplayController` - Orchestrates scene image and video generation
- `AgentController` - Handles the ReAct loop for general agent interactions

**Providers** (`lib/providers/`)
- `ChatProvider` - Main state coordinator for the video generation flow
- `ConversationProvider` - Manages conversation history persistence
- `VideoMergeProvider` - Handles video merging state

**Services** (`lib/services/`)
- `ApiService` - All external API calls (GLM, Gemini, Tuzi/Sora, Doubao)
- `ApiConfigService` - Manages API keys (stored in SharedPreferences)
- `VideoMergerService` - Native Android video merging via platform channels

### AI Model Integration

| Model | Provider | Purpose |
|-------|----------|---------|
| GLM-4.7 | 智谱 AI | Script generation, intent understanding |
| Gemini (gemini-2.5-flash-image-vip) | Google (via Tuzi API) | Image generation |
| Veo 3.1 | Google (via Tuzi API) | Video generation from images |
| Doubao ARK | ByteDance | Image analysis/recognition |

### Character Consistency Mechanism

The app maintains character consistency across scenes using a "character sheet" approach:
1. Generate a three-view reference image (front/side/back) for each character
2. Use this reference image for all subsequent scene generations (image-to-image)
3. Include the reference in video generation to maintain consistency during motion

Key files:
- `lib/models/character_sheet.dart` - Character sheet data model
- `lib/controllers/screenplay_draft_controller.dart` - Generates character sheets
- `lib/controllers/screenplay_controller.dart` - Uses sheets for scene generation

### Video Generation Flow

1. User describes video idea
2. GLM-4.7 generates screenplay JSON (configurable scene count, default 7)
3. Character sheets generated for each character
4. User reviews/confirms screenplay
5. Parallel generation of scene images (configurable concurrency, default 2)
6. Parallel generation of scene videos
7. Optional: merge videos using Android MediaMuxer

## Configuration

Key settings in `lib/services/api_service.dart`:
- `ApiConfig.sceneCount` - Number of scenes per video (default: 7)
- `ApiConfig.concurrentScenes` - Parallel scene processing (default: 2)
- `USE_MOCK_*` flags - Enable mock APIs for testing

API keys are configured via the in-app settings screen (gear icon) and stored securely.

## Data Persistence

- **Hive** - Local database for conversations and messages
- **SharedPreferences** - API keys and app settings
- **flutter_cache_manager** - Media caching

Models requiring Hive adapters are in `lib/models/` with `.g.dart` generated files.
