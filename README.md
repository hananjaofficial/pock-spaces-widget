# 🖥️ Spaces Live Preview Widget for Pock & PockV3 (macOS Touch Bar)

A lightweight, native macOS **Touch Bar widget** for **[Pock](https://pock.app)** and **PockV3** that displays **live thumbnail previews** of all your active macOS Spaces (Desktops & Fullscreen Apps) — with zero text clutter and smooth native transitions.

> **Why this widget?**  
> Pock overrides the default macOS Touch Bar and hides Apple's native Spaces strip. This widget brings back visual Mission Control thumbnails directly inside Pock without requiring Xcode or slow AppleScripts.

---

## ✨ Features

- **🖼️ Live Space Thumbnails**: Automatically captures and updates clean miniature previews of each active Desktop and Fullscreen App (e.g., Safari, Xcode, Terminal).
- **🔄 Dynamic Space Detection**: Automatically adds or removes tiles in real time whenever you open or close a Desktop or Fullscreen window.
- **⚡ Native Smooth Switching**: Uses macOS `SkyLight` / `CoreGraphics` display APIs and `NSWorkspace` to switch Spaces with native macOS animations — no broken menubars or ghost windows.
- **🪶 Ultra-Lightweight**: Built in pure Swift with zero external dependencies and compiles in under 2 seconds using only Apple Command Line Tools (no full Xcode required).

---

## 📦 Installation

### Option A: Quick Install (Pre-built Release)
1. Download `Spaces.pock.zip` from the **[Releases](../../releases)** page and unzip it.
2. Double-click `Spaces.pock` (or copy it manually to `~/Library/Application Support/com.pigigaldi.pock/Widgets/` and `~/Library/Application Support/Pock/Widgets/`).
3. Restart **PockV3** (or **Pock**).
4. Click the **Pock icon in your macOS Menu Bar → Customize Pock** and drag the **Spaces** widget onto your Touch Bar.
5. When prompted by macOS, grant **Screen Recording** permission to PockV3 so live desktop thumbnails can be captured.

### Option B: Build from Source (No Xcode Needed)
Make sure you have Apple Command Line Tools installed (`xcode-select --install`), then run:

```bash
git clone https://github.com/hananjaofficial/pock-spaces-widget.git
cd pock-spaces-widget
./build.sh --install
```

---

## 🛠️ How It Works

- **Space Discovery**: Queries `SLSCopyManagedDisplaySpaces` and `SLSCopySpacesForWindows` to detect all user Desktops (`type == 0`) and Fullscreen App spaces (`type == 4`) on the main display.
- **Live Thumbnails**: Captures silent background snapshots via `/usr/sbin/screencapture -x` whenever you switch spaces and scales them down to crisp `92×52` Retina thumbnails.
- **Glitch-Free Switching**: Resolves the owning `pid` of each Space and activates the corresponding application via `NSWorkspace.shared.openApplication`, triggering macOS's native swipe transition.

---

## 📋 Requirements

- **macOS 12.0+** (Tested on macOS 15 Sequoia & newer)
- **MacBook Pro with Touch Bar** (or Touch Bar Simulator)
- **PockV3** or **Pock**

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
