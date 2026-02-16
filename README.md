# BLELock

## Note: This app is now an Automatic Locking tool. Auto-Unlock has been removed for security and simplicity.

![Github Release](https://img.shields.io/github/v/release/ShawnRn/BLEUnlock)
![Github All Releases](https://img.shields.io/github/downloads/ShawnRn/BLEUnlock/total.svg)

BLELock is a small menu bar utility that **automatically locks** your Mac by proximity of your iPhone, Apple Watch, or any other Bluetooth Low Energy device. 

This document is also available in:
- [Chinese (简体中文)](README.zh-cn.md)

## Features

- No iPhone app is required.
- **Auto-Lock**: Automatically locks your Mac when your BLE device moves away or the signal is lost.
- **Countdown Notifications**: Notifies you before locking, giving you a chance to stay active.
- **Dock Icon Toggle**: Option to show or hide the application icon in the Dock.
- Works with any BLE devices that periodically transmit signals from a static MAC address.
- Optionally runs your own script upon locking.
- Optionally puts the display to sleep upon locking.
- Optionally pauses music/video playback (Now Playing) when you leave.

## Requirements

- A Mac with Bluetooth Low Energy support.
- macOS 26.0 (Tahoe) or later recommended.
- iPhone, Apple Watch, or another BLE device that transmits signal periodically.

## Installation

### Manual installation

Download the dmg file from [Releases](https://github.com/ShawnRn/BLEUnlock/releases), and move BLELock.app to the Applications folder.

## Setting up

On the first launch, it asks for the following permissions:

| Permission | Description |
|------------|-------------|
| Bluetooth | Required for device scanning and proximity detection. |
| Notification | BLELock shows a countdown message before locking the screen. |

Finally, from the menu bar icon, select **Device**. Select your device, and you're done!

## Options

| Option | Description |
|--------|-------------|
| Lock Screen Now | Manually locks the screen immediately. |
| Lock RSSI | Signal strength threshold to lock. Smaller value means the device needs to be farther away. |
| Delay to Lock | Duration of time before locking after the device is detected away. |
| Timeout | Time between last signal reception and locking. |
| Wake on Proximity | Wakes up the display from sleep when the device approaches (Note: Manual password entry still required). |
| Pause "Now Playing" | Pauses playback of music or video (Apple Music, Spotify, etc.) upon locking. |
| Use Screensaver | Launches screensaver instead of immediate system lock. |
| Sleep Display | Turns off the display immediately when locking. |
| Show Dock Icon | Toggles the visibility of the app in the Dock. |
| Passive Mode | Uses passive scanning to avoid interference with other Bluetooth peripherals. |
| Launch at Login | Automatically starts the app when you log in. |

## Troubleshooting

### Can't find my device in the list
If your device doesn't have a name, it will appear as a UUID. Move your device closer/farther to identify it by RSSI changes.

### Frequent “Signal is lost” locking
Increase the **Timeout** value or try **Passive Mode**.

## Credit & License

Original project by [Takeshi Sone](https://github.com/ts1/BLEUnlock). Rebranded and modernized by Shawn Rain.

MIT License. Copyright © 2026-present Shawn Rain.
