import Cocoa
import SwiftUI
import Combine

class NotchWindowController: NSWindowController {
    let viewModel: NotchViewModel
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var miniTimerWindow: NSWindow?
    private var miniTimerHostingView: NSHostingView<MiniTimerView>?
    private var coffeeIconWindow: NSWindow?
    private var focusIconWindow: NSWindow?

    private var screenMidX: CGFloat = 0
    private var screenTopY: CGFloat = 0
    private var screenFrame: NSRect = .zero
    private var notchRegion: NSRect = .zero
    private var isInitialPositionSet = false
    private var pillHeight: CGFloat = 32

    private init(window: NSWindow, viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init(window: window)
        observeState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func create() -> NotchWindowController {
        let viewModel = NotchViewModel()
        let window = NotchWindow()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.styleMask = [.borderless, .nonactivatingPanel]
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovable = false
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false

        let hostingController = NSHostingController(rootView: NotchRootView(viewModel: viewModel))
        window.contentViewController = hostingController

        let controller = NotchWindowController(window: window, viewModel: viewModel)
        controller.setupInitialPosition()
        controller.setupMouseMonitoring()
        controller.setupMiniTimer()

        NotificationCenter.default.addObserver(
            controller,
            selector: #selector(updatePosition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        return controller
    }

    deinit {
        removeEventMonitors()
        miniTimerWindow?.orderOut(nil)
        coffeeIconWindow?.orderOut(nil)
        focusIconWindow?.orderOut(nil)
    }

    private func setupInitialPosition() {
        guard let screen = NSScreen.main else { return }
        screenMidX = screen.frame.midX
        screenTopY = screen.frame.maxY
        screenFrame = screen.frame

        let safeTop = screen.safeAreaInsets.top
        pillHeight = safeTop
        let notchWidth: CGFloat = 200
        notchRegion = NSRect(
            x: screenMidX - notchWidth / 2,
            y: screenTopY - safeTop,
            width: notchWidth,
            height: safeTop
        )

        let initialW: CGFloat = 2
        let initialH: CGFloat = 2
        window?.setFrame(
            NSRect(x: screenMidX - initialW / 2, y: screenTopY - initialH, width: initialW, height: initialH),
            display: false
        )
        window?.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isInitialPositionSet = true
            self?.checkMousePosition()
            self?.updateMiniWindows()
        }
    }

    private func setupMiniTimer() {
        let pVM = viewModel.pomodoroViewModel
        let safeTop = NSScreen.main?.safeAreaInsets.top ?? 32
        pillHeight = safeTop
        let cornerR: CGFloat = 14

        let timerWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: pillHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        timerWindow.isOpaque = false
        timerWindow.backgroundColor = .clear
        timerWindow.hasShadow = false
        timerWindow.level = .popUpMenu
        timerWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        timerWindow.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: MiniTimerView(viewModel: pVM, cornerRadius: cornerR, width: 300))
        timerWindow.contentView = hostingView
        miniTimerHostingView = hostingView
        miniTimerWindow = timerWindow

        let coffeeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 32, height: pillHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        coffeeWindow.isOpaque = false
        coffeeWindow.backgroundColor = .clear
        coffeeWindow.hasShadow = false
        coffeeWindow.level = .popUpMenu
        coffeeWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        coffeeWindow.ignoresMouseEvents = true
        coffeeWindow.contentView = NSHostingView(rootView: CoffeeIconView(cornerRadius: cornerR))
        coffeeIconWindow = coffeeWindow

        let focusWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 32, height: pillHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        focusWindow.isOpaque = false
        focusWindow.backgroundColor = .clear
        focusWindow.hasShadow = false
        focusWindow.level = .popUpMenu
        focusWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        focusWindow.ignoresMouseEvents = true
        focusWindow.contentView = NSHostingView(rootView: FocusIconView(musicViewModel: viewModel.musicViewModel, cornerRadius: cornerR))
        focusIconWindow = focusWindow

        Publishers.CombineLatest3(
            viewModel.$notchState,
            pVM.$isRunning,
            pVM.$state
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.updateMiniWindows()
        }
        .store(in: &cancellables)
    }

    private func updateMiniWindows() {
        guard let timerWindow = miniTimerWindow,
              let coffeeWindow = coffeeIconWindow,
              let focusWindow = focusIconWindow else { return }

        let running = viewModel.pomodoroViewModel.isRunning
        let showPills = running && viewModel.notchState != .expanded
        let onBreak = viewModel.pomodoroViewModel.isOnBreak
        let height = pillHeight

        if showPills {
            let timerFrame = NSRect(x: screenMidX - 150, y: screenTopY - height, width: 300, height: height)
            timerWindow.setFrame(timerFrame, display: true)
            miniTimerHostingView?.frame = NSRect(x: 0, y: 0, width: 300, height: height)
            timerWindow.orderFrontRegardless()
        } else {
            timerWindow.orderOut(nil)
        }

        let iconFrame = NSRect(x: screenMidX + 150 - 26, y: screenTopY - height, width: 32, height: height)
        if showPills && onBreak {
            coffeeWindow.setFrame(iconFrame, display: true)
            coffeeWindow.orderFrontRegardless()
            focusWindow.orderOut(nil)
        } else if showPills {
            focusWindow.setFrame(iconFrame, display: true)
            focusWindow.orderFrontRegardless()
            coffeeWindow.orderOut(nil)
        } else {
            coffeeWindow.orderOut(nil)
            focusWindow.orderOut(nil)
        }
    }

