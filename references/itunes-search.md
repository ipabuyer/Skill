# iTunes Search API：应用评分与元数据补查

ipatool 的搜索结果不含评分。当用户给出挑选标准（如「挑评分高的免费番茄钟」）或需要更多应用信息时，用本公开接口补查——它就是 ipatool 底层使用的同一接口，无需登录、不涉及凭据。

## 端点与调用

- 搜索：`GET https://itunes.apple.com/search`
- 定向查询：`GET https://itunes.apple.com/lookup`

推荐用 curl 的 `-G --data-urlencode` 组合传参（自动完成 URL 编码）：

```bash
curl -fsSL -G "https://itunes.apple.com/search" \
  --data-urlencode "term=番茄钟" \
  --data-urlencode "country=cn" \
  --data-urlencode "entity=software" \
  --data-urlencode "limit=10" > "$TMP/itunes-search.json"

curl -fsSL -G "https://itunes.apple.com/lookup" \
  --data-urlencode "id=<trackId1>,<trackId2>,<trackId3>" \
  --data-urlencode "country=cn" > "$TMP/itunes-lookup.json"
```

| 参数 | 适用 | 说明 |
| --- | --- | --- |
| `term` | search | 搜索词，支持中文 |
| `country` | 两者 | 国家/地区代码，必须与账户的 App Store 区域一致（如中国大陆为 `cn`）；省略默认 `US` |
| `entity` | search | 固定 `software` |
| `limit` | search | 结果数上限，最大 200 |
| `id` | lookup | 逗号分隔的 `trackId` 列表，可一次批量查询 |

**注意：中文等非 ASCII 参数必须 URL 编码，直接拼进 URL 会返回 HTTP 400**——所以不要手写 URL，交给 `--data-urlencode`。

响应是**单个 UTF-8 JSON 对象**（不是 JSONL）：`resultCount` 为结果数，结果在 `results` 数组中；`resultCount` 为 0 表示无结果或该区域未上架。其中 `artist` 类条目（`wrapperType` 非 `software`）按需过滤。

## 常用字段

| 字段 | 说明 |
| --- | --- |
| `trackId` / `bundleId` | 与 ipatool 搜索结果的 ID、包标识对应 |
| `trackName` / `sellerName` | 应用名 / 开发者 |
| `version` / `currentVersionReleaseDate` | 当前版本 / 发布时间 |
| `price` / `formattedPrice` | 价格数值（0 即免费）/ 本地化价格文本 |
| `averageUserRating` | 平均评分（1–5） |
| `userRatingCount` | 评分人数 |
| `genres` / `minimumOsVersion` | 分类 / 最低系统要求 |

## 与 ipatool 搜索的配合

1. 先用 ipatool `search` 拿到候选（结果跟随账户的 storefront）。
2. 需要评分时，把候选的 `trackId` 用 lookup 一次性批量补查（`country` 与账户区域保持一致，避免查到其他区域的上架状态与评分）。注意字段名不同：ipatool 搜索结果是 `id` / `bundleID` / `name`，iTunes API 是 `trackId` / `bundleId` / `trackName`，数值 ID 含义相同。
3. 挑选依据：以 `averageUserRating` 为主、`userRatingCount` 为辅——评分人数过少时评分参考价值低。
4. 挑选结果只作为推荐，购买仍须遵循 SKILL.md 第 3 步的确认规则。
