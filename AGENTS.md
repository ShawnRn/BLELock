# 仓库指南 (BLELock)

## 项目结构与模块详细说明

### 1. 核心应用 (`BLELock/`)
- `AppDelegate.swift`: **核心协调器**。负责应用生命周期、菜单栏 UI 管理、用户通知触发以及退出鉴权逻辑。
- `BLE.swift`: **蓝牙执行引擎**。封装了 `CBCentralManager`，负责设备扫描、信号监测（RSSI）、自动距离判断及锁定触发。
- `LEDeviceInfo.swift`: 蓝牙低功耗设备信息解析。处理制造商特定数据（如 Apple 设备的特定 payload）。
- `appleDeviceNames.swift`: 设备型号映射表。将蓝牙广播中的硬件标识符转换为可读的设备名称（如 "iPhone 15 Pro"）。
- `checkUpdate.swift`: 简单的版本更新检查逻辑。
- `AboutBox.swift`: 自定义“关于”窗口的实现。

### 2. 资源与本地化
- `Base.lproj/`, `zh-Hans.lproj/` 等: 包含 `Localizable.strings`（界面文本）和 `InfoPlist.strings`（系统权限标题）。
- **蓝牙权限说明**: `InfoPlist.strings` 中的 `NSBluetoothAlwaysUsageDescription` 必须在所有支持的语言中进行本地化，以确保用户在首次授权时看到母语提示。

## 开发最佳实践

### 退出鉴权逻辑
- **安全性**: 采用 TouchID / 密码鉴权保护退出过程。
- **系统适配**: 务必保留针对系统关机/重启的豁免逻辑（监听 `willPowerOffNotification`），防止应用阻塞系统核心流程。

### 状态管理与通知
- **通知标题**: 通知应区分触发原因。使用 `lost` 时代表信号丢失，使用 `away` 时代表物理距离过远。
- **UI 更新**: 在操作菜单（如更新 RSSI 或移除设备）时，需注意 `isDeviceMenuOpen` 的状态，避免产生不必要的 UI 渲染冲突或警告。

### 本地化规范
- **禁止硬编码**: 任何用户可见的字符串都应通过 `t("key")`（在 `AppDelegate` 中定义的辅助函数）调取。
- **排版**: 中文 README 文档应统一使用弯引号 (“ ” 和 ‘ ’)。

### 构建验证
- 每次修改核心逻辑后，建议在 Xcode 中执行 `Product -> Build` 或使用命令行 `xcodebuild` 验证。
- 确保没有编译器警告（Warnings），特别是与 `MainActor` 或 Swift 6 并发相关的警告。

## 更新日志撰写规范
保持简洁、专业。
- **动词开头**: “修复”、“新增”、“优化”、“重构”。
- **示例**:
    - `修复了在菜单打开时新设备无法加载的 bug。`
    - `新增为蓝牙权限请求说明添加 8 国语言本地化支持。`
    - `优化了锁定通知的标题显示，使其能区分“信号丢失”与“距离远离”。`
