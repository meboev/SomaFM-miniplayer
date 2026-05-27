//
//  SessionStats.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Foundation
import AVFoundation

/// Tracks runtime statistics for the current session.
class SessionStats {
    static let shared = SessionStats()

    private(set) var songsPlayed: Int = 0
    private(set) var channelChanges: Int = 0
    private(set) var trackArtworkFetched: Int = 0
    private(set) var trackArtworkBytes: Int64 = 0
    private(set) var stationArtworkFetched: Int = 0
    private(set) var stationArtworkBytes: Int64 = 0
    private(set) var streamBytesReceived: Int64 = 0
    private(set) var sessionStart: Date = Date()

    private init() {}

    /// Total bytes = accumulated from previous items + current item's access log
    var totalStreamBytes: Int64 {
        guard let item = RadioPlayer.player.currentItem,
              let events = item.accessLog()?.events else { return streamBytesReceived }
        let currentBytes = events.reduce(Int64(0)) { $0 + $1.numberOfBytesTransferred }
        return streamBytesReceived + currentBytes
    }

    func snapshotCurrentItemBytes() {
        // Called before replacing player item — save current item bytes
        guard let item = RadioPlayer.player.currentItem,
              let events = item.accessLog()?.events else { return }
        let currentBytes = events.reduce(Int64(0)) { $0 + $1.numberOfBytesTransferred }
        streamBytesReceived += currentBytes
    }

    var formattedStreamSize: String {
        ByteCountFormatter.string(fromByteCount: totalStreamBytes, countStyle: .file)
    }

    func recordSongPlayed() {
        songsPlayed += 1
        NotificationCenter.default.post(name: .sessionStatsUpdated, object: nil)
    }

    func recordChannelChange() {
        channelChanges += 1
        NotificationCenter.default.post(name: .sessionStatsUpdated, object: nil)
    }

    func recordTrackArtwork(bytes: Int64) {
        trackArtworkFetched += 1
        trackArtworkBytes += bytes
        NotificationCenter.default.post(name: .sessionStatsUpdated, object: nil)
    }

    func recordStationArtwork(bytes: Int64) {
        stationArtworkFetched += 1
        stationArtworkBytes += bytes
        NotificationCenter.default.post(name: .sessionStatsUpdated, object: nil)
    }

    var sessionDuration: TimeInterval {
        return Date().timeIntervalSince(sessionStart)
    }

    var formattedSessionDuration: String {
        let interval = Int(sessionDuration)
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }

    var formattedTotalArtworkSize: String {
        let total = trackArtworkBytes + stationArtworkBytes
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
}

extension Notification.Name {
    static let sessionStatsUpdated = Notification.Name("SessionStats.Updated")
}
