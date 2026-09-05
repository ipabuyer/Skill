# search：搜索应用

搜索前账户必须已登录（命令内部会先查询账户信息），见 [auth.md](auth.md)。

## 用法

```bash
ipatool search <关键词> [--limit N] [--platform iphone|ipad|appletv] --keychain-passphrase <口令> --format json --non-interactive
```

| 参数 | 说明 |
| --- | --- |
| `<关键词>` | 位置参数，支持中文 |
| `-l, --limit` | 返回数量上限，默认 5 |
| `--platform` | `iphone` / `ipad` / `appletv`；留空为 iPhone 与 iPad 混合搜索 |

- 搜索范围跟随账户的 App Store 区域（storefront），没有指定国家/地区的参数。
- `--platform` 取值非法时直接报错 `invalid platform "…"`。

## 输出

成功输出 `count` 与 `apps` 数组：

```json
{"level":"info","count":2,"apps":[{"trackId":123456,"bundleId":"com.example.app","trackName":"示例应用","version":"1.2.3","price":0}],"success":true,"time":"2026-01-01T00:00:00+08:00"}
```

`apps` 每项的字段：

| 字段 | 说明 |
| --- | --- |
| `trackId` | 应用的数值 ID |
| `bundleId` | 包标识，购买与下载时使用 |
| `trackName` | 应用名称 |
| `version` | 当前上架版本 |
| `price` | 价格；**字段缺失即免费（0 元）**——源码中价格序列化带 `omitempty`，0 值不会出现 |
