# SomaFM miniplayer

[![Latest Release](https://img.shields.io/badge/release-2.0.3-blue.svg)](https://github.com/meboev/SomaFM-miniplayer/releases/latest)
[![License](https://img.shields.io/github/license/meboev/SomaFM-miniplayer.svg)](LICENSE.md)
![Platform](https://img.shields.io/badge/platform-macos%20(Apple%20Silicon)-lightgrey.svg)
![Tested](https://img.shields.io/badge/tested-macOS%2026-success.svg)

![Screenshot](shot.png)

This is an unofficial player that gives you minimal, background playback of SomaFM channels on macOS.

## Capabilities

* Menu bar controls with colored status icons (red/amber/green, adaptive for light/dark mode)
* Scrolling track name in menu bar with configurable width and frame rate
* Media key support (play/pause, previous/next station) via keyboard, Control Center, Lock Screen, and Bluetooth devices
* Now Playing integration with track-specific or station artwork in Control Center and Lock Screen
* System notifications for track changes with album artwork (click to search track)
* Track-specific album art fetched from iTunes Search API (with disk cache)
* Stations menu with listener counts and genre tooltips
* Track search integration (YouTube Music, Spotify, Apple Music) — via menu item or notification click
* Stream format and quality preferences (Any/AAC/MP3, Highest/High/Low) with immediate apply
* Statistics window with live stream info, session stats, and playback details
* Automatic reconnection on network errors (5s retry)
* Persistent play mode (survives app restarts)
* Start at Login support
* Configurable channels sort order

## Installation

* Download the DMG from the [releases page](https://github.com/meboev/SomaFM-miniplayer/releases/latest)
* Or clone this repo and build it from source:

```bash
./build.sh
./create-dmg.sh
./install.sh
```

## Changes in 2.0.3

* Fixed remote play/pause handling so external pause and play commands are no longer treated as toggles
* Fixed local run script to launch the installed `/Applications` app instead of a stale Xcode DerivedData build

## Changes in 2.0.2

* Colored menu bar icons: red (stopped), amber (connecting/offline), green (playing) — darker variants in light mode
* Added scrolling track name in menu bar ("Show track in menu bar" preference)
* Configurable scroller width (50–400px, default 50px) and frame rate (5–60fps, default 60fps)
* Track-specific album artwork via iTunes Search API with disk cache and fallback to station art
* Added "Show artwork" and "Track artwork" preferences (both enabled by default)
* Clicking a notification opens the configured track search provider in the browser
* Added persistent play mode with automatic retry on network errors
* Now Playing integration with artwork (Control Center, Lock Screen, media keys, Bluetooth controls)
* Previous/next media keys switch stations
* Track notifications include album or station artwork
* Stations menu shows listener counts and genre tooltips
* Informative menu bar icon tooltip (version, station, description, current track)
* Stream format preference (Any/AAC/MP3, default Any) and quality preference (Highest/High/Low)
* Changing stream format or quality applies immediately if playing
* Statistics window (right-click menu) with live playback state, station info, stream details, and session stats
* Added "Error notifications" preference (disabled by default)
* Renamed "Enable notifications" to "Track notifications"
* Renamed "Music search provider" to "Track search provider"
* Removed all modal error dialogs — errors shown via system notifications (if enabled)
* Track artwork cache cleared on each app launch
* Fixed channel description decoding bug
* Replaced all `URLSession` instances with shared session
* Removed `NSAllowsArbitraryLoads` (all endpoints are HTTPS)
* Code cleanup: removed dead code, updated copyrights, modernized to `@main`
* Tested on macOS 26 (Tahoe)

## Changes in 2.0.0

* Apple Silicon only (arm64)
* Removed all Carthage dependencies (Reachability, MediaKeyTap)
* Replaced Reachability with built-in `NWPathMonitor`
* Replaced MediaKeyTap with built-in `MPRemoteCommandCenter`
* Replaced `NSUserNotification` with `UserNotifications` framework
* Replaced deprecated `SMLoginItemSetEnabled` with `SMAppService`
* Fixed stream playback by resolving PLS playlists and adding User-Agent header
* Track metadata fetched via SomaFM songs API (ICY metadata no longer works on macOS 15+)
* Updated Swift to 5.0, deployment target to macOS 14.0
* Removed shell script build phases (swiftlint, git version bump)
* Added build, install, and DMG creation scripts

## Authors

Originally created by Evgeny Aleksandrov ([@ealeksandrov](https://twitter.com/ealeksandrov)).

Maintained and updated by Milen Boev ([@meboev](https://github.com/meboev)).

## License

`SomaFM miniplayer` is available under the MIT license. See the [LICENSE.md](LICENSE.md) file for more info.
