import Foundation

enum NotchState: Equatable {
    case collapsed
    case hovering
    case expanded
}

enum MusicProvider: String, CaseIterable, Codable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case yandexMusic = "Yandex Music"

    var iconName: String {
        switch self {
        case .spotify: return "music.note"
        case .appleMusic: return "apple.logo"
        case .yandexMusic: return "music.note.list"
        }
    }
}

struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let albumArtURL: URL?
    let duration: TimeInterval
    let progress: TimeInterval
    let isPlaying: Bool
    let provider: MusicProvider

    static let placeholder = Track(
        id: "placeholder",
        title: "No Track Playing",
        artist: "",
        album: "",
        albumArtURL: nil,
        duration: 0,
        progress: 0,
        isPlaying: false,
        provider: .spotify
    )

    var displayTitle: String {
        id == "placeholder" ? tr("No Track Playing") : title
    }
}

enum PomodoroState: Equatable {
    case idle
    case working
    case break_
    case longBreak
}

struct PomodoroConfig {
    var workDuration: TimeInterval {
        let min = UserDefaults.standard.double(forKey: "workDuration")
        return (min > 0 ? min : 25) * 60
    }
    var shortBreakDuration: TimeInterval {
        let min = UserDefaults.standard.double(forKey: "shortBreakDuration")
        return (min > 0 ? min : 5) * 60
    }
    var longBreakDuration: TimeInterval {
        let min = UserDefaults.standard.double(forKey: "longBreakDuration")
        return (min > 0 ? min : 5) * 60
    }
    var extendedBreakDuration: TimeInterval {
        let min = UserDefaults.standard.double(forKey: "extendedBreakDuration")
        return (min > 0 ? min : 45) * 60
    }
    var sessionsBeforeLongBreak: Int {
        let val = UserDefaults.standard.integer(forKey: "sessionsBeforeLongBreak")
        return val > 0 ? val : 4
    }
}

enum NotchTab: String, CaseIterable {
    case timer = "Focus"
    case music = "Music"
    case settings = "Settings"

    var iconName: String {
        switch self {
        case .timer: return "timer"
        case .music: return "music.note"
        case .settings: return "gearshape"
        }
    }
}

struct YandexMusicCredentials: Codable {
    var token: String
    var userId: String?
}
