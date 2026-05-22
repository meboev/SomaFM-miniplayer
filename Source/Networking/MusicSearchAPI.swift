//
//  MusicSearchAPI.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

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
        guard let encoded = trackName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        trackSearchURL = URL(string: "https://music.youtube.com/search?q=" + encoded)
    }

    static func searchSpotify(_ trackName: String) {
        guard let encoded = trackName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        trackSearchURL = URL(string: "https://open.spotify.com/search/" + encoded)
    }

    static func searchAppleMusic(_ trackName: String) {
        guard let encoded = trackName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        trackSearchURL = URL(string: "https://music.apple.com/us/search?term=" + encoded)
    }

    struct SearchResultsList: Codable {
        let results: [SearchResult]
    }
}
