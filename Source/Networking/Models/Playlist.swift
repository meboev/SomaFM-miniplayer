//
//  Playlist.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Foundation

public struct Playlist: Codable {
    enum Format: String, Codable {
        case aac
        case aacp
        case mp3
    }

    enum Quality: String, Codable {
        case highest
        case high
        case low
    }

    let url: URL
    let format: Format
    let quality: Quality
}
