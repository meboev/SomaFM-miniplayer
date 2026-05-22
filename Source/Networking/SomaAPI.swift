//
//  SomaAPI.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation
import Cocoa

public extension Notification.Name {
    static let somaApiChannelsUpdated = Notification.Name("SomaAPI.Channels.Updated")
    static let somaApiError = Notification.Name("SomaAPI.Error")
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

    static func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "SomaFM Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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

        let session = URLSession(configuration: URLSessionConfiguration.default)
        let request = URLRequest(url: channelsURL)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                showError("Failed to load channels: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                showError("Invalid response from SomaFM API")
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                showError("SomaFM API returned status \(httpResponse.statusCode)")
                return
            }

            guard let data = data else {
                showError("No data received from SomaFM API")
                return
            }

            do {
                let channelList = try JSONDecoder().decode(ChannelList.self, from: data)
                self.channels = channelList.channels
                SomaAPI.saveChannelsToDisk()
            } catch {
                showError("Failed to parse channels: \(error.localizedDescription)")
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
            print("SomaAPI: Error saving channels to disk")
        }
    }

    static func getChannelsFromDisk() {
        guard let url = fileCacheURL() else { return }

        do {
            let data = try Data(contentsOf: url, options: [])
            let channelsToLoad = try JSONDecoder().decode([Channel].self, from: data)
            self.channels = channelsToLoad
        } catch {
            print("SomaAPI: Error loading channels from disk")
        }
    }
}
