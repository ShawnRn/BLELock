# BLELock

## 注意：本应用现在是一个自动锁定工具。出于安全和简化考虑，已移除自动解锁功能。

![CI](https://github.com/ShawnRn/BLELock/workflows/CI/badge.svg)
![Github All Releases](https://img.shields.io/github/downloads/ShawnRn/BLELock/total.svg)

BLELock 是一个轻量级菜单栏工具，它通过检测 iPhone、Apple Watch 或任何其他蓝牙低功耗 (BLE) 设备的距离来**自动锁定**您的 Mac。

本文档另有以下语言版本：
- [English (英文)](README.md)

## 功能特性

- 无需安装 iPhone 端 App。
- **自动锁定**：当 BLE 设备远离或信号丢失时，自动锁定您的 Mac。
- **倒计时通知**：在锁定前通知您，给您留出保持活跃的机会。
- **Dock 图标切换**：可选择在 Dock 中显示或隐藏应用程序图标。
- 适用于任何定期从静态 MAC 地址传输信号的 BLE 设备。
- 锁定后可选择运行自定义脚本。
- 锁定后可选择使显示器进入睡眠状态。
- 离开时可选择暂停音乐/视频播放 (Now Playing)。

## 系统要求

- 支持蓝牙低功耗 (BLE) 的 Mac。
- 建议 macOS 26.0 (Tahoe) 或更高版本。
- 定期传输信号的 iPhone、Apple Watch 或其他 BLE 设备。

## 安装方法

### 手动安装

从 [Releases](https://github.com/ShawnRn/BLELock/releases) 下载 dmg 文件，移动“BLELock.app”到“应用程序”文件夹。

## 设置指南

首次启动时，应用会请求以下权限：

| 权限 | 说明 |
|------|------|
| 蓝牙 | 用于设备扫描和近距离检测。 |
| 通知 | BLELock 会在锁定屏幕前显示倒计时消息。 |

最后，点击菜单栏图标，选择 **Device (设备)**。选择您的设备，设置即告完成！

## 选项说明

| 选项 | 说明 |
|------|------|
| 立即锁定 (Lock Now) | 立即手动锁定屏幕。 |
| 锁定信号强度 (Lock RSSI) | 触发锁定的信号阈值。值越小表示设备需要离得越远。 |
| 锁定延迟 (Lock Delay) | 检测到设备远离后到执行锁定之前的持续时间。 |
| 超时 (Timeout) | 最后一次收到信号到执行锁定之间的时间。 |
| 近距唤醒 (Wake on Proximity) | 当设备靠近时唤醒显示器睡眠（注意：仍需手动输入密码）。 |
| 暂停“正在播放” | 锁定后暂停音乐或视频播放（Apple Music、Spotify 等）。 |
| 使用屏幕保护程序 | 启动屏幕保护程序而非立即系统锁定。 |
| 睡眠显示器 | 锁定后立即关闭显示器。 |
| 显示 Dock 图标 | 切换应用在 Dock 中的可见性。 |
| 被动模式 (Passive Mode) | 使用被动扫描以避免干扰其他蓝牙外设。 |
| 登录时启动 | 在您登录时自动启动应用。 |

## 常见问题排查

### 在列表中找不到我的设备
如果您的设备没有名称，它将显示为 UUID。尝试靠近/远离设备，通过 RSSI 值的变化来识别它。

### 频繁触发“信号丢失”锁定
增加 **Timeout (超时)** 值或尝试开启 **Passive Mode (被动模式)**。

## 致谢与许可

原项目由 [Takeshi Sone](https://github.com/ts1/BLEUnlock) 开发。由 Shawn Rain 进行品牌重塑和现代化重构。

MIT 许可证。版权所有 © 2026-present Shawn Rain。
