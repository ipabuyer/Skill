# ipatool 错误对照表

基于 ipatool v2.4.0。错误以 JSONL 的 error 行输出（格式与解析见 [../ipatool/overview.md](../ipatool/overview.md)），`error` 字段为英文消息，按子串匹配下表定位原因。

| 错误消息（子串） | 原因与处理 |
| --- | --- |
| `keychain passphrase is required` | 缺少 `--keychain-passphrase` 参数 |
| `password is required when not running in interactive mode` | login 缺少 `--password` |
| `2FA code is required`（注意退出码为 0） | 需要双重验证码，取新验证码后带 `--auth-code` 重跑 |
| `either the app ID or the bundle identifier must be specified` | download 未提供目标应用 |
| `invalid platform "…"` | `--platform` 取值不在 iphone / ipad / appletv 之内 |
| 许可相关错误（未持有许可） | 先执行 purchase，或 download 加 `--purchase`（需用户同意） |
| 凭据 / token 过期 | download 与 purchase 内置自动重试，无需人工干预 |

## 排查顺序建议

1. 先看 `error` 消息本身，多数情况可直接对上上表。
2. 涉及凭据的错误（keychain、token、账户）先重跑 `auth info` 确认登录状态，再决定是否重新登录。
3. 涉及双重验证码的问题与苹果账户政策限制，见 [faq.md](faq.md)。
4. 命令参数拿不准时回到 [../ipatool/](../ipatool/) 下对应命令的文档（[auth](../ipatool/auth.md) / [search](../ipatool/search.md) / [purchase](../ipatool/purchase.md) / [download](../ipatool/download.md)）核对。
