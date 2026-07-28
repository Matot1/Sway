import Foundation
import Combine
import Cocoa

class SpotifyService: MusicServiceProtocol {
    private let trackSubject = CurrentValueSubject<Track?, Never>(nil)
    private let authSubject = CurrentValueSubject<Bool, Never>(false)

    var trackPublisher: AnyPublisher<Track?, Never> { trackSubject.eraseToAnyPublisher() }
    var authPublisher: AnyPublisher<Bool, Never> { authSubject.eraseToAnyPublisher() }

    var currentTrack: Track? { trackSubject.value }
    var isAuthorized: Bool { authSubject.value }

    private var pollingTimer: AnyCancellable?
    private let bgQueue = DispatchQueue(label: "spotify.poll", qos: .utility)

    private static let bundleID = "com.spotify.client"

    init() {
        checkAuthorization()
        startObserving()
    }

    func authorize() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) {
            NSWorkspace.shared.open(url)
        }
        authSubject.send(true)
    }

    func playPause() {
        runOSAScript("tell application \"Spotify\" to playpause")
    }

    func nextTrack() {
        runOSAScript("tell application \"Spotify\" to next track")
    }

    func previousTrack() {
        runOSAScript("tell application \"Spotify\" to previous track")
    }

    func startObserving() {
        pollingTimer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.poll()
            }
    }

    func stopObserving() {
        pollingTimer?.cancel()
        pollingTimer = nil
    }

    private func poll() {
        guard isRunning else { return }
        bgQueue.async { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    private func fetchNowPlaying() {
        let script = """
        set output to ""
        tell application "Spotify"
            if player state is playing or player state is paused then
                set trackId to id of current track
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set trackDuration to duration of current track
                set trackPosition to player position
                set isPlaying to player state is playing
                set output to trackId & "|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & trackPosition & "|||" & isPlaying
            end if
        end tell
        return output
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        task.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        task.standardOutput = pipe
        var trackID: String?
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            trackID = parseResult(output)
        } catch {
        }

        guard let tid = trackID else { return }
        let normalized = tid.replacingOccurrences(of: "spotify:track:", with: "")
        guard !normalized.isEmpty else { return }

        let savePath = NSTemporaryDirectory() + "spotify-art-\(normalized).jpg"
        if !FileManager.default.fileExists(atPath: savePath) {
            guard let url = URL(string: "https://open.spotify.com/oembed?url=spotify:track:\(normalized)") else { return }
            guard let jsonData = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let thumbURL = json["thumbnail_url"] as? String,
                  let imgURL = URL(string: thumbURL),
                  let imgData = try? Data(contentsOf: imgURL) else { return }
            try? imgData.write(to: URL(fileURLWithPath: savePath))
            guard FileManager.default.fileExists(atPath: savePath) else { return }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, let t = self.trackSubject.value, t.id == tid else { return }
            let withArt = Track(
                id: t.id, title: t.title, artist: t.artist, album: t.album,
                albumArtURL: URL(fileURLWithPath: savePath), duration: t.duration,
                progress: t.progress, isPlaying: t.isPlaying, provider: .spotify
            )
            if withArt != t {
                self.trackSubject.send(withArt)
            }
        }
    }

    @discardableResult
    private func parseResult(_ output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        guard let line = lines.first(where: { !$0.isEmpty }) else { return nil }
        let parts = line.components(separatedBy: "|||")
        guard parts.count >= 7 else { return nil }

        let title = parts[1]
        guard !title.isEmpty else { return nil }
        let artist = parts[2]
        let album = parts[3]
        let duration = TimeInterval(parts[4]) ?? 0
        let position = TimeInterval(parts[5]) ?? 0
        let isPlaying = parts[6] == "true"
        let trackId = parts[0]

        let current = trackSubject.value
        if current?.id == trackId, let artURL = current?.albumArtURL {
            let reuse = Track(
                id: trackId, title: title, artist: artist, album: album,
                albumArtURL: artURL, duration: duration / 1000, progress: position,
                isPlaying: isPlaying, provider: .spotify
            )
            if reuse != current {
                DispatchQueue.main.async {
                    self.trackSubject.send(reuse)
                }
            }
            return trackId
        }

        let track = Track(
            id: trackId,
            title: title,
            artist: artist,
            album: album,
            albumArtURL: nil,
            duration: duration / 1000,
            progress: position,
            isPlaying: isPlaying,
            provider: .spotify
        )
        DispatchQueue.main.async {
            self.trackSubject.send(track)
        }
        return trackId
    }

    private var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == Self.bundleID })
    }

    private func checkAuthorization() {
        authSubject.send(isRunning)
    }

    private func runOSAScript(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", command]
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    deinit {
        stopObserving()
    }
}
