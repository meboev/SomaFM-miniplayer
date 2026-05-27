//
//  StatisticsViewController.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Cocoa
import AVFoundation

class StatisticsViewController: NSViewController {

    private var labels: [String: NSTextField] = [:]
    private var updateTimer: Timer?

    private static var windowController: NSWindowController?

    override func loadView() {
        let width: CGFloat = 420
        let rows: [(String, String, Bool)] = [
            // (key, title, selectable)
            ("state", "Playback state", true),
            ("track", "Current track", true),
            ("station", "Station", true),
            ("description", "Description", true),
            ("genre", "Genre", true),
            ("dj", "DJ", true),
            ("listeners", "Listeners", true),
            ("sep1", "", false),
            ("streamChosen", "Stream selection", false),
            ("streamFormat", "Stream format", false),
            ("streamThroughput", "Network throughput", false),
            ("streamData", "Stream data received", false),
            ("streamDuration", "Stream uptime", false),
            ("streamServer", "Stream server", true),
            ("sep2", "", false),
            ("duration", "Session duration", false),
            ("songs", "Songs played", false),
            ("channels", "Station changes", false),
            ("trackArt", "Track artwork fetched", false),
            ("stationArt", "Station artwork fetched", false),
            ("artworkSize", "Total artwork downloaded", false),
        ]

        let rowHeight: CGFloat = 20
        let separatorHeight: CGFloat = 12
        var totalHeight: CGFloat = 20 // top padding

        for (key, _, _) in rows {
            if key.hasPrefix("sep") {
                totalHeight += separatorHeight
            } else {
                totalHeight += rowHeight
            }
        }
        totalHeight += 10 // bottom padding

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalHeight))

        var y = totalHeight - 16

        for (key, title, selectable) in rows {
            if key.hasPrefix("sep") {
                y -= separatorHeight
                continue
            }

            y -= rowHeight

            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = .systemFont(ofSize: 11)
            titleLabel.textColor = .secondaryLabelColor
            titleLabel.frame = NSRect(x: 16, y: y, width: 160, height: 16)
            container.addSubview(titleLabel)

            let valueLabel: NSTextField
            if selectable {
                valueLabel = NSTextField(string: "—")
                valueLabel.isEditable = false
                valueLabel.isBordered = false
                valueLabel.drawsBackground = false
                valueLabel.isSelectable = true
                valueLabel.lineBreakMode = .byTruncatingTail
            } else {
                valueLabel = NSTextField(labelWithString: "—")
            }
            valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            valueLabel.frame = NSRect(x: 180, y: y, width: width - 196, height: 16)
            valueLabel.alignment = .left
            container.addSubview(valueLabel)

            labels[key] = valueLabel
        }

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateStats()

        NotificationCenter.default.addObserver(self, selector: #selector(updateStats), name: .sessionStatsUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateStats), name: .radioPlayerStateUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateStats), name: .radioPlayerTrackNameUpdated, object: nil)

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDynamicFields()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        view.window?.close()
    }

    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func updateStats() {
        let stats = SessionStats.shared

        // Playback state
        let state: String
        switch RadioPlayer.player.timeControlStatus {
        case .playing: state = "Playing"
        case .paused: state = "Stopped"
        case .waitingToPlayAtSpecifiedRate: state = "Connecting..."
        @unknown default: state = "Unknown"
        }
        labels["state"]?.stringValue = state

        // Track
        labels["track"]?.stringValue = RadioPlayer.currentTrack ?? "—"

        // Station info
        if let channel = SomaAPI.lastPlayedChannel {
            labels["station"]?.stringValue = channel.title
            labels["description"]?.stringValue = channel.description ?? "—"
            labels["genre"]?.stringValue = channel.genre?.replacingOccurrences(of: "|", with: ", ") ?? "—"
            labels["dj"]?.stringValue = channel.dj?.isEmpty == false ? channel.dj! : "—"
            labels["listeners"]?.stringValue = "\(channel.listeners)"

            // Stream selection (what was chosen based on preferences)
            if let playlist = channel.bestQualityPlaylist {
                let format = playlist.format.rawValue.uppercased()
                let quality = playlist.quality.rawValue.capitalized
                let bitrate = bitrateFromURL(playlist.url)
                if let bitrate = bitrate {
                    labels["streamChosen"]?.stringValue = "\(format) \(quality) (\(bitrate))"
                } else {
                    labels["streamChosen"]?.stringValue = "\(format) \(quality)"
                }
            } else {
                labels["streamChosen"]?.stringValue = "—"
            }
        } else {
            labels["station"]?.stringValue = "—"
            labels["description"]?.stringValue = "—"
            labels["genre"]?.stringValue = "—"
            labels["dj"]?.stringValue = "—"
            labels["listeners"]?.stringValue = "—"
            labels["streamChosen"]?.stringValue = "—"
        }

        // Stream info from access log
        updateStreamInfo()

        // Session stats
        labels["duration"]?.stringValue = stats.formattedSessionDuration
        labels["songs"]?.stringValue = "\(stats.songsPlayed)"
        labels["channels"]?.stringValue = "\(stats.channelChanges)"
        labels["trackArt"]?.stringValue = "\(stats.trackArtworkFetched)"
        labels["stationArt"]?.stringValue = "\(stats.stationArtworkFetched)"
        labels["artworkSize"]?.stringValue = stats.formattedTotalArtworkSize
        labels["streamData"]?.stringValue = stats.formattedStreamSize
    }

    private func updateDynamicFields() {
        labels["duration"]?.stringValue = SessionStats.shared.formattedSessionDuration
        updateStreamInfo()
        labels["streamData"]?.stringValue = SessionStats.shared.formattedStreamSize
    }

    private func updateStreamInfo() {
        guard let item = RadioPlayer.player.currentItem,
              let event = item.accessLog()?.events.last else {
            labels["streamFormat"]?.stringValue = "—"
            labels["streamThroughput"]?.stringValue = "—"
            labels["streamData"]?.stringValue = SessionStats.shared.formattedStreamSize
            labels["streamDuration"]?.stringValue = "—"
            labels["streamServer"]?.stringValue = "—"
            return
        }

        // Format from URI
        let uri = event.uri ?? ""
        let format: String
        if uri.contains("aacp") || (uri.contains("aac") && !uri.contains("aac1")) {
            format = "AAC"
        } else if uri.contains("mp3") {
            format = "MP3"
        } else {
            format = "Audio"
        }
        labels["streamFormat"]?.stringValue = format

        // Network throughput
        let observedBitrate = event.observedBitrate
        if observedBitrate > 0 {
            let kbps = Int(observedBitrate / 1000)
            labels["streamThroughput"]?.stringValue = "\(kbps) kbps"
        } else {
            labels["streamThroughput"]?.stringValue = "—"
        }

        // Stream data from access log
        let totalBytes = item.accessLog()?.events.reduce(Int64(0)) { $0 + $1.numberOfBytesTransferred } ?? 0
        if totalBytes > 0 {
            labels["streamData"]?.stringValue = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }

        // Stream uptime (how long connected to current stream)
        let duration = event.durationWatched
        if duration > 0 {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            let seconds = Int(duration) % 60
            if hours > 0 {
                labels["streamDuration"]?.stringValue = String(format: "%dh %02dm %02ds", hours, minutes, seconds)
            } else {
                labels["streamDuration"]?.stringValue = String(format: "%dm %02ds", minutes, seconds)
            }
        } else {
            labels["streamDuration"]?.stringValue = "—"
        }

        // Stream server (host from URI)
        if let url = URL(string: uri), let host = url.host {
            labels["streamServer"]?.stringValue = host
        } else {
            labels["streamServer"]?.stringValue = "—"
        }
    }

    /// Extract bitrate from PLS URL naming convention (e.g., groovesalad256.pls → 256k)
    private func bitrateFromURL(_ url: URL) -> String? {
        let filename = url.deletingPathExtension().lastPathComponent
        // Match trailing digits: e.g. "groovesalad256" → "256", "groovesalad130" → "130"
        let pattern = "(\\d+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
              let range = Range(match.range(at: 1), in: filename) else {
            // No number suffix — default MP3 streams are typically 128k
            return "128k"
        }
        let number = String(filename[range])
        // Common SomaFM bitrates: 32, 64, 130 (=128 AAC), 256, 320
        switch number {
        case "130": return "128k"
        case "320": return "320k"
        case "256": return "256k"
        case "80": return "80k"
        case "64": return "64k"
        case "32": return "32k"
        default: return "\(number)k"
        }
    }

    // MARK: - Window Creation

    static func showWindow() {
        if let wc = windowController, let window = wc.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vc = StatisticsViewController()
        let window = NSWindow(contentViewController: vc)
        window.title = "Statistics"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let wc = NSWindowController(window: window)
        windowController = wc
    }
}
