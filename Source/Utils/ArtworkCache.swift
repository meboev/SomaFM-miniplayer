//
//  ArtworkCache.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Cocoa

struct ArtworkCache {
    private static var artworkDir: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("SomaFM miniplayer/artwork")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Returns cached image for channel, or nil if not cached.
    static func image(for channelId: String) -> NSImage? {
        guard let url = fileURL(for: channelId), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Saves image data to disk for a channel.
    static func save(data: Data, for channelId: String) {
        guard let url = fileURL(for: channelId) else { return }
        try? data.write(to: url)
    }

    /// Fetches artwork for a channel, using disk cache if available. Calls completion on main thread.
    static func fetchImage(for channel: Channel, completion: @escaping (NSImage?) -> Void) {
        // Check disk cache first
        if let cached = image(for: channel.id) {
            completion(cached)
            return
        }

        // Download
        guard let imageURL = channel.xlimage ?? channel.largeimage ?? channel.image else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: imageURL) { data, _, error in
            guard let data = data, error == nil, let image = NSImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            save(data: data, for: channel.id)
            DispatchQueue.main.async {
                SessionStats.shared.recordStationArtwork(bytes: Int64(data.count))
                completion(image)
            }
        }.resume()
    }

    /// Removes all cached artwork (call when channels are refreshed from API).
    static func clearAll() {
        guard let dir = artworkDir else { return }
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private static func fileURL(for channelId: String) -> URL? {
        return artworkDir?.appendingPathComponent("\(channelId).jpg")
    }
}
