# 第五阶段需求文档：商业 (The Business)

> **周期**: 4 周  
> **目标**: 建立商业模式与运营监控体系

---

## 1. 阶段概述

| 任务编号 | 任务名称 | 优先级 | 预计周期 |
|----------|----------|--------|----------|
| #18 | 使用统计与埋点 | P0 | 1 周 |
| #19 | 付费模式与会员体系 | P1 | 2 周 |
| #20 | 崩溃监控 | P1 | 1 周 |

---

## 2. 任务 #18: 使用统计与埋点

**优先级**: P0 | **关联**: 运营商业化 5.1

### 2.1 核心埋点事件

| 事件名 | 触发时机 | 参数 |
|--------|----------|------|
| `create_start` | 开始创作 | template_id, source |
| `prompt_submit` | 提交创意 | prompt_length |
| `script_generated` | 剧本生成完成 | scene_count, duration_ms |
| `images_generated` | 图片生成完成 | image_count |
| `video_generated` | 视频生成完成 | video_count |
| `video_exported` | 视频导出 | format |
| `share_complete` | 分享成功 | channel |

### 2.2 技术方案

使用 Firebase Analytics，核心代码：

```dart
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  Future<void> logEvent(String name, [Map<String, dynamic>? params]) async {
    await _analytics.logEvent(name: name, parameters: params);
  }
}
```

### 2.3 验收标准

- [ ] 核心埋点事件覆盖完整
- [ ] 转化漏斗数据可查看

---

## 3. 任务 #19: 付费模式与会员体系

**优先级**: P1 | **关联**: 运营商业化 5.2

### 3.1 会员等级

| 等级 | 价格 | 每月额度 | 特权 |
|------|------|----------|------|
| 免费用户 | 0 | 3 次生成 | 带水印，标清 |
| 基础会员 | ¥29/月 | 30 次生成 | 无水印，高清 |
| 专业会员 | ¥99/月 | 100 次 | 4K，优先队列 |

### 3.2 Token 消耗规则

| 操作 | 消耗 Token |
|------|-----------|
| 剧本生成 | 1 |
| 图片生成 | 2/张 |
| 视频生成 | 5/段 |

### 3.3 支付集成

| 渠道 | 平台 | SDK |
|------|------|-----|
| 苹果内购 | iOS | StoreKit |
| Google Play | Android | Google Play Billing |
| 微信支付 | Android | Fluwx |

### 3.4 自带 API Key 模式

允许用户配置自己的 API Key，绕过平台计费。

### 3.5 验收标准

- [ ] 会员订阅功能可用
- [ ] Token 扣费逻辑正确
- [ ] 付费转化率 > 2%

---

## 4. 任务 #20: 崩溃监控

**优先级**: P1 | **关联**: 工程稳健性 1.6

### 4.1 技术方案

使用 Firebase Crashlytics：

```dart
void main() async {
  await Firebase.initializeApp();
  
  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  
  runApp(MyApp());
}
```

### 4.2 错误分类

| 错误类型 | 处理方式 |
|----------|----------|
| 网络超时 | 自动重试 3 次 |
| API 错误 | 上报 + 提示 |
| 未知崩溃 | 上报 + 重启 |

### 4.3 验收标准

- [ ] Crashlytics 集成完成
- [ ] 崩溃日志实时上报
- [ ] 崩溃率 < 0.5%

---

## 5. 技术依赖

```yaml
dependencies:
  firebase_analytics: ^10.7.4
  firebase_crashlytics: ^3.4.8
  in_app_purchase: ^3.1.13
```

---

## 6. 里程碑与成功指标

| 任务 | 成功指标 |
|------|----------|
| 使用统计 | 转化漏斗可视化 |
| 付费模式 | 付费转化率 > 2% |
| 崩溃监控 | 崩溃率 < 0.5% |

---

## 7. 验收清单

- [ ] 核心埋点覆盖完整
- [ ] 会员订阅功能可用
- [ ] Token 系统正常运行
- [ ] 崩溃监控实时可用
- [ ] 隐私政策合规
