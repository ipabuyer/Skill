---
name: ipabuyer
description: 通过 ipatool 购买、下载与备份 App Store 应用（IPA 文件）。当用户想获取 iOS/iPadOS/tvOS 应用的安装包、收藏免费或限免 App、找回已购应用，或提到 IPA、ipatool、App Store 下载等需求时使用本技能；即使用户没有明确说出 ipatool 也应触发。
---

# IPAbuyer：购买与下载 App Store 应用

本技能配合 [ipatool](https://github.com/majd/ipatool) 完成「登录 App Store → 搜索 → 购买（获取许可）→ 下载 IPA」的完整流程。所有命令参数、JSON 输出格式与常见错误的细节见 [references/ipatool.md](references/ipatool.md)，首次执行某个步骤前先阅读对应小节。

## 环境要求

- Windows 10 及以上（amd64 / arm64），PowerShell 或 Git Bash 任一可用。
- 可访问 Apple 与 GitHub 的网络。

macOS / Linux 用户可从 ipatool 的 GitHub Releases 自行安装 `ipatool` 命令，后续命令完全一致；技能自带的下载脚本仅支持 Windows。

## 第 0 步：准备 ipatool

按以下顺序定位 ipatool，命中即止：

1. 用户明确指定了 ipatool 路径，直接使用。
2. PATH 中已有 `ipatool`（`command -v ipatool`），使用并用 `ipatool --version` 确认版本不低于 2.4。
3. 都没有，用技能自带脚本安装（自动从 ipatool 官方 Release 下载并做 SHA-256 校验，amd64 与 arm64 各装一份）：

   ```bash
   powershell -NoProfile -ExecutionPolicy Bypass -File "<技能目录>/scripts/get-ipatool-release.ps1" -OutputDir "$LOCALAPPDATA/IPAbuyer/bin"
   ```

   然后按 CPU 架构选择可执行文件（从脚本 stdout 的 `Installed <arch>: <path>` 行取路径，或按文件名匹配）：

   ```bash
   case "$PROCESSOR_ARCHITECTURE" in ARM64) A=arm64 ;; *) A=amd64 ;; esac
   IPATOOL=$(ls "$LOCALAPPDATA/IPAbuyer/bin"/ipatool-*-windows-"$A".exe | tail -1)
   ```

安装脚本默认解析 ipatool 最新正式版，也可用 `-Version 2.4.0` 锁定版本；本技能的文档与命令参数以 v2.4.0 为基准验证。若目标文件已存在脚本会报错，说明本机装过，直接复用即可（确要覆盖时加 `-Force`）。技能目录在安装后可能只读，因此不要省略 `-OutputDir`。

## 第 1 步：登录

所有业务命令（search / purchase / download / auth info）都要求已登录的凭据和 `--keychain-passphrase`。ipatool 把凭据加密存放在 `~/.ipatool/`，passphrase 是加密口令，与 Apple ID 密码无关。

1. **先查状态**，已登录就跳过本步骤余下内容：

   ```bash
   "$IPATOOL" auth info --keychain-passphrase "$KC" --format json --non-interactive
   ```

2. **确定 passphrase**：询问用户之前是否设置过（用过 IPAbuyer 或 ipatool 就可能有）；没有则生成一个强随机值（如 `openssl rand -base64 24`），告知用户并提醒妥善保存——建议记入密码管理器，经用户同意后也可存入 `~/.ipatool/passphrase`。passphrase 一旦丢失，已存凭据无法解密，只能 `auth revoke` 后重新登录。
3. **收集凭据**：Apple ID 邮箱、密码、双重验证码（6 位，从受信任设备或 <https://account.apple.com/> 获取）。验证码有效期很短，让用户先拿到再执行。
4. **执行登录**：

   ```bash
   "$IPATOOL" auth login --email "$EMAIL" --password "$PASS" --auth-code "$CODE" --keychain-passphrase "$KC" --format json --non-interactive > "$TMP/login.json"
   ```

判定成败看 JSON 的 `success` 字段，**不要只看退出码**：需要双重验证码但未提供 `--auth-code` 时，ipatool 输出一行提示后退出码仍为 0。见到 `2FA code is required` 就让用户取一个新验证码重跑。登录成功输出 `"success":true` 与账户的 name / email。

密码含特殊字符时注意 shell 引号转义（Git Bash 中用单引号包裹整个参数值）。

## 第 2 步：搜索应用

```bash
"$IPATOOL" search "应用名" --limit 10 --platform iphone --keychain-passphrase "$KC" --format json --non-interactive > "$TMP/search.json"
```

- 搜索范围跟随账户的 App Store 区域（storefront），v2.4.0 不支持指定国家/地区。
- `--platform` 可选 `iphone` / `ipad` / `appletv`，留空为 iPhone 与 iPad 混合搜索。
- 结果在 `apps` 数组中，每项含 `trackId`（数值 ID）、`bundleId`、`trackName`、`version`、`price`。`price` 字段缺失即免费（0 元）。
- 把候选列表（名称、版本、价格、bundleId）呈现给用户选择，不要替用户猜。

## 第 3 步：购买（获取许可）

下载前账户必须持有该 App 的许可。购买会改变账户的已购列表，执行前**必须向用户确认目标应用**（名称 + bundleId），得到明确同意再执行：

```bash
"$IPATOOL" purchase -b "<bundleId>" --keychain-passphrase "$KC" --format json --non-interactive > "$TMP/purchase.json"
```

- 仅对免费 App（`price` 缺失或为 0）直接执行；付费 App 必须先向用户说明可能产生扣费并取得明确同意。
- 输出 `"alreadyOwned":true` 表示账户已持有许可，直接进入下载。

## 第 4 步：下载 IPA

```bash
"$IPATOOL" download -b "<bundleId>" -o "<输出目录或完整文件路径>" --keychain-passphrase "$KC" --format json --non-interactive > "$TMP/download.json"
```

- `-o` 传目录时自动按「应用名-版本.ipa」命名，省略则下载到当前工作目录。先确认输出目录存在且可写。
- `download` 内置最多 3 次自动重试（凭据过期会自动重登）；加 `--purchase` 会在缺许可时自动购买——仅在用户已同意购买的前提下使用。
- 大型应用有数百 MB，耗时长：为命令设置足够的超时，或放后台执行并轮询完成状态。
- 成功输出 `"success":true` 与 `"output":"<文件路径>"`。把该路径报告给用户，并用 `ls -la` 确认文件真实存在、大小合理。

下载完成即达成目标。除非用户要求，不要主动 `auth revoke`——它会清除本机凭据，导致下次重新登录。

## 输出解析与编码（重要）

- ipatool 的 `--format json` 输出是 JSONL：每行一个独立的 JSON 对象，结果行带 `"success":true`，错误行形如 `{"level":"error","error":"…","success":false}`。逐行解析，不要把整个文件当一个 JSON 读。
- 输出为 UTF-8，一律重定向到文件再按 UTF-8 读取（如上所示），不要依赖终端直接显示——中文 Windows 控制台默认 GBK，会把中文应用名打成乱码。必须在 PowerShell 里查看输出时，先执行 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`。
- 本仓库所有文本文件以 UTF-8 存储；Windows PowerShell 5.1 解析含中文注释的 `.ps1` 需要 BOM，因此 `scripts/` 下的脚本只使用 ASCII 字符。

## 安全规则

- Apple ID 密码、双重验证码、keychain passphrase 不得写入任何日志、git 提交、对话总结；除用户同意的 `~/.ipatool/passphrase` 外不做任何持久化。命令行传参是 ipatool 的设计使然，但不要额外回显或复制这些值。
- 向用户展示登录状态时只显示姓名与邮箱。
- 脚本安装的 ipatool 经过 SHA-256 校验，不要引导用户从其他来源获取 ipatool。
