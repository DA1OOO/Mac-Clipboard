# AGENTS.md

本文件面向在此仓库中工作的 Codex、自动化 Agent 和开发者。

## 项目目标

MacClipboard 是一个轻量、私密、仅在本机运行的 macOS 菜单栏剪贴板历史工具。

当前范围：

- 监听并保存系统剪贴板中的纯文本。
- 使用菜单栏图标或可自定义的全局快捷键（默认 `⌘⇧V`）打开历史面板。
- 支持搜索、再次复制、回车填入原应用输入光标、去重、删除、清空和暂停监听。
- 历史数据只保存在本机，不包含网络请求或云同步。

除非用户明确要求，不要引入账号、遥测、网络同步或第三方服务。

## 技术栈与系统要求

- Swift Package Manager
- SwiftUI：列表、搜索和设置 UI
- AppKit：`NSPasteboard`、`NSStatusItem`、非激活 `NSPanel`
- ApplicationServices/CoreGraphics：辅助功能焦点检测和定向粘贴事件
- Carbon HIToolbox：全局快捷键
- 最低系统版本：macOS 13
- Bundle ID：`com.da1ooo.MacClipboard`

完整 Xcode 不是必需项；Apple Command Line Tools 和 Swift 6 可以完成命令行构建。

## 目录结构

```text
.
├── Package.swift
├── Resources/
│   └── Info.plist                 # app bundle 元数据、Bundle ID、菜单栏代理配置
├── Scripts/
│   ├── run.sh                     # 从源码运行应用
│   ├── self-test.sh               # 运行零依赖核心自检
│   └── build-app.sh               # Release 构建并生成、临时签名 .app
├── Sources/
│   ├── MacClipboardCore/
│   │   └── ClipboardItem.swift    # 数据模型和纯历史规则
│   ├── MacClipboard/
│   │   ├── MacClipboardApp.swift  # App/Delegate 入口和根依赖装配
│   │   ├── Services/              # 剪贴板、持久化、状态栏和快捷键
│   │   └── Views/                 # 历史面板与设置界面
│   └── MacClipboardSelfTests/
│       └── main.swift             # 不依赖 XCTest 的自检程序
└── dist/                          # 本地构建产物；必须保持 Git 忽略
```

## 架构与数据流

1. `AppDelegate` 创建唯一的 `ClipboardStore`，启动监听并装配 `StatusBarController`。
2. `ClipboardStore` 每 0.5 秒比较 `NSPasteboard.changeCount`；发生变化时读取纯文本。
3. `ClipboardHistoryRules` 负责忽略空文本、将重复项移到首位并应用历史数量上限。
4. `HistoryPersistence` 将 `[ClipboardItem]` 以 JSON 原子写入本机 Application Support。
5. `ClipboardHistoryView` 观察 store，负责搜索、选择、删除和再次复制。
6. `StatusBarController` 使用 `NSStatusItem` 和非激活 `NSPanel` 承载 SwiftUI UI；打开面板时只 `orderFront`，不得令面板成为 Key Window 或自动聚焦 Search。
7. `GlobalHotKey` 持久化快捷键设置，并在修改后重新注册全局快捷键。
8. 面板显示期间使用临时 Carbon 热键接收上下、回车和 Esc；`FocusedInputPaster` 记录原应用，并在回车时校验该应用当前仍有可编辑焦点，再发送 `⌘V`。

保持以下边界：

- 与平台无关的数据模型和规则放入 `MacClipboardCore`，不要依赖 AppKit/SwiftUI。
- 系统剪贴板、文件存储、菜单栏和快捷键逻辑放入 `Services`。
- View 只负责 UI 状态和调用 store，不直接读写文件或轮询剪贴板。
- `ClipboardStore` 是主线程对象；更新 `@Published` 状态时保持 `@MainActor`。
- 辅助功能代码只检查焦点元素是否提供文本选择范围，不读取或记录输入框正文。
- 动态列表必须使用 `ClipboardItem.id` 作为稳定标识，不使用数组下标作为 ID。

## 构建与验证

在仓库根目录运行：

```bash
# 核心逻辑自检
./Scripts/self-test.sh

# 从源码启动
./Scripts/run.sh

# 构建本地 app bundle
./Scripts/build-app.sh

# 启动构建产物
open dist/MacClipboard.app
```

`build-app.sh` 会：

1. 执行 Release 构建。
2. 将可执行文件和 `Info.plist` 组装到 `dist/MacClipboard.app`。
3. 使用 ad-hoc 签名，供本机运行。

ad-hoc 签名按当前二进制哈希标识应用；代码变化后，已有辅助功能授权会失效。涉及辅助功能的手动验证必须在最后一次构建后重新授权，或使用稳定的开发者签名身份。

本机 Command Line Tools 若默认 SDK 与 Swift 编译器版本不匹配，脚本会优先使用已存在的 `/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk`。其他机器没有该 SDK 时，脚本会使用系统默认 `SDKROOT`。

完成代码修改后至少运行：

```bash
./Scripts/self-test.sh
./Scripts/build-app.sh
plutil -lint Resources/Info.plist
codesign --verify --deep --strict dist/MacClipboard.app
git diff --check
```

如果改动涉及菜单栏、剪贴板、快捷键或 UI，还需要实际启动应用进行手动验证。

## 本地数据与隐私

历史数据位于：

```text
~/Library/Application Support/MacClipboard/history.json
```

注意事项：

- 不要把真实剪贴板历史复制进测试夹具、日志或提交内容。
- 不要提交 `.env`、密钥、Token、证书、SSH 文件或开发者本机绝对路径。
- 不要打印剪贴板正文；错误日志只记录错误描述。
- 不要通过辅助功能接口读取、记录或持久化其他应用的输入框正文。
- 新增网络能力前必须获得用户明确同意，并同步更新 README 的隐私说明。

## Git 与产物约束

以下内容必须保持未跟踪：

- `.build/`
- `dist/`
- `.DS_Store`
- `*.app`、编译后二进制和 Swift 模块缓存
- `~/Library/Application Support/MacClipboard/history.json`

提交前检查：

```bash
git status --short --ignored
git ls-files | rg '(^|/)(\.build|dist)(/|$)|\.app(/|$)'
```

第二条命令应无输出。提交身份优先使用 GitHub noreply 邮箱，避免公开个人邮箱。

## 代码风格

- 沿用 Swift API Design Guidelines 和现有两空格缩进。
- 使用 `swift-format` 格式化 `Sources/` 下的 Swift 文件。
- 优先小型、职责单一的类型；不要把平台逻辑塞进 SwiftUI `body`。
- 文件写入使用原子操作；持久化失败不应令菜单栏进程崩溃。
- 新增纯逻辑时同步扩充 `MacClipboardSelfTests`。
- 不使用强制解包、`try!` 或无说明的 `fatalError`。
