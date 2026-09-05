# 开发指南

本文档面向本仓库的开发者（含 AI 辅助开发），描述仓库结构、编码约定、打包发布流程与测试方法。基准约束见 [AGENTS.md](./AGENTS.md)（该文件不允许修改），本文档鼓励随开发进度持续更新。

## 项目定位

本仓库是一个 agent skill（AI 助手技能），配合 [ipatool](https://github.com/majd/ipatool) 帮助用户通过 AI 助手购买与下载 App Store 中的应用。它与 [IPAbuyer 桌面版](https://github.com/ipabuyer/ipabuyer)同源同能力：桌面版把 ipatool 封装进 WinUI 3 界面，本仓库把 ipatool 的使用流程写成 AI 助手可执行的指引（SKILL.md）与辅助脚本（scripts/）。桌面版内置 amd64 与 arm64 两份 ipatool 是为打包分发；本技能只在用户机器上运行，安装脚本按当前 CPU 架构只下载一份（可用 `-Architecture` 覆盖）。

## 仓库结构

```text
IPAbuyer.Skill/
├── SKILL.md                        # 技能主文件：工作流程、命令用法、安全规则
├── references/
│   ├── ipatool/
│   │   ├── commands.md             # ipatool 命令参数与用法（按 v2.4.0 验证）
│   │   └── output.md               # JSONL 输出格式与解析规则
│   └── troubleshooting/
│       ├── errors.md               # 错误对照表
│       └── faq.md                  # 账户要求与常见问题
├── scripts/
│   ├── get-ipatool-release.ps1     # Windows（PowerShell）：从 ipatool 官方 Release 下载并安装可执行文件
│   ├── get-ipatool-release.sh      # macOS / Linux（bash）：同上
│   └── get-ipatool-release.zsh     # macOS / Linux（zsh）：同上
├── bin/                            # 上述脚本的默认下载目录（不入库，运行脚本后生成）
├── README.md                       # 面向使用者的介绍、安装、使用示例
├── DEVELOPMENT.md                  # 本文档
├── CHANGELOG.md                    # 更新日志（发布说明引用此文件）
├── LICENSE                         # MIT 许可证
├── VERSION                         # 当前版本号（发布流程读取）
├── tag.ps1                         # 本地打 tag 并推送的辅助脚本
├── AGENTS.md                       # AI 开发基准约束（禁止修改）
├── .markdownlint.jsonc             # markdownlint 规则（中文文档场景定制）
├── .gitignore                      # 忽略打包目录 dist/ 与可执行文件目录 bin/
└── .github/workflows/release.yml   # 推送 tag 后打包发布到 GitHub Release
```

## 硬性约束

1. AGENTS.md 是基准文件，不允许修改；本文件为详细开发内容，鼓励修改以同步最新开发进度。
2. 所有文本文件以 UTF-8 格式存储、读取和修改；实际开发中注意终端的 GBK 与 UTF-8 问题（详见下文「编码约定」）。
3. 所有 ipatool 命令示例必须加 `--format json` 与 `--non-interactive`，输出一律重定向到文件后按 UTF-8 读取。
4. 更新内置 ipatool 版本或准备发布前，提示用户确认上游正式版是否变化。

## 编码约定

本节是 GBK/UTF-8 问题的落地规则：

- **Markdown 与文档**：UTF-8（无 BOM）、LF 换行。`.gitattributes` 已强制 `.md` 为 LF。
- **PowerShell 脚本**：Windows PowerShell 5.1 按 ANSI（中文系统即 GBK）解析无 BOM 的 `.ps1`，含中文注释或字符串时会乱码甚至解析失败。因此 `scripts/` 下的脚本**只使用 ASCII 字符**（注释与输出均为英文）；如未来必须写中文，需保存为带 BOM 的 UTF-8（仓库内 `tag.ps1` 即为此格式）。
- **Shell 脚本**：`.sh` 与 `.zsh` 同样只用 ASCII 字符，保存为 UTF-8、LF；只使用 bash 与 zsh 共有的语法（不含 zsh 方言），因此能统一用 shfmt 按 bash 方言格式化。改动后执行 `shfmt -w -i 4 -ci -ln bash scripts/get-ipatool-release.sh scripts/get-ipatool-release.zsh`。
- **运行 ipatool**：其 JSON 输出固定 UTF-8，而中文 Windows 控制台默认 GBK，直接在终端看输出会乱码。技能内约定的做法是把 stdout 重定向到文件再按 UTF-8 读取；PowerShell 场景可先执行 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`。
- 用 `file <路径>` 或 `Get-Content -Encoding` 抽查可疑文件的编码。

### 已知坑：tar 的解析顺序

`scripts/get-ipatool-release.ps1` 解压时固定使用 `C:\Windows\System32\tar.exe`（Windows 10 1803+ 自带），而不是 PATH 中的 `tar`。原因：从 Git Bash 环境调用时 PATH 里 GNU tar（`/usr/bin/tar`）优先，它会把 `D:\...` 形式的参数当作远程主机名（报 `Cannot connect to D: resolve failed`），导致解压失败。修改脚本时保留 `$tarExecutable` 的解析逻辑，不要改回裸的 `& tar`。

## 打包与发布

### 发布机制

推送 `v*` 格式的 tag 后，GitHub Action（`.github/workflows/release.yml`）调用 `BlazeSnow/release-skill-action` 打包发布。该 Action 按**白名单**从 `base-dir`（当前为仓库根目录）选取文件：

| 文件 | 状态 |
| --- | --- |
| `SKILL.md` | 必需，缺失时 Action 直接报错 |
| `references/`、`scripts/` | 可选，整目录打包 |
| `CHANGELOG.md`、`LICENSE`、`README.md`、`VERSION` | 可选 |

白名单之外的文件不会进入发布包；如需新增进包内容，放入上述目录，或在 workflow 中用 `extra-files` 指定。打包后 zip 内顶层目录名为 `ipabuyer`（来自 workflow 的 `skill-lower-name`），版本号优先级为：`VERSION` 文件首行 > `tag` 输入 > 当前 ref 名。

因此 **SKILL.md 的 frontmatter `name` 必须保持 `ipabuyer`**，与 zip 内顶层目录名一致，否则部分工具加载技能时会校验失败。

### 发布步骤

1. 更新 `VERSION`（当前内容 `v1.0.0-beta.1`；tag 含 `-` 时 Release 会标记为预发布）。
2. 在 `CHANGELOG.md` 追加对应版本条目（Release 说明直接链接到该文件）。
3. 提交全部改动并推送到远程。
4. 运行 `tag.ps1`（读取 `VERSION`、创建并推送 tag，需交互确认），GitHub Action 自动完成打包与发布。

### 修改 SKILL.md 的规范

- frontmatter 只需 `name` 与 `description`；`name` 固定为 `ipabuyer`。
- `description` 是技能触发的主要依据，要覆盖用户的常见说法（IPA、ipatool、App Store、下载、购买、备份等），可以适度「主动」一些。
- 正文控制在 500 行以内；命令参数、输出格式等细节放入 `references/`，由正文按步骤引导按需阅读。
- 命令示例必须可直接复制执行，且与 `references/ipatool/` 下的文档保持一致。

### 上游 ipatool 升级流程

1. 查看 [ipatool Releases](https://github.com/majd/ipatool/releases) 的最新正式版，运行新版的 `--help` 逐一核对参数变化。
2. 用新版本实测各命令的 `--format json` 输出结构（可参照 `references/ipatool/output.md` 的示例逐条比对）。
3. 更新 `references/ipatool/` 下的版本标注与受影响的参数、输出示例；`scripts/get-ipatool-release.ps1` 默认拉取最新正式版，通常无需改动。
4. 提交前提示用户确认上游正式版是否变化，以及是否需要在文档中锁定版本（如 `-Version 2.4.0`）。

## 本地测试

### Markdown 规范

```bash
npx markdownlint-cli "*.md" "references/**/*.md"
```

规则见 `.markdownlint.jsonc`（为中文文档关闭了行长、内联 HTML 等不适用项）。

### PowerShell 脚本语法

```bash
powershell -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('<脚本绝对路径>', [ref]$null, [ref]$errors); $errors"
```

无输出即无语法错误。

### Shell 脚本语法与格式

```bash
bash -n scripts/get-ipatool-release.sh
zsh -n scripts/get-ipatool-release.zsh   # 有 zsh 环境时
shfmt -d -i 4 -ci -ln bash scripts/get-ipatool-release.sh scripts/get-ipatool-release.zsh
```

`bash -n` / `zsh -n` 无输出即无语法错误；`shfmt -d` 无输出即格式符合（有差异时用 `-w` 直接改写）。macOS / Linux 路径的完整流程无法在 Windows 上执行，但脚本依赖的上游事实（资产名 `ipatool-<版本>-linux|macos-<架构>.tar.gz`、校验文件为纯 64 位十六进制、包内路径 `bin/`）已对照 ipatool 官方 Release 逐项核实，改动涉及这些假设时需重新验证。

### 安装脚本实测

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/get-ipatool-release.ps1 -Version 2.4.0
```

不传 `-OutputDir` 时默认安装到仓库根目录的 `bin/`（已被 .gitignore 按目录忽略，`git status` 应保持干净）；发布包场景建议显式指定 `-OutputDir "$LOCALAPPDATA/IPAbuyer/bin"`。

预期：自动检测 CPU 架构（`-Architecture amd64|arm64` 可覆盖），只下载该架构的压缩包、SHA-256 校验通过、输出 `Installed <arch>: <路径>`。重复运行应报「Destination already exists」，加 `-Force` 可覆盖。

### 技能行为测试

把仓库（或发布 zip 解压后的 `ipabuyer` 目录）放入 AI 助手的技能目录，用以下真实场景验证触发与流程：

1. 「下载微信的 IPA」——应触发技能并从第 0 步开始执行。
2. 「搜索免费番茄钟应用」——应先确认登录状态，再搜索并呈现候选。
3. 未提供凭据时的表现——应主动询问 Apple ID、密码与验证码，而不是跳过或编造。

注意：购买与下载会操作真实 Apple 账户，测试时使用用户授权的账户，付费应用一律停在确认环节。
