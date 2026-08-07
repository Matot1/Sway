import SwiftUI
import Combine

class MusicViewModel: ObservableObject {
    @Published var currentTrack: Track = .placeholder
    @Published var isAuthorized: Bool = false
    @Published var activeProvider: MusicProvider = .yandexMusic

    private var serviceCancellables = Set<AnyCancellable>()
    private var defaultsObserver: AnyCancellable?
    private var service: (any MusicServiceProtocol)?

    static let providerDefaultsKey = "musicProvider"

    init() {
        defaultsObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.syncProvider()
            }
        installService(for: selectedProvider())
    }

    deinit {
        service?.stopObserving()
    }

    private func selectedProvider() -> MusicProvider {
        let stored = UserDefaults.standard.string(forKey: Self.providerDefaultsKey)
        return MusicProvider.fromStorageKey(stored ?? "") ?? .yandexMusic
    }

    private func syncProvider() {
        let provider = selectedProvider()
        guard provider != activeProvider else { return }
        activeProvider = provider
        installService(for: provider)
    }

    private func installService(for provider: MusicProvider) {
        service?.stopObserving()
        service = nil
        serviceCancellables.removeAll()

        let newService: MusicServiceProtocol
        switch provider {
        case .spotify: newService = SpotifyService()
        case .appleMusic: newService = AppleMusicService()
        case .yandexMusic: newService = YandexMusicService()
        }
        service = newService

        isAuthorized = newService.isAuthorized
        if let track = newService.currentTrack {
            currentTrack = track
        } else {
            currentTrack = .placeholder
        }

        newService.trackPublisher
            .compactMap { $0 }
            .sink { [weak self] track in
                self?.currentTrack = track
            }
            .store(in: &serviceCancellables)

        newService.authPublisher
            .sink { [weak self] authorized in
                self?.isAuthorized = authorized
            }
            .store(in: &serviceCancellables)
    }

    func playPause() {
        let t = currentTrack
        currentTrack = Track(
            id: t.id, title: t.title, artist: t.artist, album: t.album,
            albumArtURL: t.albumArtURL, duration: t.duration, progress: t.progress,
            isPlaying: !t.isPlaying, provider: t.provider
        )
        service?.playPause()
    }

    func nextTrack() {
        service?.nextTrack()
    }

    func previousTrack() {
        service?.previousTrack()
    }

    func authorize() {
        service?.authorize()
    }
}
