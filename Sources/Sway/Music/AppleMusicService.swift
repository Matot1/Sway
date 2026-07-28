import Foundation
import Combine
import Cocoa

class AppleMusicService: MusicServiceProtocol {
    private let trackSubject = CurrentValueSubject<Track?, Never>(nil)
    private let authSubject = CurrentValueSubject<Bool, Never>(false)

    var trackPublisher: AnyPublisher<Track?, Never> { trackSubject.eraseToAnyPublisher() }
    var authPublisher: AnyPublisher<Bool, Never> { authSubject.eraseToAnyPublisher() }

    var currentTrack: Track? { trackSubject.value }
    var isAuthorized: Bool { authSubject.value }

    private var pollingTimer: AnyCancellable?

    init() {
        checkAuthorization()
        startObserving()
    }

    func authorize() {
        if let url = URL(string: "music://") {
            NSWorkspace.shared.open(url)
        }
        authSubject.send(true)
    }

    func playPause() {
        runAppleScript("tell application \"Music\" to playpause")
    }

    func nextTrack() {
        runAppleScript("tell application \"Music\" to next track")
    }

    func previousTrack() {
        runAppleScript("tell application \"Music\" to previous track")
    }

    func startObserving() {
        pollingTimer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollCurrentTrack()
            }
    }

    func stopObserving() {
        pollingTimer?.cancel()
        pollingTimer = nil
    }

    private func pollCurrentTrack() {
        guard isRunning else { return }

        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set trackId to (persistent ID of current track) as string
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set trackDuration to duration of current track
                set trackPosition to player position
                set isPlaying to player state is playing
                return trackId & "|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & trackPosition & "|||" & isPlaying
            end if
        end tell
        """

        guard let result = runAppleScriptWithResult(script) else { return }
        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 7 else { return }

        let trackId = parts[0]
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = TimeInterval(parts[4]) ?? 0
        let position = TimeInterval(parts[5]) ?? 0
        let isPlaying = parts[6] == "true"

        let track = Track(
            id: trackId,
            title: title,
            artist: artist,
            album: album,
            albumArtURL: nil,
            duration: duration,
            progress: position,
            isPlaying: isPlaying,
            provider: .appleMusic
        )
        trackSubject.send(track)
    }

    private var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Music"
        }
    }

    private func checkAuthorization() {
        authSubject.send(isRunning)
    }

    private func runAppleScript(_ command: String) {
        var error: NSDictionary?
        if let script = NSAppleScript(source: command) {
            script.executeAndReturnError(&error)
        }
    }

    private func runAppleScriptWithResult(_ command: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: command) else { return nil }
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }

    deinit {
        stopObserving()
    }
}
