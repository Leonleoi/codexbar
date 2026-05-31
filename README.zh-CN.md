# CodexBar 🎚️

[English](README.md) | [简体中文](README.zh-CN.md)

> 把 AI 编程服务的额度、余额和重置时间放到 macOS 状态栏里。

这是基于原项目 [steipete/CodexBar](https://github.com/steipete/CodexBar) 修改的自定义版本。本版本保留原来的状态栏菜单，并新增 Liquid Glass 风格的桌面设置菜单，方便集中管理所有功能和 provider 设置。

## 下载

自定义版本下载地址：

<https://github.com/Leonleoi/codexbar/releases>

当前上传的 app 包：

<https://github.com/Leonleoi/codexbar/releases/download/desktop-menu-debug-2026-05-31/CodexBar-debug-ad-hoc.zip>

> 注意：当前上传的是 ad-hoc signed debug build，适合本地使用，不是 notarized Developer ID 正式分发包。

## 系统要求

- macOS 14+ (Sonoma)

## 这个版本改了什么

- 新增桌面端设置菜单。
- 桌面菜单使用 Liquid Glass 风格视觉设计。
- 原状态栏菜单保留，不影响原来的使用方式。
- 所有原有设置功能仍然保留。
- 优化了桌面菜单的渲染性能，减少掉帧。
- README 和 Release 指向本仓库的自定义构建。

## 主要功能

- 在 macOS 状态栏显示多个 AI provider 的额度、余额和重置时间。
- 支持 Codex、OpenAI、Claude、Cursor、Gemini、Copilot、Grok、GroqCloud、MiniMax、Kiro、OpenRouter、AWS Bedrock 等 provider。
- 支持一个 provider 一个状态栏图标，也支持 Merge Icons 合并显示。
- 支持按 provider 查看 session、weekly、monthly 等不同额度窗口。
- 支持 API key、OAuth、浏览器 cookie、本地 CLI、本地文件等多种数据来源。
- 支持 provider 状态检测、余额显示、成本扫描、用量图表和通知。
- 隐私优先：尽量复用本机已有登录状态和本地配置，不保存密码。

## 首次使用

1. 下载并解压 `CodexBar-debug-ad-hoc.zip`。
2. 打开 `CodexBar.app`。
3. 在状态栏里打开 CodexBar 菜单。
4. 进入 `Settings -> Providers`，启用你正在使用的 provider。
5. 根据 provider 要求配置 API key、OAuth、浏览器 cookie 或本地 CLI 登录。
6. 如果使用本版本新增的桌面菜单，可以从状态栏菜单打开桌面端设置入口。

## 设置入口说明

- `General`：语言、开机启动、刷新频率、通知等通用设置。
- `Providers`：启用、禁用和配置各个 AI provider。
- `Display`：状态栏图标、文字、用量条、重置时间显示方式和合并图标模式。
- `Advanced`：诊断、路径、钥匙串访问和高级选项。
- `About`：版本、更新、项目链接和致谢。
- `Debug`：调试信息，仅在启用调试菜单时显示。

## 权限说明

CodexBar 可能会在部分场景请求以下 macOS 权限：

- 完全磁盘访问权限：用于读取 Safari cookie 或 local storage。不是所有 provider 都需要。
- 钥匙串访问：用于解密浏览器 cookie，或读取 OAuth/device-flow 凭据。
- 文件与文件夹权限：某些本地 CLI 或 provider 探测需要读取对应配置目录。

CodexBar 不会在后台请求屏幕录制或辅助功能权限。浏览器 cookie 和 API key 只在你启用对应 provider 时使用。

## 从源码构建

```bash
swift build
```

运行测试：

```bash
swift test
```

项目检查：

```bash
make check
```

## 上游项目

原始项目：

<https://github.com/steipete/CodexBar>

本仓库是自定义版本，不是 GitHub fork 标记仓库，但提交历史保留了上游项目来源。
