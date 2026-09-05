# list-purchases：列出账户已购应用（v2.5.0 新增）

按购买时间从新到旧列出当前账户拥有的应用，适合「把我下载过的应用再下载一遍」这类批量场景；配合 [download.md](download.md) 逐个下载。账户必须已登录。

## 用法

```bash
ipatool list-purchases [-l <每页数量>] [-p <页码>] --keychain-passphrase <口令> --format json --non-interactive
```

| 参数 | 说明 |
| --- | --- |
| `-l, --max-results` | 每页返回数量，默认 10 |
| `-p, --page` | 页码，默认 1 |

## 输出

结果行**没有 `success` 字段**（与 search 相同），`level` 为 `info` 且含 `apps` 即为结果行：

```json
{"level":"info","count":5,"totalCount":26,"page":1,"apps":[{"id":1242689729,"bundleID":"com.kot32.tomatodo","name":"番茄ToDo-极简高效自律番茄钟","version":"8.12.61","price":0,"purchaseDate":"2026-09-05T02:05:05Z"}],"time":"2026-09-05T10:59:56+08:00"}
```

| 字段 | 说明 |
| --- | --- |
| `count` | 本页条数 |
| `totalCount` | 账户已购应用总数，用于判断是否还有下一页 |
| `page` | 当前页码 |
| `apps[].purchaseDate` | 许可获取时间（UTC），`apps` 其余字段与 [search.md](search.md) 相同 |

翻页方式：`totalCount` 大于已取得的条数时，`-p` 递增取下一页，直到取完。
