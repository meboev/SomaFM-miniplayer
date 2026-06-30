//
//  AppDelegate.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Cocoa
import MediaPlayer
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {

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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: [
            UserDefaultsKey.apiChannelsSortOrder: ChannelsSortOrder.listeners.rawValue,
            UserDefaultsKey.shouldPlayOnLaunch: true,
            UserDefaultsKey.notificationsEnabled: true,
            UserDefaultsKey.errorNotificationsEnabled: false,
            UserDefaultsKey.musicSearchProvider: MusicSearchProvider.youtubeMusic.rawValue,
            UserDefaultsKey.volume: Float(0.07),
            UserDefaultsKey.playMode: true,
            UserDefaultsKey.showTrackInMenuBar: false,
            UserDefaultsKey.marqueeWidth: Double(50),
            UserDefaultsKey.marqueeFrameRate: 60,
            UserDefaultsKey.artworkEnabled: true,
            UserDefaultsKey.trackArtworkEnabled: true,
            UserDefaultsKey.preferredFormat: 0,
            UserDefaultsKey.preferredQuality: 0
        ])

        Log.info("Starting \(AppDelegate.bundleId) v\(AppDelegate.bundleShortVersion)")

        TrackArtworkFetcher.clearCache()

        UNUserNotificationCenter.current().delegate = self
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
            self?.menubarController.playPlayback()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.menubarController.pausePlayback()
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

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let url = MusicSearchAPI.trackSearchURL {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }
}