    private func setupMouseMonitoring() {
        removeEventMonitors()

        let mouseMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseMask) { [weak self] _ in
            self?.checkMousePosition()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseMask) { [weak self] event in
            self?.checkMousePosition()
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, viewModel.notchState == .expanded else { return }
            guard let windowFrame = window?.frame else { return }
            if !windowFrame.contains(NSEvent.mouseLocation) {
                viewModel.collapseNotch()
            }
        }

        viewModel.pomodoroViewModel.$isRunning
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkMousePosition()
            }
            .store(in: &cancellables)
    }

    private func removeEventMonitors() {
        [globalClickMonitor, globalMouseMonitor, localMouseMonitor].compactMap { $0 }.forEach {
            NSEvent.removeMonitor($0)
        }
        globalClickMonitor = nil
        globalMouseMonitor = nil
        localMouseMonitor = nil
    }

    private var hoverDetectionRegion: NSRect {
        if viewModel.pomodoroViewModel.isRunning {
            return NSRect(
                x: screenMidX - 150,
                y: screenTopY - notchRegion.height,
                width: 306,
                height: notchRegion.height
            )
        }
        return notchRegion
    }

    private func checkMousePosition() {
        guard isInitialPositionSet else { return }

        let isInRegion = hoverDetectionRegion.contains(NSEvent.mouseLocation)
        switch viewModel.notchState {
        case .collapsed where isInRegion:
            viewModel.hoverEnter()
        case .hovering where !isInRegion:
            viewModel.hoverExit()
        default:
            break
        }
    }

    private func observeState() {
        viewModel.$notchState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.onStateChanged(state)
            }
            .store(in: &cancellables)
    }

    private func onStateChanged(_ state: NotchState) {
        guard let window = window, isInitialPositionSet else { return }

        switch state {
        case .collapsed:
            let newFrame = NSRect(x: screenMidX - 1, y: screenTopY - 1, width: 2, height: 2)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
                window.animator().setFrame(newFrame, display: true)
                window.animator().alphaValue = 0
            }

        case .hovering:
            let safeTop = NSScreen.main?.safeAreaInsets.top ?? 32
            let h = safeTop + 8
            let isTimerActive = viewModel.pomodoroViewModel.isRunning
            let w: CGFloat = isTimerActive ? 306 : 220
            let x = isTimerActive ? screenMidX - 150 : screenMidX - w / 2
            let hoverFrame = NSRect(x: x, y: screenTopY - h, width: w, height: h)
            if let cv = window.contentViewController?.view {
                cv.wantsLayer = true
                cv.layer?.cornerRadius = 16
                cv.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                cv.layer?.masksToBounds = true
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1.0)
                window.animator().setFrame(hoverFrame, display: true)
                window.animator().alphaValue = 1
            }
            recreateTrackingArea()

        case .expanded:
            window.alphaValue = 1
            let expandedW = viewModel.expandedWidth
            let expandedH = viewModel.expandedHeight
            let fullFrame = NSRect(
                x: screenMidX - expandedW / 2,
                y: screenTopY - expandedH,
                width: expandedW,
                height: expandedH
            )
            if let cv = window.contentViewController?.view {
                cv.wantsLayer = true
                cv.layer?.cornerRadius = 16
                cv.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                cv.layer?.masksToBounds = true
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
                window.animator().setFrame(fullFrame, display: true)
            } completionHandler: {
                self.recreateTrackingArea()
            }
        }
    }

    private func recreateTrackingArea() {
        guard let contentView = window?.contentView else { return }
        for area in contentView.trackingAreas {
            contentView.removeTrackingArea(area)
        }
        let w = window?.frame.width ?? 200
        let h = window?.frame.height ?? 40
        let trackingArea = NSTrackingArea(
            rect: NSRect(x: -120, y: -20, width: w + 240, height: h + 60),
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
    }

    @objc private func updatePosition() {
        setupInitialPosition()
        updateMiniWindows()
    }
}

class NotchWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard let wc = windowController as? NotchWindowController else { return }
        let state = wc.viewModel.notchState
        if state == .hovering || state == .collapsed {
            wc.viewModel.toggleNotch()
        }
    }
}
