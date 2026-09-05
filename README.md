# IPAbuyer Skill

IPAbuyer Skill 是一个 agent 技能（Agent Skill），配合开源工具 [ipatool](https://github.com/majd/ipatool)，帮助 AI 助手快速**购买与下载 App Store 中的应用**（IPA 文件）。把「登录、搜索、购买、下载」的完整流程交给对话完成：你只需提供 Apple ID 凭据，剩下的由 AI 助手按本技能的指引执行。

与 [IPAbuyer 桌面版](https://github.com/ipabuyer/ipabuyer)（WinUI 3 应用，Microsoft Store 可下载）同源同能力，本技能面向习惯在终端与 AI 助手中工作的用户。

## 功能特性

- **一键安装 ipatool**：自动适配 Windows / macOS / Linux 与 CPU 架构（amd64 或 arm64），从 ipatool 官方 GitHub Releases 下载对应的可执行文件，SHA-256 校验通过后才安装。
- **完整购买下载流程**：登录 App Store（支持双重验证）→ 搜索应用 → 获取许可（购买）→ 下载 IPA，全部由 AI 助手按步骤完成。
- **免费 App 优先**：默认仅自动购买免费应用；付费应用必须经过用户明确确认，保护账户安全。
- **凭据本地加密**：Apple ID 凭据经 ipatool 加密存储在本机 `~/.ipatool/`，不上传任何服务器。
- **UTF-8 全流程**：搜索中文应用名、解析返回结果不乱码。

## 安装

1. 从本仓库的 [Releases](https://github.com/ipabuyer/Skill/releases) 页面下载 `IPAbuyer-Skill-<版本>.zip`。
2. 解压后把得到的 `ipabuyer` 目录放入你的 AI 助手的技能（Agent Skill）目录，例如跨工具通用的 `~/.agents/skills/`，最终路径为 `~/.agents/skills/ipabuyer`；具体位置以所用 AI 助手的文档为准。
3. 重启 AI 助手会话，即可通过自然语言触发。

## 使用示例

放置好技能后，直接对 AI 助手说：

- 「帮我下载微信的 IPA」
- 「搜索一下免费的番茄钟应用，挑一个评分高的买下来」
- 「把我上个月下载过的应用再下载一遍，备份到 D:\ipa-backup」

助手会自动：准备 ipatool →（首次）询问你的 Apple ID、密码与双重验证码并登录 → 搜索并列出候选 → 经你确认后购买 → 下载 IPA 到指定目录。

## 环境要求

- Windows 10 及以上、macOS 或 Linux（amd64 / arm64）。
- PowerShell、bash 或 zsh 任一可用（系统均自带其一）。
- 可访问 Apple 与 GitHub 的网络。
- 一个登录过 iCloud 与 App Store、且完成过至少一次有效购买的 Apple ID（苹果的账户政策要求）。

## 常见问题

无法获取双重验证码？

> 仅用手机号作为验证手段的账户收不到验证码，请到 <https://account.apple.com/> 获取后告诉助手。

账户、密码和验证码都正确，但无法登入？

> 受苹果账户政策限制，你的 Apple ID 需要登录过 iCloud 和 App Store，并在 App Store 中完成过一次有效购买。

为什么付费应用助手不直接帮我买？

> 为保证账户安全，技能默认仅自动购买免费应用；付费应用会先向你说明可能产生扣费，经你明确同意后才会继续。

更多问题见 [references/troubleshooting/faq.md](./references/troubleshooting/faq.md)。

## 开发信息

- 代码仓库：<https://github.com/ipabuyer/Skill>
- 更新日志：<https://github.com/ipabuyer/Skill/blob/main/CHANGELOG.md>
- 上游工具：[ipatool](https://github.com/majd/ipatool)

## 版权信息

Copyright © 2026 IPAbuyer

以 MIT 许可证发布，详见 [LICENSE](./LICENSE)。本技能中引用的 ipatool 遵循其原有的许可证。
