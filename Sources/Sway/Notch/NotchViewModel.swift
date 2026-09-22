import SwiftUI
import Combine

class NotchViewModel: ObservableObject {
    @Published var notchState: NotchState = .collapsed
    @Published var selectedTab: NotchTab = .timer

    let pomodoroViewModel = PomodoroViewModel()
    let musicViewModel = MusicViewModel()
    let clipboardManager = ClipboardScreenshotManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        $selectedTab
            .combineLatest($notchState)
            .sink { [weak self] tab, state in
                guard tab == .manager, state == .expanded else { return }
                self?.clipboardManager.pollNow()
            }
            .store(in: &cancellables)
    }

    func toggleNotch() {
        switch notchState {
        case .hovering:
            expandNotch()
        case .expanded:
            collapseNotch()
        case .collapsed:
            break
        }
    }

    func expandNotch() {
        notchState = .expanded
    }

    func collapseNotch() {
        notchState = .collapsed
    }

    func hoverEnter() {
        if notchState == .collapsed {
            notchState = .hovering
        }
    }

    func hoverExit() {
        if notchState == .hovering {
            notchState = .collapsed
        }
    }

    var hoveringWidth: CGFloat { 200 }
    var hoveringHeight: CGFloat { 42 }

    var expandedWidth: CGFloat { 520 }
    var expandedHeight: CGFloat { 110 }
}
