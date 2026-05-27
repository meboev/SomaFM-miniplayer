//
//  MenubarController.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Cocoa
import Network
import UserNotifications
import MediaPlayer

class MenubarController: NSObject {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var marqueeMaxWidth: CGFloat { Settings.marqueeWidth }

    let rightClickMenu = NSMenu()
    let stationsMenu = NSMenu()

    let trackItem = NSMenuItem(title: "...", action: #selector(MenubarController.searchTrack), keyEquivalent: "")

    var sortedChannels: [Channel]? {
        guard let channels = SomaAPI.channels, channels.count > 0 else { return nil }

        if Settings.channelsSortOrder == .listeners {
            return channels.sorted { $0.listeners > $1.listeners }
        } else if Settings.channelsSortOrder == .alphabetically {
            return channels.sorted { $0.title < $1.title }
        } else {
            return channels
        }
    }

    private var hasAutoPlayed = false
    private var lastNotifiedTrack: String?
    private var retryTimer: Timer?
    private var marqueeTimer: Timer?
    private var marqueePixelOffset: CGFloat = 0
    private var marqueeTextWidth: CGFloat = 0
    private let marqueePadding: CGFloat = 40
    private var currentIcon: NSImage?

    override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        setupReachability()

        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.channelsUpdated), name: .somaApiChannelsUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.updateTrackName), name: .radioPlayerTrackNameUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.updatePlaybackState), name: .radioPlayerStateUpdated, object: nil)

        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.\(UserDefaultsKey.showTrackInMenuBar)", options: .new, context: nil)
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.\(UserDefaultsKey.marqueeWidth)", options: .new, context: nil)
        NSUserDefaultsController.shared.addObserver(self, forKeyPath: "values.\(UserDefaultsKey.marqueeFrameRate)", options: .new, context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)

        SomaAPI.loadChannels()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "values.\(UserDefaultsKey.showTrackInMenuBar)" || keyPath == "values.\(UserDefaultsKey.marqueeWidth)" || keyPath == "values.\(UserDefaultsKey.marqueeFrameRate)" {
            handleShowTrackChanged()
        }
    }

    private var lastShowTrackValue = Settings.showTrackInMenuBar
    private var lastMarqueeWidth = Settings.marqueeWidth
    private var lastMarqueeFrameRate = Settings.marqueeFrameRate

    @objc private func defaultsChanged() {
        let currentShow = Settings.showTrackInMenuBar
        let currentWidth = Settings.marqueeWidth
        let currentFps = Settings.marqueeFrameRate
        if currentShow != lastShowTrackValue || currentWidth != lastMarqueeWidth || currentFps != lastMarqueeFrameRate {
            lastShowTrackValue = currentShow
            lastMarqueeWidth = currentWidth
            lastMarqueeFrameRate = currentFps
            handleShowTrackChanged()
        }
    }

    private func handleShowTrackChanged() {
        stopMarquee()
        updateStatusIcon()
        updateMarquee()
    }

    @objc func channelsUpdated() {
        updateStationsMenu()
        if !hasAutoPlayed && Settings.shouldPlayOnLaunch {
            hasAutoPlayed = true
            Settings.playMode = true
            startPlaying()
        }
    }

    func setupStatusItem() {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(MenubarController.toggleStatus(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateStatusIcon()
    }

    func setupMenu() {
        let volumeItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeItem.view = setupVolumeSlider()
        rightClickMenu.addItem(volumeItem)

        let stationsItem = NSMenuItem(title: "Stations", action: nil, keyEquivalent: "")
        stationsItem.submenu = stationsMenu
        rightClickMenu.addItem(stationsItem)
        rightClickMenu.addItem(NSMenuItem.separator())
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(MenubarController.openPreferences(_:)), keyEquivalent: "")
        preferencesItem.target = self
        rightClickMenu.addItem(preferencesItem)
        rightClickMenu.addItem(NSMenuItem.separator())
        rightClickMenu.addItem(NSMenuItem(title: "Quit SomaFM miniplayer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        updateStationsMenu()
    }

    func setupVolumeSlider() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        container.autoresizingMask = [.width]
        let slider = NSSlider(frame: NSRect(x: 10, y: 0, width: 80, height: 30))
        slider.autoresizingMask = [.width, .height]
        slider.target = self
        slider.action = #selector(MenubarController.updateVolume(_:))
        slider.floatValue = Settings.volume

        container.addSubview(slider)

        return container
    }

    // MARK: - Actions

    @objc func toggleStatus(_ sender: NSStatusBarButton) {
        guard let event = NSApplication.shared.currentEvent else { return }

        if event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) || event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePlay()
        }
    }

    @objc func updateStationsMenu() {
        stationsMenu.removeAllItems()

        guard let channels = SomaAPI.channels, let sortedChannels = sortedChannels else {
            stationsMenu.addItem(NSMenuItem(title: "No channels available", action: nil, keyEquivalent: ""))
            return
        }

        let lastPlayedChannel = SomaAPI.lastPlayedChannel

        for channel in sortedChannels {
            let listenersStr = " (\(channel.listeners))"
            let channelItem = NSMenuItem(title: channel.title + listenersStr, action: #selector(MenubarController.selectStation(_:)), keyEquivalent: "")
            channelItem.tag = channels.firstIndex(where: { $0.id == channel.id }) ?? 0
            channelItem.target = self

            if let genre = channel.genre ?? channel.description {
                channelItem.toolTip = genre
            }

            if channel.id == lastPlayedChannel?.id {
                channelItem.state = .on
            }

            stationsMenu.addItem(channelItem)
        }
    }

    @objc func updateTrackName() {
        if !isNetworkAvailable, RadioPlayer.player.timeControlStatus != .playing {
            trackItem.title = "Network unavailable"
            trackItem.target = nil
            if rightClickMenu.items.first != trackItem {
                rightClickMenu.insertItem(trackItem, at: 0)
            }
            return
        }

        guard let trackName = RadioPlayer.currentTrack, !trackName.isEmpty else {
            if rightClickMenu.items.first == trackItem {
                rightClickMenu.removeItem(trackItem)
            }
            return
        }

        let truncatedTrackName = trackName.trunc(length: 35)
        trackItem.title = truncatedTrackName
        trackItem.target = self
        let providerName: String
        switch Settings.musicSearchProvider {
        case .youtubeMusic: providerName = "YouTube Music"
        case .spotify: providerName = "Spotify"
        case .appleMusic: providerName = "Apple Music"
        }
        trackItem.toolTip = "Click to search in \(providerName)"
        if rightClickMenu.items.first != trackItem {
            rightClickMenu.insertItem(trackItem, at: 0)
        }
        rightClickMenu.update()

        if truncatedTrackName != lastNotifiedTrack && RadioPlayer.player.timeControlStatus == .playing {
            lastNotifiedTrack = truncatedTrackName
            if Settings.notificationsEnabled {
                showUserNotification()
            }
            MusicSearchAPI.searchTrack()
            updateNowPlayingInfo()
            updateMarquee()
        }
    }

    @objc func updatePlaybackState() {
        updateStatusIcon()
        updateTrackName()
        updateNowPlayingInfo()
        updateMarquee()
        startRetryTimerIfNeeded()
    }

    @objc func selectStation(_ sender: NSMenuItem) {
        guard let channels = SomaAPI.channels, channels.count > sender.tag else { return }

        selectChannel(channels[sender.tag])
    }

    @objc func updateVolume(_ sender: NSSlider) {
        RadioPlayer.player.volume = sender.floatValue

        if sender.window?.currentEvent?.type == .leftMouseUp {
            Settings.volume = sender.floatValue
        }
    }

    @objc func openPreferences(_ sender: NSMenuItem) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }

        if let preferencesWindowController = appDelegate.preferencesWindowController {
            NSApp.activate(ignoringOtherApps: true)
            preferencesWindowController.showWindow(sender)
            preferencesWindowController.window?.delegate = appDelegate
        }
    }

    @objc func togglePlay() {
        if Settings.playMode {
            // Currently in play mode -> switch to stopped
            Settings.playMode = false
            RadioPlayer.player.pause()
            stopRetryTimer()
        } else {
            // Switch to play mode
            Settings.playMode = true
            startPlaying()
        }
        updateStatusIcon()
    }

    @objc func previousTap() {
        guard let sortedChannels = sortedChannels,
            let lastPlayedChannel = SomaAPI.lastPlayedChannel,
            let lastPlayedIndex = sortedChannels.firstIndex(where: { $0.id == lastPlayedChannel.id })
            else { return }

        let newIndex = lastPlayedIndex == 0 ? sortedChannels.count - 1 : lastPlayedIndex - 1
        selectChannel(sortedChannels[newIndex])
    }

    @objc func nextTap() {
        guard let sortedChannels = sortedChannels,
            let lastPlayedChannel = SomaAPI.lastPlayedChannel,
            let lastPlayedIndex = sortedChannels.firstIndex(where: { $0.id == lastPlayedChannel.id })
            else { return }

        let newIndex = lastPlayedIndex == sortedChannels.count - 1 ? 0 : lastPlayedIndex + 1
        selectChannel(sortedChannels[newIndex])
    }

    @objc func searchTrack() {
        MusicSearchAPI.searchTrack()

        if let trackURL = MusicSearchAPI.trackSearchURL {
            NSWorkspace.shared.open(trackURL)
        }
    }

    // MARK: - Private

    private func startPlaying() {
        guard isNetworkAvailable else {
            // Will retry via timer
            updateStatusIcon()
            startRetryTimerIfNeeded()
            return
        }

        if RadioPlayer.player.currentItem != nil {
            RadioPlayer.resumeLive()
        } else if let savedChannel = SomaAPI.lastPlayedChannel {
            selectChannel(savedChannel)
        }
    }

    private func selectChannel(_ channel: Channel) {
        guard let channels = SomaAPI.channels, let selectedChannelIdx = channels.firstIndex(where: { $0.id == channel.id }) else { return }

        // Selecting a channel implies play mode
        Settings.playMode = true

        guard isNetworkAvailable else {
            updateStatusIcon()
            startRetryTimerIfNeeded()
            return
        }

        lastNotifiedTrack = nil
        cachedArtwork = nil
        cachedArtworkChannelId = nil
        stationsMenu.items.forEach { $0.state = $0.tag == selectedChannelIdx ? .on : .off }

        RadioPlayer.play(channel: channel)
        Log.info("Selected station \"\(channel.title)\"")
    }

    private func showMenu() {
        statusItem.menu = rightClickMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Status Icon (colored)

    private func updateStatusIcon() {
        let isPlaying = RadioPlayer.player.timeControlStatus == .playing
        let isDark = (statusItem.button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)

        if !Settings.playMode {
            currentIcon = tintedImage(named: "media_play", color: NSColor(red: 0.906, green: 0.188, blue: 0.153, alpha: 1.0))
        } else if isPlaying {
            let green = isDark
                ? NSColor(red: 0.298, green: 0.851, blue: 0.392, alpha: 1.0)
                : NSColor(red: 0.133, green: 0.545, blue: 0.133, alpha: 1.0)
            currentIcon = tintedImage(named: "media_pause", color: green)
        } else {
            let amber = isDark
                ? NSColor(red: 0.945, green: 0.769, blue: 0.059, alpha: 1.0)
                : NSColor(red: 0.750, green: 0.580, blue: 0.000, alpha: 1.0)
            currentIcon = tintedImage(named: "media_pause", color: amber)
        }

        statusItem.button?.image = currentIcon
        statusItem.button?.toolTip = buildTooltip()
    }

    private func buildTooltip() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        var parts = ["SomaFM miniplayer v\(version)"]

        if let channel = SomaAPI.lastPlayedChannel {
            var channelParts = [channel.title]
            if let desc = channel.description ?? channel.genre {
                channelParts.append(desc)
            }
            parts.append(channelParts.joined(separator: "\n"))
        }

        if let track = RadioPlayer.currentTrack, !track.isEmpty {
            parts.append(track)
        }

        return parts.joined(separator: "\n\n")
    }

    private func tintedImage(named name: String, color: NSColor) -> NSImage? {
        guard let original = NSImage(named: NSImage.Name(name)) else { return nil }
        let image = NSImage(size: original.size, flipped: false) { rect in
            original.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }

    private func updateNowPlayingInfo() {
        let infoCenter = MPNowPlayingInfoCenter.default()

        if !Settings.playMode || RadioPlayer.player.timeControlStatus == .paused {
            infoCenter.playbackState = .paused
            infoCenter.nowPlayingInfo = nil
            return
        }

        var info = [String: Any]()
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyIsLiveStream] = true

        if let trackName = RadioPlayer.currentTrack {
            let parts = trackName.components(separatedBy: " - ")
            if parts.count >= 2 {
                info[MPMediaItemPropertyArtist] = parts[0]
                info[MPMediaItemPropertyTitle] = parts.dropFirst().joined(separator: " - ")
            } else {
                info[MPMediaItemPropertyTitle] = trackName
            }
        }

        if let stationName = SomaAPI.lastPlayedChannel?.title {
            info[MPMediaItemPropertyAlbumTitle] = stationName
        }

        // Set artwork if cached
        if let artwork = cachedArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = .playing

        // Fetch artwork if not cached
        if cachedArtwork == nil, let channel = SomaAPI.lastPlayedChannel {
            fetchArtwork(for: channel)
        }
    }

    private var cachedArtwork: MPMediaItemArtwork?
    private var cachedArtworkChannelId: String?

    private func fetchArtwork(for channel: Channel) {
        guard channel.id != cachedArtworkChannelId else { return }

        ArtworkCache.fetchImage(for: channel) { [weak self] image in
            guard let self = self, let image = image else { return }
            self.cachedArtworkChannelId = channel.id
            self.cachedArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            self.updateNowPlayingInfo()
        }
    }

    private func showUserNotification() {
        guard let trackName = RadioPlayer.currentTrack else { return }
        let stationName = SomaAPI.lastPlayedChannel?.title ?? "SomaFM"

        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()

        let content = UNMutableNotificationContent()
        content.title = stationName
        content.body = trackName

        // Attach station artwork if available
        if let channel = SomaAPI.lastPlayedChannel {
            attachArtwork(for: channel, to: content) {
                let request = UNNotificationRequest(identifier: "nowPlaying", content: content, trigger: nil)
                center.add(request)
            }
        } else {
            let request = UNNotificationRequest(identifier: "nowPlaying", content: content, trigger: nil)
            center.add(request)
        }
    }

    private func attachArtwork(for channel: Channel, to content: UNMutableNotificationContent, completion: @escaping () -> Void) {
        ArtworkCache.fetchImage(for: channel) { image in
            if let image = image, let tiffData = image.tiffRepresentation {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                if let bitmap = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                    try? jpegData.write(to: tempURL)
                    if let attachment = try? UNNotificationAttachment(identifier: "artwork", url: tempURL, options: nil) {
                        content.attachments = [attachment]
                    }
                }
            }
            completion()
        }
    }

    // MARK: - Reachability (NWPathMonitor)

    private let pathMonitor = NWPathMonitor()
    private var isNetworkAvailable: Bool = true

    private func setupReachability() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = (path.status == .satisfied)

                if path.status == .satisfied {
                    self?.updateTrackName()
                    // If in play mode and not playing, try to connect
                    if Settings.playMode && RadioPlayer.player.timeControlStatus != .playing {
                        self?.startPlaying()
                    }
                } else {
                    self?.updateTrackName()
                    self?.updateStatusIcon()
                    self?.startRetryTimerIfNeeded()
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    // MARK: - Retry Timer

    private func startRetryTimerIfNeeded() {
        guard Settings.playMode, !isNetworkAvailable || RadioPlayer.player.timeControlStatus != .playing else {
            stopRetryTimer()
            return
        }

        // Don't create duplicate timers
        guard retryTimer == nil else { return }

        retryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if Settings.playMode {
                if self.isNetworkAvailable {
                    self.stopRetryTimer()
                    self.startPlaying()
                }
                // If network still unavailable, keep retrying
            } else {
                self.stopRetryTimer()
            }
        }
    }

    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    // MARK: - Marquee

    private func updateMarquee() {
        let iconWidth: CGFloat = 22
        let fixedLength = iconWidth + marqueeMaxWidth + 8

        guard Settings.showTrackInMenuBar else {
            stopMarquee()
            statusItem.button?.title = ""
            statusItem.length = NSStatusItem.variableLength
            statusItem.button?.image = currentIcon
            return
        }

        // Keep fixed width whenever the setting is on
        statusItem.length = fixedLength
        statusItem.button?.title = ""

        guard Settings.playMode,
              RadioPlayer.player.timeControlStatus != .paused,
              let track = RadioPlayer.currentTrack, !track.isEmpty else {
            stopMarquee()
            statusItem.button?.image = currentIcon
            return
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0)
        ]
        let textWidth = (track as NSString).size(withAttributes: attrs).width

        if textWidth <= marqueeMaxWidth {
            // Short enough — display static
            stopMarquee()
            statusItem.button?.image = currentIcon
            statusItem.button?.title = " \(track)"
        } else {
            // Start pixel scrolling
            marqueeTextWidth = textWidth

            if marqueeTimer == nil {
                marqueePixelOffset = 0
                renderMarqueeFrame(track: track, attrs: attrs)
                let fps = Double(Settings.marqueeFrameRate)
                let interval = 1.0 / fps
                let pixelsPerSecond: Double = 30.0
                let step = CGFloat(pixelsPerSecond / fps)
                marqueeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                    guard let self = self,
                          let track = RadioPlayer.currentTrack else {
                        self?.stopMarquee()
                        return
                    }
                    self.marqueePixelOffset += step
                    let totalWidth = self.marqueeTextWidth + self.marqueePadding
                    if self.marqueePixelOffset >= totalWidth {
                        self.marqueePixelOffset = 0
                    }
                    self.renderMarqueeFrame(track: track, attrs: attrs)
                }
            }
        }
    }

    private func renderMarqueeFrame(track: String, attrs: [NSAttributedString.Key: Any]) {
        guard let icon = currentIcon else { return }
        let height: CGFloat = 18
        let clipWidth = marqueeMaxWidth
        let totalWidth = marqueeTextWidth + marqueePadding

        // Resolve text color based on menu bar appearance
        let isDark = (statusItem.button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        let textColor: NSColor = isDark ? .white : .black

        var drawAttrs = attrs
        drawAttrs[.foregroundColor] = textColor

        let iconWidth = icon.size.width
        let combinedWidth = iconWidth + 4 + clipWidth
        let combinedHeight = max(icon.size.height, height)
        let offset = marqueePixelOffset
        let str = track as NSString

        let combinedImage = NSImage(size: NSSize(width: combinedWidth, height: combinedHeight), flipped: false) { rect in
            // Draw icon
            let iconY = (rect.height - icon.size.height) / 2
            icon.draw(in: NSRect(x: 0, y: iconY, width: iconWidth, height: icon.size.height))

            // Clip text area and draw scrolling text
            let textX = iconWidth + 4
            let textY = (rect.height - height) / 2
            NSGraphicsContext.current?.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: textX, y: textY, width: clipWidth, height: height)).addClip()
            str.draw(at: NSPoint(x: textX - offset, y: textY + 1), withAttributes: drawAttrs)
            str.draw(at: NSPoint(x: textX - offset + totalWidth, y: textY + 1), withAttributes: drawAttrs)
            NSGraphicsContext.current?.restoreGraphicsState()
            return true
        }
        combinedImage.isTemplate = false
        statusItem.button?.image = combinedImage
    }

    private func stopMarquee() {
        marqueeTimer?.invalidate()
        marqueeTimer = nil
        marqueePixelOffset = 0
        marqueeTextWidth = 0
    }
}
