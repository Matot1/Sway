import Foundation
import Combine

protocol MusicServiceProtocol: AnyObject {
    var trackPublisher: AnyPublisher<Track?, Never> { get }
    var authPublisher: AnyPublisher<Bool, Never> { get }
    var currentTrack: Track? { get }
    var isAuthorized: Bool { get }

    func authorize()
    func playPause()
    func nextTrack()
    func previousTrack()
    func startObserving()
    func stopObserving()
}
