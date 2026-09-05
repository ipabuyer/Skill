# ipatool 命令参考（v2.4.0）

本文档基于 ipatool v2.4.0 的 `--help` 输出与源码逐一验证。升级上游版本后请重新核对参数与输出格式。

## 全局参数

所有子命令共享以下参数：

| 参数 | 说明 |
| --- | --- |
| `--format text\|json` | 输出格式，默认 `text`。agent 环境下始终使用 `--format json` |
| `--keychain-passphrase <string>` | 解锁本机凭据的口令。非交互模式下，所有需要凭据的命令都必须提供 |
| `--non-interactive` | 非交互模式。agent 环境下始终添加，否则命令会尝试从 stdin 读取输入 |
| `--verbose` | 详细日志。JSONL 输出中会多出中间过程行 |

## 命令一览

### auth login — 登录 App Store

```bash
ipatool auth login --email <邮箱> --password <密码> [--auth-code <6位验证码>] --keychain-passphrase <口令> --format json --non-interactive
```

| 参数 | 说明 |
| --- | --- |
| `-e, --email` | Apple ID 邮箱（必填） |
| `-p, --password` | Apple ID 密码；非交互模式下必填 |
| `--auth-code` | 双重验证码。账户开启了双重认证时需要 |

成功输出：

```json
{"level":"info","name":"张三","email":"user@example.com","success":true,"time":"2026-01-01T00:00:00+08:00"}
```

注意：需要双重验证码但未提供 `--auth-code` 时，ipatool 输出一行含 `2FA code is required` 的提示后**退出码为 0**。判定登录成败必须检查 `success` 字段，不能依赖退出码。

### auth info — 查询登录状态

```bash
ipatool auth info --keychain-passphrase <口令> --format json --non-interactive
```

成功输出 `"success":true` 与 `name` / `email` 字段；未登录或口令错误则输出错误 JSON 并返回非零退出码。

### auth revoke — 撤销本机凭据

```bash
ipatool auth revoke --keychain-passphrase <口令> --format json --non-interactive
```

删除本机存储的凭据。除非用户明确要求，不要主动执行——执行后下次必须重新登录。

### search — 搜索应用

```bash
ipatool search <关键词> [--limit N] [--platform iphone|ipad|appletv] --keychain-passphrase <口令> --format json --non-interactive
```

| 参数 | 说明 |
| --- | --- |
| `<关键词>` | 位置参数，支持中文 |
| `-l, --limit` | 返回数量上限，默认 5 |
| `--platform` | `iphone` / `ipad` / `appletv`；留空为 iPhone 与 iPad 混合搜索 |

- **search 必须先登录**：命令内部会先查询账户信息。
- 搜索范围跟随账户的 App Store 区域（storefront），没有指定国家/地区的参数。
- `--platform` 取值非法时直接报错 `invalid platform "…"`。

成功输出（`apps` 数组，每项为一个应用）：

```json
{"level":"info","count":2,"apps":[{"trackId":123456,"bundleId":"com.example.app","trackName":"示例应用","version":"1.2.3","price":0}],"success":true,"time":"2026-01-01T00:00:00+08:00"}
```

字段说明：`trackId` 是应用的数值 ID，`bundleId` 是购买与下载用的包标识，`version` 为当前上架版本。**`price` 字段缺失即免费（0 元）**——源码中价格序列化带 `omitempty`，0 值不会出现。

### purchase — 获取应用许可

```bash
ipatool purchase -b <bundleId> --keychain-passphrase <口令> --format json --non-interactive
```

成功输出：

```json
{"level":"info","alreadyOwned":false,"success":true,"time":"2026-01-01T00:00:00+08:00"}
```

`alreadyOwned` 为 `true` 表示账户此前已持有许可。命令内置最多 2 次尝试（凭据过期自动重登）。

### download — 下载应用包

```bash
ipatool download [-i <trackId>] [-b <bundleId>] [-o <路径>] [--platform iphone|ipad|appletv] [--purchase] [--external-version-id <ID>] --keychain-passphrase <口令> --format json --non-interactive
```

