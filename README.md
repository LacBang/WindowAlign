# WindowAlign

WindowAlign 是独立的 macOS 菜单栏窗口管理器。它通过辅助功能 API 直接调整当前窗口，不调用快捷指令里的“移动窗口”动作，也没有网络请求、账号或订阅。

如果 Align 或其他窗口管理器占用了相同的 `⌘⌃` 快捷键，请先退出，以免热键冲突。WindowAlign 不会修改或停用那些应用。

## 功能

- 菜单栏展示半屏、四分屏、三分屏、全屏四组快捷键。点击任一布局或其快捷键文字，即可调整打开菜单前聚焦的窗口。
- 全局默认快捷键为 `⌘⌃` + 方向键（半屏）、I/O/K/L（四角）、X/B/Z（三分屏）、F（填满可用区域）。
- 点击菜单中的“修改快捷键…”进入设置窗口，点选任一快捷键后直接按新组合键；Esc 取消，Delete 清除，可恢复默认。设置会保存在本机。
- 独立矢量菜单栏小图标与应用图标。
- `windowalign://left` 等 URL 动作仍可供快捷指令“打开 URL”使用。

## 安装

从发布页下载与版本号对应的安装包，例如 `WindowAlign-0.1.0.dmg` 或 `WindowAlign-0.1.0.pkg`。两种方式都会把应用装进 `/Applications`。WindowAlign 是菜单栏应用（`LSUIElement`），打开后看菜单栏图标，而不是程序坞。

### 磁盘镜像（DMG）

打开 `WindowAlign-<版本>.dmg`，把 WindowAlign 拖到“应用程序”文件夹，再从启动台或“应用程序”打开它。

### 安装包（PKG）

运行 `WindowAlign-<版本>.pkg`。安装程序会显示简短说明和 MIT 许可证，并把 `WindowAlign.app` 安装到 `/Applications`。安装结束时会尝试打开一次应用，以便马上出现首次授权窗口。

### 首次打开：辅助功能权限

尚未获得辅助功能权限时（包括首次打开，以及权限后来被关掉），会弹出“需要辅助功能权限”窗口，并暂时把应用调到前台：

- 窗口说明：WindowAlign 需要辅助功能权限，才能移动和调整其他应用的窗口；这是 macOS 的系统保护；授权后才能使用快捷键和菜单栏布局。应用无网络请求，不会上传窗口内容。
- 点击“打开系统设置”会打开“隐私与安全性 → 辅助功能”，并让系统把 WindowAlign 列入该页面。请打开 WindowAlign 的开关。
- 如果列表里已有 WindowAlign 但无法使用，先移除再重新添加，然后回到本窗口。
- 授权完成后，窗口会变成“已授权，可以开始使用”，并随即关闭。
- 选择“稍后”可先关掉窗口。之后可从菜单栏图标里的“检查辅助功能权限…”重新打开。权限被撤销后，下次启动也会再次出现该窗口。

### Gatekeeper

脚本默认只做 ad-hoc 签名（`codesign -`），不包含 Apple Developer ID 证书，也不会公证。从 GitHub 下载后，macOS 可能提示无法打开或来自身份不明的开发者。请在 Finder 里对安装包或 `WindowAlign.app` 右键 → 打开，并确认打开；较新的系统也可能要到“系统设置 → 隐私与安全性”里点“仍要打开”。维护者日后若用 Developer ID 公证，这一步才可以省去。

不需要证书也能完成本地构建。若以后有签名身份，可以选用下面的环境变量，未设置时保持 ad-hoc、安装包不签名：

```bash
export WINDOWALIGN_CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)"
export WINDOWALIGN_INSTALLER_IDENTITY="Developer ID Installer: Name (TEAMID)"
```

## 使用

1. 若其他窗口管理器占用了相同快捷键，请先退出。
2. 打开 `/Applications` 里的 WindowAlign，按上面的授权窗口完成辅助功能授权。
3. 菜单栏出现重叠窗口图标后，选中普通应用窗口，按菜单所示快捷键测试布局。
4. 原快捷指令中如有系统“移动窗口”动作，可用“打开 URL”动作访问 `windowalign://left`、`windowalign://right` 等；若只需热键，可以直接删除该快捷指令动作。

URL 名称：`left right top bottom full center topLeft topRight bottomLeft bottomRight leftThird middleThird rightThird leftTwoThirds rightTwoThirds nextScreen previousScreen restore`。

## 从源码构建

需要 macOS 13 或更高版本，以及 Xcode 命令行工具（`swiftc`、`codesign`）。打包还需要 `hdiutil`、`pkgbuild` 和 `productbuild`。

```bash
./build.sh
```

这会在 `outputs/WindowAlign.app` 生成应用并做 ad-hoc 签名。`outputs/`、`build/`、`.dmg` 和 `.pkg` 都不会进入 git。

生成带版本号的 DMG（应用和“应用程序”替身）以及安装到 `/Applications` 的 PKG：

```bash
./Scripts/package.sh
```

等价写法是 `./build.sh package`。当前版本会得到 `outputs/WindowAlign-0.1.0.dmg` 和 `outputs/WindowAlign-0.1.0.pkg`。这些脚本只能在 macOS 上真正打出安装包。

纯布局测试：

```bash
swiftc -module-cache-path build/module-cache Sources/Layout.swift Tests/LayoutTests.swift -o build/LayoutTests && build/LayoutTests
```

## 边界

需辅助功能许可；部分系统窗口或应用自身限定的最小尺寸不能强制改变。当前版本未实现拖拽边缘磁吸、圆形热键菜单和开机自启。通过 URL 仍可调用居中、跨屏和恢复等扩展布局，但菜单只展示四组常用布局。

## 技术决策

采用 AppKit + Accessibility + Carbon 热键，而非 Tauri：这里没有复杂内容界面，原生 API 更轻量，也避开了快捷指令执行器。快捷键设置由 `UserDefaults` 本机保存；无网络请求、数据库或订阅逻辑。窗口坐标通过主显示器顶部在 AX 顶左坐标与 Cocoa 底左坐标之间换算，布局使用各显示器的 `visibleFrame`。
