# 兔子 API 图像生成接口文档
## 一、接口基础信息
- **接口地址**：`https://api.tu-zi.com/v1/images/generations`
- **请求方式**：POST
- **内容类型**：application/json
- **响应格式**：application/json（200 成功状态）

## 二、请求参数
### 1. Header 参数
| 参数名 | 类型 | 是否必需 | 说明 | 示例 |
|--------|------|----------|------|------|
| Authorization | string | 可选 | Bearer + Token 格式的身份验证 | Bearer {{YOUR_API_KEY}} |

### 2. Body 参数
| 参数名 | 类型 | 是否必需 | 说明 | 枚举值/约束 |
|--------|------|----------|------|-------------|
| prompt | string | 是 | 图像文本描述，支持 URL 上传图像，最大长度 1000 字符 | - |
| model | string | 是 | 图像生成模型 | 含 gemini-3-pro-image-preview-hd、nano banana 2 等 |
| image | array [string] | 否 | 图片上传，支持 URL 或 base64 格式，支持单图/多图 | 单图："xxx"；多图：["xxx","xxx"] |
| n | integer | 否 | 生成图像数量 | 1-10 之间 |
| response_format | enum<string> | 否 | 返回格式 | url（返回 URL）、b64_json（返回 base64） |
| size | enum<string> | 否 | 生成图像尺寸 | 1x1、1024x1024、832x1248（2x3）、1248x832（3x2）、864x1184（3x4）、1184x864（4x3）、896x1152（4x5）、1152x896（5x4）、768x1344（9x16）、1344x768（16x9）、1536x672（21x9） |
| quality | enum<string> | 否 | 图像生成质量（仅香蕉 2 模型有效） | 1k、2k、4k |

## 三、模型特性说明
| 模型名称 | 核心优势 | 单图体积 | 适用场景 |
|----------|----------|----------|----------|
| gemini-3-pro-image-preview-hd | 4k 分辨率，清晰度高 | 约 3 MB | 高清图像生成需求 |
| nano banana 2 | 中文显示效果出色，清晰度高 | 约 1.5 MB | 中文海报、文案类图片 |

## 四、使用建议
1. default 分组推荐调用「chat/generations/edit 接口」，稳定性与效果更佳；
2. 原价分组返回 base64 格式。

## 五、请求示例
### 1. 完整请求代码（cURL）
```curl
curl --location --request POST 'https://api.tu-zi.com/v1/images/generations' \
--header 'Authorization: Bearer <token>' \
--header 'Content-Type: application/json' \
--data-raw '{
  "model": "gemini-3-pro-image-preview-2k",
  "prompt": "两个形象在奔跑。",
  "image": ["https://tuziai.oss-cn-shenzhen.aliyuncs.com/wiki/code/mdjourney/cat_3.png","https://tuziai.oss-cn-shenzhen.aliyuncs.com/wiki/code/mdjourney/cat_4.png"],
  "n": 1,
  "size": "9x16",
  "response_format": "url"
}'
```

### 2. Body 示例
```json
{
  "model": "gemini-3-pro-image-preview-2k",
  "prompt": "两个形象在奔跑。",
  "image": ["https://tuziai.oss-cn-shenzhen.aliyuncs.com/wiki/code/mdjourney/cat_3.png","https://tuziai.oss-cn-shenzhen.aliyuncs.com/wiki/code/mdjourney/cat_4.png"],
  "n": 1,
  "size": "9x16",
  "response_format": "url"
}
```

## 六、响应示例（200 成功）
```json
{
    "created": 1589478378,
    "data": [
        {
            "url": "https://..."
        },
        {
            "url": "https://..."
        }
    ]
}
```

### 响应字段说明
| 字段名 | 类型 | 说明 |
|--------|------|------|
| created | integer | 图像创建时间戳 |
| data | array [object] | 生成的图像列表 |
| data[].url | string | 图像访问 URL（response_format 为 url 时返回） |