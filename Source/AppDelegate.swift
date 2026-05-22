//
//  AppDelegate.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa
import MediaPlayer
import UserNotifications

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    let menubarController = MenubarController()

    private var prefsWindowController: NSWindowController?
    var preferencesWindowController: NSWindowController? {
        if prefsWindowController == nil {
            let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
            prefsWindowController = storyboard.instantiateController(withIdentifier:
                NSStoryboard.SceneIdentifier("PreferencesWindow")) as? NSWindowController
        }
        return prefsWindowController
    }

    static let bundleId: String = Bundle.main.bundleIdentifier ?? "unknown"
    static let bundleShortVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    static let bundleVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: [
            UserDefaultsKey.apiChannelsSortOrder: ChannelsSortOrder.listeners.rawValue,
            UserDefaultsKey.shouldPlayOnLaunch: true,
            UserDefaultsKey.notificationsEnabled: true,
            UserDefaultsKey.musicSearchProvider: MusicSearchProvider.youtubeMusic.rawValue,
            UserDefaultsKey.volume: Float(0.07)
        ])

        Log.info("Starting \(AppDelegate.bundleId) v\(AppDelegate.bundleShortVersion) (\(AppDelegate.bundleVersion))")

        UserDefaults.standard.register(defaults: ["RadioPlayer.NotificationsEnabled": true])

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        setupRemoteCommands()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        prefsWindowController = nil
    }

    // MARK: - Media Keys

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.menubarController.togglePlay()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.menubarController.togglePlay()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.menubarController.togglePlay()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.menubarController.previousTap()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.menubarController.nextTap()
            return .success
        }
    }
}
