//
//  MenubarController.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa
import Network
import UserNotifications

class MenubarController {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

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

    init() {
        setupStatusItem()
        setupMenu()
        setupReachability()

        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.channelsUpdated), name: .somaApiChannelsUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.updateTrackName), name: .radioPlayerTrackNameUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.updatePlaybackState), name: .radioPlayerStateUpdated, object: nil)

        SomaAPI.loadChannels()
    }

    @objc func channelsUpdated() {
        updateStationsMenu()
        if !hasAutoPlayed && Settings.shouldPlayOnLaunch {
            hasAutoPlayed = true
            togglePlay()
        }
    }

    func setupStatusItem() {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(MenubarController.toggleStatus(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        setStatusItem(playing: false)
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
            let channelItem = NSMenuItem(title: channel.title, action: #selector(MenubarController.selectStation(_:)), keyEquivalent: "")
            channelItem.tag = channels.firstIndex(where: { $0.id == channel.id }) ?? 0
            channelItem.target = self

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
        }
    }

    @objc func updatePlaybackState() {
        setupRecoveringTimerIfNeeded()
        setStatusItem(playing: RadioPlayer.player.timeControlStatus != .paused)
        updateTrackName()
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
        if RadioPlayer.player.timeControlStatus != .paused {
            RadioPlayer.player.pause()
            return
        }

        guard isNetworkAvailable else {
            showConnectionError()
            return
        }

        if RadioPlayer.player.currentItem != nil {
            RadioPlayer.resumeLive()
        } else if let savedChannel = SomaAPI.lastPlayedChannel {
            selectChannel(savedChannel)
        }
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
        // Re-search with current provider in case it changed
        MusicSearchAPI.searchTrack()

        // For YouTube Music and Spotify the URL is set synchronously
        if let trackURL = MusicSearchAPI.trackSearchURL {
            NSWorkspace.shared.open(trackURL)
        }
    }

    // MARK: - Private

    private func selectChannel(_ channel: Channel) {
        guard let channels = SomaAPI.channels, let selectedChannelIdx = channels.firstIndex(where: { $0.id == channel.id }) else { return }
        guard isNetworkAvailable else {
            showConnectionError()
            return
        }

        lastNotifiedTrack = nil
        stationsMenu.items.forEach { $0.state = $0.tag == selectedChannelIdx ? .on : .off }

        RadioPlayer.play(channel: channel)
        Log.info("Selected station \"\(channel.title)\"")
    }

    private func showMenu() {
        statusItem.menu = rightClickMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func setStatusItem(playing: Bool) {
        if playing {
            statusItem.button?.image = NSImage(named: NSImage.Name("media_pause"))
            statusItem.button?.toolTip = "Click to pause\nRight click to show menu"
        } else {
            statusItem.button?.image = NSImage(named: NSImage.Name("media_play"))
            statusItem.button?.toolTip = "Click to play\nRight click to show menu"
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
        let request = UNNotificationRequest(identifier: "nowPlaying", content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - Reachability (NWPathMonitor)

    private let pathMonitor = NWPathMonitor()
    private var isNetworkAvailable: Bool = true
    private var resumePlaybackTimer: Timer?

    private func setupReachability() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasAvailable = self?.isNetworkAvailable ?? true
                self?.isNetworkAvailable = (path.status == .satisfied)

                if path.status == .satisfied {
                    self?.updateTrackName()
                    self?.recoverFromConnectionErrorIfNeeded()
                } else {
                    if wasAvailable {
                        self?.updateTrackName()
                    }
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    private func setupRecoveringTimerIfNeeded() {
        guard !isNetworkAvailable, RadioPlayer.player.timeControlStatus == .waitingToPlayAtSpecifiedRate else { return }

        resumePlaybackTimer?.invalidate()
        resumePlaybackTimer = Timer.scheduledTimer(timeInterval: 5,
                                                   target: self,
                                                   selector: #selector(MenubarController.showConnectionError),
                                                   userInfo: nil,
                                                   repeats: false)
    }

    private func recoverFromConnectionErrorIfNeeded() {
        resumePlaybackTimer?.invalidate()
        guard RadioPlayer.player.timeControlStatus != .paused else { return }

        RadioPlayer.resumeLive()
    }

    @objc func showConnectionError() {
        resumePlaybackTimer?.invalidate()
        updateTrackName()

        RadioPlayer.player.pause()
        setStatusItem(playing: true)

        let content = UNMutableNotificationContent()
        content.title = "Network error"
        content.body = "Can't connect to SomaFM.com"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.setStatusItem(playing: false)
        }
    }
}
