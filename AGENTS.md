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
- **排版**: 中文 README 文档应统一使用直角引号 (「『』」)；英文 README 文档应统一使用弯引号 (“ ” 和 ‘ ’)。

### 构建验证
- 每次修改核心逻辑后，建议在 Xcode 中执行 `Product -> Build` 或使用命令行 `xcodebuild` 验证。
- 确保没有编译器警告（Warnings），特别是与 `MainActor` 或 Swift 6 并发相关的警告。

## 近期经验与实操要点

- **多设备监控**  
  - 支持多选；锁定策略：仅当已出现过的任一已选设备判定为 away/lost 才触发。未曾出现过的已选设备不应导致锁定。  
  - 被动模式下关闭掉线计时器，直接视作在场，避免因不读 RSSI 而频繁误锁。  
  - 状态栏顶部标题使用 `attributedTitle` 多行展示：首行“已选择 X 台设备”，其余为左对齐圆点列表，行距加大。

- **扫描/菜单闪烁**  
  - `startScanning()` 应仅在需要时调用；关闭菜单时 `stopScanning()`，避免菜单频繁闪烁。  
  - 菜单打开时注意 `isDeviceMenuOpen` 再刷新标题，减少 AppKit 警告。

- **信号计时与节流**  
  - `resetSignalTimer` 仅在设备首次被发现后启动；否则不要计时，避免 Unknown/未见设备触发锁。  
  - 平滑 RSSI 时保留小窗口（最新 N=5），防止抖动。

- **持久化与启动恢复**  
  - 用户选择存储在 `UserDefaults.devices`（UUID 数组）。启动时直接恢复集合并启动扫描，不要因设备未现而清空选择。  
  - 设备删除时不要自动移除选择集合，以免暂时离线设备被误删。

- **睡眠/唤醒安全**  
  - 进入睡眠：暂停扫描以避免对系统休眠的潜在影响；唤醒后恢复扫描。  
  - 保留 `willPowerOffNotification` 豁免逻辑，确保关机/重启不被阻塞。

- **通知文案**  
  - 文案格式：“『Mac 名称』已由『失联/断开的 BLE 设备』锁定。” 双占位符，带句号。  
  - `reason` 区分 `lost`/`away`，并传入具体设备名；缺省回退 UUID。

- **故障排查速查**  
  1. 频繁误锁：检查是否在被动模式仍运行掉线计时；确认 `seenDevices` 是否只在发现时标记。  
  2. 顶部标题缺设备名：确认启动时已调用 `startScanning()` 并未清空 `monitoredUUIDs`；检查 `deviceNameMap` 更新。  
  3. 菜单闪烁：确保扫描开关与菜单开合同步；避免循环调用 `startScanning()`。  
  4. 休眠异常：确认睡眠时已 `stopScanning()`，唤醒后恢复扫描。

## 更新日志撰写规范
保持简洁、专业。
- **动词开头**: “修复”、“新增”、“优化”、“重构”。
- **示例**:
    - `修复了在菜单打开时新设备无法加载的 bug。`
    - `新增为蓝牙权限请求说明添加 8 国语言本地化支持。`
    - `优化了锁定通知的标题显示，使其能区分“信号丢失”与“距离远离”。`
