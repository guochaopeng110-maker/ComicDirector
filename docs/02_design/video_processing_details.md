
---

# Tuzi API 接口文档：视频处理全集

---

## 1.生成视频 (Generate Video)

该接口利用 Sora 技术，支持提取视频中的非真人角色进行“客串表演”，并提供视频转换及插件输出功能。

### 1.1 接口基本信息

* **请求路径**：`/v1/videos`
* **请求方法**：`POST`
* **功能描述**：从视频中提取非真人对象（如宠物、虚拟角色、日常物品），并将其作为“客串角色”加入新视频中，实现数字孪生或虚构角色的无缝嵌入。

---

### 1.2 请求参数 (Request)

#### Header 参数

| 参数名 | 类型 | 必选 | 描述 |
| --- | --- | --- | --- |
| `Authorization` | `string` | 是 | API 调用凭证。格式：`Bearer [Token]` |

#### Body 参数 (`multipart/form-data`)

| 参数名 | 类型 | 必选 | 描述 |
| --- | --- | --- | --- |
| **model** | `enum<string>` | 是 | 模型版本。可选：`sora-1` (10s/15s 高清), `sora-2-pro` (10s/15s 高清, 25s 极速) |
| **prompt** | `string` | 是 | 视频生成提示词，可用中文描述视频场景 |
| `seconds` | `enum<string>` | 否 | 视频时长。可选：`10` (高清), `15` (高清), `25` (sora-2-pro 专用极速) |
| `input_reference` | `file` | 否 | 参考文件，支持图片或 URL |
| `size` | `enum<string>` | 否 | 分辨率比例。可选：`1280x720` (横屏), `720x1280` (竖屏), `1024x1024`, `1792x1024` (后两者仅限 pro) |
| `watermark` | `boolean` | 否 | 是否携带水印，默认 `false` |
| `private` | `boolean` | 否 | 是否私有生成（不显示在广场），默认 `false` |
| `character_url` | `string` | 否 | 提取非真人角色的视频链接 |
| `character_timestamps` | `string` | 否 | 角色提取的时间段（秒）。格式：`开始,结束`（建议时长 1~3s），如 `1,3` |
| `character_from_task` | `string` | 否 | 从历史成功任务 ID 中复用角色 |
| `character_create` | `boolean` | 否 | 是否在创建任务时自动创建并审核角色 |

---

### 1.3 返回响应 (Response)

#### 成功状态码：`200 OK`

#### 响应字段说明 (`application/json`)

| 参数名 | 类型 | 必选 | 描述 |
| --- | --- | --- | --- |
| `id` | `string` | 是 | 任务唯一标识 ID |
| `object` | `string` | 是 | 对象类型，固定为 `"video"` |
| `model` | `string` | 是 | 所使用的模型名称 |
| `status` | `string` | 是 | 任务状态，如 `"queued"` (排队中) |
| `progress` | `integer` | 是 | 生成进度 (0-100) |
| `created_at` | `integer` | 是 | 任务创建的时间戳 |
| `seconds` | `string` | 是 | 视频生成时长 |

### 响应示例

```json
{
  "id": "sora-2:task_01k78gpb3ffrmtyww...",
  "object": "video",
  "model": "sora-2",
  "status": "queued",
  "progress": 0,
  "created_at": 1760148794833,
  "seconds": "10"
}

```



---

## 2. 查询视频 (Query Video)

**接口路径**：`GET` `/v1/videos/{video_id}`

**功能说明**：根据任务 ID 查询生成进度及结果。

### 请求参数 (Path)

| 参数名 | 类型 | 必选 | 描述 |
| --- | --- | --- | --- |
| `video_id` | `string` | 是 | 生成任务返回的唯一 ID |

### 响应字段说明

| 参数名 | 类型 | 描述 |
| --- | --- | --- |
| **status** | `string` | 状态：`queued` (排队), `in_progress` (进行中), `completed` (完成), `failed` (失败) |
| **progress** | `integer` | 任务进度百分比 |
| **video_url** | `string` | 视频生成的直链地址（完成后返回） |

---

## 3. 下载视频 (Download Video)

**接口路径**：`GET` `/v1/videos/{task_id}/content`

**功能说明**：通过任务 ID 获取视频文件内容。

### 请求参数 (Path)

| 参数名 | 类型 | 必选 | 描述 |
| --- | --- | --- | --- |
| `task_id` | `string` | 是 | 视频任务的唯一标识 ID |

### Header 参数

| 参数名 | 类型 | 必选 | 描述 |
| --- | --- | --- | --- |
| `Authorization` | `string` | 是 | 格式：`Bearer <token>` |

### 响应信息

* **成功状态**：`200 OK`
* **响应类型**：`text/plain`（通常返回视频文件的二进制流或直接重定向到下载地址）

---

## 💡 开发工作流建议

1. **提交任务**：调用 `POST /v1/videos` 获取 `task_id`。
2. **轮询状态**：使用 `GET /v1/videos/{video_id}` 检查 `status` 是否为 `completed`。
3. **获取内容**：
* 直接使用查询接口返回的 `video_url` 下载。
* 或者调用 `GET /v1/videos/{task_id}/content` 获取视频流。