//
//  MusicSearchAPI.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Foundation

public struct MusicSearchAPI {
    static var trackSearchURL: URL?

    static func searchTrack() {
        trackSearchURL = nil

        guard let trackName = RadioPlayer.currentTrack else { return }

        switch Settings.musicSearchProvider {
        case .youtubeMusic:
            searchYouTubeMusic(trackName)
        case .spotify:
            searchSpotify(trackName)
        case .appleMusic:
            searchAppleMusic(trackName)
        }
    }
}

private extension MusicSearchAPI {
    static func searchYouTubeMusic(_ trackName: String) {
        var components = URLComponents(string: "https://music.youtube.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: trackName)]
        trackSearchURL = components?.url
    }

    static func searchSpotify(_ trackName: String) {
        guard let encoded = trackName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        trackSearchURL = URL(string: "https://open.spotify.com/search/" + encoded)
    }

    static func searchAppleMusic(_ trackName: String) {
        var components = URLComponents(string: "https://music.apple.com/us/search")
        components?.queryItems = [URLQueryItem(name: "term", value: trackName)]
        trackSearchURL = components?.url
    }
}
