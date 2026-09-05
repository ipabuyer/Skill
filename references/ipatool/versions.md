# versions：查询历史版本

查询某应用的历史版本信息，通常服务于 [download.md](download.md) 的 `--external-version-id` 参数。账户必须已登录。

## list-versions — 列出可用版本

```bash
ipatool list-versions -b <bundleId> --keychain-passphrase <口令> --format json --non-interactive
```

## get-version-metadata — 查询指定版本元数据

```bash
ipatool get-version-metadata -b <bundleId> --external-version-id <ID> --keychain-passphrase <口令> --format json --non-interactive
```

两个命令都支持用 `-i, --app-id` 替代 `-b, --bundle-identifier` 定位应用（提供 `-b` 时覆盖 `-i`）。
