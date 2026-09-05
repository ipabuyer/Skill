# search：搜索应用

搜索前账户必须已登录（命令内部会先查询账户信息），见 [auth.md](auth.md)。

## 用法

```bash
ipatool search <关键词> [--limit N] [--platform iphone|ipad|appletv] --keychain-passphrase <口令> --format json --non-interactive
```

| 参数 | 说明 |
| --- | --- |
| `<关键词>` | 位置参数，支持中文 |
| `-l, --limit` | 返回数量上限，默认 5（visionOS 平台上限为 12） |
| `--platform` | `iphone` / `ipad` / `appletv` / `visionos`（v2.5.0 起）；留空为 iPhone 与 iPad 混合搜索 |

- 搜索范围跟随账户的 App Store 区域（storefront），没有指定国家/地区的参数。
- `--platform` 取值非法时直接报错 `invalid platform "…"`。

## 输出

成功输出 `count` 与 `apps` 数组。**注意：搜索结果行没有 `success` 字段**，`level` 为 `info` 且含 `apps` 即为结果行：

```json
{"level":"info","count":10,"apps":[{"id":1242689729,"bundleID":"com.kot32.tomatodo","name":"番茄ToDo-极简高效自律番茄钟","version":"8.12.61","price":0}],"time":"2026-09-05T10:02:00+08:00"}
```

`apps` 每项的字段：

| 字段 | 说明 |
| --- | --- |
| `id` | 应用的数值 ID，对应 download 的 `-i` |
| `bundleID` | 包标识（注意是大写 `ID`），对应 purchase / download 的 `-b` |
| `name` | 应用名称 |
| `version` | 当前上架版本 |
| `price` | 价格，0 即免费 |

字段命名与 iTunes Search API（`trackId` / `bundleId` / `trackName`）不同，两份数据配合使用时不要混用；数值 ID 本身一致。
