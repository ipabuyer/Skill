---
name: ipabuyer
description: 通过 ipatool 购买、下载与备份 App Store 应用（IPA 文件）。当用户想获取 iOS/iPadOS/tvOS 应用的安装包、收藏免费或限免 App、找回已购应用，或提到 IPA、ipatool、App Store 下载等需求时使用本技能；即使用户没有明确说出 ipatool 也应触发。
---

# IPAbuyer：购买与下载 App Store 应用

本技能配合 [ipatool](https://github.com/majd/ipatool) 完成「登录 App Store → 搜索 → 购买（获取许可）→ 下载 IPA」的完整流程。通用背景（全局参数、JSONL 输出规则、凭据存储）见 [references/ipatool/overview.md](references/ipatool/overview.md)；命令报错查 [references/troubleshooting/errors.md](references/troubleshooting/errors.md)；账户与登录类问题查 [references/troubleshooting/faq.md](references/troubleshooting/faq.md)。各步骤专属的命令文档在小节内标注，走到哪步读哪份。

## 环境要求

- Windows 10 及以上、macOS 或 Linux（amd64 / arm64），PowerShell、bash 或 zsh 任一可用。
- 可访问 Apple 与 GitHub 的网络。

三个系统的 ipatool 命令完全一致。

## 第 0 步：准备 ipatool

按以下顺序定位 ipatool，命中即止：

1. 用户明确指定了 ipatool 路径，直接使用。
2. PATH 中已有 `ipatool`（`command -v ipatool`），使用并用 `ipatool --version` 确认版本不低于 2.4。
3. 都没有，用技能自带脚本安装（自动检测系统与 CPU 架构，从 ipatool 官方 Release 下载对应的一份并做 SHA-256 校验）：

   ```bash
   # Windows（PowerShell）
   powershell -NoProfile -ExecutionPolicy Bypass -File "<技能目录>/scripts/get-ipatool-release.ps1" -OutputDir "$LOCALAPPDATA/IPAbuyer/bin"
   IPATOOL=$(ls "$LOCALAPPDATA/IPAbuyer/bin"/ipatool-*-windows-*.exe | tail -1)

   # macOS / Linux（bash 或 zsh）
   sh "<技能目录>/scripts/get-ipatool-release.sh" --output-dir "$HOME/.local/share/IPAbuyer/bin"   # zsh 用户可用 .zsh 版
   IPATOOL=$(ls "$HOME/.local/share/IPAbuyer/bin"/ipatool-* | tail -1)
   ```

   两种脚本的 stdout 都带安装路径（`Installed <系统>/<架构>: <path>` 行），优先直接取用。

安装脚本默认解析 ipatool 最新正式版，也可锁定版本（Windows 用 `-Version 2.4.0`，macOS/Linux 用 `--version 2.4.0`）；本技能的文档与命令参数以 v2.4.0 为基准验证。若目标文件已存在脚本会报错，说明本机装过，直接复用即可（确要覆盖时加 `-Force` 或 `--force`）。技能目录在安装后可能只读，因此不要省略输出目录参数。

## 第 1 步：登录

命令用法与输出解析详见 [references/ipatool/auth.md](references/ipatool/auth.md)。

所有业务命令（search / purchase / download / auth info）都要求已登录的凭据和 `--keychain-passphrase`。ipatool 把凭据加密存放在 `~/.ipatool/`，passphrase 是加密口令，与 Apple ID 密码无关。

1. **确定 passphrase**：询问用户之前是否设置过（用过 IPAbuyer 或 ipatool 就可能有）；首次登录时让用户在交互提示中自设并妥善保存——建议记入密码管理器，经用户同意后也可存入 `~/.ipatool/passphrase`。passphrase 一旦丢失，已存凭据无法解密，只能删除 `~/.ipatool` 后重新登录。
2. **先查状态**，已登录就跳过本步骤余下内容：

   ```bash
   "$IPATOOL" auth info --keychain-passphrase "$KC" --format json --non-interactive
   ```

3. **未登录时，引导用户在自己的终端交互式登录（首选方式，登录不经手 agent）**。把命令交给用户执行：

   ```bash
   ipatool auth login --email <AppleID邮箱>
   ```

   ipatool 依次提示：输入 Apple ID 密码（隐藏输入）→ 需要时输入 6 位双重验证码（从受信任设备或 <https://account.apple.com/> 获取）→ 输入 keychain passphrase（首次自设）。完成后让用户回来告知，agent 用第 2 步命令复核，成功输出 `"success":true` 与账户的 name / email。

   交互式登录必须由用户完成：agent 的执行环境通常没有终端（TTY），ipatool 会按非交互模式运行、交互提示不可用；且 ipatool 无法主动请求 Apple 下发验证码，非交互代跑依赖验证码推送、路径不稳定（桌面版 IPAbuyer 曾用假验证码 000000 触发下发，不要复刻该做法）。
4. **备选（仅用户明确要求 agent 代跑时）**：非交互登录——密码会因此暴露给 agent 会话与 shell 历史：

   ```bash
   "$IPATOOL" auth login --email "$EMAIL" --password "$PASS" --auth-code "$CODE" --keychain-passphrase "$KC" --format json --non-interactive > "$TMP/login.json"
   ```

   判定成败看 JSON 的 `success` 字段，**不要只看退出码**：需要双重验证码但未提供 `--auth-code` 时，ipatool 输出一行提示后退出码仍为 0。密码含特殊字符时注意 shell 引号转义（Git Bash 中用单引号包裹整个参数值）。

## 第 2 步：搜索应用

命令用法与输出字段详见 [references/ipatool/search.md](references/ipatool/search.md)。

```bash
"$IPATOOL" search "应用名" --limit 10 --platform iphone --keychain-passphrase "$KC" --format json --non-interactive > "$TMP/search.json"
```

- 搜索范围跟随账户的 App Store 区域（storefront），v2.4.0 不支持指定国家/地区。
- `--platform` 可选 `iphone` / `ipad` / `appletv`，留空为 iPhone 与 iPad 混合搜索。
- 结果在 `apps` 数组中，每项含 `id`（数值 ID）、`bundleID`、`name`、`version`、`price`（注意结果行没有 `success` 字段，含 `apps` 的 info 行即结果行；字段名与 iTunes API 的 `trackId` / `bundleId` / `trackName` 不同）。`price` 为 0 即免费。
- 把候选列表（名称、版本、价格、bundleId）呈现给用户选择，不要替用户猜，并附上 App Store 直达链接（写法与区域限制见 [references/app-store-links.md](references/app-store-links.md)）。例外：用户给出明确挑选标准并委托时（如「挑评分最高的免费番茄钟」），可用 iTunes Search API 补查评分等信息后按标准选定（用法见 [references/itunes-search.md](references/itunes-search.md)），并向用户说明所选应用与依据。

## 第 3 步：购买（获取许可）

命令用法与输出详见 [references/ipatool/purchase.md](references/ipatool/purchase.md)。

下载前账户必须持有该 App 的许可。购买会改变账户的已购列表，执行前**必须向用户确认目标应用**（名称 + bundleId），得到明确同意再执行。用户委托挑选的场景也不例外：按标准选定后，复述所选应用（名称、bundleId、评分依据）请求确认，同意后才执行：

```bash
"$IPATOOL" purchase -b "<bundleId>" --keychain-passphrase "$KC" --format json --non-interactive > "$TMP/purchase.json"
```

- 仅对免费 App（`price` 缺失或为 0）直接执行；付费 App 必须先向用户说明可能产生扣费并取得明确同意。
- 输出 `"alreadyOwned":true` 表示账户已持有许可，直接进入下载。

## 第 4 步：下载 IPA

命令用法与输出详见 [references/ipatool/download.md](references/ipatool/download.md)；要下载历史版本，先查 [references/ipatool/versions.md](references/ipatool/versions.md)。

```bash
"$IPATOOL" download -b "<bundleId>" -o "<输出目录或完整文件路径>" --keychain-passphrase "$KC" --format json --non-interactive > "$TMP/download.json"
```

- `-o` 传目录时自动按 `<bundleId>_<trackId>_<版本>.ipa` 命名，省略则下载到当前工作目录。先确认输出目录存在且可写。
- `download` 内置最多 3 次自动重试（凭据过期会自动重登）；加 `--purchase` 会在缺许可时自动购买——仅在用户已同意购买的前提下使用。
- 大型应用有数百 MB，耗时长：为命令设置足够的超时，或放后台执行并轮询完成状态。
- 成功输出 `"success":true` 与 `"output":"<文件路径>"`。把该路径报告给用户，并用 `ls -la` 确认文件真实存在、大小合理。

下载完成即达成目标。除非用户要求，不要主动 `auth revoke`——它会清除本机凭据，导致下次重新登录。

## 输出解析与编码（重要）

- ipatool 的 `--format json` 输出是 JSONL：每行一个独立的 JSON 对象，结果行带 `"success":true`，错误行形如 `{"level":"error","error":"…","success":false}`。逐行解析，不要把整个文件当一个 JSON 读。
- 输出为 UTF-8，一律重定向到文件再按 UTF-8 读取（如上所示），不要依赖终端直接显示——中文 Windows 控制台默认 GBK，会把中文应用名打成乱码。必须在 PowerShell 里查看输出时，先执行 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`。
- 本仓库所有文本文件以 UTF-8 存储；Windows PowerShell 5.1 解析含中文注释的 `.ps1` 需要 BOM，因此 `scripts/` 下的脚本只使用 ASCII 字符。

## 安全规则

- 不向用户索要 Apple ID 密码与双重验证码；用户主动在对话中提供时，引导其改用交互式登录。密码与验证码不得写入任何日志、git 提交、对话总结。keychain passphrase 除用户同意的 `~/.ipatool/passphrase` 外不做持久化；业务命令的传参是 ipatool 的设计使然，但不要额外回显或复制。
- 向用户展示登录状态时只显示姓名与邮箱。
- 脚本安装的 ipatool 经过 SHA-256 校验，不要引导用户从其他来源获取 ipatool。
