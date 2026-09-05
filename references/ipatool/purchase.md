# purchase：获取应用许可

下载前账户必须持有该 App 的许可；购买会改变账户的已购列表，执行前先按 SKILL.md 第 3 步的规则向用户确认。

## 用法

```bash
ipatool purchase -b <bundleId> --keychain-passphrase <口令> --format json --non-interactive
```

命令内置最多 2 次尝试（凭据过期自动重登），无需人工干预。

## 输出

成功：

```json
{"level":"info","alreadyOwned":false,"success":true,"time":"2026-01-01T00:00:00+08:00"}
```

`alreadyOwned` 为 `true` 表示账户此前已持有许可，可直接下载。
