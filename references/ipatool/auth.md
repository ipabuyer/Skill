# auth：登录、查询状态、登出

登录前先读 SKILL.md 第 1 步的流程与凭据管理规则。报错排查见 [../troubleshooting/errors.md](../troubleshooting/errors.md)，账户类问题见 [../troubleshooting/faq.md](../troubleshooting/faq.md)。

## auth login — 登录 App Store

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

需要双重验证码但未提供 `--auth-code` 时，输出一行含 `2FA code is required` 的提示（无 `success` 字段）后**退出码为 0**——登录成败必须检查 `success` 字段，不能依赖退出码。见到该提示就取一个新验证码重跑。

## auth info — 查询登录状态

```bash
ipatool auth info --keychain-passphrase <口令> --format json --non-interactive
```

成功输出与 auth login 相同（`name`、`email`、`success`）；凭据不可用（未登录或口令不对）则输出错误 JSON 并返回非零退出码——注意两种情况输出可能相同（`integrity check failed`），无法直接区分，处理方式见 [../troubleshooting/errors.md](../troubleshooting/errors.md)。用于流程开始时判断是否已登录。

## auth revoke — 撤销本机凭据

```bash
ipatool auth revoke --keychain-passphrase <口令> --format json --non-interactive
```

成功仅含 `success:true`。删除本机存储的凭据，除非用户明确要求，不要主动执行——执行后下次必须重新登录。
