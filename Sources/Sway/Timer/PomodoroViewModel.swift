import SwiftUI
import Combine

class PomodoroViewModel: ObservableObject {
    @Published var state: PomodoroState = .idle
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var currentSession: Int = 0
    @Published var totalSessions: Int = 0
    @Published var isRunning = false

    var config = PomodoroConfig()

    private var timer: AnyCancellable?
    private var lastTickTime: Date?

    // cached values from when the current session started, for detecting config changes
    private var sessionWorkDuration: TimeInterval = 0
    private var sessionCoffeeBreak: TimeInterval = 0
    private var sessionExtendedBreak: TimeInterval = 0

    private var configSyncCancellable: AnyCancellable?

    init() {
        configSyncCancellable = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.syncConfig()
            }
    }

    private func syncConfig() {
        guard !isRunning else { return }

        let currentWork = config.workDuration
        let currentCoffee = config.longBreakDuration
        let currentExtended = config.extendedBreakDuration

        var changed = false

        switch state {
        case .idle:
            changed = true
        case .working:
            if abs(sessionWorkDuration - currentWork) > 0.5 {
                timeRemaining = currentWork
                sessionWorkDuration = currentWork
                changed = true
            }
        case .break_:
            if abs(sessionCoffeeBreak - currentCoffee) > 0.5 {
                timeRemaining = currentCoffee
                sessionCoffeeBreak = currentCoffee
                changed = true
            }
        case .longBreak:
            if abs(sessionExtendedBreak - currentExtended) > 0.5 {
                timeRemaining = currentExtended
                sessionExtendedBreak = currentExtended
                changed = true
            }
        }

        if changed {
            objectWillChange.send()
        }
    }

    private func cacheCurrentConfig() {
        sessionWorkDuration = config.workDuration
        sessionCoffeeBreak = config.longBreakDuration
        sessionExtendedBreak = config.extendedBreakDuration
    }

    var progress: Double {
        let total = totalTimeForCurrentState
        guard total > 0 else { return 0 }
        let remaining = state == .idle ? total : timeRemaining
        return 1 - (remaining / total)
    }

    private var totalTimeForCurrentState: TimeInterval {
        switch state {
        case .idle: return config.workDuration
        case .working: return config.workDuration
        case .break_: return config.longBreakDuration
        case .longBreak: return config.extendedBreakDuration
        }
    }

    var formattedTime: String {
        let displayTime = state == .idle ? config.workDuration : timeRemaining
        let minutes = Int(displayTime) / 60
        let seconds = Int(displayTime) % 60
        return "\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
    }

    var isOnBreak: Bool { state == .break_ || state == .longBreak }

    var stateLabel: String {
        switch state {
        case .idle: return tr("Ready to Focus")
        case .working: return tr("Focus Session %d", currentSession + 1)
        case .break_: return tr("Coffee break")
        case .longBreak: return tr("Long Break")
        }
    }

    func start() {
        if state == .idle {
            state = .working
            currentSession = 0
            cacheCurrentConfig()
            timeRemaining = sessionWorkDuration
        }
        if UserDefaults.standard.bool(forKey: "soundAlerts") {
            NSSound(named: "Bottle")?.play()
        }
        startTimer()
    }

    func pause() {
        timer?.cancel()
        timer = nil
        lastTickTime = nil
        isRunning = false
    }

    func reset() {
        guard state != .idle else { return }
        pause()
        state = .idle
        timeRemaining = config.workDuration
        currentSession = 0
        totalSessions = 0
    }

    func startBreak() {
        pause()
        state = .break_
        cacheCurrentConfig()
        timeRemaining = sessionCoffeeBreak
        if UserDefaults.standard.bool(forKey: "soundAlerts") {
            NSSound(named: "Blow")?.play()
        }
        startTimer()
    }

    func skip() {
        pause()
        moveToNextState()
        if state != .idle {
            startTimer()
        }
    }

    private func startTimer() {
        lastTickTime = Date()
        isRunning = true
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        let now = Date()
        guard let lastTick = lastTickTime else {
            lastTickTime = now
            return
        }

        let elapsed = now.timeIntervalSince(lastTick)
        lastTickTime = now

        let newRemaining = max(0, timeRemaining - elapsed)
        timeRemaining = newRemaining

        if newRemaining <= 0 {
            pause()
            completeCurrentState()
        }
    }

    private func completeCurrentState() {
        NSSound.beep()

        switch state {
        case .working:
            totalSessions += 1
            moveToNextState()
        case .break_, .longBreak:
            moveToNextState()
        default:
            break
        }

        if state == .idle {
        }

        if state != .idle {
            startTimer()
        }
    }

    private func moveToNextState() {
        switch state {
        case .idle:
            state = .working
            cacheCurrentConfig()
            timeRemaining = sessionWorkDuration
        case .working:
            currentSession += 1
            if currentSession % config.sessionsBeforeLongBreak == 0 {
                state = .longBreak
                cacheCurrentConfig()
                timeRemaining = sessionExtendedBreak
            } else {
                state = .break_
                cacheCurrentConfig()
                timeRemaining = sessionCoffeeBreak
            }
        case .break_, .longBreak:
            state = .working
            cacheCurrentConfig()
            timeRemaining = sessionWorkDuration
        }
    }
}


