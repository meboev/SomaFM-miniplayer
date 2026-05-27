//
//  SomaAPI.swift
//
//  Copyright © 2026 Milen Boev. All rights reserved.

import Foundation

public extension Notification.Name {
    static let somaApiChannelsUpdated = Notification.Name("SomaAPI.Channels.Updated")
}

public struct SomaAPI {
    static var channels: [Channel]? {
        didSet {
            NotificationCenter.default.post(name: .somaApiChannelsUpdated, object: nil)
        }
    }

    static var lastPlayedChannel: Channel? {
        let channelId = Settings.lastPlayedChannelId
        return channels?.first(where: { $0.id == channelId })
    }

    static func loadChannels() {
        getChannelsFromDisk()
        loadChannelsFromAPI()
    }
}

private extension SomaAPI {
    // MARK: - Networking

    struct ChannelList: Codable {
        let channels: [Channel]
    }

    static let channelsURL = URL(string: "https://api.somafm.com/channels.json")!

    static func loadChannelsFromAPI() {
        if channels != nil,
            let cacheTimestamp = Settings.cacheTimestamp,
            Date().timeIntervalSince(cacheTimestamp) < 3*60 {
            // channels are still fresh, do not update
            return
        }

        let request = URLRequest(url: channelsURL)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                RadioPlayer.postErrorNotification("Failed to load channels: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                RadioPlayer.postErrorNotification("Invalid response from SomaFM API")
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                RadioPlayer.postErrorNotification("SomaFM API returned status \(httpResponse.statusCode)")
                return
            }

            guard let data = data else {
                RadioPlayer.postErrorNotification("No data received from SomaFM API")
                return
            }

            do {
                let channelList = try JSONDecoder().decode(ChannelList.self, from: data)
                self.channels = channelList.channels
                SomaAPI.saveChannelsToDisk()
            } catch {
                RadioPlayer.postErrorNotification("Failed to parse channels: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Persistence

    static func fileCacheURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let appDir = appSupport.appendingPathComponent("SomaFM miniplayer")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("somafm_channels.json")
    }

    static func saveChannelsToDisk() {
        guard let channelsToSave = self.channels,
            let url = fileCacheURL() else { return }

        do {
            let data = try JSONEncoder().encode(channelsToSave)
            try data.write(to: url, options: [])
            Settings.cacheTimestamp = Date()
        } catch {
            Log.warning("SomaAPI: Error saving channels to disk")
        }
    }

    static func getChannelsFromDisk() {
        guard let url = fileCacheURL() else { return }

        do {
            let data = try Data(contentsOf: url, options: [])
            let channelsToLoad = try JSONDecoder().decode([Channel].self, from: data)
            self.channels = channelsToLoad
        } catch {
            Log.warning("SomaAPI: Error loading channels from disk")
        }
    }
}
