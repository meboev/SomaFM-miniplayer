# SomaFM miniplayer

[![Latest Release](https://img.shields.io/badge/release-2.0.0-blue.svg)](https://github.com/meboev/SomaFM-miniplayer/releases/latest)
[![License](https://img.shields.io/github/license/meboev/SomaFM-miniplayer.svg)](LICENSE.md)
![Platform](https://img.shields.io/badge/platform-macos%20(Apple%20Silicon)-lightgrey.svg)

![Screenshot](shot.png)

This is an unofficial player that gives you minimal, background playback of SomaFM channels.

## Installation

* Download the DMG from the [releases page](https://github.com/meboev/SomaFM-miniplayer/releases/latest)
* Or clone this repo and build it from source:

```bash
./build.sh
./create-dmg.sh
./install.sh
```

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
* Added error dialogs for network/playback failures
* Added build, install, and DMG creation scripts

## Authors

Originally created by Evgeny Aleksandrov ([@ealeksandrov](https://twitter.com/ealeksandrov)).

Maintained and updated by Milen Boev ([@meboev](https://github.com/meboev)).

## License

`SomaFM miniplayer` is available under the MIT license. See the [LICENSE.md](LICENSE.md) file for more info.
