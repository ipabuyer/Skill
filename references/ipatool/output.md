# ipatool 输出格式与解析（JSONL）

与 [commands.md](commands.md)（命令参数，v2.4.0）配套使用：运行命令前查参数，解析输出时查本文档。

## 总规则

- `--format json` 的输出是**换行分隔的 JSON（JSONL）**，stdout 每行一个独立对象；**逐行解析，不要把整个文件当一个 JSON 读**。
- 结果行带 `"success":true`，业务字段直接平铺在对象中（如 `apps`、`output`、`alreadyOwned`）。
- 错误行形如：

```json
{"level":"error","error":"failed to get account: failed to get item: keychain passphrase is required when not running in interactive mode; use the \"--keychain-passphrase\" flag","success":false,"time":"2026-09-05T08:12:40+08:00"}
```

- 判定成败以 `success` 字段为准，**不要只看退出码**（例外见 auth login）。
- 带 `--verbose` 时会多出中间过程行（`level` 为 `info` 但无 `success` 字段），按同样的规则过滤。
- 输出为 UTF-8；中文 Windows 控制台默认 GBK，应把 stdout 重定向到文件后按 UTF-8 读取，不要依赖终端直接显示。

## 各命令输出

### auth login

成功：

```json
{"level":"info","name":"张三","email":"user@example.com","success":true,"time":"2026-01-01T00:00:00+08:00"}
```

需要双重验证码但未提供 `--auth-code` 时，输出一行含 `2FA code is required` 的提示（无 `success` 字段）后**退出码为 0**——登录成败必须检查 `success` 字段，不能依赖退出码。

### auth info

成功字段与 auth login 相同：`name`、`email`、`success`。

### auth revoke

成功仅含 `success:true`。

### search

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

### purchase

成功：

```json
{"level":"info","alreadyOwned":false,"success":true,"time":"2026-01-01T00:00:00+08:00"}
```

`alreadyOwned` 为 `true` 表示账户此前已持有许可，可直接下载。

### download

成功：

```json
{"level":"info","output":"C:\\Users\\me\\Downloads\\示例应用-1.2.3.ipa","purchased":false,"success":true,"time":"2026-01-01T00:00:00+08:00"}
```

`output` 是产物完整路径（注意 JSON 转义的反斜杠），`purchased` 为 `true` 表示本次下载触发了自动购买。拿到路径后应确认文件真实存在、大小合理。

## 解析要点

- 逐行处理，先按 `"success":true` 过滤出结果行，再读取业务字段。
- 不同命令的业务字段不同：以本文档的示例为准，不要假设字段名。
- `time` 字段每行都有，可用于排序或过滤重试产生的多行输出。
