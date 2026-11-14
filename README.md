# WindowAlign

本机独立菜单栏窗口管理器。通过 macOS 辅助功能 API 直接调整当前窗口，不调用快捷指令里的“移动窗口”动作，也不修改 Align 的二进制、收据或订阅状态。

## 功能

- 菜单栏展示半屏、四分屏、三分屏、全屏四组快捷键。点击任一布局或其快捷键文字，即可调整打开菜单前聚焦的窗口。
- 全局默认快捷键为 `⌘⌃` + 方向键（半屏）、I/O/K/L（四角）、X/B/Z（三分屏）、F（填满可用区域）。
- 点击菜单中的“修改快捷键…”进入设置窗口，点选任一快捷键后直接按新组合键；Esc 取消，Delete 清除，可恢复默认。设置会保存在本机。
- 独立矢量菜单栏小图标与应用图标。
- `windowalign://left` 等 URL 动作仍可供快捷指令“打开 URL”使用。

## 使用

1. 退出原 Align，以免其 `⌘⌃` 热键抢占。
2. 打开 `WindowAlign.app`，在系统设置 → 隐私与安全性 → 辅助功能中允许它。
3. 再次打开应用，菜单栏出现重叠窗口小图标。选中普通应用窗口后，按菜单所示快捷键测试布局。
4. 原快捷指令中如有系统“移动窗口”动作，可用“打开 URL”动作访问 `windowalign://left`、`windowalign://right` 等；若只需热键，可以直接删除该快捷指令动作。

URL 名称：`left right top bottom full center topLeft topRight bottomLeft bottomRight leftThird middleThird rightThird leftTwoThirds rightTwoThirds nextScreen previousScreen restore`。

## 边界

需辅助功能许可；部分系统窗口或应用自身限定的最小尺寸不能强制改变。当前版本未实现拖拽边缘磁吸、圆形热键菜单、开机自启，也未安装到 `/Applications`；它不会自动停用旧 Align。通过 URL 仍可调用居中、跨屏和恢复等扩展布局，但菜单只展示用户指定的四组。

## 技术决策

采用 AppKit + Accessibility + Carbon 热键，而非 Tauri：这里没有复杂内容界面，原生 API 更轻量，也避开了快捷指令执行器。快捷键设置由 `UserDefaults` 本机保存；无网络请求、数据库或订阅逻辑。窗口坐标通过主显示器顶部在 AX 顶左坐标与 Cocoa 底左坐标之间换算，布局使用各显示器的 `visibleFrame`。

构建：`./build.sh`。纯布局测试：`swiftc -module-cache-path build/module-cache Sources/Layout.swift Tests/LayoutTests.swift -o build/LayoutTests && build/LayoutTests`。
