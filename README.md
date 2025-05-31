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

