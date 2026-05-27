//
//  Channel.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Foundation

public struct Channel: Codable {
    let id: String
    let title: String
    let description: String?
    let dj: String?
    let genre: String?
    let image: URL?
    let largeimage: URL?
    let xlimage: URL?
    let twitter: String?
    let updated: String
    let listeners: Int
    let lastPlaying: String?

    let playlists: [Playlist]

    var bestQualityPlaylist: Playlist? {
        let prefFormat = Settings.preferredFormat  // 0=Any, 1=AAC, 2=MP3
        let prefQuality = Settings.preferredQuality  // 0=Highest, 1=High, 2=Low

        let targetFormats: [Playlist.Format]
        switch prefFormat {
        case 1: targetFormats = [.aac, .aacp]
        case 2: targetFormats = [.mp3]
        default: targetFormats = [.aac, .aacp, .mp3]
        }

        let targetQualities: [Playlist.Quality]
        switch prefQuality {
        case 0: targetQualities = [.highest, .high, .low]
        case 1: targetQualities = [.high, .highest, .low]
        case 2: targetQualities = [.low, .high, .highest]
        default: targetQualities = [.highest, .high, .low]
        }

        // Try preferred format + preferred quality order
        for quality in targetQualities {
            if let match = playlists.first(where: { targetFormats.contains($0.format) && $0.quality == quality }) {
                return match
            }
        }

        // Fallback: any format with preferred quality order
        for quality in targetQualities {
            if let match = playlists.first(where: { $0.quality == quality }) {
                return match
            }
        }

        return playlists.first
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try? container.decode(String.self, forKey: .description)
        self.dj = try? container.decode(String.self, forKey: .dj)
        self.genre = try? container.decode(String.self, forKey: .genre)
        self.image = try? container.decode(URL.self, forKey: .image)
        self.largeimage = try? container.decode(URL.self, forKey: .largeimage)
        self.xlimage = try? container.decode(URL.self, forKey: .xlimage)
        self.twitter = try? container.decode(String.self, forKey: .twitter)
        self.updated = try container.decode(String.self, forKey: .updated)
        if let listenersString = try? container.decode(String.self, forKey: .listeners) {
            self.listeners = Int(listenersString) ?? 0
        } else if let listenersInt = try? container.decode(Int.self, forKey: .listeners) {
            self.listeners = listenersInt
        } else {
            self.listeners = 0
        }
        self.lastPlaying = try? container.decode(String.self, forKey: .lastPlaying)

        self.playlists = try container.decode([Playlist].self, forKey: .playlists)
    }
}
