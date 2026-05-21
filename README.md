# MonitorSwitcher

> A simple macOS menu bar app to turn off your MacBook's built-in display when an external monitor is connected — without needing a restart.

[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## About

When you plug an external monitor into a MacBook, macOS treats it as an extended or mirrored display. If you want to use the external as your main screen and keep the MacBook closed-feeling — using its keyboard and trackpad but with the built-in screen off — there's no built-in way to do that with the lid open.

The common workaround is `displayplacer "id:1 enabled:false"`, but that uses a private API that **requires a restart to undo**. Toggling the built-in display on and off shouldn't mean rebooting.

MonitorSwitcher solves this with a different mechanism: it mirrors the built-in display onto the external and sets the built-in backlight to zero. The screen is effectively off, but the system stays stable and the action is **fully reversible with a single click** — no restart, no reboot, no fuss.

I made this for my own daily setup, but figured others might find it useful too.

## Features

- Lives in your menu bar — out of the way until you need it.
- Shows all connected displays at a glance.
- One-click toggle to turn the MacBook built-in display on or off.
- Auto-detects when an external display is connected or disconnected.
- No restart required to bring the built-in display back.

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac with a built-in display
- At least one external display connected (the toggle only works when an external is present)

## Installation

1. Go to the [**Releases**](https://github.com/marctuinier/MonitorSwitcher/releases) page.
2. Download the latest `.dmg` file.
3. Open the DMG and drag **MonitorSwitcher.app** into your **Applications** folder.
4. Launch the app — its icon appears in your menu bar.

> **Note:** Since this app is not from the App Store, you may need to right-click the app and select **Open** on the first launch. If that doesn't work, go to **System Settings > Privacy & Security > Open Anyway**.

To launch automatically at login: **System Settings > General > Login Items > Open at Login > +** and add MonitorSwitcher.

## Usage

1. Plug in your external monitor.
2. Click the **MonitorSwitcher** icon in the menu bar.
3. Click **Turn Off MacBook Display**.
4. To turn it back on, click the icon again and select **Turn On MacBook Display**.

That's it.

## How it works

Instead of trying to "disable" the built-in display (which is what `displayplacer enabled:false` does via a private API that requires a restart to undo), MonitorSwitcher:

- **Off:** Mirrors the built-in display onto the external using `CGConfigureDisplayMirrorOfDisplay`, then sets the built-in backlight to 0 via the private `DisplayServices.framework` (the only way to control built-in backlight on Apple Silicon). The panel is dark, and any windows that wander to it remain visible on the external.
- **On:** Unmirrors and restores the previously saved brightness.

The state is fully reversible at any time — no reboot, no private "disable" calls.

## Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/marctuinier/MonitorSwitcher.git
   cd MonitorSwitcher
   ```
2. Build:
   ```bash
   ./build.sh
   ```
3. The signed `.app` will be at `build/MonitorSwitcher.app`. Move it to `/Applications` to install.

No Xcode project required — the build script compiles a single Swift source file directly with `swiftc` and ad-hoc-signs the result.

## Caveats

- Mirroring may lock the external display's resolution to a mode the built-in also supports. If you notice this happening on your setup, open an issue — the off-path can be switched to brightness-only without mirroring.
- The brightness control relies on a private macOS framework (`DisplayServices`). It works on all macOS versions through 26.x, but Apple could change it in the future. If brightness control silently stops working, the mirror part will still operate.

## License

This project is licensed under the [MIT License](LICENSE).
