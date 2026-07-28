import Foundation
import Combine
import Cocoa

private let NX_KEYTYPE_PLAY: Int32 = 16
private let NX_KEYTYPE_NEXT: Int32 = 17
private let NX_KEYTYPE_PREVIOUS: Int32 = 18

class YandexMusicService: MusicServiceProtocol {
    private let trackSubject = CurrentValueSubject<Track?, Never>(nil)
    private let authSubject = CurrentValueSubject<Bool, Never>(false)

    var trackPublisher: AnyPublisher<Track?, Never> { trackSubject.eraseToAnyPublisher() }
    var authPublisher: AnyPublisher<Bool, Never> { authSubject.eraseToAnyPublisher() }

    var currentTrack: Track? { trackSubject.value }
    var isAuthorized: Bool { authSubject.value }

    private var pollingTimer: AnyCancellable?
    private let bgQueue = DispatchQueue(label: "yandex.mediaremote", qos: .utility, attributes: .concurrent)

    private static let bundleID = "ru.yandex.desktop.music"

    private typealias MRMediaRemoteGetNowPlayingInfoFn = @convention(c) (AnyObject, @escaping @convention(block) (NSDictionary) -> Void) -> Void
    private typealias MRMediaRemoteGetNowPlayingClientFn = @convention(c) (@escaping @convention(block) (AnyObject?) -> Void) -> Void

    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFn?
    private var getNowPlayingClient: MRMediaRemoteGetNowPlayingClientFn?
    private func loadMediaRemote() {
        let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, url as CFURL) else { return }
        CFBundleLoadExecutable(bundle)
        if let fn = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            getNowPlayingInfo = unsafeBitCast(fn, to: MRMediaRemoteGetNowPlayingInfoFn.self)
        }
        if let fn = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingClient" as CFString) {
            getNowPlayingClient = unsafeBitCast(fn, to: MRMediaRemoteGetNowPlayingClientFn.self)
        }
    }

    init() {
        loadMediaRemote()
        checkAuthorization()
        startObserving()
    }

    func authorize() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) {
            NSWorkspace.shared.open(url)
        }
    }

    func playPause() {
        postMediaKey(NX_KEYTYPE_PLAY)
    }

    func nextTrack() {
        postMediaKey(NX_KEYTYPE_NEXT, delayPoll: 0.3)
    }

    func previousTrack() {
        postMediaKey(NX_KEYTYPE_PREVIOUS, delayPoll: 0.3)
    }

    private func postMediaKey(_ key: Int32, delayPoll: TimeInterval = 0) {
        let loc = NSPoint(x: NSScreen.main?.frame.midX ?? 0, y: 0)
        let down = NSEvent.otherEvent(
            with: .systemDefined, location: loc, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: Int((key << 16) | (0x0a << 8)), data2: -1
        )
        let up = NSEvent.otherEvent(
            with: .systemDefined, location: loc, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: Int((key << 16) | (0x0b << 8)), data2: -1
        )
        down?.cgEvent?.post(tap: .cghidEventTap)
        up?.cgEvent?.post(tap: .cghidEventTap)

        if delayPoll > 0 {
            bgQueue.asyncAfter(deadline: .now() + delayPoll) { [weak self] in
                self?.fetchNowPlaying()
            }
        }
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
        let running = isAppRunning()
        authSubject.send(running)
        checkClient()
        fetchNowPlaying()
    }

    private func checkClient() {
        guard let getClient = getNowPlayingClient else { return }
        getClient { _ in }
    }

    private func fetchNowPlaying() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        let script = """
        import Foundation
        let h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)
        typealias F = @convention(c) (AnyObject, @escaping @convention(block) ([String:Any]) -> Void) -> Void
        let f = unsafeBitCast(dlsym(h, "MRMediaRemoteGetNowPlayingInfo"), to: F.self)
        let sem = DispatchSemaphore(value: 0)
        let q = DispatchQueue(label: "t", attributes: .concurrent)
        f(q as AnyObject) { info in
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            let dur = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            let pos = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
            let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let id = info["kMRMediaRemoteNowPlayingInfoContentItemIdentifier"] as? String ?? ""
            let path = NSTemporaryDirectory() + "ya-" + UUID().uuidString + ".jpg"
            if let d = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                try? d.write(to: URL(fileURLWithPath: path))
            }
            print("RESULT: \\(title)|||\\(artist)|||\\(album)|||\\(dur)|||\\(pos)|||\\(rate)|||\\(id)|||\\(path)")
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 3)
        """
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            parseHelperOutput(output)
        } catch {
        }
    }

    private func parseHelperOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        guard let resultLine = lines.first(where: { $0.hasPrefix("RESULT:") }) else { return }
        let payload = String(resultLine.dropFirst(7))
        let parts = payload.components(separatedBy: "|||")
        guard parts.count >= 7 else { return }

        let title = parts[0].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        let artist = parts[1].trimmingCharacters(in: .whitespaces)
        let album = parts[2].trimmingCharacters(in: .whitespaces)
        let duration = TimeInterval(parts[3]) ?? 0
        let progress = TimeInterval(parts[4]) ?? 0
        let rate = Double(parts[5]) ?? 0
        let identifier = parts[6]
        let imagePath = parts.count > 7 ? parts[7] : ""

        let track = Track(
            id: identifier.isEmpty ? UUID().uuidString : identifier,
            title: title,
            artist: artist,
            album: album,
            albumArtURL: imagePath.isEmpty ? nil : URL(fileURLWithPath: imagePath),
            duration: duration,
            progress: progress,
            isPlaying: rate > 0,
            provider: .yandexMusic
        )

        DispatchQueue.main.async {
            self.trackSubject.send(track)
        }
    }

    private func isAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == Self.bundleID })
    }

    private func checkAuthorization() {
        authSubject.send(isAppRunning())
    }
}
