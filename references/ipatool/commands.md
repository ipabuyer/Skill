# ipatool 命令参考（v2.4.0）

本文档基于 ipatool v2.4.0 的 `--help` 输出与源码逐一验证，升级上游版本后请重新核对。各命令的输出示例与 JSONL 解析规则见 [output.md](output.md)；命令报错的排查见 [../troubleshooting/errors.md](../troubleshooting/errors.md)。

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

注意：需要双重验证码但未提供 `--auth-code` 时，ipatool 输出一行提示后**退出码为 0**，判定登录成败必须检查输出中的 `success` 字段。

### auth info — 查询登录状态

```bash
ipatool auth info --keychain-passphrase <口令> --format json --non-interactive
```

成功输出账户的 `name` / `email`；未登录或口令错误则输出错误 JSON 并返回非零退出码。用于流程开始时判断是否已登录。

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

### purchase — 获取应用许可

```bash
ipatool purchase -b <bundleId> --keychain-passphrase <口令> --format json --non-interactive
```

命令内置最多 2 次尝试（凭据过期自动重登）。`alreadyOwned` 为 `true` 表示账户此前已持有许可。

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

- `-o` 的行为：传入已存在的目录时，文件自动按「应用名-版本.ipa」命名存入该目录；传入完整文件路径（含不存在的一级文件名）时按该路径保存。
- 命令内置最多 3 次尝试：凭据过期自动重登；配合 `--purchase` 时缺许可会自动购买后继续。
- 下载的文件已由 ipatool 注入授权信息（sinf），可直接安装到已登录同一 Apple ID 的设备。

### list-versions — 列出历史版本

```bash
ipatool list-versions -b <bundleId> --keychain-passphrase <口令> --format json --non-interactive
```

### get-version-metadata — 查询指定版本元数据

```bash
ipatool get-version-metadata -b <bundleId> --external-version-id <ID> --keychain-passphrase <口令> --format json --non-interactive
```

## 本机存储

凭据与 Cookie 保存在用户主目录的 `.ipatool` 目录（如 `C:\Users\<用户>\.ipatool\`、`~/.ipatool/`）：keyring 凭据文件以 `--keychain-passphrase` 加密，`cookies` 为会话 Cookie。删除该目录等效于登出。

## 平台支持

- 可操作的应用平台：`iphone`、`ipad`、`appletv`，下载产物为 `.ipa`。
- ipatool 自身可运行于 Windows / macOS / Linux；本技能的安装脚本（PowerShell / bash / zsh）覆盖全部三个系统（amd64 / arm64）。macOS 也可用 `brew install ipatool`。
