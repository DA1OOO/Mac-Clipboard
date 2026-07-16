# Mac Clipboard

一个轻量、私密、在本机运行的 macOS 菜单栏剪贴板历史工具。

它会记录你复制过的纯文本，通过菜单栏或全局快捷键快速搜索并再次复制。当前版本没有账号、云同步、遥测或网络请求。

![MacClipboard 剪贴板历史界面](image.png)

## 功能

- 自动监听 macOS 系统剪贴板中的纯文本。
- 点击菜单栏剪贴板图标或按 `⌘⇧V` 打开历史。
- 支持搜索、点击复制、回车复制第一条结果。
- 自动去重；重复内容会移动到列表顶部。
- 支持单条删除、全部清空和暂停监听。
- 历史上限可设置为 25、50、100、200 或 500 条。
- 仅在本机保存 JSON 历史文件。

当前版本暂不记录图片、文件、富文本或 HTML。

## 系统要求

- macOS 13 或更高版本
- Apple Command Line Tools
- Swift 6

使用脚本构建不需要安装完整 Xcode。

## 快速开始

从源码直接运行：

```bash
./Scripts/run.sh
```

启动后应用只出现在菜单栏，不会显示 Dock 图标。复制一段文本，再点击菜单栏图标或按 `⌘⇧V` 查看历史。

## 构建本地应用

```bash
./Scripts/build-app.sh
open dist/MacClipboard.app
```

构建结果位于：

```text
dist/MacClipboard.app
```

脚本执行 Swift Release 构建，组装标准 macOS app bundle，并使用 ad-hoc 签名供本机运行。`dist/` 和 `.build/` 已被 Git 忽略，不会提交到仓库。

如果 macOS 首次打开时阻止应用，可在“系统设置 → 隐私与安全性”中确认打开。当前版本不需要辅助功能权限。

## 使用方法

1. 启动 MacClipboard。
2. 在任意应用中复制文本。
3. 按 `⌘⇧V` 或点击菜单栏剪贴板图标。
4. 输入关键词筛选历史。
5. 点击某一条，或按回车复制第一条搜索结果。

面板设置中可以调整历史数量、暂停监听或清空全部历史。

## 架构概览

```text
NSPasteboard
    ↓ changeCount polling
ClipboardStore
    ├── ClipboardHistoryRules → 去重、排序、数量限制
    ├── HistoryPersistence    → 本地 JSON
    └── SwiftUI Views         → 搜索、复制、删除、设置

StatusBarController → NSStatusItem + NSPopover
GlobalHotKey        → ⌘⇧V
```

Swift Package 包含三个 target：

| Target | 职责 |
| --- | --- |
| `MacClipboardCore` | 不依赖 UI 的数据模型和历史规则 |
| `MacClipboard` | SwiftUI/AppKit 菜单栏应用 |
| `MacClipboardSelfTests` | 无需 XCTest 的核心逻辑自检 |

更详细的目录结构、维护约束和验证清单见 [AGENTS.md](AGENTS.md)。

## 自检与开发验证

运行核心逻辑自检：

```bash
./Scripts/self-test.sh
```

当前自检覆盖：

- 新内容插入顶部和历史数量限制。
- 重复内容去重并保留稳定 ID。
- 忽略空白剪贴板内容。

完整验证：

```bash
./Scripts/self-test.sh
./Scripts/build-app.sh
plutil -lint Resources/Info.plist
codesign --verify --deep --strict dist/MacClipboard.app
```

## 本地数据与隐私

历史文件位于：

```text
~/Library/Application Support/MacClipboard/history.json
```

剪贴板管理器在运行期间能够读取复制的文本。复制密码、Token 等敏感内容前，可以在设置中暂停监听；也可以随时清空历史。

MacClipboard 当前不会连接网络或上传数据。删除本地历史文件不会影响系统剪贴板。

## 项目结构

```text
Resources/                  App bundle 配置
Scripts/                    运行、自检和构建脚本
Sources/MacClipboardCore/   纯 Swift 核心规则
Sources/MacClipboard/       macOS 应用、服务和界面
Sources/MacClipboardSelfTests/  核心自检入口
Package.swift               SwiftPM 配置
```

## 已知限制

- 仅支持纯文本。
- 全局快捷键目前固定为 `⌘⇧V`，暂不支持自定义。
- 重新登录后不会自动启动，需要手动打开应用。
- 本地历史当前为明文 JSON，请勿把历史文件提交或分享。
