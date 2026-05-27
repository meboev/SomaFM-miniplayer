//
//  TrackArtworkFetcher.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Cocoa
import CryptoKit

/// Fetches track-specific album artwork from the iTunes Search API with disk caching.
struct TrackArtworkFetcher {

    private static let artworkSize = 600 // 600x600 — good quality for notifications and Now Playing

    private static var cacheDir: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("SomaFM miniplayer/track-artwork")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Fetches track artwork. Calls completion on main thread with the image, or nil if not found.
    static func fetchImage(artist: String, title: String, completion: @escaping (NSImage?) -> Void) {
        let cacheKey = cacheKeyFor(artist: artist, title: title)

        // Check disk cache
        if let url = fileURL(for: cacheKey), FileManager.default.fileExists(atPath: url.path) {
            let image = NSImage(contentsOf: url)
            DispatchQueue.main.async { completion(image) }
            return
        }

        // Build search query
        let query = "\(artist) \(title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let searchURL = URL(string: "https://itunes.apple.com/search?term=\(query)&entity=song&limit=1") else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        URLSession.shared.dataTask(with: searchURL) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artworkUrl100 = first["artworkUrl100"] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Replace 100x100 with desired size
            let artworkUrlString = artworkUrl100.replacingOccurrences(
                of: "100x100bb",
                with: "\(artworkSize)x\(artworkSize)bb"
            )

            guard let artworkURL = URL(string: artworkUrlString) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Download the artwork image
            URLSession.shared.dataTask(with: artworkURL) { imgData, _, imgError in
                guard let imgData = imgData, imgError == nil, let image = NSImage(data: imgData) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                // Cache to disk
                if let fileUrl = fileURL(for: cacheKey) {
                    try? imgData.write(to: fileUrl)
                }

                DispatchQueue.main.async {
                    SessionStats.shared.recordTrackArtwork(bytes: Int64(imgData.count))
                    completion(image)
                }
            }.resume()
        }.resume()
    }

    /// Parses a track string like "Artist - Title" into components.
    static func parseTrack(_ trackName: String) -> (artist: String, title: String)? {
        let parts = trackName.components(separatedBy: " - ")
        guard parts.count >= 2 else { return nil }
        let artist = parts[0].trimmingCharacters(in: .whitespaces)
        let title = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
        return (artist, title)
    }

    // MARK: - Private

    private static func cacheKeyFor(artist: String, title: String) -> String {
        let normalized = "\(artist)-\(title)".lowercased()
        let hash = SHA256.hash(data: Data(normalized.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func fileURL(for key: String) -> URL? {
        return cacheDir?.appendingPathComponent("\(key).jpg")
    }

    /// Removes all cached track artwork.
    static func clearCache() {
        guard let dir = cacheDir else { return }
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
