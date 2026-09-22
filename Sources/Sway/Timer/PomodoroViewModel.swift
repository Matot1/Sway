import SwiftUI
import Combine

class PomodoroViewModel: ObservableObject {
    @Published var state: PomodoroState = .idle
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var currentSession: Int = 0
    @Published var totalSessions: Int = 0
    @Published var isRunning = false

    var config = PomodoroConfig()

    private var timer: Timer?
    private var endDate: Date?

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

    deinit {
        timer?.invalidate()
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
        let totalSeconds = Self.displaySeconds(displayTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
    }

    private static func displaySeconds(_ time: TimeInterval) -> Int {
        guard time > 0 else { return 0 }
        return Int(ceil(time))
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
        if let endDate {
            timeRemaining = max(0, endDate.timeIntervalSinceNow)
        }
        timer?.invalidate()
        timer = nil
        endDate = nil
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
        timer?.invalidate()
        endDate = Date().addingTimeInterval(timeRemaining)
        isRunning = true
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        timer?.invalidate()
        guard let endDate else { return }

        let remaining = endDate.timeIntervalSinceNow
        if remaining <= 0 {
            tick()
            return
        }

        let fraction = remaining - floor(remaining)
        let delay = fraction > 0.0005 ? fraction : 1.0
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let endDate else { return }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        if Self.displaySeconds(remaining) != Self.displaySeconds(timeRemaining) || remaining <= 0 {
            timeRemaining = remaining
        }
        if remaining <= 0 {
            pause()
            completeCurrentState()
            return
        }
        scheduleNextTick()
    }

    private func completeCurrentState() {
        if UserDefaults.standard.bool(forKey: "soundAlerts") {
            NSSound.beep()
        }

        switch state {
        case .working:
            totalSessions += 1
            if UserDefaults.standard.bool(forKey: "autoStartBreak") {
                moveToNextState()
            } else {
                currentSession += 1
                cacheCurrentConfig()
                timeRemaining = sessionWorkDuration
                return
            }
        case .break_, .longBreak:
            moveToNextState()
        default:
            break
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


