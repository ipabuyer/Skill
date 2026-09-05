# 更新日志

## v1.0.0-beta.1

1. 发布首个版本：配合 ipatool 实现「登录 App Store（支持双重验证）→ 搜索 → 购买（获取许可）→ 下载 IPA」的完整流程
2. 新增三平台 ipatool 安装脚本（PowerShell / bash / zsh）：自动检测系统与 CPU 架构，只下载对应一份，经 SHA-256 与可执行文件格式校验后安装到指定目录
3. 参考文档按工作流步骤拆分（references/ipatool/ 下按命令单文件、references/troubleshooting/ 按问题类型），agent 走到哪步读哪份
4. 新增 iTunes Search API 评分补查：用户给出明确挑选标准（如「挑评分最高的免费番茄钟」）时可按标准推荐，购买前仍复述所选应用请求确认
5. 新增 App Store 直达链接指引：展示候选与结果时附商店页面链接，并明确中国大陆区对外区应用页面强制跳转首页的行为及应对方式
6. 约定账户安全底线：默认仅自动购买免费 App，付费 App 须经用户明确确认；凭据经 ipatool 加密存储于本机，不写入日志与提交
7. 全流程 UTF-8 处理：支持中文搜索词，命令输出一律重定向文件后按 UTF-8 读取，规避 GBK 终端乱码
8. 推送 tag 后由 GitHub Action 自动按白名单打包技能并发布至 GitHub Release
