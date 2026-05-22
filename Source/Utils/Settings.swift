//
//  Settings.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation

enum UserDefaultsKey {
    static let volume = "RadioPlayer.Volume"
    static let lastPlayedChannel = "RadioPlayer.Channel.LastPlayed"
    static let shouldPlayOnLaunch = "RadioPlayer.ShouldPlayOnLaunch"
    static let notificationsEnabled = "RadioPlayer.NotificationsEnabled"
    static let musicSearchProvider = "RadioPlayer.MusicSearchProvider"
    static let apiCacheTimestamp = "SomaAPI.Cache.Timestamp"
    static let apiChannelsSortOrder = "SomaAPI.Channels.SortOrder"
}

enum ChannelsSortOrder: Int {
    case `default`
    case listeners
    case alphabetically
}

enum MusicSearchProvider: Int {
    case youtubeMusic
    case spotify
    case appleMusic
}

struct Settings {
    static var volume: Float {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.volume) as? Float ?? 0.07
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.volume)
        }
    }

    static var cacheTimestamp: Date? {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.apiCacheTimestamp) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.apiCacheTimestamp)
        }
    }

    static var channelsSortOrder: ChannelsSortOrder {
        get {
            if let intValue = UserDefaults.standard.object(forKey: UserDefaultsKey.apiChannelsSortOrder) as? Int,
                let enumValue = ChannelsSortOrder(rawValue: intValue) {
                return enumValue
            } else {
                return .listeners
            }
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.apiChannelsSortOrder)
        }
    }

    static var lastPlayedChannelId: String {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.lastPlayedChannel) as? String ?? "groovesalad"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.lastPlayedChannel)
        }
    }

    static var shouldPlayOnLaunch: Bool {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.shouldPlayOnLaunch) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.shouldPlayOnLaunch)
        }
    }

    static var notificationsEnabled: Bool {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.notificationsEnabled) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.notificationsEnabled)
        }
    }

    static var musicSearchProvider: MusicSearchProvider {
        get {
            if let intValue = UserDefaults.standard.object(forKey: UserDefaultsKey.musicSearchProvider) as? Int,
               let enumValue = MusicSearchProvider(rawValue: intValue) {
                return enumValue
            } else {
                return .youtubeMusic
            }
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.musicSearchProvider)
        }
    }
}
