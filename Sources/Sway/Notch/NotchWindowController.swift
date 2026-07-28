import Cocoa
import SwiftUI
import Combine

class NotchWindowController: NSWindowController {
    let viewModel: NotchViewModel
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var miniTimerWindow: NSWindow?
    private var miniTimerHostingView: NSHostingView<MiniTimerView>?
    private var coffeeIconWindow: NSWindow?
    private var focusIconWindow: NSWindow?

    private var screenMidX: CGFloat = 0
    private var screenTopY: CGFloat = 0
    private var screenFrame: NSRect = .zero
    private var notchRegion: NSRect = .zero
    private var isInitialPositionSet = false

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
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
        }

        setupMouseMonitoring()
    }

    private func setupMiniTimer() {
        let pVM = viewModel.pomodoroViewModel
        let safeTop = NSScreen.main?.safeAreaInsets.top ?? 32
        let pillHeight = safeTop
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

        Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let notchState = viewModel.notchState

                let timerVisible = pVM.isRunning && notchState != .expanded
                if timerVisible {
                    let w: CGFloat = 300
                    let h: CGFloat = pillHeight
                    let x = screenMidX - 150
                    let y = screenTopY - h
                    timerWindow.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
                    miniTimerHostingView?.frame = NSRect(x: 0, y: 0, width: w, height: h)
                    timerWindow.orderFrontRegardless()
                } else {
                    timerWindow.orderOut(nil)
                }

                let coffeeVisible = pVM.isRunning && pVM.isOnBreak && notchState != .expanded
                if coffeeVisible {
                    let w: CGFloat = 32
                    let h: CGFloat = pillHeight
                    let x = screenMidX + 150 - 26
                    let y = screenTopY - h
                    coffeeWindow.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
                    coffeeWindow.orderFrontRegardless()
                } else {
                    coffeeWindow.orderOut(nil)
                }

                let focusVisible = pVM.isRunning && !pVM.isOnBreak && notchState != .expanded
                if focusVisible {
                    let w: CGFloat = 32
                    let h: CGFloat = pillHeight
                    let x = screenMidX + 150 - 26
                    let y = screenTopY - h
                    focusWindow.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
                    focusWindow.orderFrontRegardless()
                } else {
                    focusWindow.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }

    private func setupMouseMonitoring() {
        Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkMousePosition()
            }
            .store(in: &cancellables)

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, viewModel.notchState == .expanded else { return }
            guard let windowFrame = window?.frame else { return }
            let clickLocation = NSEvent.mouseLocation
            if !windowFrame.contains(clickLocation) {
                viewModel.collapseNotch()
            }
        }
    }

    private func checkMousePosition() {
        guard isInitialPositionSet else { return }

        let mouseLocation = NSEvent.mouseLocation
        let pVM = viewModel.pomodoroViewModel

        var detectionRegion = notchRegion
        if pVM.isRunning {
            let timerRect = NSRect(
                x: screenMidX - 150,
                y: screenTopY - notchRegion.height,
                width: 306,
                height: notchRegion.height
            )
            detectionRegion = timerRect
        }

        let isInRegion = detectionRegion.contains(mouseLocation)

        if viewModel.notchState == .collapsed && isInRegion {
            viewModel.hoverEnter()
        } else if viewModel.notchState == .hovering && !isInRegion {
            viewModel.hoverExit()
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
