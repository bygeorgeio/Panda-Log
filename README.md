# 🐼 Panda Log

A beautiful, lightning-fast log viewer for macOS — inspired by CMTrace, crafted for Mac by [George Mihailovski](https://bygeorge.io).

---

## Features

- 📝 View and tail plain text log files in real time
- 🔍 Instant search/filtering
- 🧷 Multiple tabs for multiple logs
- 🐞 Error and warning highlighting (with badges)
- 🪄 Mac-native design and keyboard shortcuts
- ⚡ Lightweight, fast, open source

---

## Installation

There are two ways to get Panda Log on your Mac:

### 1. Download the Prebuilt App (ZIP)

1. Go to the [Releases page on GitHub](https://github.com/bygeorgeio/Panda-Log/releases).
2. Download the latest **PandaLog.zip** asset.
3. Unzip it by running in Terminal:
    ```sh
    ditto -xk PandaLog.zip
    ```
    This will produce `Panda Log.app`. Move it into your `/Applications` folder (or anywhere you prefer).

---

### 2. Build from Source

```sh
git clone https://github.com/bygeorgeio/Panda-Log.git
cd Panda-Log
open "Panda Log.xcodeproj"
Build and run in Xcode.
To create your own distributable .app, use Product ▶ Archive in Xcode, then export.

Gatekeeper & “Unidentified Developer” Warning

Because Panda Log is not signed with a paid Developer ID, macOS Gatekeeper will show a warning the first time you open it:

Right-click (or Control-click) Panda Log.app in Finder.
Select Open from the menu.
In the dialog, click Open again.
From then on, you can open the app normally.
Alternatively, to remove the quarantine attribute in Terminal:

sudo xattr -r -d com.apple.quarantine /Applications/Panda\ Log.app
(Adjust the path if you placed the app elsewhere.)

Usage

Open log files: Use the “+” button or Cmd+O.
Search: Press Cmd+F or use the search field.
Follow Tail: Toggle to always see the newest log lines.
Keyboard Shortcuts:
Cmd+W Close tab
Cmd+L Clear search
Contributing

Pull requests and issues welcome!
See CONTRIBUTING.md for guidelines.

License

MIT License

Credits

Inspired by CMTrace
Designed and developed by George Mihailovski
