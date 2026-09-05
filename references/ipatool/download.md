# download：下载应用包

账户必须已持有许可（先 [purchase.md](purchase.md)，或配合 `--purchase` 自动获取——仅在用户已同意购买的前提下使用）。

## 用法

```bash
ipatool download [-i <trackId>] [-b <bundleId>] [-o <路径>] [--platform iphone|ipad|appletv] [--purchase] [--external-version-id <ID>] --keychain-passphrase <口令> --format json --non-interactive
```

| 参数 | 说明 |
| --- | --- |
| `-i, --app-id` | 应用的数值 ID（与 `-b` 至少提供一个） |
| `-b, --bundle-identifier` | 包标识，提供时**覆盖** `-i` |
| `-o, --output` | 输出目录或完整文件路径，省略时下载到当前工作目录 |
| `--platform` | `iphone` / `ipad` / `appletv` / `visionos`（v2.5.0 起）；留空默认 iPhone |
| `--purchase` | 缺少许可时自动购买（等效自动执行 purchase） |
| `--external-version-id` | 指定历史版本；省略时下载最新版 |

- `-o` 的行为：传入已存在的目录时，文件自动按 `<bundleId>_<trackId>_<版本>.ipa` 命名存入该目录（实测示例：`com.kot32.tomatodo_1242689729_8.12.61.ipa`）；传入完整文件路径（含不存在的一级文件名）时按该路径保存。
- 命令内置最多 3 次尝试：凭据过期自动重登；配合 `--purchase` 时缺许可会自动购买后继续。
- 下载的文件已由 ipatool 注入授权信息（sinf），**与下载时使用的 Apple ID 绑定**：可直接安装到已登录同一 Apple ID 的设备；安装后该应用的后续更新，也需要设备的 App Store 登录同一 Apple ID 才能进行。

## 输出

成功：

```json
{"level":"info","output":"C:\\Users\\me\\Downloads\\示例应用-1.2.3.ipa","purchased":false,"success":true,"time":"2026-01-01T00:00:00+08:00"}
```

`output` 是产物完整路径（注意 JSON 转义的反斜杠），`purchased` 为 `true` 表示本次下载触发了自动购买。拿到路径后应确认文件真实存在、大小合理。

## 历史版本

要下载指定历史版本，先经 [versions.md](versions.md) 查询可用版本，再把 `--external-version-id` 传入本命令。
