# ipatool 通用背景（v2.4.0）

各命令的专属文档：[auth.md](auth.md)、[search.md](search.md)、[purchase.md](purchase.md)、[download.md](download.md)、[versions.md](versions.md)。命令报错排查见 [../troubleshooting/errors.md](../troubleshooting/errors.md)。

本文档基于 ipatool v2.4.0 的 `--help` 输出与源码逐一验证，升级上游版本后请重新核对。

## 全局参数

所有子命令共享以下参数：

| 参数 | 说明 |
| --- | --- |
| `--format text\|json` | 输出格式，默认 `text`。agent 环境下始终使用 `--format json` |
| `--keychain-passphrase <string>` | 解锁本机凭据的口令。非交互模式下，所有需要凭据的命令都必须提供 |
| `--non-interactive` | 非交互模式。agent 环境下始终添加，否则命令会尝试从 stdin 读取输入 |
| `--verbose` | 详细日志。JSONL 输出中会多出中间过程行 |

## JSONL 输出总规则

- `--format json` 的输出是**换行分隔的 JSON（JSONL）**，stdout 每行一个独立对象；**逐行解析，不要把整个文件当一个 JSON 读**。
- 业务字段直接平铺在结果行对象中（如 `apps`、`output`、`alreadyOwned`）；多数命令的结果行带 `"success":true`，但 **search 的结果行没有 `success` 字段**（`level` 为 `info` 且含 `apps` 即为结果行），各命令的字段与判定方式见对应命令文档。
- 错误行形如：

```json
{"level":"error","error":"failed to get account: failed to get item: keychain passphrase is required when not running in interactive mode; use the \"--keychain-passphrase\" flag","success":false,"time":"2026-09-05T08:12:40+08:00"}
```

- 判定成败以 `success` 字段为准，**不要只看退出码**（auth login 存在退出码为 0 的例外，见 [auth.md](auth.md)）。
- 带 `--verbose` 时会多出中间过程行（`level` 为 `info` 但无 `success` 字段），按同样的规则过滤。
- 输出为 UTF-8；中文 Windows 控制台默认 GBK，应把 stdout 重定向到文件后按 UTF-8 读取，不要依赖终端直接显示。

## 本机存储

凭据与 Cookie 保存在用户主目录的 `.ipatool` 目录（如 `C:\Users\<用户>\.ipatool\`、`~/.ipatool/`）：keyring 凭据文件以 `--keychain-passphrase` 加密，`cookies` 为会话 Cookie。删除该目录等效于登出。

## 平台支持

- 可操作的应用平台：`iphone`、`ipad`、`appletv`，下载产物为 `.ipa`。
- ipatool 自身可运行于 Windows / macOS / Linux；本技能的安装脚本（PowerShell / bash / zsh）覆盖全部三个系统（amd64 / arm64）。macOS 也可用 `brew install ipatool`。
