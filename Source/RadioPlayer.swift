import Foundation
import AVFoundation
import Cocoa
import UserNotifications

extension Notification.Name {
    static let radioPlayerTrackNameUpdated = Notification.Name("RadioPlayer.TrackName.Updated")
    static let radioPlayerStateUpdated = Notification.Name("RadioPlayer.State.Updated")
}

struct RadioPlayer {
    private static var timeControlStatusToken: NSKeyValueObservation?
    private static var errorToken: NSKeyValueObservation?
    private static var itemStatusToken: NSKeyValueObservation?
    private static var metadataTimer: Timer?

    static var player: AVPlayer = {
        $0.volume = Settings.volume
        timeControlStatusToken = $0.observe(\.timeControlStatus) { player, _ in
            DispatchQueue.main.async {
                if player.timeControlStatus == .paused {
                    stopMetadataPolling()
                }
                NotificationCenter.default.post(name: .radioPlayerStateUpdated, object: nil)
            }
        }
        errorToken = $0.observe(\.currentItem?.error) { player, _ in
            if let error = player.currentItem?.error {
                let nsError = error as NSError
                if nsError.code != -1005 && nsError.code != -1009 {
                    postErrorNotification("Playback error: \(error.localizedDescription)")
                }
            }
        }
        return $0
    }(AVPlayer())

    static var currentTrack: String? {
        didSet {
            NotificationCenter.default.post(name: .radioPlayerTrackNameUpdated, object: nil)
        }
    }

    static func play(channel: Channel) {
        Settings.lastPlayedChannelId = channel.id

        guard let playlist = channel.bestQualityPlaylist else {
            postErrorNotification("No playable stream found for \"\(channel.title)\"")
            return
        }

        resolveStreamURL(from: playlist.url) { streamURL in
            guard let streamURL = streamURL else {
                postErrorNotification("Could not resolve stream for \"\(channel.title)\"")
                return
            }

            DispatchQueue.main.async {
                SessionStats.shared.snapshotCurrentItemBytes()
                let playerItem = makePlayerItem(url: streamURL)

                player.replaceCurrentItem(with: playerItem)
                itemStatusToken = playerItem.observe(\.status) { item, _ in
                    if item.status == .failed, let error = item.error {
                        postErrorNotification("Failed to play \"\(channel.title)\": \(error.localizedDescription)")
                    }
                }
                player.play()
                startMetadataPolling()
            }
        }
    }

    static func resumeLive() {
        guard let channel = SomaAPI.lastPlayedChannel, let playlist = channel.bestQualityPlaylist else { return }

        resolveStreamURL(from: playlist.url) { streamURL in
            guard let streamURL = streamURL else { return }

            DispatchQueue.main.async {
                SessionStats.shared.snapshotCurrentItemBytes()
                let playerItem = makePlayerItem(url: streamURL)
                player.replaceCurrentItem(with: playerItem)
                player.play()
                startMetadataPolling()
            }
        }
    }

    static func postErrorNotification(_ message: String) {
        guard Settings.errorNotificationsEnabled else { return }
        DispatchQueue.main.async {
            let content = UNMutableNotificationContent()
            content.title = "SomaFM miniplayer"
            content.body = message
            let request = UNNotificationRequest(identifier: "error-\(UUID().uuidString)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Metadata Polling

    private static func startMetadataPolling() {
        stopMetadataPolling()
        pollCurrentTrack()
        metadataTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            pollCurrentTrack()
        }
    }

    private static func stopMetadataPolling() {
        metadataTimer?.invalidate()
        metadataTimer = nil
    }

    private static func pollCurrentTrack() {
        let channelId = Settings.lastPlayedChannelId
        guard !channelId.isEmpty else { return }
        guard let url = URL(string: "https://api.somafm.com/songs/\(channelId).json") else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }

            struct SongList: Decodable {
                let songs: [Song]
            }
            struct Song: Decodable {
                let title: String
                let artist: String
            }

            guard let songList = try? JSONDecoder().decode(SongList.self, from: data),
                  let song = songList.songs.first else { return }

            let trackName = "\(song.artist) - \(song.title)"
            DispatchQueue.main.async {
                if trackName != currentTrack {
                    currentTrack = trackName
                }
            }
        }.resume()
    }

    // MARK: - Private

    private static func resolveStreamURL(from plsURL: URL, completion: @escaping (URL?) -> Void) {
        var request = URLRequest(url: plsURL)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                postErrorNotification("PLS fetch failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                postErrorNotification("PLS fetch: invalid response")
                completion(nil)
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                postErrorNotification("PLS fetch: HTTP \(httpResponse.statusCode)")
                completion(nil)
                return
            }

            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                postErrorNotification("PLS fetch: no data")
                completion(nil)
                return
            }

            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.lowercased().hasPrefix("file1=") {
                    let urlString = String(line.dropFirst(6))
                    if let streamURL = URL(string: urlString) {
                        completion(streamURL)
                    } else {
                        postErrorNotification("PLS parse: invalid URL '\(urlString)'")
                        completion(nil)
                    }
                    return
                }
            }

            postErrorNotification("PLS parse: no File1 entry found")
            completion(nil)
        }.resume()
    }

    private static func makePlayerItem(url: URL) -> AVPlayerItem {
        let headers = ["User-Agent": "SomaFMminiplayer/2.0.3 (macOS)"]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 5
        currentTrack = nil
        return item
    }
}