| 参数 | 说明 |
| --- | --- |
| `-i, --app-id` | 应用的数值 ID（与 `-b` 至少提供一个） |
| `-b, --bundle-identifier` | 包标识，提供时**覆盖** `-i` |
| `-o, --output` | 输出目录或完整文件路径，省略时下载到当前工作目录 |
| `--platform` | `iphone` / `ipad` / `appletv`；留空默认 iPhone |
| `--purchase` | 缺少许可时自动购买（等效自动执行 purchase） |
| `--external-version-id` | 指定历史版本；省略时下载最新版 |

`-o` 的行为：传入已存在的目录时，文件自动按「应用名-版本.ipa」命名存入该目录；传入完整文件路径（含不存在的一级文件名）时按该路径保存。

成功输出：

```json
{"level":"info","output":"C:\\Users\\me\\Downloads\\示例应用-1.2.3.ipa","purchased":false,"success":true,"time":"2026-01-01T00:00:00+08:00"}
```

`purchased` 为 `true` 表示本次下载触发了自动购买。命令内置最多 3 次尝试：凭据过期自动重登；配合 `--purchase` 时缺许可会自动购买后继续。下载的文件已由 ipatool 注入授权信息（sinf），可直接安装到已登录同一 Apple ID 的设备。

### list-versions — 列出历史版本

```bash
ipatool list-versions -b <bundleId> --keychain-passphrase <口令> --format json --non-interactive
```

### get-version-metadata — 查询指定版本元数据

```bash
ipatool get-version-metadata -b <bundleId> --external-version-id <ID> --keychain-passphrase <口令> --format json --non-interactive
```

## 输出格式：JSONL

`--format json` 的输出是**换行分隔的 JSON（JSONL）**，stdout 每行一个独立对象：

- 结果行带 `"success":true`，业务字段直接平铺在对象中（如 `apps`、`output`、`alreadyOwned`）。
- 错误行形如：

```json
{"level":"error","error":"failed to get account: failed to get item: keychain passphrase is required when not running in interactive mode; use the \"--keychain-passphrase\" flag","success":false,"time":"2026-09-05T08:12:40+08:00"}
```

- 解析时逐行处理，过滤 `level` 为 `info` 且 `success` 为 `true` 的行；带 `--verbose` 时会多出中间行，按同样的规则过滤即可。

## 错误对照表

| 错误消息（子串） | 原因与处理 |
| --- | --- |
| `keychain passphrase is required` | 缺少 `--keychain-passphrase` 参数 |
| `password is required when not running in interactive mode` | login 缺少 `--password` |
| `2FA code is required`（退出码为 0） | 需要双重验证码，取新验证码后带 `--auth-code` 重跑 |
| `either the app ID or the bundle identifier must be specified` | download 未提供目标应用 |
| `invalid platform "…"` | `--platform` 取值不在 iphone / ipad / appletv 之内 |
| 许可相关错误（未持有许可） | 先执行 purchase，或 download 加 `--purchase`（需用户同意） |
| 凭据 / token 过期 | download 与 purchase 内置自动重试，无需人工干预 |

## 本机存储

凭据与 Cookie 保存在用户主目录的 `.ipatool` 目录（如 `C:\Users\<用户>\.ipatool\`）：keyring 凭据文件以 `--keychain-passphrase` 加密，`cookies` 为会话 Cookie。删除该目录等效于登出。

## 账户要求与常见问题

以下问题来自 IPAbuyer 的用户实践：

- **无法获取双重验证码**：仅以手机号作为验证手段的账户收不到验证码。请让用户到 <https://account.apple.com/> 获取。
- **账户密码正确却无法登录**：苹果的账户政策要求账户登录过 iCloud 与 App Store，并在 App Store 完成过一次有效购买，否则第三方客户端无法登录。
- **购买后 iPhone 仍显示未购买**：iPhone 不会立即刷新已购列表，在 iPhone 上对任意 App 完成一次购买（含免费 App）即可刷新。
- **为什么默认只自动购买免费 App**：购买付费 App 会真实产生扣费。为账户安全起见，本技能对付费 App 一律先向用户确认。

## 平台支持

- 可操作的应用平台：`iphone`、`ipad`、`appletv`，下载产物为 `.ipa`。
- ipatool 自身可运行于 Windows / macOS / Linux；本技能的安装脚本（PowerShell / bash / zsh）覆盖全部三个系统（amd64 / arm64）。macOS 也可用 `brew install ipatool`。
