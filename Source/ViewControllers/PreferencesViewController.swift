//
//  PreferencesViewController.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Cocoa

class PreferencesViewController: NSViewController {

    @IBOutlet weak var startAtLoginButton: NSButton!
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var frameRatePopup: NSPopUpButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        startAtLoginButton.state = StartAtLogin.isEnabled ? .on : .off
        frameRatePopup.selectItem(withTag: Settings.marqueeFrameRate)

        if let shortVersionString: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            versionLabel.stringValue = "Version \(shortVersionString)"
        }
    }

    override func cancelOperation(_ sender: Any?) {
        view.window?.close()
    }

    @IBAction func tapStartAtLogin(_ sender: NSButton) {
        StartAtLogin.isEnabled = sender.state == .on
    }

    @IBAction func updateSortOrder(_ sender: NSPopUpButton) {
        NotificationCenter.default.post(name: .somaApiChannelsUpdated, object: nil)
    }

    @IBAction func updateMusicProvider(_ sender: NSPopUpButton) {
        NotificationCenter.default.post(name: .radioPlayerTrackNameUpdated, object: nil)
    }

    @IBAction func updateFrameRate(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        Settings.marqueeFrameRate = item.tag
    }

    @IBAction func updateStreamFormat(_ sender: NSPopUpButton) {
        replayIfPlaying()
    }

    @IBAction func updateStreamQuality(_ sender: NSPopUpButton) {
        replayIfPlaying()
    }

    private func replayIfPlaying() {
        guard RadioPlayer.player.timeControlStatus == .playing else { return }
        // Delay slightly so the binding writes the new value before we read it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let channel = SomaAPI.lastPlayedChannel else { return }
            RadioPlayer.play(channel: channel)
        }
    }
}
